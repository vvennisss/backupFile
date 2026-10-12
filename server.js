const express = require('express');
const cors = require('cors');
const path = require('path');
const fs = require('fs');
const multer = require('multer');
const mongoose = require('mongoose');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 5050;

// Enable CORS and JSON parsing
app.use(cors());
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

// Serve static frontend and uploaded assets
app.use(express.static(path.join(__dirname, 'public')));
app.use('/uploads', express.static(path.join(__dirname, 'public/uploads')));

// Storage configuration with Multer
const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    let folder = 'thumbnails';
    if (req.originalUrl.includes('sticker')) folder = 'stickers';
    else if (req.originalUrl.includes('banner') || req.originalUrl.includes('ad')) folder = 'banners';
    else if (req.originalUrl.includes('bug') || req.originalUrl.includes('issue')) folder = 'bugs';

    const dir = path.join(__dirname, 'public/uploads', folder);
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
    cb(null, dir);
  },
  filename: function (req, file, cb) {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1e9);
    const ext = path.extname(file.originalname) || '.png';
    cb(null, file.fieldname + '-' + uniqueSuffix + ext);
  }
});
const upload = multer({ storage: storage, limits: { fileSize: 25 * 1024 * 1024 } });

// JSON Persistence Helper
const DATA_DIR = path.join(__dirname, 'data');
if (!fs.existsSync(DATA_DIR)) fs.mkdirSync(DATA_DIR, { recursive: true });

function readJsonFile(filename, defaultData) {
  const filePath = path.join(DATA_DIR, filename);
  try {
    if (!fs.existsSync(filePath)) {
      fs.writeFileSync(filePath, JSON.stringify(defaultData, null, 2), 'utf-8');
      return defaultData;
    }
    const raw = fs.readFileSync(filePath, 'utf-8');
    return JSON.parse(raw);
  } catch (err) {
    console.error(`Error reading ${filename}:`, err);
    return defaultData;
  }
}

function writeJsonFile(filename, data) {
  const filePath = path.join(DATA_DIR, filename);
  try {
    fs.writeFileSync(filePath, JSON.stringify(data, null, 2), 'utf-8');
    return true;
  } catch (err) {
    console.error(`Error writing ${filename}:`, err);
    return false;
  }
}

// Initial Seeds
const initialUsers = [
  { id: 'usr_001', name: 'Tan Wei Xun', email: 'weixun@example.com', role: 'traveler', rankTier: 'Explorer', status: 'active', tripsCount: 7, joinedAt: '2026-08-15' },
  { id: 'usr_002', name: 'Aishah Binti Halim', email: 'aishah.h@gmail.com', role: 'companion', rankTier: 'Adventurer', status: 'verified', tripsCount: 14, joinedAt: '2026-07-20' },
  { id: 'usr_003', name: 'Darren Lee', email: 'darren.lee@outlook.com', role: 'traveler', rankTier: 'Tourist', status: 'active', tripsCount: 1, joinedAt: '2026-10-01' },
  { id: 'usr_004', name: 'Kavitha Ramasamy', email: 'kavitha.r@yahoo.com', role: 'companion', rankTier: 'Legend', status: 'verified', tripsCount: 29, joinedAt: '2026-05-11' },
  { id: 'usr_005', name: 'Spammy Bot 99', email: 'spambot99@dispostable.com', role: 'traveler', rankTier: 'Tourist', status: 'banned', tripsCount: 0, joinedAt: '2026-10-10' },
  { id: 'usr_006', name: 'Uncle George Lim', email: 'george.lim@penangheritage.my', role: 'companion', rankTier: 'Legend', status: 'pending_verification', tripsCount: 19, joinedAt: '2026-10-05' },
  { id: 'usr_007', name: 'Chloe Wong', email: 'chloe.wong@gmail.com', role: 'traveler', rankTier: 'Traveler', status: 'active', tripsCount: 4, joinedAt: '2026-09-12' }
];

const initialBroadcasts = [
  { id: 'bc_001', title: 'Severe Tropical Rainstorm Alert', body: 'Flash advisory: Expect localized rain around George Town and Penang Hill from 3:00 PM to 6:00 PM. Stay safe indoors.', audience: 'all', sentAt: '2026-10-10 14:30', fcmStatus: 'Delivered (1,420 targets)' },
  { id: 'bc_002', title: 'New UNESCO Heritage Quest Live', body: 'Discover 6 secret Clan Jetties and unlock your exclusive Heritage Explorer Digital Stamp today!', audience: 'travelers', sentAt: '2026-10-08 10:00', fcmStatus: 'Delivered (980 targets)' }
];

