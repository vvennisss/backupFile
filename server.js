// // require('dotenv').config();
// // const express = require('express');
// // const cors = require('cors');
// // const mongoose = require('mongoose');
// // const axios = require('axios');
// // const Place = require('./models/Place');

// // const app = express();
// // app.use(cors());
// // app.use(express.json());

// // // --- CATEGORY NORMALIZATION MAPS ---
// // const categoryMap = {
// //   'Restaurant': 'food & beverages',
// //   'restaurant': 'food & beverages',
// //   'Nyonya restaurant': 'food & beverages',
// //   'Chinese restaurant': 'food & beverages',
// //   'Western restaurant': 'food & beverages',
// //   'Malaysian restaurant': 'food & beverages',
// //   'Asian restaurant': 'food & beverages',
// //   'fast_food': 'food & beverages',
// //   'Dinner theater': 'food & beverages',
// //   'confectionery': 'Dessert and Pastry',
// //   'ice_cream': 'Dessert and Pastry',
// //   'cafe': 'Cafes',
// //   'Cafe': 'Cafes',
// //   'Coffee shop': 'Cafes',
// //   'hip cafes': 'Cafes',
// //   'bar': 'bars & bistros',
// //   'hotel': 'Accommodations & Hotels',
// //   'museum': 'Museums & Galleries',
// //   'Tourist attraction': 'historical sites',
// //   'arts_centre': 'Museums & Galleries',
// //   'events_venue': 'cultural & heritage',
// //   'protected_area': 'nature & parks'
// // };

// // const garbageCategories = [
// //   'yes', 'lawyer', 'pawnbroker', 'military', 'residential', 
// //   'works', 'car', 'alternative', 'beauty', 'clothes', 'educational_institution', 'college'
// // ];

// // // --- HELPER 1: Query Photon (OpenStreetMap) API ---
// // async function fetchFromPhoton(query) {
// //   try {
// //     const url = 'https://photon.komoot.io/api/';
    
// //     const response = await axios.get(url, {
// //       params: {
// //         q: query,
// //         limit: 10,
// //         lat: 5.414, 
// //         lon: 100.328,
// //         bbox: '100.10,5.10,100.60,5.60' // Confine to Penang boundaries
// //       },
// //       timeout: 5000
// //     });

// //     return response.data.features || [];
// //   } catch (error) {
// //     console.error('Photon API Request Error:', error.message);
// //     return [];
// //   }
// // }

// // // --- HELPER 2: Transform Photon Feature into MongoDB Place Schema ---
// // function transformPhotonToPlace(feature) {
// //   const coords = feature.geometry.coordinates;
// //   const props = feature.properties;

// //   const addressParts = [props.name, props.street, props.city, props.state, props.country]
// //     .filter(Boolean);
// //   const fullAddress = addressParts.join(', ');
// //   const placeName = props.name || props.street || 'Unknown Place';

// //   // NEW: Standardize the category before saving
// //   const rawCategory = props.osm_value || 'General';
// //   let cleanCategory = categoryMap[rawCategory] || rawCategory;
  
// //   // If OSM returns a garbage tag, assign it to 'General'
// //   if (garbageCategories.includes(cleanCategory)) {
// //     cleanCategory = 'General';
// //   }

// //   return {
// //     place_name: placeName,
// //     place_summary: fullAddress,
// //     place_category: cleanCategory,
// //     place_address: fullAddress,
// //     place_location: {
// //       type: 'Point',
// //       coordinates: coords 
// //     },
// //     place_business_hours: {},
// //     place_media: {
// //       thumbnail: '',
// //       photos: []
// //     },
// //     place_geofence_radius: 50,
// //     place_information: {
// //       osm_id: props.osm_id,
// //       osm_type: props.osm_type,
// //       source: 'Photon (OpenStreetMap)'
// //     },
// //     external_place_id: `osm_${props.osm_type}_${props.osm_id}`
// //   };
// // }

// // // --- MAIN SEARCH ENDPOINT ---
// // app.get('/api/places/search', async (req, res) => {
// //   try {
// //     const query = req.query.q;
// //     if (!query) {
// //       return res.status(400).json({ error: 'Search query is required' });
// //     }

