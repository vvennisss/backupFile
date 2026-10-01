const mongoose = require('mongoose');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });
const PlaceNew = require('./models/PlaceNew');

const MONGODB_URI = process.env.MONGODB_URI;

// 名字标准化处理（去除标点、多余空格和常见后缀噪音）
function cleanName(str = '') {
  return str
    .toLowerCase()
    .replace(/,\s*(penang|pulau pinang|malaysia|george town).*$/i, '')
    .replace(/[^\w\s\u4e00-\u9fa5]/gi, ' ') // 保留中英文和数字
    .replace(/\s+/g, ' ')
    .trim();
}

// 计算两点之间的近似距离（米）
function getDistanceMeters(lat1, lon1, lat2, lon2) {
  const R = 6371e3; // 地球半径 (米)
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

// 评分函数：评估哪条记录的信息更完善
function getScore(p) {
  let score = 0;
  if (p.place_media?.thumbnail && p.place_media.thumbnail.startsWith('/images/')) score += 5; // 本地实拍优先
  if (p.mapillaryImageId) score += 3;
  if (p.isPano) score += 2;
  if (p.place_information?.phone && !p.place_information.phone.includes('+60 4-2')) score += 2;
  if (p.place_information?.website && !p.place_information.website.includes('cid=')) score += 2;
  if (p.place_summary && p.place_summary.length > 100) score += 3;
  if (p.review_count && p.review_count > 10) score += 2;
  return score;
}

async function runDeduplication() {
  try {
    console.log('🔄 Connecting to MongoDB Atlas for Deduplication...');
    await mongoose.connect(MONGODB_URI);
    console.log('✅ Connected successfully!');

    const allPlaces = await PlaceNew.find({}).lean();
    console.log(`\n📦 Total initial records in 'places_new': ${allPlaces.length}`);

    const idsToDelete = new Set();

    // ==========================================
    // 阶段 1: 按标准化名称分组去重 (Exact & Cleaned Name)
    // ==========================================
    console.log('\n🔍 [Stage 1] Checking duplicates by cleaned place name...');
    const nameMap = new Map();

    for (const p of allPlaces) {
      const cName = cleanName(p.name);
      if (!cName || cName.length < 2) continue;

      if (!nameMap.has(cName)) {
        nameMap.set(cName, [p]);
      } else {
        nameMap.get(cName).push(p);
      }
    }

    let nameDupRemoved = 0;
    for (const [name, list] of nameMap.entries()) {
      if (list.length > 1) {
        // 按数据质量打分，排序出最佳的一条作为保留主体
        list.sort((a, b) => getScore(b) - getScore(a));
        const keep = list[0];
        const duplicates = list.slice(1);

        for (const dup of duplicates) {
          idsToDelete.add(dup._id.toString());
          nameDupRemoved++;
        }
      }
    }
    console.log(`✅ Identified ${nameDupRemoved} duplicate records by name match.`);

    // ==========================================
    // 阶段 2: 空间距离近邻碰撞去重 (Geo-Proximity < 20米 + 名称高度相似)
    // ==========================================
    console.log('\n🧭 [Stage 2] Checking geo-proximity duplicates (distance < 20m & similar name)...');
    const remainingPlaces = allPlaces.filter(p => !idsToDelete.has(p._id.toString()));

    let geoDupRemoved = 0;
    for (let i = 0; i < remainingPlaces.length; i++) {
      const p1 = remainingPlaces[i];
      if (idsToDelete.has(p1._id.toString())) continue;

      const [lng1, lat1] = p1.location?.coordinates || [0, 0];
      if (lat1 === 0 || lng1 === 0) continue;

      const name1 = cleanName(p1.name);

      for (let j = i + 1; j < remainingPlaces.length; j++) {
        const p2 = remainingPlaces[j];
        if (idsToDelete.has(p2._id.toString())) continue;

        const [lng2, lat2] = p2.location?.coordinates || [0, 0];
        if (lat2 === 0 || lng2 === 0) continue;

        const dist = getDistanceMeters(lat1, lng1, lat2, lng2);

        // 如果两点相距小于 20 米
        if (dist <= 20) {
          const name2 = cleanName(p2.name);
          // 并且名字高度相似或包含
          if (name1 === name2 || name1.includes(name2) || name2.includes(name1)) {
            // 选择保留得分更高的一条
            const toDelete = getScore(p1) >= getScore(p2) ? p2 : p1;
            idsToDelete.add(toDelete._id.toString());
            geoDupRemoved++;
          }
        }
      }
    }
    console.log(`✅ Identified ${geoDupRemoved} duplicate records by geo-proximity match.`);

    // ==========================================
    // 阶段 3: 执行物理删除
    // ==========================================
    const totalToDelete = idsToDelete.size;
    console.log(`\n🗑️ Total unique duplicate documents to remove: ${totalToDelete}`);

    if (totalToDelete > 0) {
      const deleteArray = Array.from(idsToDelete).map(id => new mongoose.Types.ObjectId(id));
      const res = await PlaceNew.deleteMany({ _id: { $in: deleteArray } });
      console.log(`🎉 Successfully deleted ${res.deletedCount} duplicate records from 'places_new'!`);
    } else {
      console.log('✨ No duplicates found! All records are completely unique.');
    }

    // 最终统计
    const finalCount = await PlaceNew.countDocuments();
    console.log(`\n📊 Final Clean Total in 'places_new': ${finalCount}`);

    // 重复率再次自检
    const checkDuplicates = await PlaceNew.aggregate([
      { $group: { _id: "$name", count: { $sum: 1 } } },
      { $match: { count: { $gt: 1 } } }
    ]);

    console.log(`\n================ ZERO DUPLICATE VERIFICATION ================`);
    console.log(`Duplicate Names Found in DB: ${checkDuplicates.length} (Must be 0)`);
    console.log(`Total Clean, Unique Places:   ${finalCount}`);
    console.log(`=============================================================\n`);

  } catch (err) {
    console.error('❌ Deduplication error:', err);
  } finally {
    await mongoose.disconnect();
    console.log('🔌 Disconnected from MongoDB.');
  }
}

runDeduplication();
