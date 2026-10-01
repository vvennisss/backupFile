const mongoose = require('mongoose');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });
const PlaceNew = require('./models/PlaceNew');

async function updatePlace() {
  await mongoose.connect(process.env.MONGODB_URI);
  
  const summary = "Sigi's Bar and Grill on the Beach is a beachfront dining venue and bar located at Golden Sands Resort along Batu Feringgi Beach, Penang. Operating daily from 3:00 PM to 11:00 PM, it offers oceanfront seating with sunset views, cocktails, and dining, with wheelchair accessibility, parking, and Wi-Fi available.";
  const description = "Located at Golden Sands Resort directly on Batu Feringgi Beach in Penang, Sigi's Bar and Grill on the Beach provides an open-air beachfront dining and bar setting overlooking the ocean. The venue serves cocktails and meals with sunset views, operating daily from 3:00 PM to 11:00 PM. Verified facilities include on-site parking, wheelchair accessibility, and Wi-Fi access.";

  const res = await PlaceNew.updateOne(
    { _id: new mongoose.Types.ObjectId('6ab3aebaceab80143ca1ad98') },
    { 
      $set: {
        summary: summary,
        description: description,
        updatedAt: new Date()
      }
    }
  );

  console.log('Update result:', res);
  const updatedDoc = await PlaceNew.findById('6ab3aebaceab80143ca1ad98').lean();
  console.log('Updated Place JSON:');
  console.log(JSON.stringify({
    _id: updatedDoc._id,
    name: updatedDoc.name,
    summary: updatedDoc.summary,
    description: updatedDoc.description
  }, null, 2));

  await mongoose.disconnect();
}

updatePlace();