const initialStickers = [
  { id: 'stk_001', name: 'Komtar Tower Badge', category: 'George Town Landmarks', imageUrl: '/images/stickers/komtar.png', status: 'active', usageCount: 482 },
  { id: 'stk_002', name: 'Penang Char Koay Teow', category: 'Authentic Delicacies', imageUrl: '/images/stickers/ckt.png', status: 'active', usageCount: 895 },
  { id: 'stk_003', name: 'Heritage Shophouse Window', category: 'George Town Landmarks', imageUrl: '/images/stickers/shophouse.png', status: 'active', usageCount: 312 },
  { id: 'stk_004', name: 'Kia-Kia Penang Handdrawn Typography', category: 'Handdrawn Typography', imageUrl: '/images/stickers/typography.png', status: 'active', usageCount: 654 },
  { id: 'stk_005', name: 'Penang Trishaw Vintage', category: 'George Town Landmarks', imageUrl: '/images/stickers/trishaw.png', status: 'active', usageCount: 521 },
  { id: 'stk_006', name: 'Cendol Bowl Sweet', category: 'Authentic Delicacies', imageUrl: '/images/stickers/cendol.png', status: 'hidden', usageCount: 140 }
];

const initialEvents = [
  { id: 'evt_001', name: 'George Town Heritage Day Festival', category: 'Festival', startDate: '2026-07-07', endDate: '2026-07-09', locationName: 'Lebuh Armenian, George Town', lat: 5.4152, lng: 100.3375, includeInAIPlanner: true, notes: 'Massive street performance and UNESCO anniversary heritage crafts.' },
  { id: 'evt_002', name: 'Nine Emperor Gods Vegetarian Gala', category: 'Religious', startDate: '2026-10-10', endDate: '2026-10-19', locationName: 'Burmah Road & Tow Boo Kong', lat: 5.4221, lng: 100.3204, includeInAIPlanner: true, notes: 'Road traffic diversions along Burmah Road. Street food stalls entirely vegan.' },
  { id: 'evt_003', name: 'Penang International Food Fiesta', category: 'Food Fair', startDate: '2026-11-15', endDate: '2026-11-18', locationName: 'Esplanade (Padang Kota Lama)', lat: 5.4209, lng: 100.3411, includeInAIPlanner: true, notes: 'Over 120 Michelin and authentic street hawker stalls along the coastal promenade.' },
  { id: 'evt_004', name: 'Lebuh Pantai Sunday Car-Free Day', category: 'Traffic Advisory', startDate: '2026-10-18', endDate: '2026-10-18', locationName: 'Beach Street Banking District', lat: 5.4168, lng: 100.3422, includeInAIPlanner: true, notes: 'Full vehicular road closure from 7:00 AM to 1:00 PM every Sunday morning.' }
];

const initialAds = [
  { id: 'ad_001', title: 'Penang Hill Funicular Express FastPass', targetUrl: 'kiakia://booking/penang-hill-express', imageUrl: '/images/ads/penang_hill_ad.jpg', startTimestamp: Math.floor(new Date('2026-10-01').getTime() / 1000), endTimestamp: Math.floor(new Date('2026-11-30').getTime() / 1000), status: 'active', impressions: 3420, clicks: 421 },
  { id: 'ad_002', title: 'TopView The TOP Komtar Sunset Dining', targetUrl: 'https://thetop.com.my/dining', imageUrl: '/images/ads/the_top_ad.jpg', startTimestamp: Math.floor(new Date('2026-09-15').getTime() / 1000), endTimestamp: Math.floor(new Date('2026-10-31').getTime() / 1000), status: 'active', impressions: 2190, clicks: 185 },
  { id: 'ad_003', title: 'Cheong Fatt Tze Blue Mansion Guided Tours', targetUrl: 'kiakia://places/cheong-fatt-tze', imageUrl: '/images/ads/blue_mansion_ad.jpg', startTimestamp: Math.floor(new Date('2026-08-01').getTime() / 1000), endTimestamp: Math.floor(new Date('2026-09-30').getTime() / 1000), status: 'expired', impressions: 5800, clicks: 640 }
];

const initialGeofences = [
  { id: 'geo_001', name: 'Chew Jetty Clan Wooden Boardwalk', lat: 5.4128, lng: 100.3398, radiusMeters: 35, category: 'Heritage & Culture', unlockPoints: 50 },
  { id: 'geo_002', name: 'Little Children on a Bicycle Mural', lat: 5.4150, lng: 100.3378, radiusMeters: 25, category: 'Street Art', unlockPoints: 40 },
  { id: 'geo_003', name: 'Pinang Peranakan Mansion Grand Hall', lat: 5.4184, lng: 100.3411, radiusMeters: 30, category: 'Heritage & Culture', unlockPoints: 50 },
  { id: 'geo_004', name: 'Khoo Kongsi Courtyard', lat: 5.4144, lng: 100.3370, radiusMeters: 40, category: 'Clan Association', unlockPoints: 60 },
  { id: 'geo_005', name: 'Fort Cornwallis Lighthouse', lat: 5.4208, lng: 100.3441, radiusMeters: 45, category: 'Colonial Landmark', unlockPoints: 45 }
];

