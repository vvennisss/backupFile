const mongoose = require('mongoose');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

async function check() {
  await mongoose.connect(process.env.MONGODB_URI);
  const sample = await mongoose.connection.db.collection('places').findOne({
    "place_media.thumbnail": { $exists: true, $ne: "" }
  });
  console.log("SAMPLE PLACE:", JSON.stringify(sample, null, 2));

  const sampleCafe = await mongoose.connection.db.collection('places').findOne({
    $or: [
      { place_name: { $regex: /cafe/i } },
      { place_category: { $regex: /cafe/i } }
    ]
  });
  console.log("SAMPLE CAFE:", JSON.stringify(sampleCafe, null, 2));

  await mongoose.disconnect();
}
check();
