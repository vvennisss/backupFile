require('dotenv').config();
const mongoose = require('mongoose');
const Place = require('./models/Place');

async function checkCategories() {
  try {
    await mongoose.connect(process.env.MONGODB_URI);
    console.log('Connected to MongoDB Atlas.\n');

    // Group by category and count the number of places in each
    const categoryCounts = await Place.aggregate([
      { $group: { _id: "$place_category", total_places: { $sum: 1 } } },
      { $sort: { total_places: -1 } } // Sort from highest count to lowest
    ]);

    console.log('=== Current Database Categories ===');
    categoryCounts.forEach(cat => {
      console.log(`- ${cat._id || 'Uncategorized'}: ${cat.total_places} records`);
    });
    console.log('===================================');

  } catch (error) {
    console.error('Error fetching categories:', error);
  } finally {
    await mongoose.disconnect();
    console.log('\nDatabase connection closed.');
  }
}

checkCategories();