// //     // 1. SEARCH LOCAL MONGODB DATABASE
// //     const words = query.trim().split(/\s+/).filter(Boolean);
    
// //     const matchAllWords = words.map(word => ({
// //       $or: [
// //         { place_name: { $regex: word, $options: 'i' } },
// //         { place_category: { $regex: word, $options: 'i' } },
// //         { place_address: { $regex: word, $options: 'i' } }
// //       ]
// //     }));

// //     const penangBoundingBox = {
// //       place_location: {
// //         $geoWithin: {
// //           $box: [
// //             [100.10, 5.10], 
// //             [100.60, 5.60]  
// //           ]
// //         }
// //       }
// //     };

// //     const uniqueLocalPlaces = await Place.find({ 
// //       $and: [...matchAllWords, penangBoundingBox] 
// //     }).limit(20);

// //     if (uniqueLocalPlaces.length > 0) {
// //       return res.json({
// //         source: 'mongodb',
// //         count: uniqueLocalPlaces.length,
// //         data: uniqueLocalPlaces
// //       });
// //     }

// //     // 2. FALLBACK TO OPENSTREETMAP PHOTON
// //     console.log(`No MongoDB matches for "${query}". Querying Photon API...`);
// //     const photonResults = await fetchFromPhoton(query);

// //     if (photonResults.length === 0) {
// //       return res.json({
// //         source: 'none',
// //         count: 0,
// //         data: []
// //       });
// //     }

// //     // 3. NORMALIZE PHOTON DATA (This now applies the clean categories)
// //     const transformedPlaces = photonResults.map(transformPhotonToPlace);

// //     // 4. AUTO-CACHE NEW PLACES INTO MONGODB
// //     const bulkOps = transformedPlaces.map(doc => ({
// //       updateOne: {
// //         filter: { external_place_id: doc.external_place_id },
// //         update: { $set: doc },
// //         upsert: true
// //       }
// //     }));

// //     if (bulkOps.length > 0) {
// //       Place.bulkWrite(bulkOps, { ordered: false }).catch(err => {
// //         console.warn('Auto-caching OSM data failed:', err.message);
// //       });
// //     }

// //     return res.json({
// //       source: 'openstreetmap',
// //       count: transformedPlaces.length,
// //       data: transformedPlaces
// //     });

// //   } catch (error) {
// //     console.error('Search API Error:', error);
// //     res.status(500).json({ error: 'Server error during search' });
// //   }
// // });

// // // --- START SERVER & CONNECT DATABASE ---
// // const PORT = process.env.PORT || 3000;
// // mongoose.connect(process.env.MONGODB_URI).then(() => {
// //   console.log('Connected to MongoDB Atlas');
// //   app.listen(PORT, () => console.log(`API Server running on http://localhost:${PORT}`));
// // });

// const path = require('path');
// require('dotenv').config({ path: path.resolve(__dirname, '../.env') });
// // require('dotenv').config();
// const express = require('express');
// const cors = require('cors');
// const mongoose = require('mongoose');
// const axios = require('axios');
// const { Ollama } = require('ollama');
// const Place = require('./models/Place');
// const Accommodation = require('./models/Accommodation');
// const CarRental = require('./models/CarRental');
// const Ferry = require('./models/Ferry');
// const RapidBus = require('./models/RapidBus');
// const BusRoute = require('./models/BusRoute');

// // ==========================================
// // CONFIGURATION
// // ==========================================
// // Change this string to specify your preferred Ollama model globally
// const DEFAULT_OLLAMA_MODEL = 'llama3.2:3b'; 

// const app = express();
// app.use(cors());
// app.use(express.json());

// // Initialize Ollama client
// const ollama = new Ollama();

