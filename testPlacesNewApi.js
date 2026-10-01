const mongoose = require('mongoose');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });
const PlaceNew = require('./models/PlaceNew');

async function testQuery() {
  try {
    await mongoose.connect(process.env.MONGODB_URI);
    console.log('✅ Connected to MongoDB');

    // 1. 测试按区域与评分排序
    const airItamPlaces = await PlaceNew.find({ area: 'Air Itam', status: 'active' })
      .sort({ rating: -1 })
      .limit(3);
    console.log('\n📍 Top 3 Air Itam Places:');
    airItamPlaces.forEach(p => {
      console.log(`  - [${p.primary_category}] ${p.name} (Rating: ${p.rating}, OpenNow: ${p.is_open_now})`);
    });

    // 2. 测试地理空间近邻查询 ($near / 2dsphere)
    // 槟城乔治市中心坐标 [100.3327, 5.4164]
    const nearby = await PlaceNew.find({
      location: {
        $near: {
          $geometry: { type: 'Point', coordinates: [100.3327, 5.4164] },
          $maxDistance: 2000 // 2km
        }
      },
      status: 'active'
    }).limit(3);
    console.log('\n🧭 Top 3 Places within 2km of George Town:');
    nearby.forEach(p => {
      console.log(`  - ${p.name} (${p.area}) at coordinates: ${JSON.stringify(p.location.coordinates)}`);
    });

    // 3. 测试搜索关键词
    const laksa = await PlaceNew.find({
      $text: { $search: 'laksa' }
    }).limit(2);
    console.log('\n🍜 Search "laksa": found', laksa.length, 'matches:');
    laksa.forEach(p => console.log(`  - ${p.name}`));

  } catch (err) {
    console.error('❌ Test failed:', err);
  } finally {
    await mongoose.disconnect();
    console.log('\n🔌 Test complete & disconnected.');
  }
}

testQuery();
