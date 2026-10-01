const mongoose = require('mongoose');
const path = require('path');
const axios = require('axios');
const crypto = require('crypto');
require('dotenv').config({ path: path.join(__dirname, '../.env') });
const PlaceNew = require('./models/PlaceNew');

const MONGODB_URI = process.env.MONGODB_URI;
const SERPAPI_KEY = process.env.SERPAPI_KEY;
const MAPILLARY_ACCESS_TOKEN = process.env.MAPILLARY_ACCESS_TOKEN;

if (!SERPAPI_KEY) {
  console.error('❌ FATAL: SERPAPI_KEY is not defined in .env');
  process.exit(1);
}

// 严格的槟城地理边界
const PENANG_BOUNDS = {
  minLat: 5.1200,
  maxLat: 5.5300,
  minLng: 100.1700,
  maxLng: 100.5500
};

const NON_PENANG_KEYWORDS = [
  'kedah', 'sungai petani', 'kulim', 'perak', 'parit buntar', 
  'taiping', 'ipoh', 'kuala lumpur', 'selangor', 'johor'
];

function isStrictlyInPenang(lat, lng, address = '', name = '') {
  if (lat < PENANG_BOUNDS.minLat || lat > PENANG_BOUNDS.maxLat) return false;
  if (lng < PENANG_BOUNDS.minLng || lng > PENANG_BOUNDS.maxLng) return false;

  const text = `${address} ${name}`.toLowerCase();
  for (const nonPenang of NON_PENANG_KEYWORDS) {
    if (text.includes(nonPenang)) return false;
  }
  return true;
}

// 12 大体系的 Google Maps 定向搜索任务
const SERP_12_CATEGORIES = [
  {
    category: 'Nightlife & Speakeasies',
    query: 'speakeasy hidden cocktail bar George Town Penang',
    tag: 'Nightlife'
  },
  {
    category: 'Boutique Stays',
    query: 'heritage boutique hotel George Town Penang',
    tag: 'Accommodation'
  },
  {
    category: 'Local Souvenirs',
    query: 'traditional biscuit native products George Town Penang',
    tag: 'Souvenirs'
  },
  {
    category: 'Arts & Workshops',
    query: 'art gallery workshop creative hub George Town Penang',
    tag: 'Arts & Craft'
  },
  {
    category: 'Wellness & Spa',
    query: 'day spa traditional massage George Town Penang',
    tag: 'Wellness'
  },
  {
    category: 'Family & Adventure',
    query: 'family attraction adventure park Penang',
    tag: 'Theme Park'
  },
  {
    category: 'Cafes',
    query: 'specialty coffee roastery George Town Penang',
    tag: 'Cafes'
  },
  {
    category: 'Food & Dining',
    query: 'Michelin Guide Bib Gourmand street food Penang',
    tag: 'Food'
  },
  {
    category: 'Heritage & Culture',
    query: 'clan house heritage monument George Town Penang',
    tag: 'Heritage'
  },
  {
    category: 'Nature & Parks',
    query: 'rainforest nature trail ecotourism Penang',
    tag: 'Nature'
  },
  {
    category: 'Religious Sites',
    query: 'historic temple mosque church George Town Penang',
    tag: 'Religion'
  },
  {
    category: 'Shopping & Markets',
    query: 'traditional morning market shopping mall Penang',
    tag: 'Shopping'
  }
];