// // --- CATEGORY NORMALIZATION MAPS ---
// const categoryMap = {
//   'Restaurant': 'food & beverages',
//   'restaurant': 'food & beverages',
//   'Nyonya restaurant': 'food & beverages',
//   'Chinese restaurant': 'food & beverages',
//   'Western restaurant': 'food & beverages',
//   'Malaysian restaurant': 'food & beverages',
//   'Asian restaurant': 'food & beverages',
//   'fast_food': 'food & beverages',
//   'Dinner theater': 'food & beverages',
//   'confectionery': 'Dessert and Pastry',
//   'ice_cream': 'Dessert and Pastry',
//   'cafe': 'Cafes',
//   'Cafe': 'Cafes',
//   'Coffee shop': 'Cafes',
//   'hip cafes': 'Cafes',
//   'bar': 'bars & bistros',
//   'hotel': 'Accommodations & Hotels',
//   'museum': 'Museums & Galleries',
//   'Tourist attraction': 'historical sites',
//   'arts_centre': 'Museums & Galleries',
//   'events_venue': 'cultural & heritage',
//   'protected_area': 'nature & parks'
// };

// const garbageCategories = [
//   'yes', 'lawyer', 'pawnbroker', 'military', 'residential', 
//   'works', 'car', 'alternative', 'beauty', 'clothes', 'educational_institution', 'college'
// ];

// // --- HELPER 1: Query Photon (OpenStreetMap) API ---
// async function fetchFromPhoton(query) {
//   try {
//     const url = 'https://photon.komoot.io/api/';
//     const response = await axios.get(url, {
//       params: {
//         q: query,
//         limit: 10,
//         lat: 5.414, 
//         lon: 100.328,
//         bbox: '100.10,5.10,100.60,5.60'
//       },
//       timeout: 5000
//     });
//     return response.data.features || [];
//   } catch (error) {
//     console.error('Photon API Request Error:', error.message);
//     return [];
//   }
// }

// // --- HELPER 2: Transform Photon Feature into MongoDB Place Schema ---
// function transformPhotonToPlace(feature) {
//   const coords = feature.geometry.coordinates;
//   const props = feature.properties;
//   const addressParts = [props.name, props.street, props.city, props.state, props.country].filter(Boolean);
//   const fullAddress = addressParts.join(', ');
//   const placeName = props.name || props.street || 'Unknown Place';

//   const rawCategory = props.osm_value || 'General';
//   let cleanCategory = categoryMap[rawCategory] || rawCategory;
  
//   if (garbageCategories.includes(cleanCategory)) {
//     cleanCategory = 'General';
//   }

//   return {
//     place_name: placeName,
//     place_summary: fullAddress,
//     place_category: cleanCategory,
//     place_address: fullAddress,
//     place_location: { type: 'Point', coordinates: coords },
//     place_business_hours: {},
//     place_media: { thumbnail: '', photos: [] },
//     place_geofence_radius: 50,
//     place_information: {
//       osm_id: props.osm_id,
//       osm_type: props.osm_type,
//       source: 'Photon (OpenStreetMap)'
//     },
//     external_place_id: `osm_${props.osm_type}_${props.osm_id}`
//   };
// }

// // --- HELPER 3: Fetch Real-Time Weather ---
// async function getWeatherData(lat, lon) {
//     const url = `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,weather_code,wind_speed_10m&timezone=auto`;
//     try {
//         const response = await axios.get(url);
//         return response.data;
//     } catch (error) {
//         console.error("Error fetching weather:", error.message);
//         return null;
//     }
// }

// function getWeatherDescription(code) {
//     const codes = {
//         0: 'Clear sky', 1: 'Mainly clear', 2: 'Partly cloudy', 3: 'Overcast',
//         45: 'Fog', 48: 'Depositing rime fog', 51: 'Light drizzle', 53: 'Moderate drizzle', 
//         61: 'Slight rain', 63: 'Moderate rain', 65: 'Heavy rain', 71: 'Slight snow', 
//         95: 'Thunderstorm'
//     };
//     return codes[code] || 'Unknown conditions';
// }


// // ==========================================
// //                 ENDPOINTS
// // ==========================================

// // --- 1. MAIN SEARCH ENDPOINT ---
// app.get('/api/places/search', async (req, res) => {
//   try {
//     const query = req.query.q;
//     if (!query) return res.status(400).json({ error: 'Search query is required' });

