const mongoose = require('mongoose');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

const MONGODB_URI = process.env.MONGODB_URI;

async function run() {
  try {
    console.log('🔄 Connecting to MongoDB Atlas...');
    await mongoose.connect(MONGODB_URI);
    console.log('✅ Connected successfully!');

    const db = mongoose.connection.db;
    const placesNewCol = db.collection('places_new');
    const placesOldCol = db.collection('places');

    // 1. 获取原 places 集合中所有的街景数据，建立 mapping (按 external_place_id 和 name)
    console.log('📦 Reading street view and pano data from source places collection...');
    const oldPlaces = await placesOldCol.find({}).project({
      external_place_id: 1,
      place_name: 1,
      name: 1,
      streetViewUpdatedAt: 1,
      isPano: 1,
      mapillaryImageId: 1,
      hasStreetView: 1
    }).toArray();

    const oldMap = new Map();
    for (const op of oldPlaces) {
      const key1 = op.external_place_id;
      const key2 = (op.place_name || op.name || '').trim();
      if (key1) oldMap.set(key1, op);
      if (key2) oldMap.set(key2, op);
    }
    console.log(`Found ${oldPlaces.length} source records for street view matching.`);

    // 2. 彻底 $unset 移除 contact 字段
    console.log('\n🗑️ Removing "contact" field from all records in places_new...');
    const unsetResult = await placesNewCol.updateMany(
      {},
      { $unset: { contact: "" } }
    );
    console.log(`✅ Unset "contact" on ${unsetResult.modifiedCount} records (matched: ${unsetResult.matchedCount}).`);

    // 3. 遍历 places_new 的所有记录，确保插入/设置：
    //    - streetViewUpdatedAt: Date
    //    - isPano: true/false
    //    - mapillaryImageId: String / null
    console.log('\n🛠️ Ensuring "streetViewUpdatedAt", "isPano", and "mapillaryImageId" for ALL records...');
    const allNewPlaces = await placesNewCol.find({}).toArray();
    console.log(`Total records in places_new to process: ${allNewPlaces.length}`);

    let updatedCount = 0;
    const bulkOps = [];

    for (const p of allNewPlaces) {
      // 匹配原记录中的真实数据
      const matchedOld = oldMap.get(p.external_place_id) || oldMap.get(p.name) || oldMap.get(p.place_name);

      // streetViewUpdatedAt: 优先使用原时间，其次已有时间，兜底生成 Date 对象
      let svDate;
      if (matchedOld?.streetViewUpdatedAt) {
        svDate = new Date(matchedOld.streetViewUpdatedAt);
      } else if (p.streetViewUpdatedAt) {
        svDate = new Date(p.streetViewUpdatedAt);
      } else {
        svDate = new Date('2026-09-09T07:59:14.530Z');
      }

      // isPano: 保证为严格的 boolean (true / false)
      let isPanoVal = false;
      if (matchedOld && typeof matchedOld.isPano === 'boolean') {
        isPanoVal = matchedOld.isPano;
      } else if (typeof p.isPano === 'boolean') {
        isPanoVal = p.isPano;
      }

      // mapillaryImageId: 优先原 ID，其次已有 ID，没有则为 null
      let mapillaryId = null;
      if (matchedOld?.mapillaryImageId) {
        mapillaryId = String(matchedOld.mapillaryImageId);
      } else if (p.mapillaryImageId) {
        mapillaryId = String(p.mapillaryImageId);
      }

      // hasStreetView: 只要有 mapillaryId 或者标志为 true
      const hasStreetViewVal = Boolean(mapillaryId || p.hasStreetView !== false);

      bulkOps.push({
        updateOne: {
          filter: { _id: p._id },
          update: {
            $set: {
              streetViewUpdatedAt: svDate,
              isPano: isPanoVal,
              mapillaryImageId: mapillaryId,
              hasStreetView: hasStreetViewVal
            },
            $unset: {
              contact: ""
            }
          }
        }
      });

      if (bulkOps.length >= 500) {
        const res = await placesNewCol.bulkWrite(bulkOps, { ordered: false });
        updatedCount += res.modifiedCount;
        bulkOps.length = 0;
      }
    }

    if (bulkOps.length > 0) {
      const res = await placesNewCol.bulkWrite(bulkOps, { ordered: false });
      updatedCount += res.modifiedCount;
    }

    console.log(`\n🎉 Successfully processed all ${allNewPlaces.length} records in places_new!`);

    // 4. 严格校验与报告
    console.log('\n================= VERIFYING ALL RECORDS =================');
    const total = await placesNewCol.countDocuments();
    const remainingContact = await placesNewCol.countDocuments({ contact: { $exists: true } });
    const withDate = await placesNewCol.countDocuments({ streetViewUpdatedAt: { $type: "date" } });
    const withPanoBool = await placesNewCol.countDocuments({ isPano: { $type: "bool" } });
    const withPanoTrue = await placesNewCol.countDocuments({ isPano: true });
    const withPanoFalse = await placesNewCol.countDocuments({ isPano: false });
    const withMapillaryKey = await placesNewCol.countDocuments({ mapillaryImageId: { $exists: true } });
    const withMapillaryNonNull = await placesNewCol.countDocuments({ mapillaryImageId: { $ne: null } });

    console.log(`Total Documents: ${total}`);
    console.log(`Records with 'contact' field: ${remainingContact} (Must be 0)`);
    console.log(`Records with streetViewUpdatedAt as BSON Date: ${withDate} / ${total} (${(withDate/total*100).toFixed(1)}%)`);
    console.log(`Records with isPano as Boolean: ${withPanoBool} / ${total} (true: ${withPanoTrue}, false: ${withPanoFalse})`);
    console.log(`Records with mapillaryImageId field: ${withMapillaryKey} / ${total} (non-null: ${withMapillaryNonNull})`);
    console.log('=========================================================\n');

    // 打印样例文档
    const sample = await placesNewCol.findOne({ mapillaryImageId: { $ne: null } });
    console.log('Sample Record Output:');
    console.log(JSON.stringify({
      _id: sample._id,
      name: sample.name,
      streetViewUpdatedAt: sample.streetViewUpdatedAt,
      isPano: sample.isPano,
      mapillaryImageId: sample.mapillaryImageId,
      hasStreetView: sample.hasStreetView,
      contact: sample.contact || undefined
    }, null, 2));

  } catch (err) {
    console.error('❌ Error during execution:', err);
  } finally {
    await mongoose.disconnect();
    console.log('🔌 Disconnected from MongoDB.');
  }
}

run();
