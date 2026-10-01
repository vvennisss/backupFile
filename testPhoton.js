const axios = require('axios');

async function testFastOsm() {
  console.log('Testing Photon (OpenStreetMap) API for Penang POIs...');
  const testKeywords = ['cafe', 'restaurant', 'hotel', 'museum', 'temple', 'park', 'market'];

  for (const kw of testKeywords) {
    try {
      const resp = await axios.get('https://photon.komoot.io/api/', {
        params: {
          q: kw,
          lat: 5.414,
          lon: 100.328,
          bbox: '100.10,5.10,100.60,5.60', // Confine to Penang boundaries
          limit: 15
        },
        timeout: 6000
      });
      const features = resp.data?.features || [];
      console.log(`✅ [Photon] Keyword "${kw}": received ${features.length} places.`);
      if (features.length > 0) {
        const p = features[0].properties;
        console.log(`   Sample: ${p.name || p.street} | OSM Key: ${p.osm_key}=${p.osm_value} | Coords:`, features[0].geometry.coordinates);
      }
    } catch (e) {
      console.warn(`Photon failed on "${kw}": ${e.message}`);
    }
  }
}

testFastOsm();