//     const words = query.trim().split(/\s+/).filter(Boolean);
//     const matchAllWords = words.map(word => ({
//       $or: [
//         { place_name: { $regex: word, $options: 'i' } },
//         { place_category: { $regex: word, $options: 'i' } },
//         { place_address: { $regex: word, $options: 'i' } }
//       ]
//     }));

//     const penangBoundingBox = {
//       place_location: {
//         $geoWithin: { $box: [ [100.10, 5.10], [100.60, 5.60] ] }
//       }
//     };

//     const uniqueLocalPlaces = await Place.find({ 
//       $and: [...matchAllWords, penangBoundingBox] 
//     }).limit(20);

//     if (uniqueLocalPlaces.length > 0) {
//       return res.json({ source: 'mongodb', count: uniqueLocalPlaces.length, data: uniqueLocalPlaces });
//     }

//     console.log(`No MongoDB matches for "${query}". Querying Photon API...`);
//     const photonResults = await fetchFromPhoton(query);

//     if (photonResults.length === 0) {
//       return res.json({ source: 'none', count: 0, data: [] });
//     }

//     const transformedPlaces = photonResults.map(transformPhotonToPlace);

//     const bulkOps = transformedPlaces.map(doc => ({
//       updateOne: {
//         filter: { external_place_id: doc.external_place_id },
//         update: { $set: doc },
//         upsert: true
//       }
//     }));

//     if (bulkOps.length > 0) {
//       Place.bulkWrite(bulkOps, { ordered: false }).catch(err => {
//         console.warn('Auto-caching OSM data failed:', err.message);
//       });
//     }

//     return res.json({ source: 'openstreetmap', count: transformedPlaces.length, data: transformedPlaces });

//   } catch (error) {
//     console.error('Search API Error:', error);
//     res.status(500).json({ error: 'Server error during search' });
//   }
// });

// // --- 2. STREAMING WEATHER LIFESTYLE TIPS ENDPOINT ---
// app.get('/api/lifestyle-tips', async (req, res) => {
//     // Uses the frontend parameter if provided, otherwise falls back to the global default
//     const { lat, lon, model = DEFAULT_OLLAMA_MODEL } = req.query;

//     if (!lat || !lon) {
//         return res.status(400).json({ error: "Please provide 'lat' and 'lon' parameters." });
//     }

//     // Set headers for Server-Sent Events (SSE) to enable streaming
//     res.setHeader('Content-Type', 'text/event-stream');
//     res.setHeader('Cache-Control', 'no-cache');
//     res.setHeader('Connection', 'keep-alive');

//     try {
//         const weather = await getWeatherData(lat, lon);
//         if (!weather) {
//             res.write(`data: ${JSON.stringify({ error: "Failed to fetch weather data." })}\n\n`);
//             return res.end();
//         }

//         const current = weather.current;
//         const condition = getWeatherDescription(current.weather_code);

//         // Instantly send the weather data back to the UI before AI generation starts
//         res.write(`data: ${JSON.stringify({ 
//             type: 'weather_metadata', 
//             data: {
//                 temp: current.temperature_2m,
//                 feels_like: current.apparent_temperature,
//                 condition: condition,
//                 humidity: current.relative_humidity_2m
//             }
//         })}\n\n`);

//         const prompt = `
//         You are an expert travel advisor. Look at the current weather for a traveler's location:
//         - Temp: ${current.temperature_2m}°C (Feels like ${current.apparent_temperature}°C)
//         - Condition: ${condition}
//         - Humidity: ${current.relative_humidity_2m}%
//         - Wind Speed: ${current.wind_speed_10m} km/h
        
//         Based ONLY on this specific weather, provide short, actionable lifestyle tips across the 3 categories below.
        
//         CRITICAL CONSTRAINT: 
//         - Provide exactly THREE bullet point tip per category.
//         - Each tips MUST be 10 words or fewer.

//         Format your output exactly as:
//         1. Hydration and Diet: [Your tip in under 10 words]
//         2. Clothing and Sun Protection: [Your tip in under 10 words]
//         3. Exercise and Activity: [Your tip in under 10 words]
//         `;

//         // Request streaming response from Ollama using the selected model
//         const stream = await ollama.chat({
//             model: model,
//             messages: [{ role: 'user', content: prompt }],
//             stream: true
//         });

