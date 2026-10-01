const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });
const mongoose = require('mongoose');
const axios = require('axios');
const BusRoute = require('./models/BusRoute');

const MONGO_URI = process.env.MONGO_URI || process.env.MONGODB_URI || process.env.MONGO_URL;

const routeIdMap = {
  "11": "30000048",
  "12": "30000049",
  "13": "30000050",
  "101": "30000001",
  "102": "30000002",
  "103": "30000003",
  "104": "30000004",
  "201": "30000005",
  "202": "30000006",
  "203": "30000007",
  "204": "30000008",
  "206": "30000009",
  "301": "30000010",
  "302": "30000012",
  "303": "30000013",
  "304": "30000014",
  "306": "30000016",
  "308": "30000018",
  "401": "30000019",
  "401E": "30000020",
  "403": "30000021",
  "404": "30000022",
  "502": "30000024",
  "601": "30000026",
  "603": "30000027",
  "604": "30000028",
  "605": "30000031",
  "606": "30000032",
  "610": "30000034",
  "613": "30000089",
  "701": "30000036",
  "702": "30000037",
  "703": "30000038",
  "708": "30000040",
  "709": "30000041",
  "801": "30000042",
  "802": "30000043",
  "C13A": "30000103",
  "C13C": "30000104",
  "CAT": "30000051",
  "CT13": "30000100",
  "CT14": "30000117",
  "CT15": "30000139",
  "EB60": "30000046",
  "EB80": "30000045",
  "T310": "30000119",
  "T713": "30000140"
};

async function fetchRouteDetails() {
  if (!MONGO_URI) {
    console.error("错误: 找不到 MongoDB URI。");
    return;
  }

  try {
    await mongoose.connect(MONGO_URI);
    console.log("✅ 成功连接到 MongoDB");

    // Fetch all routes from DB
    const routes = await BusRoute.find({});
    console.log(`Found ${routes.length} routes in database to process.`);

    for (const r of routes) {
      const busNumber = r.bus_number.trim();
      const routeId = routeIdMap[busNumber];

      if (!routeId) {
        console.warn(`⚠️ No routeId mapping found for bus number: ${busNumber}`);
        continue;
      }

      console.log(`Processing bus: ${busNumber} (Route ID: ${routeId})...`);
      const url = `https://myrapidbus.prasarana.com.my/kiosk/rpg?route=${routeId}&bus=`;

      try {
        const response = await axios.get(url, { timeout: 10000 });
        const html = response.data;

        // Extract rawShapes
        const shapesMatch = html.match(/const\s+rawShapes\s*=\s*\$\.parseJSON\(`([^`]+)`\);/);
        let shapes = null;
        if (shapesMatch) {
          try {
            shapes = JSON.parse(shapesMatch[1]);
            console.log(`  -> Successfully parsed shapes.`);
          } catch (e) {
            console.error(`  -> Error parsing shapes JSON for ${busNumber}:`, e.message);
          }
        } else {
          console.warn(`  -> No shapes match found for ${busNumber}.`);
        }

        // Extract bstp
        const bstpMatch = html.match(/var\s+bstp\s*=\s*([^;]+);/);
        let stops = null;
        if (bstpMatch) {
          try {
            stops = JSON.parse(bstpMatch[1].trim());
            console.log(`  -> Successfully parsed stops count: ${stops.length}`);
          } catch (e) {
            console.error(`  -> Error parsing stops JSON for ${busNumber}:`, e.message);
          }
        } else {
          console.warn(`  -> No stops match found for ${busNumber}.`);
        }

        // Update DB
        r.shapes = shapes;
        r.stops = stops;
        await r.save();
        console.log(`  -> Saved ${busNumber} to DB.`);

      } catch (err) {
        console.error(`❌ Error fetching details for ${busNumber} (ID: ${routeId}):`, err.message);
      }

      // Add a slight delay to be nice to the server
      await new Promise(resolve => setTimeout(resolve, 800));
    }

    console.log("🎉 All routes processed!");

  } catch (error) {
    console.error("执行时发生错误:", error);
  } finally {
    mongoose.connection.close();
  }
}

fetchRouteDetails();
