require('dotenv').config();
const mongoose = require('mongoose');
const Place = require('./models/Place');

// 1. Define the merging map (Old Category -> Target Category)
const categoryMap = {
  // Consolidate general dining
  'Restaurant': 'food & beverages',
  'restaurant': 'food & beverages',
  'Nyonya restaurant': 'food & beverages',
  'Chinese restaurant': 'food & beverages',
  'Western restaurant': 'food & beverages',
  'Malaysian restaurant': 'food & beverages',
  'Asian restaurant': 'food & beverages',
  'fast_food': 'food & beverages',
  'Dinner theater': 'food & beverages',
  // Note: 'Halal restaurant' is deliberately excluded here so it remains unchanged in the database
  
  // New: Dessert and Pastry routing
  'confectionery': 'Dessert and Pastry',
  'ice_cream': 'Dessert and Pastry',
  
  // Consolidate and rename all cafes to 'Cafes'
  'cafe': 'Cafes',
  'Cafe': 'Cafes',
  'Coffee shop': 'Cafes',
  'hip cafes': 'Cafes', // This converts your existing 165 'hip cafes' records
  
  // Other standardizations
  'bar': 'bars & bistros',
  'hotel': 'Accommodations & Hotels',
  'museum': 'Museums & Galleries',
  'Tourist attraction': 'historical sites',
  'arts_centre': 'Museums & Galleries',
  'events_venue': 'cultural & heritage',
  'protected_area': 'nature & parks'
};

// 2. Define completely useless OSM tags to delete from the database
const garbageCategories = [
  'yes', 'lawyer', 'pawnbroker', 'military', 'residential', 
  'works', 'car', 'alternative', 'beauty', 'clothes', 'educational_institution', 'college'
];

async function cleanDatabase() {
  try {
    await mongoose.connect(process.env.MONGODB_URI);
    console.log('Connected to MongoDB Atlas. Starting cleanup...\n');

    // Step 1: Delete irrelevant records
    console.log(`Deleting records in garbage categories...`);
    const deleteResult = await Place.deleteMany({ place_category: { $in: garbageCategories } });
    console.log(`-> Deleted ${deleteResult.deletedCount} useless records.\n`);

    // Step 2: Remap overlapping categories
    console.log(`Remapping fragmented categories...`);
    let updatedTotal = 0;
    
    for (const [oldCat, newCat] of Object.entries(categoryMap)) {
      const updateResult = await Place.updateMany(
        { place_category: oldCat }, 
        { $set: { place_category: newCat } }
      );
      if (updateResult.modifiedCount > 0) {
        console.log(`-> Mapped '${oldCat}' to '${newCat}' (${updateResult.modifiedCount} records)`);
        updatedTotal += updateResult.modifiedCount;
      }
    }
    
    console.log(`\n-> Successfully remapped ${updatedTotal} total records.`);

  } catch (error) {
    console.error('Error during cleanup:', error);
  } finally {
    await mongoose.disconnect();
    console.log('Database connection closed.');
  }
}

cleanDatabase();