//         // Pipe chunks to the client as they arrive
//         for await (const chunk of stream) {
//             res.write(`data: ${JSON.stringify({ 
//                 type: 'token', 
//                 text: chunk.message.content 
//             })}\n\n`);
//         }

//         // Close the stream
//         res.write(`data: ${JSON.stringify({ type: 'done' })}\n\n`);
//         res.end();

//     } catch (error) {
//         console.error('Tips Generation Error:', error);
//         res.write(`data: ${JSON.stringify({ error: "An error occurred generating tips." })}\n\n`);
//         res.end();
//     }
// });

// // --- 3. ACCOMMODATIONS ENDPOINT ---
// app.get('/api/accommodations', async (req, res) => {
//   try {
//     const list = await Accommodation.find({ isAvailable: true }).limit(50);
//     res.json({ source: 'mongodb', count: list.length, data: list });
//   } catch (error) {
//     console.error('Accommodations Error:', error);
//     res.status(500).json({ error: 'Server error fetching accommodations' });
//   }
// });

// // --- 4. CAR RENTALS ENDPOINT ---
// app.get('/api/car-rentals', async (req, res) => {
//   try {
//     const list = await CarRental.find({ isAvailable: true }).limit(50);
//     res.json({ source: 'mongodb', count: list.length, data: list });
//   } catch (error) {
//     console.error('Car Rentals Error:', error);
//     res.status(500).json({ error: 'Server error fetching car rentals' });
//   }
// });

// // --- 5. FERRY SERVICE ENDPOINT ---
// app.get('/api/ferry-service', async (req, res) => {
//   try {
//     const list = await Ferry.find({ isAvailable: true }).limit(50);
//     res.json({ source: 'mongodb', count: list.length, data: list });
//   } catch (error) {
//     console.error('Ferry Service Error:', error);
//     res.status(500).json({ error: 'Server error fetching ferry services' });
//   }
// });

// // --- 6. RAPID BUSES ENDPOINT ---
// app.get('/api/rapid-buses', async (req, res) => {
//   try {
//     const list = await BusRoute.find({}).limit(100);
//     res.json({ source: 'mongodb', count: list.length, data: list });
//   } catch (error) {
//     console.error('Rapid Buses Error:', error);
//     res.status(500).json({ error: 'Server error fetching rapid buses' });
//   }
// });

// // --- START SERVER & CONNECT DATABASE ---
// const PORT = process.env.PORT || 3000;

// // Ensure MONGODB_URI is provided
// if (!process.env.MONGODB_URI) {
//     console.error("FATAL ERROR: MONGODB_URI is not defined in .env file");
//     process.exit(1);
// }

// mongoose.connect(process.env.MONGODB_URI).then(() => {
//   console.log('Connected to MongoDB Atlas');
//   app.listen(PORT, () => console.log(`API Server running on http://localhost:${PORT}`));
// }).catch(err => {
//   console.error('Failed to connect to MongoDB', err);
// });

const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });
const express = require('express');
const cors = require('cors');
const mongoose = require('mongoose');
const axios = require('axios');
const { Ollama } = require('ollama');

// --- IMPORT MONGODB MODELS ---
const Place = require('./models/Place');
const PlaceNew = require('./models/PlaceNew');
const Accommodation = require('./models/Accommodation');
const CarRental = require('./models/CarRental');
const Ferry = require('./models/Ferry');
const RapidBus = require('./models/RapidBus');
const BusRoute = require('./models/BusRoute');

// --- IMPORT ROUTERS ---
// This brings in the Bird AI logic we just created
const birdRoutes = require('./routes/birdRoutes');
const placesNewRoutes = require('./routes/placesNewRoutes');


// ==========================================
// CONFIGURATION
// ==========================================
const DEFAULT_OLLAMA_MODEL = 'llama3.2:3b'; 

const app = express();
// This tells Express to allow access to the 'public' folder
app.use(express.static(path.join(__dirname, 'public')));
app.use(cors());
app.use(express.json());
app.use('/api/bird', birdRoutes);

const ollama = new Ollama();

