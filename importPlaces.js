require('dotenv').config();
const mongoose = require('mongoose');
const { getJson } = require('serpapi');
const Place = require('./models/Place');

// Helper to wrap SerpApi callback in a Promise
const fetchGoogleMapsPlaces = (query) => {
  return new Promise((resolve, reject) => {
    getJson({
      engine: 'google_maps',
      q: query,
      api_key: process.env.SERPAPI_KEY,
      hl: 'en'
    }, (json) => {
      if (json.error) return reject(json.error);
      resolve(json.local_results || []);
    });
  });
};

async function runImporter() {
  try {
    console.log('Connecting to MongoDB Atlas...');
    await mongoose.connect(process.env.MONGODB_URI);
    console.log('Connected successfully.');
    
    const delay = (ms) => new Promise(resolve => setTimeout(resolve, ms));

    // Define search terms / areas you want to pull
    const categories = [
      // 'cultural & heritage', 'adventure', 'outdoors', 
      // 'shopping & malls', 'beaches', 'nature & parks', 
      // 'food & beverages', 'historical sites', 'places of worship', 
      // 'hip cafes', 'bars & bistros'
      'Street Art & Murals', 'Local Handicrafts & Souvenirs',
      'Museums & Galleries', 'Hawker Centres & Food Courts',
      'Night Markets (Pasar Malam)', 'Accommodations & Hotels',
      'Transit Hubs', 'Wellness & Spas'
    ];

    const locations = [
      'George Town Penang', 'Bayan Lepas Penang', 
      'Batu Ferringhi Penang', 'Balik Pulau Penang',
      'Air Itam Penang', 'Tanjung Bungah Penang',
      'Tanjung Tokong Penang',
      // Mainland Areas
      'Butterworth Penang', 
      //'Bukit Mertajam Penang',
      'Batu Kawan Penang'
      //, 'Nibong Tebal Penang'
    ];

    // FIX: Store both the query string AND the category label as an object
    const searchTargets = [];
    for (const category of categories) {
      for (const location of locations) {
        searchTargets.push({
          queryStr: `${category} in ${location}`,
          categoryLabel: category
        });
      }
    }

    // Loop through the objects instead of just strings
    for (const target of searchTargets) {
      console.log(`\nFetching: "${target.queryStr}"...`);
      const results = await fetchGoogleMapsPlaces(target.queryStr);
      console.log(`Retrieved ${results.length} raw places.`);
      
      // Add a 2-second delay to respect API rate limits
      await delay(2000); 
      
      const bulkOps = [];

      for (const item of results) {
        // Bottleneck Check 1: Ensure valid GPS coordinates exist
        if (!item.gps_coordinates || !item.gps_coordinates.longitude || !item.gps_coordinates.latitude) {
          continue;
        }

        // Bottleneck Check 2: GeoJSON requires [Longitude, Latitude]
        const longitude = Number(item.gps_coordinates.longitude);
        const latitude = Number(item.gps_coordinates.latitude);

        const placeDoc = {
          place_name: item.title || 'Unknown Place',
          place_summary: item.description || item.snippet || '',
          // FIX: Access the category label from our target object
          place_category: target.categoryLabel,
          place_address: item.address || '',
          place_location: {
            type: 'Point',
            coordinates: [longitude, latitude] // Longitude first!
          },
          place_business_hours: item.operating_hours || {},
          place_media: {
            thumbnail: item.thumbnail || '',
            photos: item.photos || []
          },
          place_geofence_radius: 50, // Default 50 meters
          place_information: {
            rating: item.rating || null,
            reviews_count: item.reviews || 0,
            price_level: item.price || '',
            phone: item.phone || '',
            website: item.website || ''
          },
          external_place_id: item.place_id || item.data_id || `${latitude},${longitude}`
        };

        // Bottleneck Check 3: Upsert using bulkWrite to avoid duplicate inserts
        bulkOps.push({
          updateOne: {
            filter: { external_place_id: placeDoc.external_place_id },
            update: { $set: placeDoc },
            upsert: true
          }
        });
      }

      if (bulkOps.length > 0) {
        const bulkResult = await Place.bulkWrite(bulkOps, { ordered: false });
        console.log(`Upserted: ${bulkResult.upsertedCount}, Modified: ${bulkResult.modifiedCount}`);
      }
    } 

    console.log('\nAll data ingestion completed successfully!');
  } catch (error) {
    console.error('Ingestion failed:', error);
  } finally {
    await mongoose.disconnect();
    console.log('MongoDB connection closed.');
  }
}

runImporter();