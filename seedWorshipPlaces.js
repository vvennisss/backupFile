const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });
const mongoose = require('mongoose');
const PlaceNew = require('./models/PlaceNew');

const MONGO_URI = process.env.MONGO_URI || process.env.MONGODB_URI || process.env.MONGO_URL;

function parseTime(str) {
  if (!str) return null;
  const clean = str.replace(/[\u202f\u00a0]/g, ' ').trim();
  const match = clean.match(/(\d+)(?::(\d+))?\s*(AM|PM)/i);
  if (!match) return null;
  let [_, h, m, meridiem] = match;
  let hours = parseInt(h, 10);
  let minutes = m ? parseInt(m, 10) : 0;
  if (meridiem.toUpperCase() === 'PM' && hours < 12) hours += 12;
  if (meridiem.toUpperCase() === 'AM' && hours === 12) hours = 0;
  return `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}`;
}

function parseDaySchedule(hourStr) {
  if (!hourStr || typeof hourStr !== 'string') return { is_closed: false, open: '08:00', close: '18:00' };
  const clean = hourStr.replace(/[\u202f\u00a0]/g, ' ').trim();
  if (/closed/i.test(clean)) {
    return { is_closed: true, open: '00:00', close: '00:00' };
  }
  if (/open 24 hours/i.test(clean)) {
    return { is_closed: false, open: '00:00', close: '23:59' };
  }
  // 处理分段营业时间 (如 "6:30 am–12 pm, 4:30–9 pm"，取整体跨度)
  const segments = clean.split(',');
  const firstPart = segments[0].trim();
  const lastPart = segments[segments.length - 1].trim();

  const firstTimes = firstPart.split(/[–\-]/);
  const lastTimes = lastPart.split(/[–\-]/);

  if (firstTimes.length === 2 && lastTimes.length === 2) {
    const open = parseTime(firstTimes[0]);
    const close = parseTime(lastTimes[1]);
    if (open && close) {
      return { is_closed: false, open, close };
    }
  }

  const parts = clean.split(/[–\-]/);
  if (parts.length === 2) {
    const open = parseTime(parts[0]);
    const close = parseTime(parts[1]);
    if (open && close) {
      return { is_closed: false, open, close };
    }
  }
  return { is_closed: false, open: '08:00', close: '18:00' };
}

function formatReadableHours(businessHours) {
  if (!businessHours || typeof businessHours !== 'object') return '8:00 AM – 6:00 PM';
  const days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
  const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  const cleaned = days.map(d => (businessHours[d] ? businessHours[d].replace(/[\u202f\u00a0]/g, ' ').replace(/\s*[–\-]\s*/g, ' – ').trim() : ''));
  const valid = cleaned.filter(h => h && !/no information/i.test(h));

  if (valid.length === 0) {
    return '8:00 AM – 6:00 PM';
  }

  if (new Set(cleaned).size === 1) {
    return `Mon–Sun: ${cleaned[0]}`;
  }

  const weekdaySet = new Set(cleaned.slice(0, 5).filter(Boolean));
  const weekendSet = new Set(cleaned.slice(5).filter(Boolean));
  if (weekdaySet.size === 1 && weekendSet.size === 1) {
    const wd = [...weekdaySet][0];
    const we = [...weekendSet][0];
    if (wd === we) return `Mon–Sun: ${wd}`;
    return `Mon–Fri: ${wd}; Sat–Sun: ${we}`;
  }

  return days.map((d, i) => `${dayLabels[i]}: ${cleaned[i] || 'Closed'}`).join(', ');
}