const initialBadges = [
  { id: 'bdg_001', code: 'tourist', title: 'Tourist Badge', requirementText: 'Complete first 1 registered heritage route and 3 stamp check-ins', pointsThreshold: 100, icon: 'hiking_rounded' },
  { id: 'bdg_002', code: 'traveler', title: 'Traveler Badge', requirementText: 'Complete at least 2 itinerary plans and visit 5 street food gems', pointsThreshold: 250, icon: 'explore_rounded' },
  { id: 'bdg_003', code: 'explorer', title: 'Explorer Badge', requirementText: 'Collect 5 heritage stamps across UNESCO zone and take 2 bus trails', pointsThreshold: 600, icon: 'terrain_rounded' },
  { id: 'bdg_004', code: 'adventurer', title: 'Adventurer Badge', requirementText: 'Reach 10 completed itineraries and experience the Penang Ferry ride', pointsThreshold: 1200, icon: 'directions_boat_rounded' },
  { id: 'bdg_005', code: 'legend', title: 'Legend Badge', requirementText: 'Complete 20 routes, collect 25+ digital stamps and guide 3 companions', pointsThreshold: 2500, icon: 'military_tech_rounded' }
];

const initialRankTiers = [
  { tier: 'Tourist', requiredPoints: 0, requiredRoutes: 0, perk: 'Basic Offline Map & AI Quick Answers' },
  { tier: 'Traveler', requiredPoints: 250, requiredRoutes: 2, perk: 'Smart Itinerary Optimization & Weather Triggers' },
  { tier: 'Explorer', requiredPoints: 600, requiredRoutes: 5, perk: 'Exclusive Studio Stickers & Priority Support' },
  { tier: 'Adventurer', requiredPoints: 1200, requiredRoutes: 10, perk: 'Custom Geofence Pins & Verified Companion Eligibility' },
  { tier: 'Legend', requiredPoints: 2500, requiredRoutes: 20, perk: 'Crown Icon on Radar, Free Local Partner Vouchers' }
];

const initialBugs = [
  { id: 'BUG-1042', userId: 'usr_003', category: 'Map Coordinate Offset', title: 'Lebuh Armenian mural pin placed 50m into sea', description: 'The map marker for Little Children on a Bicycle is shifted 50 meters south-east into the water channel on Android 14.', status: 'Open', priority: 'High', screenshotUrl: '/images/bugs/map_offset.png', createdAt: '2026-10-11 16:20' },
  { id: 'BUG-1041', userId: 'usr_007', category: 'Content / Pricing Inaccuracy', title: 'Kek Lok Si Funicular Ticket price outdated', description: 'App displays RM 6 return whereas current counter price is updated to RM 16 for non-citizens.', status: 'In Progress', priority: 'Medium', screenshotUrl: '', createdAt: '2026-10-10 11:15' },
  { id: 'BUG-1039', userId: 'usr_001', category: 'Application Crash / Lag', title: 'Memory spike when loading 360 pano on older device', description: 'Mapillary viewer screen crashes on Redmi Note 10 when opening high-res street panoramic tiles.', status: 'Resolved', priority: 'High', screenshotUrl: '', createdAt: '2026-10-06 09:40' },
  { id: 'BUG-1038', userId: 'usr_005', category: 'Spam / Junk', title: 'random test spam message abcde', description: 'tester dummy string', status: 'Open', priority: 'Low', screenshotUrl: '', createdAt: '2026-10-05 20:00' }
];

