const axios = require('axios');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

const SERPAPI_KEY = process.env.SERPAPI_KEY;

async function testSerp() {
  console.log('Testing SerpAPI Google Maps Engine...');
  if (!SERPAPI_KEY) {
    console.error('❌ No SERPAPI_KEY in .env');
    return;
  }

  try {
    const url = 'https://serpapi.com/search.json';
    const params = {
      engine: 'google_maps',
      q: 'specialty coffee cafe George Town Penang',
      ll: '@5.414,100.328,14z',
      api_key: SERPAPI_KEY
    };

    const resp = await axios.get(url, { params, timeout: 15000 });
    const results = resp.data.local_results || [];
    console.log(`✅ SerpAPI success! Found ${results.length} Google Maps results.`);
    if (results.length > 0) {
      const sample = results[0];
      console.log('Sample Google Maps Result:');
      console.log({
        title: sample.title,
        place_id: sample.place_id,
        rating: sample.rating,
        reviews: sample.reviews,
        phone: sample.phone,
        website: sample.website,
        thumbnail: sample.thumbnail ? 'YES (Valid URL)' : 'NO',
        gps: sample.gps_coordinates,
        address: sample.address
      });
    }
  } catch (err) {
    console.error('❌ SerpAPI Test failed:', err.response?.data?.error || err.message);
  }
}

testSerp();
