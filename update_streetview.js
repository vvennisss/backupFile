/**
 * 脚本说明:
 * 智能街景匹配脚本 (A/B 测试支持):
 * 1. 采用多级渐进式半径搜索 (30m -> 80m -> 150m) 匹配 Mapillary 360° 全景图 (is_pano: true)。
 * 2. 若无全景图，自动降级匹配最近的普通街景图 (is_pano: false, MapillaryJS 同样支持交互预览)。
 * 3. 始终保留 Google 街景支持 (Google 会自动吸附到最近路网)。
 * 4. 支持 `--force` 参数重新扫描之前被标记为 false 的地点。
 */

const path = require('path');
// 加载 .env 环境变量
require('dotenv').config({ path: path.resolve(__dirname, './.env') });
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });

const mongoose = require('mongoose');
const axios = require('axios');

// =================== 配置区域 ===================
const MONGO_URI = process.env.MONGODB_URI || process.env.MONGO_URI || process.env.MONGO_URL;
const MAPILLARY_ACCESS_TOKEN = process.env.MAPILLARY_ACCESS_TOKEN || 'MLY|YOUR_MAPILLARY_CLIENT_TOKEN';

// 渐进式搜索半径梯度 (单位: 经纬度差值，0.0003 ≈ 33m, 0.0008 ≈ 88m, 0.0014 ≈ 150m)
const RADIUS_TIERS = [
  { name: '30m (精准)', delta: 0.0003 },
  { name: '80m (周边道路)', delta: 0.0008 },
  { name: '150m (扩展道路)', delta: 0.0014 }
];

const API_DELAY_MS = 200; // 请求防抖
// ================================================

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

// 计算两点之间的近似几何距离平方
function getDistanceSq(lng1, lat1, lng2, lat2) {
  const dLng = lng1 - lng2;
  const dLat = lat1 - lat2;
  return dLng * dLng + dLat * dLat;
}

// 提取坐标
function extractCoordinates(place) {
  if (place.place_location && Array.isArray(place.place_location.coordinates) && place.place_location.coordinates.length >= 2) {
    return {
      lng: Number(place.place_location.coordinates[0]),
      lat: Number(place.place_location.coordinates[1]),
    };
  }
  if (place.location && Array.isArray(place.location.coordinates) && place.location.coordinates.length >= 2) {
    return {
      lng: Number(place.location.coordinates[0]),
      lat: Number(place.location.coordinates[1]),
    };
  }
  if (place.lat !== undefined && place.lng !== undefined) {
    return {
      lng: Number(place.lng),
      lat: Number(place.lat),
    };
  }
  return null;
}

// 逐级向 Mapillary 请求图片
async function findBestMapillaryImage(lat, lng, token) {
  let fallbackImage = null; // 备选的普通街景图

  for (const tier of RADIUS_TIERS) {
    const minLng = (lng - tier.delta).toFixed(6);
    const minLat = (lat - tier.delta).toFixed(6);
    const maxLng = (lng + tier.delta).toFixed(6);
    const maxLat = (lat + tier.delta).toFixed(6);
    const bbox = `${minLng},${minLat},${maxLng},${maxLat}`;

    const apiUrl = `https://graph.mapillary.com/images?fields=id,is_pano,geometry&bbox=${bbox}&limit=50&access_token=${token}`;

    try {
      const response = await axios.get(apiUrl, { timeout: 8000 });
      const images = response.data?.data || [];

      if (images.length === 0) continue;

      // 按距地点坐标的距离排序
      images.sort((a, b) => {
        const coordA = a.geometry?.coordinates || [0, 0];
        const coordB = b.geometry?.coordinates || [0, 0];
        return getDistanceSq(coordA[0], coordA[1], lng, lat) - getDistanceSq(coordB[0], coordB[1], lng, lat);
      });

      // 1. 优先寻找 360° 全景图
      const pano = images.find((img) => img.is_pano === true);
      if (pano) {
        return {
          id: pano.id,
          isPano: true,
          tierName: tier.name
        };
      }

      // 2. 记录最近的普通街景照片作为备选
      if (!fallbackImage && images.length > 0) {
        fallbackImage = {
          id: images[0].id,
          isPano: false,
          tierName: `${tier.name} (普通街景照片)`
        };
      }
    } catch (err) {
      // 记录单个级别请求异常并继续尝试下一个级别
      const msg = err.response?.data?.error?.message || err.message;
      if (msg.includes('rate limit') || msg.includes('access token')) {
        throw new Error(msg); // 关键错误直接抛出
      }
    }
  }

  // 若无全景，返回最佳普通街景（若有）
  return fallbackImage;
}