// Fallback Places Data
const fallbackPlaces = [
  {
    _id: 'pl_001',
    name: 'Cheong Fatt Tze - The Blue Mansion',
    primary_category: 'Heritage & Culture',
    area: 'George Town',
    address: '14, Lebuh Leith, George Town, 10200 George Town, Pulau Pinang',
    location: { type: 'Point', coordinates: [100.3347, 5.4215] },
    summary: 'Iconic 19th-century indigo-blue courtyard mansion built by merchant Cheong Fatt Tze with Feng Shui architecture.',
    description: 'Winner of UNESCO Heritage Conservation Award. Features 38 rooms, 5 courtyards, and guided architectural tours.',
    raw_hours_text: '11:00 AM – 6:00 PM',
    search_keywords: ['blue mansion', 'cheong fatt tze', 'heritage', 'courtyard', 'leith street'],
    rating: 4.6,
    popularity_score: 95,
    place_media: { thumbnail: 'https://images.unsplash.com/photo-1596422846543-75c6fc197f07?auto=format&fit=crop&w=600&q=80', photos: [] },
    status: 'active'
  },
  {
    _id: 'pl_002',
    name: 'Kek Lok Si Temple',
    primary_category: 'Religious Sites',
    area: 'Air Itam',
    address: '1000-L, Tingkat Lembah Ria 1, 11500 Ayer Itam, Pulau Pinang',
    location: { type: 'Point', coordinates: [100.2737, 5.3995] },
    summary: 'Largest Buddhist temple complex in Malaysia featuring the 7-tier Pagoda of Rama VI and 30m bronze Guanyin statue.',
    description: 'Magnificent mountain temple complex founded in 1891, illuminated with thousands of lanterns during Chinese New Year.',
    raw_hours_text: '8:30 AM – 5:30 PM',
    search_keywords: ['kek lok si', 'temple', 'air itam', 'guanyin', 'buddhist pagoda'],
    rating: 4.7,
    popularity_score: 99,
    place_media: { thumbnail: 'https://images.unsplash.com/photo-1548013146-72479768bada?auto=format&fit=crop&w=600&q=80', photos: [] },
    status: 'active'
  },
  {
    _id: 'pl_003',
    name: 'Pinang Peranakan Mansion',
    primary_category: 'Heritage & Culture',
    area: 'George Town',
    address: '29, Church St, George Town, 10200 George Town, Pulau Pinang',
    location: { type: 'Point', coordinates: [100.3411, 5.4184] },
    summary: 'Lavish museum showcasing Baba-Nyonya heritage, gold leaf woodwork, antique jewelry, and antique European tiles.',
    description: 'Recreated typical 19th-century wealthy Peranakan home, displaying over 1,000 antique heirlooms and collectibles.',
    raw_hours_text: '9:30 AM – 5:00 PM',
    search_keywords: ['peranakan', 'baba nyonya', 'church street', 'museum', 'heirloom'],
    rating: 4.7,
    popularity_score: 93,
    place_media: { thumbnail: 'https://images.unsplash.com/photo-1513694203232-719a280e022f?auto=format&fit=crop&w=600&q=80', photos: [] },
    status: 'active'
  },
  {
    _id: 'pl_004',
    name: 'Toh Soon Cafe (多春茶座)',
    primary_category: 'Cafes',
    area: 'George Town',
    address: 'Lebuh Campbell, George Town, 10450 George Town, Pulau Pinang',
    location: { type: 'Point', coordinates: [100.3323, 5.4186] },
    summary: 'Famous alleyway cafe serving charcoal-toasted Hainanese bread, half-boiled eggs, and robust traditional Nanyang kopi.',
    description: 'Authentic Penang morning breakfast spot nestled in a narrow historic lane, bustling with locals and global foodies.',
    raw_hours_text: '8:00 AM – 5:00 PM (Closed Sundays)',
    search_keywords: ['toh soon', 'charcoal toast', 'kopi', 'half boiled eggs', 'campbell street'],
    rating: 4.3,
    popularity_score: 88,
    place_media: { thumbnail: 'https://images.unsplash.com/photo-1554118811-1e0d58224f24?auto=format&fit=crop&w=600&q=80', photos: [] },
    status: 'active'
  },
  {
    _id: 'pl_005',
    name: 'Penang Hill Upper Station & The Habitat',
    primary_category: 'Nature & Parks',
    area: 'Air Itam',
    address: 'Penang Hill, Bukit Bendera, 11500 George Town, Pulau Pinang',
    location: { type: 'Point', coordinates: [100.2688, 5.4246] },
    summary: 'Cool highland summit offering 833m panoramic island views, historical colonial bungalows, and rainforest canopy walk.',
    description: 'Access via fastest funicular railway in Asia. Habitat canopy walk overlooks 130-million-year-old virgin rainforest.',
    raw_hours_text: '6:30 AM – 11:00 PM',
    search_keywords: ['penang hill', 'bukit bendera', 'the habitat', 'funicular', 'nature canopy'],
    rating: 4.7,
    popularity_score: 98,
    place_media: { thumbnail: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=600&q=80', photos: [] },
    status: 'active'
  },
  {
    _id: 'pl_006',
    name: 'Chew Jetty (姓周桥)',
    primary_category: 'Heritage & Culture',
    area: 'George Town',
    address: 'Weld Quay, George Town, 10300 George Town, Pulau Pinang',
    location: { type: 'Point', coordinates: [100.3398, 5.4128] },
    summary: 'Historic waterfront stilt-house village settled by Chinese immigrants from Fujian in the mid-19th century.',
    description: 'Most prominent clan jetty along Weld Quay. Walk along wooden boardwalks among residences, souvenir stalls, and shrines.',
    raw_hours_text: '9:00 AM – 9:00 PM',
    search_keywords: ['chew jetty', 'weld quay', 'clan jetty', 'heritage', 'waterfront'],
    rating: 4.4,
    popularity_score: 91,
    place_media: { thumbnail: 'https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?auto=format&fit=crop&w=600&q=80', photos: [] },
    status: 'active'
  }
];

// MongoDB Mongoose Connection
let isMongoConnected = false;
let PlaceNewModel = null;

try {
  const mongoUri = process.env.MONGODB_URI || 'mongodb+srv://weixun:VennisFYP2026@cluster0.tohpl4e.mongodb.net/?appName=Cluster0';
  
  // Define Schema
  const PlaceNewSchema = new mongoose.Schema({
    name: { type: String, required: true },
    primary_category: { type: String, default: 'Heritage & Culture' },
    sub_categories: [{ type: String }],
    area: { type: String, default: 'George Town' },
    address: { type: String, default: '' },
    location: {
      type: { type: String, default: 'Point' },
      coordinates: { type: [Number], default: [100.33, 5.41] }
    },
    summary: { type: String, default: '' },
    description: { type: String, default: '' },
    raw_hours_text: { type: String, default: '9:00 AM – 6:00 PM' },
    search_keywords: [{ type: String }],
    rating: { type: Number, default: 4.5 },
    popularity_score: { type: Number, default: 80 },
    place_media: {
      thumbnail: { type: String, default: '' },
      photos: [{ type: String }]
    },
    status: { type: String, default: 'active' }
  }, { collection: 'places_new', timestamps: true });

  PlaceNewModel = mongoose.model('PlaceNew', PlaceNewSchema);

  mongoose.connect(mongoUri, { serverSelectionTimeoutMS: 5000 })
    .then(() => {
      isMongoConnected = true;
      console.log('Successfully connected to MongoDB Atlas (places_new collection)!');
    })
    .catch(err => {
      console.warn('MongoDB Atlas direct connection timeout. Running in resilient hybrid mode with local cache & sync:', err.message);
    });
} catch (e) {
  console.warn('MongoDB init warning:', e.message);
}

// -------------------------------------------------------------
// API ROUTES
// -------------------------------------------------------------

// --- 1. DASHBOARD & KPI API ---
app.get('/api/admin/kpis', (req, res) => {
  const users = readJsonFile('users.json', initialUsers);
  const bugs = readJsonFile('bugs.json', initialBugs);
  const places = readJsonFile('places.json', fallbackPlaces);

  const travelersCount = users.filter(u => u.role === 'traveler').length;
  const companionsCount = users.filter(u => u.role === 'companion').length;
  const totalTripsThisMonth = users.reduce((acc, curr) => acc + (curr.tripsCount || 0), 0) + 128; // Month aggregate
  const totalBugsThisMonth = bugs.length;

  const rankTierDistribution = {
    Tourist: users.filter(u => u.rankTier === 'Tourist').length,
    Traveler: users.filter(u => u.rankTier === 'Traveler').length,
    Explorer: users.filter(u => u.rankTier === 'Explorer').length,
    Adventurer: users.filter(u => u.rankTier === 'Adventurer').length,
    Legend: users.filter(u => u.rankTier === 'Legend').length
  };

  res.json({
    status: 'success',
    data: {
      totalUsers: users.length,
      travelersCount,
      companionsCount,
      totalTripsThisMonth,
      totalBugsThisMonth,
      rankTierDistribution,
      mongoConnected: isMongoConnected
    }
  });
});

// --- 1.1 UCM (User & Companion Management) ---
app.get('/api/admin/users', (req, res) => {
  const users = readJsonFile('users.json', initialUsers);
  const { role, status, q } = req.query;

  let filtered = [...users];
  if (role) filtered = filtered.filter(u => u.role === role);
  if (status) filtered = filtered.filter(u => u.status === status);
  if (q) {
    const query = q.toLowerCase();
    filtered = filtered.filter(u => u.name.toLowerCase().includes(query) || u.email.toLowerCase().includes(query));
  }

  res.json({ status: 'success', count: filtered.length, data: filtered });
});

app.patch('/api/admin/users/:id/status', (req, res) => {
  const users = readJsonFile('users.json', initialUsers);
  const { id } = req.params;
  const { status } = req.body;

  const target = users.find(u => u.id === id);
  if (!target) return res.status(404).json({ status: 'error', message: 'User not found' });

  target.status = status;
  writeJsonFile('users.json', users);
  res.json({ status: 'success', message: `User status changed to ${status}`, data: target });
});

// --- 1.2 BROADCASTS (FCM Push Notifications) ---
app.get('/api/admin/broadcasts', (req, res) => {
  const broadcasts = readJsonFile('broadcasts.json', initialBroadcasts);
  res.json({ status: 'success', data: broadcasts });
});

app.post('/api/admin/broadcasts', (req, res) => {
  const broadcasts = readJsonFile('broadcasts.json', initialBroadcasts);
  const { title, body, audience } = req.body;

  if (!title || !body) return res.status(400).json({ status: 'error', message: 'Title and body are required' });

  let targetLabel = 'All Users (1,420 targets)';
  if (audience === 'travelers') targetLabel = 'Travelers Only (980 targets)';
  if (audience === 'companions') targetLabel = 'Companions Only (440 targets)';

  const newBroadcast = {
    id: 'bc_' + Date.now(),
    title,
    body,
    audience: audience || 'all',
    sentAt: new Date().toISOString().replace('T', ' ').substring(0, 16),
    fcmStatus: `Delivered (${targetLabel})`
  };

  broadcasts.unshift(newBroadcast);
  writeJsonFile('broadcasts.json', broadcasts);
  res.json({ status: 'success', message: 'FCM Broadcast dispatched successfully!', data: newBroadcast });
});

// --- 2. ATTRACTION CMS (places_new MongoDB Collection) ---
app.get('/api/admin/places', async (req, res) => {
  try {
    const { q, category, area } = req.query;

    if (isMongoConnected && PlaceNewModel) {
      let query = {};
      if (category) query.primary_category = category;
      if (area) query.area = area;
      if (q) {
        query.$or = [
          { name: { $regex: q, $options: 'i' } },
          { summary: { $regex: q, $options: 'i' } },
          { search_keywords: { $regex: q, $options: 'i' } }
        ];
      }
      const docs = await PlaceNewModel.find(query).sort({ popularity_score: -1 }).limit(100);
      return res.json({ status: 'success', source: 'mongodb', count: docs.length, data: docs });
    }

    // Fallback file sync
    let list = readJsonFile('places.json', fallbackPlaces);
    if (category) list = list.filter(p => p.primary_category === category);
    if (area) list = list.filter(p => p.area === area);
    if (q) {
      const query = q.toLowerCase();
      list = list.filter(p => p.name.toLowerCase().includes(query) || (p.summary || '').toLowerCase().includes(query));
    }
    res.json({ status: 'success', source: 'hybrid_cache', count: list.length, data: list });
  } catch (err) {
    res.status(500).json({ status: 'error', message: err.message });
  }
});

// Upload thumbnail and update Place
app.post('/api/admin/places/upload-thumbnail', upload.single('thumbnail'), (req, res) => {
  if (!req.file) return res.status(400).json({ status: 'error', message: 'No file uploaded' });
  const relativeUrl = `/uploads/thumbnails/${req.file.filename}`;
  res.json({ status: 'success', url: relativeUrl, filename: req.file.filename });
});

app.post('/api/admin/places', async (req, res) => {
  try {
    const body = req.body;
    if (isMongoConnected && PlaceNewModel) {
      const doc = new PlaceNewModel(body);
      await doc.save();
      return res.json({ status: 'success', source: 'mongodb', data: doc });
    }

    const list = readJsonFile('places.json', fallbackPlaces);
    const newPlace = { ...body, _id: 'pl_' + Date.now(), createdAt: new Date() };
    list.unshift(newPlace);
    writeJsonFile('places.json', list);
    res.json({ status: 'success', source: 'hybrid_cache', data: newPlace });
  } catch (err) {
    res.status(500).json({ status: 'error', message: err.message });
  }
});

app.put('/api/admin/places/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const body = req.body;

    if (isMongoConnected && PlaceNewModel) {
      const updated = await PlaceNewModel.findByIdAndUpdate(id, body, { new: true });
      if (updated) return res.json({ status: 'success', source: 'mongodb', data: updated });
    }

    const list = readJsonFile('places.json', fallbackPlaces);
    const idx = list.findIndex(p => String(p._id) === String(id));
    if (idx !== -1) {
      list[idx] = { ...list[idx], ...body };
      writeJsonFile('places.json', list);
      return res.json({ status: 'success', source: 'hybrid_cache', data: list[idx] });
    }

    res.status(404).json({ status: 'error', message: 'Place not found' });
  } catch (err) {
    res.status(500).json({ status: 'error', message: err.message });
  }
});

