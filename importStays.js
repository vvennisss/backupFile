const path = require('path');
// 强行使用绝对路径解析上一层目录的 .env
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });

const axios = require('axios');
const mongoose = require('mongoose');
const Accommodation = require('./models/Accommodation');

// 兼容多种常见的数据库变量名
const MONGO_URI = process.env.MONGO_URI || process.env.MONGODB_URI || process.env.MONGO_URL;

console.log('--- 数据库连接检查 ---');
console.log('读取到的 MONGO_URI:', MONGO_URI ? MONGO_URI : '❌ 未找到变量，请检查 .env 变量名');
console.log('----------------------');

if (!MONGO_URI) {
  console.error('致命错误: 无法从 .env 读取到数据库链接，请确认 .env 里的变量名是 MONGO_URI。');
  process.exit(1);
}

// Overpass QL 查询语句：获取槟城 (Pulau Pinang) 所有的酒店、民宿、旅馆
const overpassUrl = 'https://overpass-api.de/api/interpreter';
const query = `
  [out:json][timeout:60];
  area["name"="Pulau Pinang"]->.searchArea;
  (
    node["tourism"~"hotel|resort|guest_house|hostel|chalet|apartment|villa"](area.searchArea);
    way["tourism"~"hotel|resort|guest_house|hostel|chalet|apartment|villa"](area.searchArea);
  );
  out body center;
`;

const fetchAndSaveStays = async () => {
  try {
    await mongoose.connect(MONGO_URI);
    console.log('✅ 成功连接至 MongoDB Atlas！');

    console.log('Fetching Penang stays from OpenStreetMap...');
    const response = await axios.post(
      overpassUrl,
      `data=${encodeURIComponent(query)}`,
      {
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent': 'TravelApp-NodeJS/1.0' // 防止 Overpass API 拦截
        }
      }
    );

    const elements = response.data.elements;
    console.log(`Found ${elements.length} places from OpenStreetMap.`);

    let count = 0;
    for (const item of elements) {
      const tags = item.tags || {};
      const name = tags.name || tags['name:en'];

      if (!name) continue;

      const lat = item.lat || (item.center && item.center.lat);
      const lng = item.lon || (item.center && item.center.lon);

      if (!lat || !lng) continue;

      // 映射 5 种类型：['Hotel', 'Resort', 'Homestay', 'Hostel', 'Villa']
      let type = 'Hotel';
      const tourismTag = tags.tourism || '';
      const nameLower = name.toLowerCase();

      if (tourismTag === 'resort' || nameLower.includes('resort')) {
        type = 'Resort';
      } else if (
        tourismTag === 'villa' ||
        tourismTag === 'chalet' ||
        nameLower.includes('villa')
      ) {
        type = 'Villa';
      } else if (
        tourismTag === 'guest_house' ||
        tourismTag === 'apartment' ||
        nameLower.includes('homestay') ||
        nameLower.includes('guesthouse')
      ) {
        type = 'Homestay';
      } else if (
        tourismTag === 'hostel' ||
        nameLower.includes('hostel') ||
        nameLower.includes('backpackers')
      ) {
        type = 'Hostel';
      } else {
        type = 'Hotel';
      }

      const accommodationData = {
        name: name,
        type: type,
        address: tags['addr:full'] || tags['addr:street'] || 'Penang, Malaysia',
        city: 'Penang',
        coordinates: { lat, lng },
        phone: tags.phone || tags['contact:phone'] || '',
        website: tags.website || tags['contact:website'] || '',
        description: tags.description || `Accommodation located in Penang.`
      };

      await Accommodation.updateOne(
        { name: accommodationData.name },
        { $set: accommodationData },
        { upsert: true }
      );
      count++;
    }

    console.log(`🎉 成功将 ${count} 条槟城住宿数据同步导入 MongoDB Atlas！`);
    process.exit(0);
  } catch (error) {
    console.error('❌ 数据同步出错:', error.message);
    process.exit(1);
  }
};

fetchAndSaveStays();