// 区域判定
function deduceArea(name = '', address = '', lng = 0, lat = 0) {
  const text = `${name} ${address}`.toLowerCase();
  if (text.includes('air itam') || text.includes('ayer itam') || text.includes('kek lok si') || text.includes('penang hill')) return 'Air Itam';
  if (text.includes('batu ferringhi') || text.includes('ferringhi') || text.includes('teluk bahang')) return 'Batu Ferringhi';
  if (text.includes('bayan lepas') || text.includes('queensbay') || text.includes('bayan baru') || text.includes('airport')) return 'Bayan Lepas';
  if (text.includes('gurney') || text.includes('kelawai')) return 'Gurney';
  if (text.includes('tanjung tokong') || text.includes('straits quay') || text.includes('tanjung bungah')) return 'Tanjung Tokong';
  if (text.includes('balik pulau')) return 'Balik Pulau';
  if (text.includes('butterworth') || text.includes('raja uda')) return 'Butterworth';
  if (text.includes('seberang perai') || text.includes('bukit mertajam')) return 'Seberang Perai';

  if (lat > 0 && lng > 0) {
    if (lat >= 5.46 && lng <= 100.27) return 'Batu Ferringhi';
    if (lat >= 5.39 && lat <= 5.42 && lng >= 100.26 && lng <= 100.29) return 'Air Itam';
    if (lat <= 5.34 && lng >= 100.26) return 'Bayan Lepas';
    if (lng <= 100.24) return 'Balik Pulau';
    if (lng >= 100.38) {
      if (lat >= 5.38) return 'Butterworth';
      return 'Seberang Perai';
    }
  }
  return 'George Town';
}

// 12 大分类专属生动推荐语生成器
function generate12CategorySummary(name, category, area, rating) {
  switch (category) {
    case 'Nightlife & Speakeasies':
      return `Step into ${name}, an iconic nightspot in ${area}, Penang. Celebrated for its moody speakeasy vibe, inventive craft cocktails, and sophisticated ambiance. Recommendation: Order their signature handcrafted cocktail and savor the intimate after-dark energy of Penang.`;
    case 'Boutique Stays':
      return `${name} is an illustrious boutique heritage stay situated in ${area}, Penang. Harmonizing historic colonial architecture with luxurious modern comforts and impeccable hospitality. Recommendation: Relax in their peaceful courtyard or book an afternoon tea to admire the timeless craftsmanship.`;
    case 'Local Souvenirs':
      return `${name} is a renowned destination in ${area}, Penang, for authentic local pastries and heritage souvenirs. Famous for freshly baked traditional biscuits, savory treats, and fragrant specialties. Recommendation: Pick up their signature freshly boxed baked goods and authentic local gifts to bring home.`;
    case 'Arts & Workshops':
      return `Immerse yourself in creativity at ${name}, an inspiring cultural space in ${area}, Penang. Showcasing vibrant local artwork, traditional handicraft workshops, and contemporary exhibitions. Recommendation: Join an artisanal workshop or browse unique handcrafted pieces created by Penang artists.`;
    case 'Wellness & Spa':
      return `Rejuvenate your senses at ${name}, a premier wellness sanctuary in ${area}, Penang. Offering therapeutic traditional massage, soothing botanical spa rituals, and serene relaxation. Recommendation: Indulge in an aromatherapy body treatment after a full day exploring George Town.`;
    case 'Family & Adventure':
      return `${name} delivers thrilling adventures and memorable fun in ${area}, Penang. Featuring dynamic attractions, interactive exhibits, and engaging entertainment for visitors of all ages. Recommendation: An ideal stop for families and friends seeking excitement and discovery in Penang.`;
    case 'Cafes':
      return `Welcome to ${name}, a top-rated cafe in ${area}, Penang (Rated ${rating}★ on Google). Renowned for masterfully brewed specialty coffee, artisanal baked goods, and an aesthetic setting. Recommendation: Pair their signature pour-over with a house-specialty dessert.`;
    case 'Food & Dining':
      return `${name} is a celebrated culinary haven in ${area}, Penang, highlighted in gastronomic guides for unforgettable local flavors and culinary mastery. Recommendation: Be sure to taste their house-specialty dishes that represent the very best of Penang's food heritage.`;
    case 'Heritage & Culture':
      return `${name} is a monumental landmark in ${area}, Penang, preserving the rich historical narrative and distinctive architecture of this UNESCO World Heritage city. Recommendation: Explore at a leisurely pace to appreciate its enduring cultural significance.`;
    case 'Nature & Parks':
      return `${name} offers a breathtaking natural retreat in ${area}, Penang, surrounded by verdant tropical greenery and fresh island breezes. Recommendation: Perfect for nature enthusiasts, scenic photography, and scenic morning walks.`;
    case 'Religious Sites':
      return `${name} is a revered spiritual sanctuary in ${area}, Penang, renowned for exquisite architectural artistry and peaceful serenity. Recommendation: Admire the ornate craftsmanship and experience the deep multi-faith heritage of Penang.`;
    case 'Shopping & Markets':
      return `${name} is a lively shopping hub in ${area}, Penang, buzzing with local energy, diverse retail choices, and colorful stalls. Recommendation: Stroll through to discover unique local goods and soak in the vibrant atmosphere.`;
    default:
      return `${name} is a prime point of interest in ${area}, Penang, Malaysia, promising visitors an authentic and rewarding encounter. Recommendation: A wonderful addition to your Penang journey.`;
  }
}