// --- CATEGORY NORMALIZATION MAPS ---
const categoryMap = {
  'Restaurant': 'food & beverages',
  'restaurant': 'food & beverages',
  'Nyonya restaurant': 'food & beverages',
  'Chinese restaurant': 'food & beverages',
  'Western restaurant': 'food & beverages',
  'Malaysian restaurant': 'food & beverages',
  'Asian restaurant': 'food & beverages',
  'fast_food': 'food & beverages',
  'Dinner theater': 'food & beverages',
  'confectionery': 'Dessert and Pastry',
  'ice_cream': 'Dessert and Pastry',
  'cafe': 'Cafes',
  'Cafe': 'Cafes',
  'Coffee shop': 'Cafes',
  'hip cafes': 'Cafes',
  'bar': 'bars & bistros',
  'hotel': 'Accommodations & Hotels',
  'museum': 'Museums & Galleries',
  'Tourist attraction': 'historical sites',
  'arts_centre': 'Museums & Galleries',
  'events_venue': 'cultural & heritage',
  'protected_area': 'nature & parks'
};

const garbageCategories = [
  'yes', 'lawyer', 'pawnbroker', 'military', 'residential', 
  'works', 'car', 'alternative', 'beauty', 'clothes', 'educational_institution', 'college'
];

// --- HELPER 1: Query Photon (OpenStreetMap) API ---
async function fetchFromPhoton(query) {
  try {
    const url = 'https://photon.komoot.io/api/';
    const response = await axios.get(url, {
      params: {
        q: query,
        limit: 10,
        lat: 5.414, 
        lon: 100.328,
        bbox: '100.10,5.10,100.60,5.60'
      },
      timeout: 5000
    });
    return response.data.features || [];
  } catch (error) {
    console.error('Photon API Request Error:', error.message);
    return [];
  }
}

// --- HELPER 2: Transform Photon Feature into MongoDB Place Schema ---
function transformPhotonToPlace(feature) {
  const coords = feature.geometry.coordinates;
  const props = feature.properties;
  const addressParts = [props.name, props.street, props.city, props.state, props.country].filter(Boolean);
  const fullAddress = addressParts.join(', ');
  const placeName = props.name || props.street || 'Unknown Place';

  const rawCategory = props.osm_value || 'General';
  let cleanCategory = categoryMap[rawCategory] || rawCategory;
  
  if (garbageCategories.includes(cleanCategory)) {
    cleanCategory = 'General';
  }

  return {
    place_name: placeName,
    place_summary: fullAddress,
    place_category: cleanCategory,
    place_address: fullAddress,
    place_location: { type: 'Point', coordinates: coords },
    place_business_hours: {},
    place_media: { thumbnail: '', photos: [] },
    place_geofence_radius: 50,
    place_information: {
      osm_id: props.osm_id,
      osm_type: props.osm_type,
      source: 'Photon (OpenStreetMap)'
    },
    external_place_id: `osm_${props.osm_type}_${props.osm_id}`
  };
}

// --- HELPER 3: Fetch Real-Time Weather ---
async function getWeatherData(lat, lon) {
    const url = `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,weather_code,wind_speed_10m&timezone=auto`;
    try {
        const response = await axios.get(url);
        return response.data;
    } catch (error) {
        console.error("Error fetching weather:", error.message);
        return null;
    }
}

function getWeatherDescription(code) {
    const codes = {
        0: 'Clear sky', 1: 'Mainly clear', 2: 'Partly cloudy', 3: 'Overcast',
        45: 'Fog', 48: 'Depositing rime fog', 51: 'Light drizzle', 53: 'Moderate drizzle', 
        61: 'Slight rain', 63: 'Moderate rain', 65: 'Heavy rain', 71: 'Slight snow', 
        95: 'Thunderstorm'
    };
    return codes[code] || 'Unknown conditions';
}


// ==========================================
//                 ENDPOINTS
// ==========================================

// 🐦 HOOK UP THE BIRD CHAT ROUTE
// This tells Express to route all /api/bird/... and /api/v1/bird/... requests to your new file
app.use('/api/bird', birdRoutes);
app.use('/api/v1/bird', birdRoutes);
app.use('/api/v2/places', placesNewRoutes);