async function runStreetViewSync() {
  if (!MONGO_URI) {
    console.error('❌ 致命错误: 未找到 MONGODB_URI，请检查 .env 文件是否配置正确。');
    return;
  }

  const isForce = process.argv.includes('--force') || process.argv.includes('-f');

  try {
    console.log('🔄 正在连接至 MongoDB Atlas...');
    await mongoose.connect(MONGO_URI);
    console.log('✅ 成功连接到 MongoDB');

    const collection = mongoose.connection.collection('places');

    // 查询规则: --force 重新检查所有地点；否则仅检查未处理的地点
    const filter = isForce
      ? {}
      : {
          $or: [
            { hasStreetView: { $exists: false } },
            { hasStreetView: null }
          ]
        };

    const totalPlaces = await collection.countDocuments(filter);
    console.log(`🔍 模式: [${isForce ? '强制重扫所有地点 (--force)' : '增量扫描'}] | 待处理地点数: ${totalPlaces}\n`);

    if (totalPlaces === 0) {
      console.log('✨ 没有待处理的地点。提示：若需重新验证之前标记为 false 的地点，请运行: node update_streetview.js --force');
      return;
    }

    const cursor = collection.find(filter);

    let processedCount = 0;
    let panoFoundCount = 0;
    let fallbackFoundCount = 0;
    let googleOnlyCount = 0;

    while (await cursor.hasNext()) {
      const place = await cursor.next();
      processedCount++;

      const coords = extractCoordinates(place);
      const placeTitle = place.place_name || place.title || `ID: ${place._id}`;

      if (!coords || isNaN(coords.lat) || isNaN(coords.lng)) {
        console.warn(`[${processedCount}/${totalPlaces}] ⚠️ 跳过: 无有效坐标 -> ${placeTitle}`);
        await collection.updateOne(
          { _id: place._id },
          { $set: { hasStreetView: false, streetViewCheckNote: 'invalid_coordinates' } }
        );
        continue;
      }

      const { lat, lng } = coords;

      try {
        const match = await findBestMapillaryImage(lat, lng, MAPILLARY_ACCESS_TOKEN);

        if (match) {
          if (match.isPano) {
            panoFoundCount++;
            console.log(`[${processedCount}/${totalPlaces}] 🌐 [360°全景] -> ${placeTitle} | 命中: ${match.tierName} | ID: ${match.id}`);
          } else {
            fallbackFoundCount++;
            console.log(`[${processedCount}/${totalPlaces}] 📸 [街景照片] -> ${placeTitle} | 命中: ${match.tierName} | ID: ${match.id}`);
          }

          await collection.updateOne(
            { _id: place._id },
            {
              $set: {
                hasStreetView: true,
                mapillaryImageId: match.id,
                isPano: match.isPano,
                streetViewUpdatedAt: new Date(),
              },
            }
          );
        } else {
          // Mapillary 暂无影像，但地点具备坐标，仍然支持 Google Maps 外部街景 A/B 测试
          googleOnlyCount++;
          console.log(`[${processedCount}/${totalPlaces}] 🚗 [仅Google街景] -> ${placeTitle} (Mapillary 150m内无影像，已保留Google街景能力)`);
          await collection.updateOne(
            { _id: place._id },
            {
              $set: {
                hasStreetView: true, // 保留街景入口供 Google Maps 使用
                mapillaryImageId: null,
                isPano: false,
                streetViewUpdatedAt: new Date(),
              },
            }
          );
        }
      } catch (err) {
        console.error(`[${processedCount}/${totalPlaces}] 🚨 请求异常 (${placeTitle}):`, err.message);
      }

      // 限流防抖
      await sleep(API_DELAY_MS);
    }

    console.log(`\n================= 处理完成 =================`);
    console.log(`总共扫描地点: ${processedCount}`);
    console.log(`匹配到 Mapillary 360° 全景: ${panoFoundCount}`);
    console.log(`匹配到 Mapillary 街景照片: ${fallbackFoundCount}`);
    console.log(`无 Mapillary 但支持 Google 街景: ${googleOnlyCount}`);
    console.log(`============================================\n`);
  } catch (error) {
    console.error('❌ 数据库或运行时异常:', error);
  } finally {
    if (mongoose.connection.readyState !== 0) {
      await mongoose.disconnect();
      console.log('🔒 MongoDB 连接已安全关闭');
    }
  }
}

// 启动脚本
runStreetViewSync();