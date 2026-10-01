const path = require('path');
// 解析根目录下的 .env
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });

const axios = require('axios');
const mongoose = require('mongoose');
const RapidBus = require('./models/RapidBus');

const MONGO_URI = process.env.MONGO_URI || process.env.MONGODB_URI || process.env.MONGO_URL;

console.log('--- 数据库连接检查 ---');
console.log('读取到的 MONGO_URI:', MONGO_URI ? MONGO_URI : '❌ 未找到变量，请检查 .env');
console.log('----------------------');

if (!MONGO_URI) {
  console.error('致命错误: 无法从 .env 读取到数据库链接！');
  process.exit(1);
}

// Overpass QL 查询语句：获取槟城所有的普通巴士站 (bus_stop) 和 巴士总站 (bus_station)
const overpassUrl = 'https://overpass-api.de/api/interpreter';
const query = `
  [out:json][timeout:60];
  area["name"="Pulau Pinang"]->.searchArea;
  (
    node["highway"="bus_stop"](area.searchArea);
    node["amenity"="bus_station"](area.searchArea);
    way["amenity"="bus_station"](area.searchArea);
  );
  out body center;
`;

const fetchAndSaveRapidBus = async () => {
  try {
    await mongoose.connect(MONGO_URI);
    console.log('✅ 成功连接至 MongoDB Atlas！');

    console.log('Fetching Rapid Penang bus stops/terminals from OpenStreetMap...');
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
    console.log(`Found ${elements.length} bus stops/terminals from OpenStreetMap.`);

    let count = 0;
    for (const item of elements) {
      const tags = item.tags || {};
      
      // 提取站名，若无名字则检查是否有站牌编号
      let name = tags.name || tags['name:en'] || tags['name:ms'];
      if (!name && tags.ref) {
        name = `Rapid Penang Stop (${tags.ref})`;
      }

      // 依然没有名字的匿名站直接跳过
      if (!name) continue;

      const lat = item.lat || (item.center && item.center.lat);
      const lng = item.lon || (item.center && item.center.lon);

      if (!lat || !lng) continue;

      // 判断是普通巴士站还是巴士总站 (Terminal)
      const isTerminal = tags.amenity === 'bus_station' || tags.bus === 'station' || name.toLowerCase().includes('terminal') || name.toLowerCase().includes('hab ');
      const type = isTerminal ? 'Bus Terminal' : 'Bus Stop';

      const busData = {
        name: name,
        type: type,
        ref: tags.ref || tags.route_ref || '',
        address: tags['addr:full'] || tags['addr:street'] || 'Penang, Malaysia',
        city: 'Penang',
        coordinates: { lat, lng },
        operator: tags.operator || 'Rapid Penang',
        isAvailable: true
      };

      // 注意：由于马路两侧同名巴士站很多，用【名称 + 坐标】双条件匹配更新，防止互相覆盖
      await RapidBus.updateOne(
        { 
          name: busData.name, 
          'coordinates.lat': busData.coordinates.lat,
          'coordinates.lng': busData.coordinates.lng 
        },
        { $set: busData },
        { upsert: true }
      );
      count++;
    }

    console.log(`🎉 成功将 ${count} 个 Rapid Penang 巴士站点同步导入 MongoDB Atlas！`);
    process.exit(0);
  } catch (error) {
    console.error('❌ 巴士站数据同步出错:', error.message);
    process.exit(1);
  }
};

fetchAndSaveRapidBus();