// --- 1. MAIN SEARCH ENDPOINT ---
app.get('/api/places/search', async (req, res) => {
  try {
    const query = req.query.q;
    if (!query) return res.status(400).json({ error: 'Search query is required' });

    const words = query.trim().split(/\s+/).filter(Boolean);

    // 1. 针对高质量 places_new 集合的查询条件 (支持名称、关键词、分类、描述与地址)
    const matchAllWordsNew = words.map(word => ({
      $or: [
        { name: { $regex: word, $options: 'i' } },
        { search_keywords: { $regex: word, $options: 'i' } },
        { primary_category: { $regex: word, $options: 'i' } },
        { sub_categories: { $regex: word, $options: 'i' } },
        { summary: { $regex: word, $options: 'i' } },
        { address: { $regex: word, $options: 'i' } }
      ]
    }));

    const penangBoundingBoxNew = {
      location: {
        $geoWithin: { $box: [ [100.10, 5.10], [100.60, 5.60] ] }
      }
    };

    const hasAircon = req.query.has_aircon === 'true';
    const extraFilter = hasAircon ? [{ 'features.has_aircon': true }] : [];

    // 优先从高质量 places_new 集合中查询 (已收录 3,248+ 精品地点)
    let uniqueLocalPlaces = await PlaceNew.find({ 
      $and: [...matchAllWordsNew, penangBoundingBoxNew, ...extraFilter] 
    }).sort({ popularity_score: -1, rating: -1 }).limit(30);

    // 兜底：若 places_new 无匹配，再查询旧版 Place 集合
    if (!uniqueLocalPlaces || uniqueLocalPlaces.length === 0) {
      const matchAllWordsOld = words.map(word => ({
        $or: [
          { place_name: { $regex: word, $options: 'i' } },
          { place_category: { $regex: word, $options: 'i' } },
          { place_address: { $regex: word, $options: 'i' } }
        ]
      }));
      const penangBoundingBoxOld = {
        place_location: {
          $geoWithin: { $box: [ [100.10, 5.10], [100.60, 5.60] ] }
        }
      };

      uniqueLocalPlaces = await Place.find({ 
        $and: [...matchAllWordsOld, penangBoundingBoxOld] 
      }).limit(20);
    }

    if (uniqueLocalPlaces.length > 0) {
      return res.json({ source: 'mongodb', count: uniqueLocalPlaces.length, data: uniqueLocalPlaces });
    }

    console.log(`No MongoDB matches for "${query}". Querying Photon API...`);
    const photonResults = await fetchFromPhoton(query);

    if (photonResults.length === 0) {
      return res.json({ source: 'none', count: 0, data: [] });
    }

    const transformedPlaces = photonResults.map(transformPhotonToPlace);

    const bulkOps = transformedPlaces.map(doc => ({
      updateOne: {
        filter: { external_place_id: doc.external_place_id },
        update: { $set: doc },
        upsert: true
      }
    }));

    if (bulkOps.length > 0) {
      Place.bulkWrite(bulkOps, { ordered: false }).catch(err => {
        console.warn('Auto-caching OSM data failed:', err.message);
      });
    }

    return res.json({ source: 'openstreetmap', count: transformedPlaces.length, data: transformedPlaces });

  } catch (error) {
    console.error('Search API Error:', error);
    res.status(500).json({ error: 'Server error during search' });
  }
});

