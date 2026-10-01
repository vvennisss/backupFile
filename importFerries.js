const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });

const axios = require('axios');
const mongoose = require('mongoose');
const Ferry = require('./models/Ferry');

const MONGO_URI = process.env.MONGO_URI || process.env.MONGODB_URI || process.env.MONGO_URL;

if (!MONGO_URI) {
  console.error('致命错误: 无法从 .env 读取到数据库链接！');
  process.exit(1);
}

// 官方时刻表硬编码数据（对应 Penang Port 官方时刻表）
const OFFICIAL_SCHEDULES = {
  butterworth: {
    name: 'Pangkalan Sultan Abdul Halim (Butterworth Terminal)',
    address: 'Butterworth, Penang',
    firstFerry: '06:30 AM',
    lastFerry: '11:00 PM',
    weekdayDepartures: [
      '06:30', '07:00', '07:20', '07:40', '08:00', '08:20', '08:40', '09:00', '09:30', '10:00', 
      '10:30', '11:00', '11:30', '12:00', '12:30', '13:00', '13:30', '14:00', '14:30', '15:00', 
      '15:30', '16:00', '16:30', '17:00', '17:20', '17:40', '18:00', '18:30', '19:00', '19:30', 
      '20:00', '20:30', '21:30', '23:00'
    ],
    weekendDepartures: [
      '06:30', '07:00', '07:30', '08:00', '08:30', '09:00', '09:30', '10:00', '10:30', '11:00', 
      '11:30', '12:00', '12:30', '13:00', '13:30', '14:00', '14:30', '15:00', '15:30', '16:00', 
      '16:30', '17:00', '17:30', '18:00', '18:30', '19:00', '19:30', '20:00', '20:30', '21:30', 
      '23:00'
    ]
  },
  georgetown: {
    name: 'Pangkalan Raja Tun Uda (George Town Terminal)',
    address: 'Weld Quay, George Town, Penang',
    firstFerry: '07:00 AM',
    lastFerry: '11:30 PM',
    weekdayDepartures: [
      '07:00', '07:20', '07:40', '08:00', '08:20', '08:40', '09:00', '09:30', '10:00', '10:30', 
      '11:00', '11:30', '12:00', '12:30', '13:00', '13:30', '14:00', '14:30', '15:00', '15:30', 
      '16:00', '16:30', '17:00', '17:20', '17:40', '18:00', '18:30', '19:00', '19:30', '20:00', 
      '20:30', '21:00', '22:00', '23:30'
    ],
    weekendDepartures: [
      '07:00', '07:30', '08:00', '08:30', '09:00', '09:30', '10:00', '10:30', '11:00', '11:30', 
      '12:00', '12:30', '13:00', '13:30', '14:00', '14:30', '15:00', '15:30', '16:00', '16:30', 
      '17:00', '17:30', '18:00', '18:30', '19:00', '19:30', '20:00', '20:30', '21:00', '22:00', 
      '23:30'
    ]
  }
};

const overpassUrl = 'https://overpass-api.de/api/interpreter';
const query = `
  [out:json][timeout:60];
  area["name"="Pulau Pinang"]->.searchArea;
  (
    node["amenity"="ferry_terminal"](area.searchArea);
    way["amenity"="ferry_terminal"](area.searchArea);
  );
  out body center;
`;

const fetchAndSaveFerries = async () => {
  try {
    await mongoose.connect(MONGO_URI);
    console.log('✅ 成功连接至 MongoDB Atlas！');

    console.log('Fetching Penang ferry terminals from OpenStreetMap...');
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
    console.log(`Found ${elements.length} ferry terminals from OpenStreetMap.`);

    // 用 Map 保存确定的 2 个官方码头，避免重复节点覆盖
    const terminalsToSave = new Map();

    for (const item of elements) {
      const lat = item.lat || (item.center && item.center.lat);
      const lng = item.lon || (item.center && item.center.lon);

      if (!lat || !lng) continue;

      // 根据经度区分：> 100.35 为东岸北海 (Butterworth)，<= 100.35 为西岸乔治市 (George Town)
      if (lng > 100.35) {
        terminalsToSave.set('butterworth', { ...OFFICIAL_SCHEDULES.butterworth, lat, lng });
      } else {
        terminalsToSave.set('georgetown', { ...OFFICIAL_SCHEDULES.georgetown, lat, lng });
      }
    }

    // 如果 OSM 缺失某一边，自动兜底补充标准坐标
    if (!terminalsToSave.has('butterworth')) {
      terminalsToSave.set('butterworth', { ...OFFICIAL_SCHEDULES.butterworth, lat: 5.3941, lng: 100.3636 });
    }
    if (!terminalsToSave.has('georgetown')) {
      terminalsToSave.set('georgetown', { ...OFFICIAL_SCHEDULES.georgetown, lat: 5.4136, lng: 100.3440 });
    }

    // 写入 MongoDB Atlas
    for (const [_, termData] of terminalsToSave) {
      await Ferry.updateOne(
        { name: termData.name },
        {
          $set: {
            name: termData.name,
            address: termData.address,
            city: 'Penang',
            coordinates: { lat: termData.lat, lng: termData.lng },
            phone: '019-473 2363',
            website: 'https://www.penangport.com.my',
            operator: 'Penang Port',
            schedule: {
              firstFerry: termData.firstFerry,
              lastFerry: termData.lastFerry,
              weekdayDepartures: termData.weekdayDepartures,
              weekendDepartures: termData.weekendDepartures
            },
            isAvailable: true
          }
        },
        { upsert: true }
      );
    }

    console.log(`🎉 成功将 ${terminalsToSave.size} 个（乔治市 + 北海）完整渡轮码头同步写入 MongoDB Atlas！`);
    process.exit(0);
  } catch (error) {
    console.error('❌ 渡轮数据同步出错:', error.message);
    process.exit(1);
  }
};

fetchAndSaveFerries();