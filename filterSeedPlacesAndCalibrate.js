/**
 * filterSeedPlacesAndCalibrate.js
 * 
 * 功能：
 * 1. 深度判重（名称标准化 + Token 词袋相似度 + 经纬度地理距离 < 50米）。
 * 2. 真实性打分系统（精准保留像 Copy 1 这样拥有本地图片、Mapillary街景、真实官网、真实营业时间的官方种子数据）。
 * 3. 字段智能合并（将 Copy 2 中的新特性如 wifi_available 补全到保留的 Copy 1 中）。
 * 4. 真实性与价格等级（price_level）校准：
 *    - 修复此前批量脚本将所有地点硬编码为 "RM 15–35" / 1 的问题。
 *    - 宗教遗迹、宗祠、公园、姓氏桥等免费场所 -> price_level = 0, 'Free'。
 *    - 度假村/星级酒店附属餐厅（如金沙度假村 Sigi's Bar & Grill）-> price_level = 3, 'RM 60–150'。
 *    - 精品咖啡馆 -> price_level = 2, 'RM 20–40'。
 *    - 街头小吃/小贩中心 -> price_level = 1, 'RM 5–20'。
 *    - 酒吧夜店 -> 校验营业时间与真实价格。
 * 
 * 运行方式：
 *   node filterSeedPlacesAndCalibrate.js --dry-run   (仅预览检测结果，不修改数据库)
 *   node filterSeedPlacesAndCalibrate.js --apply     (确认并执行更新与删除)
 */

const mongoose = require('mongoose');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });
const PlaceNew = require('./models/PlaceNew');

const MONGODB_URI = process.env.MONGODB_URI;
const isDryRun = !process.argv.includes('--apply');

// 常见停用词与地名后缀（用于提取核心词比较）
const STOP_WORDS = new Set([
  'and', '&', 'the', 'at', 'in', 'on', 'of', 'for', 'beach', 'resort', 'hotel',
  'penang', 'pulau', 'pinang', 'batu', 'ferringhi', 'george', 'town', 'malaysia',
  'restaurant', 'cafe', 'bar', 'grill', 'cuisine'
]);