// --- 2. STREAMING WEATHER LIFESTYLE TIPS ENDPOINT ---
app.get('/api/lifestyle-tips', async (req, res) => {
    const { lat, lon, model = DEFAULT_OLLAMA_MODEL } = req.query;

    if (!lat || !lon) {
        return res.status(400).json({ error: "Please provide 'lat' and 'lon' parameters." });
    }

    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');

    try {
        const weather = await getWeatherData(lat, lon);
        if (!weather) {
            res.write(`data: ${JSON.stringify({ error: "Failed to fetch weather data." })}\n\n`);
            return res.end();
        }

        const current = weather.current;
        const condition = getWeatherDescription(current.weather_code);

        res.write(`data: ${JSON.stringify({ 
            type: 'weather_metadata', 
            data: {
                temp: current.temperature_2m,
                feels_like: current.apparent_temperature,
                condition: condition,
                humidity: current.relative_humidity_2m
            }
        })}\n\n`);

        const prompt = `
        You are an expert travel advisor. Look at the current weather for a traveler's location:
        - Temp: ${current.temperature_2m}°C (Feels like ${current.apparent_temperature}°C)
        - Condition: ${condition}
        - Humidity: ${current.relative_humidity_2m}%
        - Wind Speed: ${current.wind_speed_10m} km/h
        
        Based ONLY on this specific weather, provide short, actionable lifestyle tips across the 3 categories below.
        
        CRITICAL CONSTRAINT: 
        - Provide exactly THREE bullet point tip per category.
        - Each tips MUST be 10 words or fewer.

        Format your output exactly as:
        1. Hydration and Diet: [Your tip in under 10 words]
        2. Clothing and Sun Protection: [Your tip in under 10 words]
        3. Exercise and Activity: [Your tip in under 10 words]
        `;

        const stream = await ollama.chat({
            model: model,
            messages: [{ role: 'user', content: prompt }],
            stream: true
        });

        for await (const chunk of stream) {
            res.write(`data: ${JSON.stringify({ 
                type: 'token', 
                text: chunk.message.content 
            })}\n\n`);
        }

        res.write(`data: ${JSON.stringify({ type: 'done' })}\n\n`);
        res.end();

    } catch (error) {
        console.error('Tips Generation Error:', error);
        res.write(`data: ${JSON.stringify({ error: "An error occurred generating tips." })}\n\n`);
        res.end();
    }
});

// --- 3. ACCOMMODATIONS ENDPOINT ---
app.get('/api/accommodations', async (req, res) => {
  try {
    const list = await Accommodation.find({ isAvailable: true }).limit(50);
    res.json({ source: 'mongodb', count: list.length, data: list });
  } catch (error) {
    console.error('Accommodations Error:', error);
    res.status(500).json({ error: 'Server error fetching accommodations' });
  }
});

// --- 4. CAR RENTALS ENDPOINT ---
app.get('/api/car-rentals', async (req, res) => {
  try {
    const list = await CarRental.find({ isAvailable: true }).limit(50);
    res.json({ source: 'mongodb', count: list.length, data: list });
  } catch (error) {
    console.error('Car Rentals Error:', error);
    res.status(500).json({ error: 'Server error fetching car rentals' });
  }
});

// --- 5. FERRY SERVICE ENDPOINT ---
app.get('/api/ferry-service', async (req, res) => {
  try {
    const list = await Ferry.find({ isAvailable: true }).limit(50);
    res.json({ source: 'mongodb', count: list.length, data: list });
  } catch (error) {
    console.error('Ferry Service Error:', error);
    res.status(500).json({ error: 'Server error fetching ferry services' });
  }
});

// --- 6. RAPID BUSES ENDPOINT ---
app.get('/api/rapid-buses', async (req, res) => {
  try {
    const list = await BusRoute.find({}).limit(100);
    res.json({ source: 'mongodb', count: list.length, data: list });
  } catch (error) {
    console.error('Rapid Buses Error:', error);
    res.status(500).json({ error: 'Server error fetching rapid buses' });
  }
});

// --- START SERVER & CONNECT DATABASE ---
const PORT = process.env.PORT || 3000;

if (!process.env.MONGODB_URI) {
    console.error("FATAL ERROR: MONGODB_URI is not defined in .env file");
    process.exit(1);
}

mongoose.connect(process.env.MONGODB_URI).then(() => {
  console.log('✅ Connected to MongoDB Atlas');
  app.listen(PORT, '0.0.0.0', () => {
      console.log(`🚀 API Server running on http://0.0.0.0:${PORT} (Accessible via localhost and your LAN IP)`);
      console.log(`💬 Bird Chat Endpoint ready at http://0.0.0.0:${PORT}/api/bird/chat`);
  });
}).catch(err => {
  console.error('❌ Failed to connect to MongoDB', err);
});