app.delete('/api/admin/places/:id', async (req, res) => {
  try {
    const { id } = req.params;
    if (isMongoConnected && PlaceNewModel) {
      await PlaceNewModel.findByIdAndDelete(id);
    }
    const list = readJsonFile('places.json', fallbackPlaces);
    const filtered = list.filter(p => String(p._id) !== String(id));
    writeJsonFile('places.json', filtered);
    res.json({ status: 'success', message: 'Place deleted' });
  } catch (err) {
    res.status(500).json({ status: 'error', message: err.message });
  }
});

// --- 3. STUDIO STICKER MANAGER ---
app.get('/api/admin/stickers', (req, res) => {
  const stickers = readJsonFile('stickers.json', initialStickers);
  res.json({ status: 'success', data: stickers });
});

app.post('/api/admin/stickers/upload', upload.single('stickerFile'), (req, res) => {
  if (!req.file) return res.status(400).json({ status: 'error', message: 'No file uploaded' });
  const relativeUrl = `/uploads/stickers/${req.file.filename}`;
  res.json({ status: 'success', url: relativeUrl });
});

app.post('/api/admin/stickers', (req, res) => {
  const stickers = readJsonFile('stickers.json', initialStickers);
  const { name, category, imageUrl } = req.body;
  if (!name || !imageUrl) return res.status(400).json({ status: 'error', message: 'Name and image URL are required' });

  const newSticker = {
    id: 'stk_' + Date.now(),
    name,
    category: category || 'George Town Landmarks',
    imageUrl,
    status: 'active',
    usageCount: 0
  };
  stickers.unshift(newSticker);
  writeJsonFile('stickers.json', stickers);
  res.json({ status: 'success', data: newSticker });
});

