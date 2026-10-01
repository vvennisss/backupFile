const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });
const mongoose = require('mongoose');
const fs = require('fs');
const BusRoute = require('./models/BusRoute');

const MONGO_URI = process.env.MONGO_URI || process.env.MONGODB_URI || process.env.MONGO_URL;
const jsonPath = "C:\\Users\\Vennis\\.gemini\\antigravity\\brain\\55eabe59-d6c7-47d8-97c7-5fe76adbcc0c\\rapid_bus_routes_data.json";

async function importRouteDetails() {
  if (!MONGO_URI) {
    console.error("错误: 找不到 MongoDB URI。");
    return;
  }

  try {
    await mongoose.connect(MONGO_URI);
    console.log("✅ 成功连接到 MongoDB");

    // Read JSON file
    console.log(`Reading JSON from: ${jsonPath}...`);
    const fileData = fs.readFileSync(jsonPath, 'utf8');
    const data = JSON.parse(fileData);

    const busNumbers = Object.keys(data);
    console.log(`Loaded details for ${busNumbers.length} bus routes from JSON.`);

    for (const busNo of busNumbers) {
      const details = data[busNo];
      console.log(`Updating bus: ${busNo}...`);

      const result = await BusRoute.updateOne(
        { bus_number: busNo },
        { 
          $set: {
            shapes: details.shapes,
            stops: details.stops
          }
        }
      );

      if (result.matchedCount > 0) {
        console.log(`  -> Updated ${busNo} in DB (modified: ${result.modifiedCount}).`);
      } else {
        console.warn(`  -> ⚠️ Bus ${busNo} not found in DB!`);
      }
    }

    console.log("🎉 Successfully imported all route details to MongoDB!");

  } catch (error) {
    console.error("执行时发生错误:", error);
  } finally {
    mongoose.connection.close();
  }
}

importRouteDetails();
