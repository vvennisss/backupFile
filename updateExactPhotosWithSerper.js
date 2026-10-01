const mongoose = require('mongoose');
const axios = require('axios');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });
const PlaceNew = require('./models/PlaceNew');

const MONGODB_URI = process.env.MONGODB_URI;
const SERPER_API_KEY = process.env.SERPER_API_KEY;

// 延时辅助函数（避免超频）
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function fetchGooglePhotoFromSerper(name, area) {
  // 1. 首选：Google Maps Places 接口（抓取真实商家/摊位在 Google Maps 上的实拍缩略图）
  try {
    const cleanName = name.replace(/[^\w\s\u4e00-\u9fa5]/gi, ' ').replace(/\s+/g, ' ').trim();
    const query = `${cleanName}, ${area || 'Penang'}, Penang`;

    const placesResp = await axios.post('https://google.serper.dev/places', {
      q: query,
      location: 'Penang, Malaysia'
    }, {
      headers: {
        'X-API-KEY': SERPER_API_KEY,
        'Content-Type': 'application/json'
      },
      timeout: 10000
    });

    const places = placesResp.data.places || [];
    if (places.length > 0 && places[0].thumbnailUrl) {
      return { url: places[0].thumbnailUrl, source: 'google_maps' };
    }
  } catch (err) {
    // 若 Places 搜索未中或超时，进入 Images 备选
  }

  // 2. 备选：Google Images 接口（针对路边摊、无认领小店抓取真实的现场实拍图）
  try {
    const cleanName = name.replace(/[^\w\s\u4e00-\u9fa5]/gi, ' ').replace(/\s+/g, ' ').trim();
    const query = `${cleanName} Penang`;

    const imagesResp = await axios.post('https://google.serper.dev/images', {
      q: query
    }, {
      headers: {
        'X-API-KEY': SERPER_API_KEY,
        'Content-Type': 'application/json'
      },
      timeout: 10000
    });

    const images = imagesResp.data.images || [];
    if (images.length > 0 && images[0].imageUrl) {
      return { url: images[0].imageUrl, source: 'google_images' };
    }
  } catch (err) {
    // 忽略异常
  }

  return null;
}

async function runBatchUpdate() {
  console.log('====================================================');
  console.log('🚀 Kia-Kia Penang: Serper API Exact Photos Updater');
  console.log('====================================================');

  if (!SERPER_API_KEY || SERPER_API_KEY.includes('YOUR_SERPER_API_KEY') || SERPER_API_KEY.trim() === '') {
    console.error('\n❌ 错误: 未检测到有效的 SERPER_API_KEY！');
    console.error('👉 请打开根目录下的 .env 文件:');
    console.error('   填入你在 serper.dev 注册获取的 API Key:');
    console.error('   SERPER_API_KEY=你的真实Key\n');
    process.exit(1);
  }

  try {
    console.log('🔄 正在连接 MongoDB Atlas...');
    await mongoose.connect(MONGODB_URI);
    console.log('✅ 数据库连接成功！');

    // 仅精准筛选使用 Unsplash 兜底图或无图的地点（绝不触碰已有本地实拍和现有实景图）
    const targetFilter = {
      $or: [
        { 'place_media.thumbnail': { $regex: /unsplash\.com/i } },
        { cover_image: { $regex: /unsplash\.com/i } },
        { 'place_media.thumbnail': { $exists: false } },
        { 'place_media.thumbnail': '' },
        { 'place_media.thumbnail': 'no_image_found' }
      ]
    };

    const totalToUpdate = await PlaceNew.countDocuments(targetFilter);
    console.log(`\n📦 发现待更新实拍图的地点数量: ${totalToUpdate} 条（已有真实实拍图的地点已全部自动跳过）\n`);

    if (totalToUpdate === 0) {
      console.log('🎉 所有地点已经拥有真实实拍照片，无需更新！');
      await mongoose.disconnect();
      return;
    }

    const places = await PlaceNew.find(targetFilter).select('_id name area cover_image');
    let successCount = 0;
    let mapsCount = 0;
    let imagesCount = 0;
    let failedCount = 0;

    for (let i = 0; i < places.length; i++) {
      const p = places[i];
      const progress = `[${i + 1}/${places.length}]`;

      process.stdout.write(`${progress} 正在检索: ${p.name} ... `);

      const result = await fetchGooglePhotoFromSerper(p.name, p.area);

      if (result && result.url) {
        await PlaceNew.updateOne(
          { _id: p._id },
          {
            $set: {
              cover_image: result.url,
              'place_media.thumbnail': result.url
            }
          }
        );

        successCount++;
        if (result.source === 'google_maps') mapsCount++;
        else imagesCount++;

        console.log(`✅ [${result.source}] 成功替换为真实照片！`);
      } else {
        failedCount++;
        console.log(`⚠️ 未检索到照片，保持原样。`);
      }

      // 请求间隔平滑流控（150ms）
      await sleep(150);
    }

    console.log('\n====================================================');
    console.log('🎉 批量替换完成统计报告:');
    console.log(`- 成功更新真实照片: ${successCount} 条`);
    console.log(`  └─ Google Maps 商家实拍: ${mapsCount} 条`);
    console.log(`  └─ Google Images 现场实拍: ${imagesCount} 条`);
    console.log(`- 未匹配跳过: ${failedCount} 条`);
    console.log('====================================================\n');

    await mongoose.disconnect();
    console.log('🔌 已安全断开数据库连接。');

  } catch (error) {
    console.error('❌ 执行过程中发生错误:', error.message);
    process.exit(1);
  }
}

runBatchUpdate();