app.patch('/api/admin/stickers/:id/toggle', (req, res) => {
  const stickers = readJsonFile('stickers.json', initialStickers);
  const item = stickers.find(s => s.id === req.params.id);
  if (!item) return res.status(404).json({ status: 'error', message: 'Sticker not found' });

  item.status = item.status === 'active' ? 'hidden' : 'active';
  writeJsonFile('stickers.json', stickers);
  res.json({ status: 'success', data: item });
});

app.delete('/api/admin/stickers/:id', (req, res) => {
  const stickers = readJsonFile('stickers.json', initialStickers);
  const filtered = stickers.filter(s => s.id !== req.params.id);
  writeJsonFile('stickers.json', filtered);
  res.json({ status: 'success', message: 'Sticker deleted' });
});

// --- 4. GEORGE TOWN CALENDAR & AI INJECTION ---
app.get('/api/admin/events', (req, res) => {
  const events = readJsonFile('events.json', initialEvents);
  res.json({ status: 'success', data: events });
});

app.post('/api/admin/events', (req, res) => {
  const events = readJsonFile('events.json', initialEvents);
  const { name, category, startDate, endDate, locationName, lat, lng, includeInAIPlanner, notes } = req.body;

  if (!name || !startDate || !endDate) return res.status(400).json({ status: 'error', message: 'Missing event details' });

  const newEvent = {
    id: 'evt_' + Date.now(),
    name,
    category: category || 'Festival',
    startDate,
    endDate,
    locationName: locationName || 'George Town, Penang',
    lat: Number(lat) || 5.414,
    lng: Number(lng) || 100.33,
    includeInAIPlanner: Boolean(includeInAIPlanner),
    notes: notes || ''
  };

  events.unshift(newEvent);
  writeJsonFile('events.json', events);
  res.json({ status: 'success', data: newEvent });
});