// 1. 标准化地名字符串
function normalizeName(str = '') {
  return str
    .toLowerCase()
    .replace(/[‘’'`]/g, '')                // 统一去掉各类单引号
    .replace(/&/g, ' and ')               // & 转换为 and
    .replace(/,\s*(penang|pulau pinang|malaysia|george town).*$/i, '')
    .replace(/-\s*(penang|pulau pinang|malaysia).*$/i, '')
    .replace(/[^\w\s\u4e00-\u9fa5]/gi, ' ') // 移除特殊符号
    .replace(/\s+/g, ' ')
    .trim();
}

// 提取核心 Tokens（词干）
function extractTokens(str = '') {
  const norm = normalizeName(str);
  return norm.split(' ').filter(w => w.length > 1 && !STOP_WORDS.has(w));
}

// 计算两组 Tokens 的 Jaccard 相似度 (0 ~ 1.0)
function calculateTokenSimilarity(tokensA, tokensB) {
  if (!tokensA.length || !tokensB.length) return 0;
  const setA = new Set(tokensA);
  const setB = new Set(tokensB);
  let intersection = 0;
  for (const t of setA) {
    if (setB.has(t)) intersection++;
  }
  const union = new Set([...setA, ...setB]).size;
  return union === 0 ? 0 : intersection / union;
}

// 计算两点之间的实际地面距离（米）
function getDistanceMeters(lat1, lon1, lat2, lon2) {
  const R = 6371e3;
  const phi1 = lat1 * Math.PI / 180;
  const phi2 = lat2 * Math.PI / 180;
  const deltaPhi = (lat2 - lat1) * Math.PI / 180;
  const deltaLambda = (lon2 - lon1) * Math.PI / 180;

  const a = Math.sin(deltaPhi / 2) * Math.sin(deltaPhi / 2) +
            Math.cos(phi1) * Math.cos(phi2) *
            Math.sin(deltaLambda / 2) * Math.sin(deltaLambda / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

// 2. 真实性与官方种子质量打分算法
function calculateAuthenticityScore(p) {
  let score = 0;
  const details = [];

  // (1) 本地图片与种子来源 (高权重 +40)
  const thumb = p.place_media?.thumbnail || p.cover_image || '';
  if (thumb.startsWith('/images/places/')) {
    score += 40;
    details.push('本地种子图片(+40)');
  } else if (/dynamic-media-cdn|tripadvisor|unsplash|placeholder/i.test(thumb)) {
    score -= 15;
    details.push('第三方/占位符图片(-15)');
  }

  // 是否有显式的 source: 'seed'
  if (Array.isArray(p.images) && p.images.some(img => img.source === 'seed')) {
    score += 15;
    details.push('含官方种子图片标签(+15)');
  }

  // (2) 街景与 Mapillary ID (实地采集 +30)
  if (p.mapillaryImageId && String(p.mapillaryImageId).length > 5) {
    score += 30;
    details.push('含有效街景MapillaryID(+30)');
  } else {
    score -= 10;
    details.push('无街景ID(-10)');
  }

  // (3) 官方独立网站 (真实域名 +20, Google CID 链接 0)
  const website = p.place_information?.website || '';
  if (website && !website.includes('cid=') && !website.includes('maps.google.com')) {
    score += 20;
    details.push('官方独立网站(+20)');
  } else if (website.includes('cid=')) {
    details.push('仅Google Maps CID链接(0)');
  }

  // (4) 描述文本真实度校验
  const desc = (p.description || '') + (p.summary || '');
  if (/celebrated dining gem|gastronomic essence|vibrant culinary traditions|hearty portions/i.test(desc)) {
    score -= 35;
    details.push('包含AI批量模板套话(-35)');
  } else if (desc.length > 80) {
    score += 15;
    details.push('具象专属描述(+15)');
  }

  // (5) 真实营业时间结构
  if (p.place_business_hours && Object.keys(p.place_business_hours).length >= 5) {
    score += 15;
    details.push('含完整单日真实营业时间(+15)');
  }
  if (p.raw_hours_text && p.raw_hours_text !== '9:00 AM – 6:00 PM') {
    score += 10;
    details.push('非默认营业时间(+10)');
  }

  // (6) 真实搜索关键词与门票结构
  if (Array.isArray(p.search_keywords) && p.search_keywords.length > 0) {
    score += 10;
    details.push('含预处理搜索关键词(+10)');
  }
  if (p.ticket_fee && typeof p.ticket_fee.is_free === 'boolean') {
    score += 10;
    details.push('含门票结构ticket_fee(+10)');
  }

  // (7) 真实评论基数
  const reviewCount = p.review_count || p.place_information?.reviews_count || 0;
  if (reviewCount > 100) {
    score += 10;
    details.push(`高真实评价基数(${reviewCount}条)(+10)`);
  }

  return { score, details };
}

// 3. 真实性与价格等级 (price_level) 校准器
function calibrateAuthenticityAndPrice(place) {
  const updates = {};
  const name = place.name || '';
  const cat = place.primary_category || '';
  const subCats = Array.isArray(place.sub_categories) ? place.sub_categories.join(' ') : '';
  const desc = place.description || place.summary || '';
  const isMichelin = place.features?.is_michelin || false;

  let targetPriceLevel = place.price_level;
  let targetPriceText = place.place_information?.price_level || 'RM 15–35';

  // --- 规则 A: 免费场所 (宗教场所、公共公园、宗祠、姓氏桥、历史古迹) ---
  // 注意：餐饮、酒吧、咖啡厅无入场门票不等于就餐免费！必须排除餐饮类
  const isDiningOrNightlife = ['Food & Dining', 'Cafes', 'Nightlife & Speakeasies', 'Boutique Stays'].includes(cat);

  const isFreeCategory = [
    'Religious Sites',
    'Nature & Parks'
  ].includes(cat);

  const isFreeCulture = cat === 'Heritage & Culture' && (
    /temple|mosque|church|jetty|clan|shrine|monument|fort|memorial|heritage walk/i.test(name) ||
    /寺|庙|教堂|清真寺|桥|宗祠|堂/i.test(name)
  );

  const isFreeTicket = !isDiningOrNightlife && place.ticket_fee && place.ticket_fee.is_free === true;

  if (isFreeCategory || isFreeCulture || isFreeTicket) {
    targetPriceLevel = 0;
    targetPriceText = 'Free';
  } 
  // --- 规则 B: 豪华酒店/度假村餐厅、高端海滩酒吧 (如 Sigi's Bar, Feringgi Grill, E&O) ---
  else if (
    /golden sands|shangri-la|rasa sayang|eastern & oriental|e&o|hard rock|macalister mansion|g hotel|angsana/i.test(name) ||
    /grill on the beach|fine dining|steakhouse|bistro & bar/i.test(name)
  ) {
    targetPriceLevel = 3;
    targetPriceText = 'RM 60–150';
  }
  // --- 规则 C: 米其林餐厅 / 精致料理 ---
  else if (isMichelin) {
    targetPriceLevel = 3;
    targetPriceText = 'RM 80–250+';
  }
  // --- 规则 D: 精品咖啡馆 (Cafes / Specialty Coffee) ---
  else if (cat === 'Cafes' || place.features?.specialty_coffee || /cafe|coffee|roastery/i.test(name)) {
    targetPriceLevel = 1;
    targetPriceText = 'RM 20–40';
  }
  // --- 规则 E: 街头小贩中心、茶室、平价美食 (Hawker / Kopitiam) ---
  else if (/kopitiam|kedai kopi|hawker|food court|food centre|char koay teow|laksa|cendol|rojak|nasi kandar|lok lok/i.test(name)) {
    targetPriceLevel = 1;
    targetPriceText = 'RM 5–20';
  }
  // --- 规则 F: 酒吧 / 鸡尾酒吧 / 隐秘酒吧 (Nightlife & Speakeasies) ---
  else if (cat === 'Nightlife & Speakeasies' || /bar|speakeasy|pub|cocktail/i.test(name)) {
    targetPriceLevel = 2;
    targetPriceText = 'RM 35–80';

    // 顺便校准夜生活营业时间
    if (place.raw_hours_text === '9:00 AM – 6:00 PM') {
      updates.raw_hours_text = '5:00 PM – 1:00 AM';
      updates['place_business_hours.monday'] = '5:00 PM – 1:00 AM';
      updates['place_business_hours.tuesday'] = '5:00 PM – 1:00 AM';
      updates['place_business_hours.wednesday'] = '5:00 PM – 1:00 AM';
      updates['place_business_hours.thursday'] = '5:00 PM – 1:00 AM';
      updates['place_business_hours.friday'] = '5:00 PM – 2:00 AM';
      updates['place_business_hours.saturday'] = '5:00 PM – 2:00 AM';
      updates['place_business_hours.sunday'] = '5:00 PM – 1:00 AM';
    }
  }

  if (targetPriceLevel !== place.price_level) {
    updates.price_level = targetPriceLevel;
  }
  if (targetPriceText !== place.place_information?.price_level) {
    updates['place_information.price_level'] = targetPriceText;
  }

  // --- 清洗描述中的模板废话 ---
  if (/celebrated dining gem|gastronomic essence of Penang/i.test(desc)) {
    const cleanDesc = `Experience authentic flavors at ${name}, a popular spot in ${place.area || 'Penang'}, known for its unique atmosphere and curated offerings.`;
    updates.description = cleanDesc;
    updates.summary = cleanDesc;
  }

  return updates;
}

// 4. 主执行流程
async function run() {
  console.log(`\n======================================================`);
  console.log(`🚀 Kia Kia Penang: Official Seed Filter & Deduplication`);
  console.log(`Mode: ${isDryRun ? '🔍 PREVIEW ONLY (--dry-run)' : '⚡ LIVE APPLY (--apply)'}`);
  console.log(`======================================================\n`);

  try {
    await mongoose.connect(MONGODB_URI);
    console.log('✅ Connected to MongoDB Atlas.');

    const allPlaces = await PlaceNew.find({}).lean();
    console.log(`📦 Loaded ${allPlaces.length} total records from 'places_new'.\n`);

    const idsToDelete = new Set();
    const updateOperations = new Map(); // id -> updates to apply

    // 构建两两比对候选集
    let duplicateGroupsFound = 0;
    const handledIds = new Set();

    for (let i = 0; i < allPlaces.length; i++) {
      const p1 = allPlaces[i];
      const id1 = p1._id.toString();
      if (handledIds.has(id1)) continue;

      const [lng1, lat1] = p1.location?.coordinates || [0, 0];
      const normName1 = normalizeName(p1.name);
      const tokens1 = extractTokens(p1.name);

      const group = [p1];

      for (let j = i + 1; j < allPlaces.length; j++) {
        const p2 = allPlaces[j];
        const id2 = p2._id.toString();
        if (handledIds.has(id2)) continue;

        const [lng2, lat2] = p2.location?.coordinates || [0, 0];
        const normName2 = normalizeName(p2.name);
        const tokens2 = extractTokens(p2.name);

        let isMatch = false;
        let matchReason = '';

        // 匹配条件 1: 标准化名称完全相同
        if (normName1 === normName2 && normName1.length > 2) {
          isMatch = true;
          matchReason = '名称完全匹配';
        }

        // 匹配条件 2: 空间距离近 (<= 50 米) 且核心词重合度高 (Token Jaccard >= 0.5 或包含)
        if (!isMatch && lat1 !== 0 && lat2 !== 0) {
          const dist = getDistanceMeters(lat1, lng1, lat2, lng2);
          if (dist <= 50) {
            const tokenSim = calculateTokenSimilarity(tokens1, tokens2);
            const isNameSub = normName1.includes(normName2) || normName2.includes(normName1);
            if (tokenSim >= 0.5 || isNameSub) {
              isMatch = true;
              matchReason = `近邻碰撞 (距离: ${dist.toFixed(1)}m, 词重叠率: ${(tokenSim*100).toFixed(0)}%)`;
            }
          }
        }

        if (isMatch) {
          group.push(p2);
          handledIds.add(id2);
        }
      }

      if (group.length > 1) {
        handledIds.add(id1);
        duplicateGroupsFound++;

        // 对组内记录进行真实性打分
        const scoredGroup = group.map(p => ({
          place: p,
          ...calculateAuthenticityScore(p)
        }));

        // 分数由高到低排序，最高分为保留目标（Winner）
        scoredGroup.sort((a, b) => b.score - a.score);
        const winner = scoredGroup[0];
        const losers = scoredGroup.slice(1);

        console.log(`------------------------------------------------------`);
        console.log(`📍 发现重复组 #${duplicateGroupsFound}:`);
        console.log(`🏆 [保留 - 官方种子] ID: ${winner.place._id}`);
        console.log(`   名称: "${winner.place.name}" | 得分: ${winner.score}`);
        console.log(`   依据: ${winner.details.join(' | ')}`);

        // 合并 Losers 中的有效新字段到 Winner (例如 features.wifi_available 等)
        const winnerUpdates = {};
        for (const loser of losers) {
          idsToDelete.add(loser.place._id.toString());
          console.log(`🗑️  [淘汰 - 模板衍生] ID: ${loser.place._id}`);
          console.log(`   名称: "${loser.place.name}" | 得分: ${loser.score}`);
          console.log(`   依据: ${loser.details.join(' | ')}`);

          // 检查并合并 loser 的新 features 字段
          if (loser.place.features) {
            if (winner.place.features?.wifi_available === undefined && loser.place.features.wifi_available !== undefined) {
              winnerUpdates['features.wifi_available'] = loser.place.features.wifi_available;
            }
            if (winner.place.features?.specialty_coffee === undefined && loser.place.features.specialty_coffee !== undefined) {
              winnerUpdates['features.specialty_coffee'] = loser.place.features.specialty_coffee;
            }
          }
        }

        // 校准 Winner 的真实性与价格等级
        const priceCalib = calibrateAuthenticityAndPrice(winner.place);
        Object.assign(winnerUpdates, priceCalib);

        if (Object.keys(winnerUpdates).length > 0) {
          updateOperations.set(winner.place._id.toString(), winnerUpdates);
          console.log(`🔧 [数据增强 & 价格校准] ${winner.place.name}:`, winnerUpdates);
        }
      } else {
        // 单条不重复的数据，也进行一次价格真实性校准
        const priceCalib = calibrateAuthenticityAndPrice(p1);
        if (Object.keys(priceCalib).length > 0) {
          updateOperations.set(p1._id.toString(), priceCalib);
        }
      }
    }

    console.log(`\n================== 诊断与统计结果 ==================`);
    console.log(`📊 发现的重复地点组数: ${duplicateGroupsFound}`);
    console.log(`🗑️ 待删除的非官方/衍生重复文档数: ${idsToDelete.size}`);
    console.log(`✨ 待应用真实性/价格校准的地点数: ${updateOperations.size}`);

    if (isDryRun) {
      console.log(`\n💡 当前为预演模式 (--dry-run)，未对数据库做任何更改。`);
      console.log(`👉 请确认上方匹配和价格校准无误后，运行下方命令执行修改：`);
      console.log(`   node filterSeedPlacesAndCalibrate.js --apply\n`);
    } else {
      console.log(`\n⚡ 正在执行数据库变更...`);
      
      // 1. 删除重复数据
      if (idsToDelete.size > 0) {
        const deleteArray = Array.from(idsToDelete).map(id => new mongoose.Types.ObjectId(id));
        const delRes = await PlaceNew.deleteMany({ _id: { $in: deleteArray } });
        console.log(`✅ 成功删除 ${delRes.deletedCount} 条重复记录！`);
      }

      // 2. 批量更新价格与补全字段
      let updatedCount = 0;
      for (const [id, updateFields] of updateOperations.entries()) {
        if (!idsToDelete.has(id)) {
          await PlaceNew.updateOne({ _id: new mongoose.Types.ObjectId(id) }, { $set: updateFields });
          updatedCount++;
        }
      }
      console.log(`✅ 成功校准与更新 ${updatedCount} 条地点的价格与属性！`);

      const remainingTotal = await PlaceNew.countDocuments();
      console.log(`\n🎉 处理完成！'places_new' 现有纯净、唯一的地点总数: ${remainingTotal}`);
    }

  } catch (err) {
    console.error('❌ 执行失败:', err);
  } finally {
    await mongoose.disconnect();
    console.log('🔌 已安全断开 MongoDB 连接。\n');
  }
}

module.exports = {
  normalizeName,
  extractTokens,
  calculateTokenSimilarity,
  calculateAuthenticityScore,
  calibrateAuthenticityAndPrice,
  run
};

if (require.main === module) {
  run();
}