async function seedWorshipPlaces() {
  if (!MONGO_URI) {
    console.error("错误: 找不到 MongoDB URI，请检查环境变量。");
    return;
  }

  try {
    await mongoose.connect(MONGO_URI);
    console.log("✅ 成功连接到 MongoDB");

    const placesData = [
      {
        name: "ACHEEN STREET MALAY MOSQUE",
        place_category: "places of worship",
        place_address: "Lebuh Acheh, George Town, 10200 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.3364, 5.4146] },
        place_summary: "Built in 1808, this iconic historic mosque stands out with its unique octagonal minaret featuring Moorish and classical architecture. It once served as the hub for Islamic studies and the gathering point for Haj pilgrims in the 19th century.",
        place_information: { rating: 4.6, reviews_count: 245, price_level: "Free", phone: "", website: "" },
        place_business_hours: { monday: "5 am–10 pm", tuesday: "5 am–10 pm", wednesday: "5 am–10 pm", thursday: "5 am–10 pm", friday: "5 am–10 pm", saturday: "5 am–10 pm", sunday: "5 am–10 pm" },
        place_media: { 
          thumbnail: "/images/places/ChIJ6CNkbc5QhEuFzkDY1RDuFnB.jpg", 
          photos: ["/images/places/ChIJ6CNkbc5QhEuFzkDY1RDuFnB.jpg"] 
        }
      },
      {
        name: "ALIMSAH WALEY MOSQUE",
        place_category: "places of worship",
        place_address: "Lebuh Chulia, George Town, 10200 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.33464, 5.41889] },
        place_summary: "Established in the early 19th century by the local Indian Muslim community, this mosque on Chulia Street serves as a peaceful sanctuary in the bustling heart of George Town.",
        place_information: { rating: 4.4, reviews_count: 85, price_level: "Free", phone: "", website: "" },
        place_business_hours: { monday: "5 am–9 pm", tuesday: "5 am–9 pm", wednesday: "5 am–9 pm", thursday: "5 am–9 pm", friday: "5 am–9 pm", saturday: "5 am–9 pm", sunday: "5 am–9 pm" },
        place_media: { 
          thumbnail: "/images/places/ChIJeAkHUM86U4XgWPsgA4D2WRO.jpg", 
          photos: ["/images/places/ChIJeAkHUM86U4XgWPsgA4D2WRO.jpg"] 
        }
      },
      {
        name: "BENGGALI MOSQUE",
        place_category: "places of worship",
        place_address: "Lebuh Leith, George Town, 10200 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.33356, 5.42021] },
        place_summary: "Tucked away on Leith Street, this historical mosque was founded by the Bengali Muslim community. It remains an important spiritual and cultural landmark representing the diverse Islamic heritage in Penang.",
        place_information: { rating: 4.5, reviews_count: 112, price_level: "Free", phone: "", website: "" },
        place_business_hours: { monday: "5 am–9 pm", tuesday: "5 am–9 pm", wednesday: "5 am–9 pm", thursday: "5 am–9 pm", friday: "5 am–9 pm", saturday: "5 am–9 pm", sunday: "5 am–9 pm" },
        place_media: { 
          thumbnail: "/images/places/ChIJBmUmkU8b45YSj3WBNUpaTXT.jpg", 
          photos: ["/images/places/ChIJBmUmkU8b45YSj3WBNUpaTXT.jpg", "https://gtwhi.com.my/ms/wp-content/uploads/2019/03/44.png"] 
        }
      },
      {
        name: "CHURCH OF THE ASSUMPTION",
        place_category: "places of worship",
        place_address: "3, Lebuh Farquhar, George Town, 10200 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.3385, 5.4215] },
        place_summary: "Established in 1786 shortly after Captain Francis Light landed in Penang, this stunning church is the oldest Catholic church in the northern region of Malaysia, boasting gorgeous colonial architecture.",
        place_information: { rating: 4.6, reviews_count: 156, price_level: "Free", phone: "+60 4-261 4172", website: "" },
        place_business_hours: { monday: "8 am–6 pm", tuesday: "8 am–6 pm", wednesday: "8 am–6 pm", thursday: "8 am–6 pm", friday: "8 am–6 pm", saturday: "8 am–7 pm", sunday: "8 am–2 pm" },
        place_media: { 
          thumbnail: "/images/places/ChIJu40ep5rDSjARuoH1NhjrY-E.jpg", 
          photos: ["/images/places/ChIJu40ep5rDSjARuoH1NhjrY-E.jpg"] 
        }
      },
      {
        name: "GODDESS OF MERCY TEMPLE",
        place_category: "places of worship",
        place_address: "Jalan Masjid Kapitan Keling, George Town, 10200 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.3386, 5.4185] },
        place_summary: "Built in 1728, this is the oldest Chinese temple in Penang. Dedicated to Kuan Yin, the Goddess of Mercy, its ornate roofs and dragon-entwined pillars make it a magnificent and deeply spiritual site for locals.",
        place_information: { rating: 4.6, reviews_count: 1450, price_level: "Free", phone: "", website: "" },
        place_business_hours: { monday: "8 am–6 pm", tuesday: "8 am–6 pm", wednesday: "8 am–6 pm", thursday: "8 am–6 pm", friday: "8 am–6 pm", saturday: "8 am–6 pm", sunday: "8 am–6 pm" },
        place_media: { 
          thumbnail: "/images/places/Goddess of Mercy Temple.jpg", 
          photos: ["/images/places/Goddess of Mercy Temple.jpg", "/images/places/ChIJTQlMJ5DDSjARGf6dJYfrYEA.jpg"] 
        }
      },
      {
        name: "HOCK TEIK CHENG SIN TEMPLE",
        place_category: "places of worship",
        place_address: "57, Armenian Street, George Town, 10200 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.3372, 5.4151] },
        place_summary: "Also known as Poh Hock Seah, this hidden gem on Armenian Street features stunning classical Chinese architecture and serves as a significant clan temple tied to the early Hokkien community in Penang.",
        place_information: { rating: 4.5, reviews_count: 220, price_level: "Free", phone: "", website: "" },
        place_business_hours: { monday: "8 am–5 pm", tuesday: "8 am–5 pm", wednesday: "8 am–5 pm", thursday: "8 am–5 pm", friday: "8 am–5 pm", saturday: "8 am–5 pm", sunday: "8 am–5 pm" },
        place_media: { 
          thumbnail: "/images/places/ChIJ1lYmrKPorqFIjdBj5Mbk2Ab.jpg", 
          photos: ["/images/places/ChIJ1lYmrKPorqFIjdBj5Mbk2Ab.jpg", "https://gtwhi.com.my/wp-content/uploads/2019/03/40.png"] 
        }
      },
      {
        name: "KAPITAN KELING MOSQUE",
        place_category: "places of worship",
        place_address: "14, Jalan Buckingham, George Town, 10200 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.3375, 5.4167] },
        place_summary: "Founded in 1801 by the head of the Indian Muslim community, this spectacular Indo-Moorish mosque is characterized by its brilliant white façade and striking black domes, forming a pivotal landmark of George Town.",
        place_information: { rating: 4.7, reviews_count: 2130, price_level: "Free", phone: "+60 4-261 4215", website: "" },
        place_business_hours: { monday: "9:30 am–5:30 pm", tuesday: "9:30 am–5:30 pm", wednesday: "9:30 am–5:30 pm", thursday: "9:30 am–5:30 pm", friday: "9:30 am–5:30 pm", saturday: "9:30 am–5:30 pm", sunday: "9:30 am–5:30 pm" },
        place_media: { 
          thumbnail: "/images/places/Kapitan Keling Mosque.jpg", 
          photos: ["/images/places/Kapitan Keling Mosque.jpg", "/images/places/ChIJq5qauJHDSjARY-1J3UITR0U.jpg"] 
        }
      },
      {
        name: "KING STREET TUA PEK KONG TEMPLE",
        place_category: "places of worship",
        place_address: "King Street, George Town, 10200 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.34007, 5.41841] },
        place_summary: "A vibrant traditional temple built by the early Cantonese and Hakka communities, dedicated to Tua Pek Kong (God of Prosperity). It features beautiful ancestral halls and intricate wood carvings.",
        place_information: { rating: 4.5, reviews_count: 140, price_level: "Free", phone: "", website: "" },
        place_business_hours: { monday: "8 am–5 pm", tuesday: "8 am–5 pm", wednesday: "8 am–5 pm", thursday: "8 am–5 pm", friday: "8 am–5 pm", saturday: "8 am–5 pm", sunday: "8 am–5 pm" },
        place_media: { 
          thumbnail: "/images/places/ChIJSSUXh2C48X1WQ9Xdz2960qr.jpg", 
          photos: ["/images/places/ChIJSSUXh2C48X1WQ9Xdz2960qr.jpg", "https://gtwhi.com.my/wp-content/uploads/2019/03/41.png"] 
        }
      },
      {
        name: "SRI MAHAMARIAMMAN TEMPLE",
        place_category: "places of worship",
        place_address: "Lebuh Queen, George Town, 10200 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.3391, 5.4172] },
        place_summary: "The oldest Hindu temple in Penang, standing since 1833. Located in Little India, it is famous for its magnificent gopuram (gateway tower) densely covered with incredibly detailed sculptures of Hindu deities.",
        place_information: { rating: 4.6, reviews_count: 890, price_level: "Free", phone: "", website: "" },
        place_business_hours: { monday: "6:30 am–12 pm, 4:30–9 pm", tuesday: "6:30 am–12 pm, 4:30–9 pm", wednesday: "6:30 am–12 pm, 4:30–9 pm", thursday: "6:30 am–12 pm, 4:30–9 pm", friday: "6:30 am–12 pm, 4:30–9:30 pm", saturday: "6:30 am–12 pm, 4:30–9 pm", sunday: "6:30 am–12 pm, 4:30–9 pm" },
        place_media: { 
          thumbnail: "/images/places/Sri Mahamariamman Temple.jpg", 
          photos: ["/images/places/Sri Mahamariamman Temple.jpg", "/images/places/ChIJCC2XbFwQd1UzIVcrNk1Y6Js.jpg"] 
        }
      },
      {
        name: "ST FRANCIS XAVIER CHURCH",
        place_category: "places of worship",
        place_address: "52K, Jalan Penang, George Town, 10000 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.33253, 5.42211] },
        place_summary: "Constructed in the 1850s to serve the Tamil Catholic community, this historic parish on Penang Road combines spiritual heritage with beautiful, well-preserved European architectural elements.",
        place_information: { rating: 4.5, reviews_count: 175, price_level: "Free", phone: "+60 4-261 0086", website: "" },
        place_business_hours: { monday: "9 am–5 pm", tuesday: "9 am–5 pm", wednesday: "9 am–5 pm", thursday: "9 am–5 pm", friday: "9 am–5 pm", saturday: "9 am–6 pm", sunday: "8 am–1 pm" },
        place_media: { 
          thumbnail: "/images/places/ChIJeKsPJ87Q89NuNkKHYV3E7Cy.jpg", 
          photos: ["/images/places/ChIJeKsPJ87Q89NuNkKHYV3E7Cy.jpg", "https://gtwhi.com.my/wp-content/uploads/2019/03/47.png"] 
        }
      },
      {
        name: "ST GEORGE’S CHURCH",
        place_category: "places of worship",
        place_address: "1, Lebuh Farquhar, George Town, 10200 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.3388, 5.4203] },
        place_summary: "Built in 1818, this majestic Anglican church is the oldest purpose-built Anglican church in Southeast Asia. Its striking Georgian architecture and elegant white columns make it an essential historical landmark.",
        place_information: { rating: 4.6, reviews_count: 678, price_level: "Free", phone: "+60 4-261 2739", website: "stgeorgeschurchpenang.com" },
        place_business_hours: { monday: "9 am–4 pm", tuesday: "9 am–4 pm", wednesday: "9 am–4 pm", thursday: "9 am–4 pm", friday: "9 am–4 pm", saturday: "Closed", sunday: "8 am–12 pm" },
        place_media: { 
          thumbnail: "/images/places/St George's Church.jpg", 
          photos: ["/images/places/St George's Church.jpg"] 
        }
      },
      {
        name: "WU TI MEOW (WAR EMPEROR’S TEMPLE)",
        place_category: "places of worship",
        place_address: "36, King Street, George Town, 10200 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.3400, 5.4180] },
        place_summary: "Dedicated to Guan Gong, the God of War and Righteousness, this temple on King Street was established in the 1830s. It features beautiful calligraphy and forms an integral part of the Toi San Association's heritage.",
        place_information: { rating: 4.4, reviews_count: 85, price_level: "Free", phone: "", website: "" },
        place_business_hours: { monday: "8 am–5 pm", tuesday: "8 am–5 pm", wednesday: "8 am–5 pm", thursday: "8 am–5 pm", friday: "8 am–5 pm", saturday: "8 am–5 pm", sunday: "8 am–5 pm" },
        place_media: { 
          thumbnail: "/images/places/St George's Church.jpg", 
          photos: ["/images/places/St George's Church.jpg", "https://gtwhi.com.my/wp-content/uploads/2019/04/Wu-Ti-Meow-War-Emperor%E2%80%99s-Temple.jpg"] 
        }
      },
      {
        name: "YAP KONGSI TEMPLE",
        place_category: "places of worship",
        place_address: "71, Armenian Street, George Town, 10200 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.3373, 5.4153] },
        place_summary: "Serving as the clan association for the Hokkien Chinese of the Yap surname, this elegant temple on Armenian Street features stunning roof ridges, intricate ancestral tablets, and a deeply peaceful courtyard.",
        place_information: { rating: 4.4, reviews_count: 125, price_level: "Free", phone: "", website: "" },
        place_business_hours: { monday: "9 am–5 pm", tuesday: "9 am–5 pm", wednesday: "9 am–5 pm", thursday: "9 am–5 pm", friday: "9 am–5 pm", saturday: "9 am–5 pm", sunday: "9 am–5 pm" },
        place_media: { 
          thumbnail: "/images/places/ChIJINaWplCLuWY3AFVUw34Phwq.jpg", 
          photos: ["/images/places/ChIJINaWplCLuWY3AFVUw34Phwq.jpg", "/images/places/ChIJE4TgwNgqf2za1T1PhPILvwZ.jpg"] 
        }
      }
    ];

    let updatedCount = 0;
    let insertedCount = 0;

    for (const place of placesData) {
      const openingHours = { is_24_hours: false };
      const days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
      for (const day of days) {
        openingHours[day] = parseDaySchedule(place.place_business_hours[day]);
      }
      const rawHoursText = formatReadableHours(place.place_business_hours);

      let typeTag = 'Temple';
      if (place.name.includes('MOSQUE')) typeTag = 'Mosque';
      else if (place.name.includes('CHURCH')) typeTag = 'Church';

      const cleanName = place.name.toLowerCase();
      const searchKeywords = Array.from(new Set([
        cleanName,
        'places of worship',
        'places of worship',
        'place of worship',
        'religious sites',
        typeTag.toLowerCase(),
        'heritage & culture',
        'george town',
        ...cleanName.replace(/[()（）’']/g, ' ').split(/\s+/).filter(w => w.length > 2)
      ]));

      // 大小写和引号不敏感匹配 (如 ST GEORGE’S CHURCH, Kapitan Keling Mosque 等)
      const normalizedQuery = place.name.replace(/[’']/g, "['’]?");
      const existing = await PlaceNew.findOne({
        $or: [
          { name: place.name },
          { name: new RegExp('^' + normalizedQuery + '$', 'i') }
        ]
      });

      const finalRating = existing && existing.rating > 0 
        ? Math.max(existing.rating, place.place_information.rating || 0)
        : (place.place_information.rating || 4.5);

      const finalReviewsCount = existing && existing.review_count > 0
        ? Math.max(existing.review_count, place.place_information.reviews_count || 0)
        : (place.place_information.reviews_count || 0);

      const thumbnail = place.place_media.thumbnail;

      const updateDoc = {
        name: existing ? existing.name : place.name,
        primary_category: 'Religious Sites',
        sub_categories: ['Places of Worship', 'Places of worship', 'Religious Sites', typeTag],
        area: 'George Town',
        address: place.place_address,
        location: place.place_location,
        summary: place.place_summary,
        description: place.place_summary,
        cover_image: thumbnail,
        place_media: place.place_media,
        images: [
          {
            url: thumbnail,
            caption: place.name,
            is_cover: true,
            source: 'curated'
          }
        ],
        place_information: {
          rating: finalRating,
          reviews_count: finalReviewsCount,
          price_level: place.place_information.price_level,
          phone: place.place_information.phone || (existing?.place_information?.phone || ''),
          website: place.place_information.website || (existing?.place_information?.website || '')
        },
        rating: finalRating,
        review_count: finalReviewsCount,
        place_business_hours: place.place_business_hours,
        opening_hours: openingHours,
        raw_hours_text: rawHoursText,
        search_keywords: searchKeywords,
        status: 'active',
        updatedAt: new Date()
      };

      const filter = existing ? { _id: existing._id } : { name: place.name };

      const result = await PlaceNew.updateOne(
        filter,
        {
          $set: updateDoc,
          $setOnInsert: {
            createdAt: new Date(),
            external_place_id: `ChIJ${Buffer.from(place.name).toString('base64').replace(/[^a-zA-Z0-9]/g, '').slice(0, 20)}`,
            hasStreetView: false,
            isPano: false
          },
          $unset: {
            place_name: "",
            place_category: "",
            place_address: "",
            place_location: "",
            place_summary: ""
          }
        },
        { upsert: true }
      );

      if (result.upsertedCount > 0) {
        insertedCount++;
        console.log(`➕ 新增插入: ${place.name}`);
      } else {
        updatedCount++;
        console.log(`🔄 成功更新: ${place.name}`);
      }
    }

    console.log("\n========================================");
    console.log("----- 宗教场所数据同步到 places_new 完成 -----");
    console.log(`总计处理: ${placesData.length} 座宗教场所`);
    console.log(`✅ 新增数量: ${insertedCount} 个`);
    console.log(`🔄 更新数量: ${updatedCount} 个`);
    console.log("========================================\n");

  } catch (error) {
    console.error("执行时发生错误:", error);
  } finally {
    await mongoose.connection.close();
  }
}

if (require.main === module) {
  seedWorshipPlaces();
}

module.exports = seedWorshipPlaces;