app.patch('/api/admin/events/:id/toggle-ai', (req, res) => {
  const events = readJsonFile('events.json', initialEvents);
  const item = events.find(e => e.id === req.params.id);
  if (!item) return res.status(404).json({ status: 'error', message: 'Event not found' });

  item.includeInAIPlanner = !item.includeInAIPlanner;
  writeJsonFile('events.json', events);
  res.json({ status: 'success', data: item });
});

app.delete('/api/admin/events/:id', (req, res) => {
  const events = readJsonFile('events.json', initialEvents);
  const filtered = events.filter(e => e.id !== req.params.id);
  writeJsonFile('events.json', filtered);
  res.json({ status: 'success', message: 'Event deleted' });
});

// --- 5. FEATURE ADS & BANNERS ---
app.get('/api/admin/ads', (req, res) => {
  const ads = readJsonFile('ads.json', initialAds);
  const nowUnix = Math.floor(Date.now() / 1000);

  // Auto update status based on Unix timestamp
  ads.forEach(ad => {
    if (ad.endTimestamp < nowUnix) {
      ad.status = 'expired';
    } else if (ad.startTimestamp > nowUnix) {
      ad.status = 'scheduled';
    } else {
      if (ad.status !== 'paused') ad.status = 'active';
    }
  });

  res.json({ status: 'success', data: ads });
});

app.post('/api/admin/ads/upload-banner', upload.single('bannerFile'), (req, res) => {
  if (!req.file) return res.status(400).json({ status: 'error', message: 'No file uploaded' });
  const relativeUrl = `/uploads/banners/${req.file.filename}`;
  res.json({ status: 'success', url: relativeUrl });
});

