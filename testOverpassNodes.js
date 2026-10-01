const axios = require('axios');

async function testOverpassNodes() {
  const query = `[out:json][timeout:25];
(
  node["amenity"="cafe"](5.28,100.22,5.46,100.36);
  node["tourism"="museum"](5.28,100.22,5.46,100.36);
  node["tourism"="attraction"](5.28,100.22,5.46,100.36);
  node["historic"](5.28,100.22,5.46,100.36);
);
out body 50;`;

  try {
    const res = await axios.post('https://overpass-api.de/api/interpreter', `data=${encodeURIComponent(query)}`, {
      headers: { 'User-Agent': 'KiaKiaPenangApp/2.0' },
      timeout: 15000
    });
    console.log(`✅ Success! Overpass returned ${res.data.elements.length} nodes.`);
    if (res.data.elements.length > 0) {
      console.log('Sample node:', res.data.elements[0].tags);
    }
  } catch (e) {
    console.log(`Failed: ${e.message}`);
  }
}

testOverpassNodes();
