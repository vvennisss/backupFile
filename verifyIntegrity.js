const mongoose = require('mongoose');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });
const PlaceNew = require('./models/PlaceNew');

async function verify() {
  await mongoose.connect(process.env.MONGODB_URI);
  const total = await PlaceNew.countDocuments();
  const emptyThumb = await PlaceNew.countDocuments({
    $or: [
      { 'place_media.thumbnail': '' },
      { 'place_media.thumbnail': null },
      { 'place_media.thumbnail': 'no_image_found' }
    ]
  });
  const withPhone = await PlaceNew.countDocuments({ 'place_information.phone': { $ne: '' } });
  const withWebsite = await PlaceNew.countDocuments({ 'place_information.website': { $ne: '' } });
  const withStreetViewTime = await PlaceNew.countDocuments({ streetViewUpdatedAt: { $ne: null } });
  const withGoogleId = await PlaceNew.countDocuments({ external_place_id: { $regex: /^ChIJ/ } });
  const withSummary = await PlaceNew.countDocuments({ place_summary: { $ne: '' } });

  console.log(`\n================= VERIFICATION REPORT =================`);
  console.log(`Total Places in places_new: ${total}`);
  console.log(`Valid Google Place IDs (^ChIJ): ${withGoogleId} / ${total} (${(withGoogleId/total*100).toFixed(1)}%)`);
  console.log(`Empty/Broken Thumbnails: ${emptyThumb} (0 = all valid!)`);
  console.log(`With Phone Number: ${withPhone} / ${total} (${(withPhone/total*100).toFixed(1)}%)`);
  console.log(`With Website: ${withWebsite} / ${total} (${(withWebsite/total*100).toFixed(1)}%)`);
  console.log(`With streetViewUpdatedAt: ${withStreetViewTime} / ${total} (${(withStreetViewTime/total*100).toFixed(1)}%)`);
  console.log(`With Rich place_summary: ${withSummary} / ${total} (${(withSummary/total*100).toFixed(1)}%)`);
  console.log(`=======================================================\n`);

  await mongoose.disconnect();
}
verify();