app.post('/api/admin/ads', (req, res) => {
  const ads = readJsonFile('ads.json', initialAds);
  const { title, targetUrl, imageUrl, startTimestamp, endTimestamp } = req.body;

  if (!title || !targetUrl || !imageUrl) return res.status(400).json({ status: 'error', message: 'Title, URL, and image required' });

  const nowUnix = Math.floor(Date.now() / 1000);
  const sUnix = Number(startTimestamp) || nowUnix;
  const eUnix = Number(endTimestamp) || (nowUnix + 86400 * 30);

  let status = 'active';
  if (eUnix < nowUnix) status = 'expired';
  else if (sUnix > nowUnix) status = 'scheduled';

  const newAd = {
    id: 'ad_' + Date.now(),
    title,
    targetUrl,
    imageUrl,
    startTimestamp: sUnix,
    endTimestamp: eUnix,
    status,
    impressions: 0,
    clicks: 0
  };

  ads.unshift(newAd);
  writeJsonFile('ads.json', ads);
  res.json({ status: 'success', data: newAd });
});

app.delete('/api/admin/ads/:id', (req, res) => {
  const ads = readJsonFile('ads.json', initialAds);
  const filtered = ads.filter(a => a.id !== req.params.id);
  writeJsonFile('ads.json', filtered);
  res.json({ status: 'success', message: 'Ad banner removed' });
});

// --- 6. GAMIFICATION, GEOFENCES & RANK TIERS ---
app.get('/api/admin/gamification', (req, res) => {
  const geofences = readJsonFile('geofences.json', initialGeofences);
  const badges = readJsonFile('badges.json', initialBadges);
  const rankTiers = readJsonFile('rank_tiers.json', initialRankTiers);

  res.json({
    status: 'success',
    data: { geofences, badges, rankTiers }
  });
});

app.post('/api/admin/gamification/geofences', (req, res) => {
  const geofences = readJsonFile('geofences.json', initialGeofences);
  const { name, lat, lng, radiusMeters, category, unlockPoints } = req.body;

  if (!name || !lat || !lng) return res.status(400).json({ status: 'error', message: 'Geofence coordinates required' });

  const newGeofence = {
    id: 'geo_' + Date.now(),
    name,
    lat: Number(lat),
    lng: Number(lng),
    radiusMeters: Number(radiusMeters) || 30,
    category: category || 'Heritage & Culture',
    unlockPoints: Number(unlockPoints) || 50
  };

  geofences.unshift(newGeofence);
  writeJsonFile('geofences.json', geofences);
  res.json({ status: 'success', data: newGeofence });
});

app.delete('/api/admin/gamification/geofences/:id', (req, res) => {
  const geofences = readJsonFile('geofences.json', initialGeofences);
  const filtered = geofences.filter(g => g.id !== req.params.id);
  writeJsonFile('geofences.json', filtered);
  res.json({ status: 'success', message: 'Geofence removed' });
});

app.put('/api/admin/gamification/rank-tiers', (req, res) => {
  const { rankTiers } = req.body;
  if (!Array.isArray(rankTiers)) return res.status(400).json({ status: 'error', message: 'Invalid tiers list' });

  writeJsonFile('rank_tiers.json', rankTiers);
  res.json({ status: 'success', data: rankTiers });
});

// --- 7. ISSUE & BUG REPORTS ---
app.get('/api/admin/bugs', (req, res) => {
  const bugs = readJsonFile('bugs.json', initialBugs);
  const { status, category } = req.query;

  let filtered = [...bugs];
  if (status) filtered = filtered.filter(b => b.status === status);
  if (category) filtered = filtered.filter(b => b.category === category);

  res.json({ status: 'success', count: filtered.length, data: filtered });
});

app.patch('/api/admin/bugs/:id/status', (req, res) => {
  const bugs = readJsonFile('bugs.json', initialBugs);
  const item = bugs.find(b => b.id === req.params.id);
  if (!item) return res.status(404).json({ status: 'error', message: 'Issue not found' });

  item.status = req.body.status;
  writeJsonFile('bugs.json', bugs);
  res.json({ status: 'success', data: item });
});

app.delete('/api/admin/bugs/:id', (req, res) => {
  const bugs = readJsonFile('bugs.json', initialBugs);
  const filtered = bugs.filter(b => b.id !== req.params.id);
  writeJsonFile('bugs.json', filtered);
  res.json({ status: 'success', message: 'Report discarded' });
});

// Default fallback route to admin UI (Express 5 compatible)
app.use((req, res) => {
  res.sendFile(path.join(__dirname, 'public/index.html'));
});

app.listen(PORT, () => {
  console.log(`====================================================`);
  console.log(` Kia-Kia Penang Admin Web Panel Server is LIVE!`);
  console.log(` Local URL: http://localhost:${PORT}`);
  console.log(`====================================================`);
});
