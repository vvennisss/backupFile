const path = require('path');
// 解析上一层根目录下的 .env 文件
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });
// 如果你是在本地运行独立脚本，通常需要 dotenv 来读取 .env 文件里的环境变量

const mongoose = require('mongoose');

const MONGO_URI = process.env.MONGO_URI || process.env.MONGODB_URI || process.env.MONGO_URL;


// 在脚本中直接定义 Schema，方便你一键运行
const busRouteSchema = new mongoose.Schema({
  bus_number: String,
  zone: String,
  origin: String,
  destination: String,
  first_trip: String,
  last_trip: String,
  frequency: String
}, { timestamps: true });

// 避免重复编译 Model
const BusRoute = mongoose.models.BusRoute || mongoose.model('BusRoute', busRouteSchema);

async function seedRapidBuses() {
  if (!MONGO_URI) {
    console.error("错误: 找不到 MongoDB URI，请检查环境变量。");
    return;
  }

  try {
    await mongoose.connect(MONGO_URI);
    console.log("✅ 成功连接到 MongoDB");

    // 1. 删除现有的所有记录 (Drop all existing records)
    const deleteResult = await BusRoute.deleteMany({});
    console.log(`🗑️ 已清理旧数据: 共删除了 ${deleteResult.deletedCount} 条记录。`);

    // 2. 准备最新的完整数据
    const busData = [
      // City Center & Free Transit (CAT)
      { bus_number: "CAT", zone: "City Center", origin: "Weld Quay (Jetty)", destination: "Komtar (Loop)", first_trip: "6:00 AM", last_trip: "11:45 PM", frequency: "10 - 15 mins" },
      { bus_number: "11", zone: "City Center", origin: "Weld Quay", destination: "Batu Lanchang", first_trip: "5:30 AM", last_trip: "11:30 PM", frequency: "20 - 30 mins" },
      { bus_number: "12", zone: "City Center", origin: "Weld Quay", destination: "Bandar Sri Pinang", first_trip: "5:30 AM", last_trip: "11:00 PM", frequency: "30 - 45 mins" },
      { bus_number: "13", zone: "City Center", origin: "Paya Terubong", destination: "Lotus's Penang E-Gate", first_trip: "5:30 AM", last_trip: "10:30 PM", frequency: "45 - 60 mins" },

      // Zone 100: Northern Coast
      { bus_number: "101", zone: "Zone 100", origin: "Weld Quay", destination: "Teluk Bahang", first_trip: "5:30 AM", last_trip: "11:30 PM", frequency: "10 - 12 mins" },
      { bus_number: "102", zone: "Zone 100", origin: "Penang Airport", destination: "Teluk Bahang", first_trip: "6:00 AM", last_trip: "11:35 PM", frequency: "75 mins" },
      { bus_number: "104", zone: "Zone 100", origin: "Weld Quay", destination: "Tanjung Bungah", first_trip: "6:00 AM", last_trip: "10:30 PM", frequency: "45 - 60 mins" },

      // Zone 200: Air Itam & Central Suburbs
      { bus_number: "201", zone: "Zone 200", origin: "Weld Quay", destination: "Paya Terubong", first_trip: "5:30 AM", last_trip: "11:30 PM", frequency: "15 - 25 mins" },
      { bus_number: "202", zone: "Zone 200", origin: "Weld Quay", destination: "Paya Terubong (via Farlim)", first_trip: "5:30 AM", last_trip: "11:00 PM", frequency: "25 - 30 mins" },
      { bus_number: "203", zone: "Zone 200", origin: "Weld Quay", destination: "Air Itam (via Farlim)", first_trip: "5:30 AM", last_trip: "11:00 PM", frequency: "20 - 30 mins" },
      { bus_number: "204", zone: "Zone 200", origin: "Weld Quay", destination: "Penang Hill", first_trip: "5:30 AM", last_trip: "11:30 PM", frequency: "35 - 45 mins" },
      { bus_number: "206", zone: "Zone 200", origin: "Weld Quay", destination: "Lotus's Tengku Kudin", first_trip: "5:30 AM", last_trip: "10:30 PM", frequency: "30 - 45 mins" },

      // Zone 300: Bayan Lepas & Southern Penang
      { bus_number: "301", zone: "Zone 300", origin: "Weld Quay", destination: "Relau", first_trip: "5:45 AM", last_trip: "11:30 PM", frequency: "15 mins" },
      { bus_number: "302", zone: "Zone 300", origin: "Weld Quay", destination: "Batu Maung", first_trip: "5:30 AM", last_trip: "11:30 PM", frequency: "20 - 30 mins" },
      { bus_number: "303", zone: "Zone 300", origin: "Weld Quay", destination: "Bukit Gedung", first_trip: "5:30 AM", last_trip: "11:00 PM", frequency: "25 - 35 mins" },
      { bus_number: "304", zone: "Zone 300", origin: "Gurney Drive", destination: "Bukit Gedung", first_trip: "6:00 AM", last_trip: "11:00 PM", frequency: "30 - 40 mins" },
      { bus_number: "308", zone: "Zone 300", origin: "Sungai Nibong", destination: "Gertak Sanggul", first_trip: "6:00 AM", last_trip: "10:30 PM", frequency: "40 - 50 mins" },

      // Zone 400: Balik Pulau & Western Penang
      { bus_number: "401", zone: "Zone 400", origin: "Weld Quay", destination: "Balik Pulau (via Bayan Baru)", first_trip: "5:55 AM", last_trip: "10:30 PM", frequency: "60 mins" },
      { bus_number: "401E", zone: "Zone 400", origin: "Weld Quay", destination: "Balik Pulau", first_trip: "5:45 AM", last_trip: "11:30 PM", frequency: "20 mins" },
      { bus_number: "403", zone: "Zone 400", origin: "Balik Pulau", destination: "Pulau Betong", first_trip: "6:30 AM", last_trip: "9:30 PM", frequency: "60 - 90 mins" },
      { bus_number: "404", zone: "Zone 400", origin: "Balik Pulau", destination: "Pantai Acheh", first_trip: "6:00 AM", last_trip: "9:00 PM", frequency: "90 mins" },

      // Zone 600-800: Mainland (Seberang Perai)
      { bus_number: "601", zone: "Zone 600-800", origin: "Penang Sentral", destination: "Kepala Batas", first_trip: "6:00 AM", last_trip: "10:30 PM", frequency: "30 - 40 mins" },
      { bus_number: "603", zone: "Zone 600-800", origin: "Penang Sentral", destination: "Kuala Muda", first_trip: "6:00 AM", last_trip: "10:00 PM", frequency: "45 - 60 mins" },
      { bus_number: "604", zone: "Zone 600-800", origin: "Penang Sentral", destination: "Desa Murni", first_trip: "6:00 AM", last_trip: "10:30 PM", frequency: "45 - 60 mins" },
      { bus_number: "606", zone: "Zone 600-800", origin: "Bukit Mertajam", destination: "Kepala Batas", first_trip: "6:00 AM", last_trip: "10:00 PM", frequency: "60 mins" },
      { bus_number: "701", zone: "Zone 600-800", origin: "Penang Sentral", destination: "Bukit Mertajam", first_trip: "6:15 AM", last_trip: "10:30 PM", frequency: "15 - 25 mins" },
      { bus_number: "702", zone: "Zone 600-800", origin: "Penang Sentral", destination: "Bukit Mertajam (via Permatang Pauh)", first_trip: "6:00 AM", last_trip: "10:30 PM", frequency: "45 mins" },
      { bus_number: "703", zone: "Zone 600-800", origin: "Penang Sentral", destination: "Seberang Jaya", first_trip: "6:00 AM", last_trip: "10:30 PM", frequency: "30 - 40 mins" },
      { bus_number: "709", zone: "Zone 600-800", origin: "Penang Sentral", destination: "Machang Bubok", first_trip: "6:00 AM", last_trip: "10:00 PM", frequency: "45 - 60 mins" },
      { bus_number: "801", zone: "Zone 600-800", origin: "Penang Sentral", destination: "Nibong Tebal", first_trip: "5:40 AM", last_trip: "10:30 PM", frequency: "40 - 50 mins" },
      { bus_number: "802", zone: "Zone 600-800", origin: "Bukit Mertajam", destination: "Nibong Tebal", first_trip: "6:00 AM", last_trip: "10:00 PM", frequency: "60 mins" }
    ];

    // 3. 批量插入新数据
    const insertResult = await BusRoute.insertMany(busData);
    
    console.log("----- 巴士路线数据同步完成 -----");
    console.log(`✅ 全新插入 (New Inserts): ${insertResult.length} 条记录`);
    console.log("--------------------------------");

  } catch (error) {
    console.error("执行时发生错误:", error);
  } finally {
    mongoose.connection.close();
  }
}

seedRapidBuses();