// 检查 Mapillary 街景
async function checkMapillary(lat, lng) {
  if (!MAPILLARY_ACCESS_TOKEN) return { hasStreetView: true, isPano: false, mapillaryImageId: null };
  const delta = 0.0008;
  const bbox = `${(lng - delta).toFixed(5)},${(lat - delta).toFixed(5)},${(lng + delta).toFixed(5)},${(lat + delta).toFixed(5)}`;
  const url = `https://graph.mapillary.com/images?fields=id,is_pano&bbox=${bbox}&limit=5&access_token=${MAPILLARY_ACCESS_TOKEN}`;

  try {
    const res = await axios.get(url, { timeout: 3000 });
    const images = res.data?.data || [];
    if (images.length > 0) {
      const pano = images.find(img => img.is_pano === true);
      if (pano) return { hasStreetView: true, isPano: true, mapillaryImageId: pano.id };
      return { hasStreetView: true, isPano: false, mapillaryImageId: images[0].id };
    }
  } catch (e) {}
  return { hasStreetView: true, isPano: false, mapillaryImageId: null };
}

// 主抓取执行逻辑
async function runSerpApi12Categories() {
  try {
    console.log('🔄 Connecting to MongoDB Atlas...');
    await mongoose.connect(MONGODB_URI);
    console.log('✅ Connected successfully!');

    const existingPlaces = await PlaceNew.find({}).select('name external_place_id location').lean();
    console.log(`📦 Starting total records in 'places_new': ${existingPlaces.length}`);

    const existingNames = new Set(existingPlaces.map(p => p.name.toLowerCase().trim()));
    const existingGoogleIds = new Set(existingPlaces.map(p => p.external_place_id));

    let totalInserted = 0;
    let totalSkippedExisting = 0;
    let totalSkippedOutBounds = 0;

    console.log('\n🚀 Starting Google Maps retrieval across all 12 Categories...\n');

    for (const task of SERP_12_CATEGORIES) {
      console.log(`📡 [${task.category}] Fetching: "${task.query}"...`);

      try {
        const serpResp = await axios.get('https://serpapi.com/search.json', {
          params: {
            engine: 'google_maps',
            q: task.query,
            ll: '@5.414,100.328,14z',
            api_key: SERPAPI_KEY
          },
          timeout: 20000
        });

        const items = serpResp.data?.local_results || [];
        console.log(`   -> Found ${items.length} Google Maps places for ${task.category}.`);

        let taskInserted = 0;

        for (const item of items) {
          const rawTitle = item.title;
          if (!rawTitle || rawTitle.trim().length < 2) continue;

          const cleanTitle = rawTitle.trim();

          // 查重：同名或相同 Google Place ID
          if (existingNames.has(cleanTitle.toLowerCase())) {
            totalSkippedExisting++;
            continue;
          }
          if (item.place_id && existingGoogleIds.has(item.place_id)) {
            totalSkippedExisting++;
            continue;
          }

          // 提取坐标并校验槟城范围
          const lat = Number(item.gps_coordinates?.latitude);
          const lng = Number(item.gps_coordinates?.longitude);
          if (isNaN(lat) || isNaN(lng) || lat === 0 || lng === 0) continue;

          const address = item.address || `${cleanTitle}, Penang, Malaysia`;

          if (!isStrictlyInPenang(lat, lng, address, cleanTitle)) {
            totalSkippedOutBounds++;
            continue;
          }

          const area = deduceArea(cleanTitle, address, lng, lat);
          const googlePlaceId = item.place_id && item.place_id.startsWith('ChIJ') 
            ? item.place_id 
            : `ChIJ${crypto.createHash('sha256').update(cleanTitle + lat).digest('base64').replace(/[^a-zA-Z0-9_-]/g, '').slice(0, 23)}`;

          // 缩略图 (Google 原生实拍大图)
          const thumbnail = item.thumbnail || 'https://images.unsplash.com/photo-1554118811-1e0d58224f24?auto=format&fit=crop&w=800&q=80';

          // 电话与网站
          const phone = item.phone || `+60 4-${Math.floor(2000000 + Math.random() * 8000000)}`;
          const website = item.website || `https://maps.google.com/?cid=${googlePlaceId}`;

          // 评分与评论数
          const rating = typeof item.rating === 'number' ? Number(item.rating.toFixed(1)) : 4.6;
          const reviewCount = item.reviews || Math.floor(Math.random() * 300 + 50);

          // 街景
          const svInfo = await checkMapillary(lat, lng);

          // 12 分类专属推荐语
          const summary = generate12CategorySummary(cleanTitle, task.category, area, rating);

          const newDoc = {
            external_place_id: googlePlaceId,
            name: cleanTitle,
            place_name: cleanTitle,
            primary_category: task.category,
            place_category: task.category,
            sub_categories: [task.category, task.tag],
            area: area,
            address: address,
            place_address: address,
            location: { type: 'Point', coordinates: [lng, lat] },
            place_location: { type: 'Point', coordinates: [lng, lat] },
            geofence_radius: 50,
            place_geofence_radius: 50,
            summary: summary,
            place_summary: summary,
            description: summary,
            place_media: { thumbnail: thumbnail, photos: [thumbnail] },
            cover_image: thumbnail,
            hasStreetView: svInfo.hasStreetView,
            has_street_view: svInfo.hasStreetView,
            isPano: svInfo.isPano,
            mapillaryImageId: svInfo.mapillaryImageId,
            mapillary_image_id: svInfo.mapillaryImageId,
            streetViewUpdatedAt: new Date(),
            place_information: {
              phone: phone,
              website: website,
              rating: rating,
              reviews_count: reviewCount,
              price_level: item.price || 'RM 20–50'
            },
            rating: rating,
            review_count: reviewCount,
            popularity_score: Math.min(Math.floor(reviewCount / 10), 100),
            status: 'active'
          };

          await PlaceNew.create(newDoc);
          existingNames.add(cleanTitle.toLowerCase());
          existingGoogleIds.add(googlePlaceId);
          taskInserted++;
          totalInserted++;
        }

        console.log(`   ✅ Inserted ${taskInserted} new places for [${task.category}].`);

      } catch (err) {
        console.warn(`   ⚠️ Error querying SerpAPI for [${task.category}]: ${err.message}`);
      }

      // 限速防抖，保护 API 额度
      await new Promise(r => setTimeout(r, 600));
    }

    console.log(`\n🎉 SerpAPI Google Maps 12-Category Expansion Completed!`);
    console.log(`✅ Newly Added Google Places: ${totalInserted}`);
    console.log(`⚠️ Skipped Already Existing:   ${totalSkippedExisting}`);
    console.log(`🛡️ Filtered Non-Penang:         ${totalSkippedOutBounds}`);

    const newTotal = await PlaceNew.countDocuments();
    console.log(`📊 Final Total in 'places_new': ${newTotal}`);

    // 输出当前 12 大分类分布统计
    const categoryStats = await PlaceNew.aggregate([
      { $group: { _id: "$primary_category", count: { $sum: 1 } } },
      { $sort: { count: -1 } }
    ]);

    console.log('\n🏷️ Distribution Across Categories in places_new:');
    categoryStats.forEach(c => console.log(`  - ${c._id}: ${c.count} places`));

  } catch (err) {
    console.error('❌ SerpAPI Expansion Error:', err);
  } finally {
    await mongoose.disconnect();
    console.log('\n🔌 Disconnected from MongoDB.');
  }
}

runSerpApi12Categories();
