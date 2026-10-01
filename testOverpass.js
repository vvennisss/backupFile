const axios = require('axios');

async function testOverpass() {
  console.log('Testing Overpass API query for Penang Cafes...');
  const overpassQuery = `
    [out:json][timeout:30];
    (
      node["amenity"="cafe"](5.25,100.18,5.48,100.42);
      way["amenity"="cafe"](5.25,100.18,5.48,100.42);
    );
    out center 30;
  `;

  const endpoints = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
    'https://maps.mail.ru/osm/tools/overpass/api/interpreter'
  ];

  for (const ep of endpoints) {
    try {
      console.log(`Trying ${ep}...`);
      const resp = await axios.post(ep, `data=${encodeURIComponent(overpassQuery)}`, {
        headers: { 'User-Agent': 'KiaKiaPenangApp/2.0' },
        timeout: 15000
      });
      console.log(`✅ Success with ${ep}! Got ${resp.data.elements.length} elements.`);
      if (resp.data.elements.length > 0) {
        console.log('Sample Element Tags:', JSON.stringify(resp.data.elements[0].tags, null, 2));
      }
      return;
    } catch (e) {
      console.warn(`Failed on ${ep}: ${e.message}`);
    }
  }
}

testOverpass();
