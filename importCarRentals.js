const path = require('path');
// 解析根目录下的 .env
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });

const axios = require('axios');
const mongoose = require('mongoose');
const CarRental = require('./models/CarRental');

const MONGO_URI = process.env.MONGO_URI || process.env.MONGODB_URI || process.env.MONGO_URL;

console.log('--- 数据库连接检查 ---');
console.log('读取到的 MONGO_URI:', MONGO_URI ? MONGO_URI : '❌ 未找到变量，请检查 .env');
console.log('----------------------');

if (!MONGO_URI) {
  console.error('致命错误: 无法从 .env 读取到数据库链接！');
  process.exit(1);
}

// Overpass QL 查询语句：获取槟城 (Pulau Pinang) 所有的租车公司/服务点 (amenity=car_rental)
const overpassUrl = 'https://overpass-api.de/api/interpreter';
const query = `
  [out:json][timeout:60];
  area["name"="Pulau Pinang"]->.searchArea;
  (
    node["amenity"="car_rental"](area.searchArea);
    way["amenity"="car_rental"](area.searchArea);
  );
  out body center;
`;

const fetchAndSaveCarRentals = async () => {
  try {
    await mongoose.connect(MONGO_URI);
    console.log('✅ 成功连接至 MongoDB Atlas！');

    console.log('Fetching Penang car rental agencies from OpenStreetMap...');
    const response = await axios.post(
      overpassUrl,
      `data=${encodeURIComponent(query)}`,
      {
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent': 'TravelApp-NodeJS/1.0'
        }
      }
    );

    const elements = response.data.elements;
    console.log(`Found ${elements.length} car rental locations from OpenStreetMap.`);

    let count = 0;
    for (const item of elements) {
      const tags = item.tags || {};
      const name = tags.name || tags['name:en'];

      // 没有名称的节点直接跳过
      if (!name) continue;

      // 获取经纬度坐标
      const lat = item.lat || (item.center && item.center.lat);
      const lng = item.lon || (item.center && item.center.lon);

      if (!lat || !lng) continue;

      const carRentalData = {
        name: name,
        address: tags['addr:full'] || tags['addr:street'] || tags['addr:housenumber'] 
          ? `${tags['addr:housenumber'] || ''} ${tags['addr:street'] || ''}`.trim() 
          : 'Penang, Malaysia',
        city: 'Penang',
        coordinates: { lat, lng },
        phone: tags.phone || tags['contact:phone'] || '',
        website: tags.website || tags['contact:website'] || '',
        description: tags.description || `Car rental agency located in Penang.`
      };

      // 按租车公司名称更新，防止重复插入
      await CarRental.updateOne(
        { name: carRentalData.name },
        { $set: carRentalData },
        { upsert: true }
      );
      count++;
    }

    console.log(`🎉 成功将 ${count} 个租车点同步导入 MongoDB Atlas！`);
    process.exit(0);
  } catch (error) {
    console.error('❌ 租车点数据同步出错:', error.message);
    process.exit(1);
  }
};

fetchAndSaveCarRentals();