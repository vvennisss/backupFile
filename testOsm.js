const axios = require('axios');

async function testNominatim() {
  const query = 'Kek Lok Si'; // A well-known landmark in OSM
  console.log(`Testing OpenStreetMap Nominatim for: "${query}"...\n`);

  try {
    const response = await axios.get('https://nominatim.openstreetmap.org/search', {
      params: {
        q: query,
        format: 'json',
        addressdetails: 1,
        limit: 3,
        countrycodes: 'my'
      },
      headers: {
        // A descriptive User-Agent is strictly required by OSM policy
        'User-Agent': 'KiaKiaPenangApp-DiagnosticTest/1.0 (p23015810@student.newinti.edu.my)'
      },
      timeout: 5000
    });

    console.log(`Status Code: ${response.status} ${response.statusText}`);
    console.log(`Results Found: ${response.data.length}\n`);

    if (response.data.length > 0) {
      console.log('Sample Place Found:');
      console.log({
        name: response.data[0].name || response.data[0].display_name.split(',')[0],
        lat: response.data[0].lat,
        lon: response.data[0].lon,
        type: response.data[0].type || response.data[0].class,
        address: response.data[0].display_name
      });
      console.log('\n SUCCESS: Connected to OpenStreetMap API successfully.');
    } else {
      console.log('⚠️ Response returned empty array []. Check your query terms.');
    }
  } catch (error) {
    console.error(' CONNECTION FAILED:');
    if (error.response) {
      console.error(`HTTP Status: ${error.response.status}`);
      console.error(`Details:`, error.response.data);
    } else {
      console.error(`Error Message: ${error.message}`);
    }
  }
}

testNominatim();