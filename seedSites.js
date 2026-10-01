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
  if (/no information/i.test(clean)) {
    return { is_closed: false, open: '08:00', close: '18:00' };
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

async function seedSites() {
  if (!MONGO_URI) {
    console.error("错误: 找不到 MongoDB URI，请检查环境变量。");
    return;
  }

  try {
    await mongoose.connect(MONGO_URI);
    console.log("✅ 成功连接到 MongoDB");

    const placesData = [
      {
        name: "Syed Mustafa Wali Mausoleum",
        place_category: "Mausoleums & Cemeteries",
        place_address: "George Town, 10200 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.3370, 5.4160] },
        place_summary: "A historical Islamic mausoleum located within the core heritage zone of George Town, serving as a resting place for the respected religious figure Syed Mustafa Wali. Fun fact: Like many ancient 'Keramat' (shrines) in Penang, it represents the deep-rooted Islamic heritage brought over by early Arab and Indian Muslim traders who established communities in the bustling port city.",
        place_information: { rating: 4.5, reviews_count: 5, price_level: "N/A", phone: "", website: "" },
        place_business_hours: { monday: "No Information", tuesday: "No Information", wednesday: "No Information", thursday: "No Information", friday: "No Information", saturday: "No Information", sunday: "No Information" },
        place_media: { 
          thumbnail: "/images/places/ChIJGb7nKhk8YB0HdtvvoaRNzzd.jpg", 
          photos: ["/images/places/ChIJGb7nKhk8YB0HdtvvoaRNzzd.jpg", "https://gtwhi.com.my/wp-content/uploads/2019/04/Syed-Mustafa-Wali-Mausoleum-e1554187147278.jpg"] 
        }
      },
      {
        name: "Syed Hussein Mausoleum",
        place_category: "Mausoleums & Cemeteries",
        place_address: "Lebuh Aceh, 10200 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.3364, 5.4146] },
        place_summary: "This is the tomb of Tuanku Syed Hussein Aidid, a wealthy Acehnese royal and trader who founded the Acheen Street Mosque in 1808. Fun fact: Tuanku Syed Hussein was so influential that he actually became the Sultan of Aceh for a mere 3 days before handing the throne to his son! His tomb is uniquely situated directly in front of the mosque he built, surrounded by other Acehnese royalty.",
        place_information: { rating: 4.5, reviews_count: 5, price_level: "N/A", phone: "", website: "" },
        place_business_hours: { monday: "No Information", tuesday: "No Information", wednesday: "No Information", thursday: "No Information", friday: "No Information", saturday: "No Information", sunday: "No Information" },
        place_media: { 
          thumbnail: "/images/places/ChIJXCVTPoi1pfeJYiMtCbKwV0f.jpg", 
          photos: ["/images/places/ChIJXCVTPoi1pfeJYiMtCbKwV0f.jpg", "https://gtwhi.com.my/wp-content/uploads/2019/04/Syed-Hussein-Mausoleum-e1554860865245.jpg"] 
        }
      },
      {
        name: "Protestant Cemetery",
        place_category: "Mausoleums & Cemeteries",
        place_address: "Jalan Sultan Ahmad Shah, 10050 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.3332, 5.4230] },
        place_summary: "Opened in 1789, this Class 1 heritage site is the final resting place of Captain Francis Light, the founder of modern Penang. Fun fact: Strolling under the ancient frangipani trees, you can find the graves of many early colonial governors, merchants, and even Thomas Leonowens—the husband of Anna Leonowens, who famously inspired the story 'The King and I'.",
        place_information: { rating: 4.5, reviews_count: 84, price_level: "N/A", phone: "", website: "" },
        place_business_hours: { monday: "8 am–6 pm", tuesday: "8 am–6 pm", wednesday: "8 am–6 pm", thursday: "8 am–6 pm", friday: "8 am–6 pm", saturday: "8 am–6 pm", sunday: "8 am–6 pm" },
        place_media: { 
          thumbnail: "/images/places/ChIJP970c6Ni1IdApmwALpjltJM.jpg", 
          photos: ["/images/places/ChIJP970c6Ni1IdApmwALpjltJM.jpg", "https://gtwhi.com.my/wp-content/uploads/2019/04/Protestant-Cemetery-e1554860842850.jpg"] 
        }
      },
      {
        name: "Noordin Family Mausoleum",
        place_category: "Mausoleums & Cemeteries",
        place_address: "92, Jln Masjid Kapitan Keling, George Town, 10200 George Town, Pulau Pinang, Malaysia",
        place_location: { type: "Point", coordinates: [100.3384, 5.4182] },
        place_summary: "Located near the Kapitan Keling Mosque, this beautiful tomb belongs to the prominent Noordin family, who were influential Indian Muslim merchants in the 19th century. Fun fact: The mausoleum features a striking prominent dome and minaret. It stands right on Chulia Street, reminding passersby of the immense wealth and philanthropic contributions of the Tamil Muslim diaspora in early Penang.",
        place_information: { rating: 4.5, reviews_count: 5, price_level: "N/A", phone: "", website: "" },
        place_business_hours: { monday: "No Information", tuesday: "No Information", wednesday: "No Information", thursday: "No Information", friday: "No Information", saturday: "No Information", sunday: "No Information" },
        place_media: { 
          thumbnail: "/images/places/ChIJ42c2yWfpJdBr9GOpmwOrfaR.jpg", 
          photos: ["/images/places/ChIJ42c2yWfpJdBr9GOpmwOrfaR.jpg", "https://gtwhi.com.my/wp-content/uploads/2019/04/Noordin-Family-Mausoleum-e1554187071630.jpg"] 
        }
      },
      {
        name: "Little India",
        place_category: "cultural & heritage",
        place_address: "59, China St, Georgetown, 10200 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.3395, 5.4172] },
        place_summary: "A vibrant, colorful ethnic enclave located around Market Street (Lebuh Pasar), filled with the scent of spices, Bollywood music, and traditional Indian attire. Fun fact: This area was historically known as the Chulia enclave, settled by early immigrants from the Coromandel Coast of India. Today, it remains the epicenter for Hindu festivals like Deepavali and Thaipusam in George Town.",
        place_information: { rating: 4.3, reviews_count: 17113, price_level: "N/A", phone: "", website: "" },
        place_business_hours: { monday: "10 am-8.30 pm", tuesday: "10 am-8.30 pm", wednesday: "10 am-8.30 pm", thursday: "10 am-8.30 pm", friday: "10 am-8.30 pm", saturday: "10 am-8.30 pm", sunday: "10 am-8.30 pm" },
        place_media: { 
          thumbnail: "/images/places/Litle India.jpg", 
          photos: ["/images/places/Litle India.jpg", "/images/places/ChIJBip0cf5kHg8NlJAdwRUhKd2.jpg"] 
        }
      },
      {
        name: "Kapitan Keling Family Mausoleum",
        place_category: "Mausoleums & Cemeteries",
        place_address: "13, Jalan Buckingham, 10200 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.3373, 5.4162] },
        place_summary: "The final resting place of Cauder Mohuddeen and his family. He was the Kapitan Keling (Head of the Indian Muslim community) appointed by the British in the early 19th century. Fun fact: Despite building the grand Kapitan Keling Mosque, Cauder Mohuddeen’s tomb is actually tucked away in a more modest location nearby on Buckingham Street, serving as a quiet tribute to one of Penang's most important pioneer leaders.",
        place_information: { rating: 4.5, reviews_count: 5, price_level: "N/A", phone: "", website: "" },
        place_business_hours: { monday: "No Information", tuesday: "No Information", wednesday: "No Information", thursday: "No Information", friday: "No Information", saturday: "No Information", sunday: "No Information" },
        place_media: { 
          thumbnail: "/images/places/ChIJtJww9w8btQXOeLjuLBIX9PX.jpg", 
          photos: ["/images/places/ChIJtJww9w8btQXOeLjuLBIX9PX.jpg", "https://gtwhi.com.my/wp-content/uploads/2019/04/Kapitan-Keling-Family-Mausoleum-e1554187227553.jpg"] 
        }
      },
      {
        name: "Fort Cornwallis",
        place_category: "historical sites",
        place_address: "4, Jalan Tun Syed Sheh Barakbah, 10200 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.3436, 5.4203] },
        place_summary: "Built by Captain Francis Light in 1786, this star-shaped fort is the largest standing fort in Malaysia. It was originally built of nibong palms before being upgraded to brick. Fun fact: The fort has never actually engaged in any combat! Inside, you will find the famous Seri Rambai cannon, which locals believe possesses magical properties to help women conceive.",
        place_information: { rating: 3.5, reviews_count: 4520, price_level: "RM 20", phone: "+6016-411 0000", website: "" },
        place_business_hours: { monday: "9 am-6 pm", tuesday: "9 am-6 pm", wednesday: "9 am-6 pm", thursday: "9 am-6 pm", friday: "9 am-6 pm", saturday: "9 am-6 pm", sunday: "9 am-6 pm" },
        place_media: { 
          thumbnail: "/images/places/Fort Cornwallis.jpg", 
          photos: ["/images/places/Fort Cornwallis.jpg", "/images/places/ChIJSYg_noXDSjAR3mSegGnJxdQ.jpg"] 
        }
      },
      {
        name: "Church Street Pier",
        place_category: "historical sites",
        place_address: "Pengkalan Weld, 10300 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.3429, 5.4148] },
        place_summary: "Constructed in the 1890s, this historic pier was an essential maritime gateway for George Town when ships couldn't dock directly at the shallow shores. Fun fact: Before the Penang Bridge was built in 1985, piers along Weld Quay like this one were the bustling lifelines connecting the island to the mainland via a relentless fleet of ferries and small sampans.",
        place_information: { rating: 4.4, reviews_count: 25, price_level: "N/A", phone: "", website: "" },
        place_business_hours: { monday: "No Information", tuesday: "No Information", wednesday: "No Information", thursday: "No Information", friday: "No Information", saturday: "No Information", sunday: "No Information" },
        place_media: { 
          thumbnail: "/images/places/ChIJmebvKUJizEzpCGgxCRNnDkI.jpg", 
          photos: ["/images/places/ChIJmebvKUJizEzpCGgxCRNnDkI.jpg", "https://gtwhi.com.my/wp-content/uploads/2019/04/Church-Street-Pier-e1554860655431.jpg"] 
        }
      },
      {
        name: "Chowrasta Market",
        place_category: "Markets",
        place_address: "28, 2, Jalan Kuala Kangsar, George Town, 10200 George Town, Pulau Pinang, Malaysia",
        place_location: { type: "Point", coordinates: [100.3314, 5.4181] },
        place_summary: "Operating since 1890, Chowrasta Market is one of the oldest running wet markets in Penang. The word 'Chowrasta' means 'four cross-roads' in Urdu. Fun fact: While the ground floor is a bustling wet market, the upper floor is famous throughout Malaysia as a treasure trove for second-hand books! The market is also the absolute best place in Penang to buy local pickled fruits (Jeruk).",
        place_information: { rating: 4.3, reviews_count: 516, price_level: "N/A", phone: "", website: "" },
        place_business_hours: { monday: "7 am–12.30 pm", tuesday: "7 am–12.30 pm", wednesday: "7 am–12.30 pm", thursday: "7 am–12.30 pm", friday: "7 am–12.30 pm", saturday: "7 am–12.30 pm", sunday: "7 am–12.30 pm" },
        place_media: { 
          thumbnail: "/images/places/ChIJH2nWHZfDSjARnmlmTw6Zi5k.jpg", 
          photos: ["/images/places/ChIJH2nWHZfDSjARnmlmTw6Zi5k.jpg", "https://gtwhi.com.my/wp-content/uploads/2019/04/Chowrasta-Market-e1554186913474.jpg"] 
        }
      },
      {
        name: "Catholic Cemetery",
        place_category: "Mausoleums & Cemeteries",
        place_address: "161, Kelawai Rd, Georgetown, 10250 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.30795, 5.43839] },
        place_summary: "Located right next to the Protestant Cemetery on Northam Road, this burial ground was opened in the late 18th century. It served the early Catholic community of Penang. Fun fact: Many of the graves here belong to French missionaries, early Portuguese-Eurasian settlers who fled from Siam, and Hakka Chinese Catholics, reflecting the truly cosmopolitan nature of early George Town.",
        place_information: { rating: 3.5, reviews_count: 6, price_level: "N/A", phone: "+604-227 8297", website: "" },
        place_business_hours: { monday: "8 am–5 pm", tuesday: "8 am–5 pm", wednesday: "8 am–5 pm", thursday: "8 am–5 pm", friday: "8 am–5 pm", saturday: "8 am–5 pm", sunday: "8 am–5 pm" },
        place_media: { 
          thumbnail: "/images/places/ChIJwtOMeuLUlJS8B7nhWwsp2RE.jpg", 
          photos: ["/images/places/ChIJwtOMeuLUlJS8B7nhWwsp2RE.jpg"] 
        }
      },
      {
        name: "Campbell Street Market",
        place_category: "Markets",
        place_address: "Lebuh Campbell, 10100 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.3341, 5.4172] },
        place_summary: "Built around 1900, this striking Victorian-style market building sits at the corner of Campbell and Carnarvon Streets. It features distinct cast-iron structures imported from Britain. Fun fact: Long before it was a market, the site was actually an old Malay cemetery! Today, the beautifully preserved building stands as one of the most architecturally unique wet markets in Malaysia.",
        place_information: { rating: 4.1, reviews_count: 349, price_level: "N/A", phone: "", website: "" },
        place_business_hours: { monday: "7 am–2 pm", tuesday: "7 am–2 pm", wednesday: "7 am–2 pm", thursday: "7 am–2 pm", friday: "7 am–2 pm", saturday: "7 am–2 pm", sunday: "7 am–2 pm" },
        place_media: { 
          thumbnail: "/images/places/ChIJzcvzZVrPLySpWVDcv75jdpn.jpg", 
          photos: ["/images/places/ChIJzcvzZVrPLySpWVDcv75jdpn.jpg", "https://gtwhi.com.my/wp-content/uploads/2019/04/Campbell-Street-Market-e1554186992606.jpg"] 
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

      // 分类策略映射
      let primaryCategory = 'Heritage & Culture';
      let subCategories = ['Historical Sites', 'Historic Sites', 'Heritage & Culture'];

      if (place.place_category === 'Markets') {
        primaryCategory = 'Shopping & Markets';
        subCategories = ['Markets', 'Shopping & Markets', 'Local Market'];
      } else if (place.place_category === 'Mausoleums & Cemeteries') {
        primaryCategory = 'Heritage & Culture';
        subCategories = ['Mausoleums & Cemeteries', 'Heritage & Culture', 'Historic Site'];
      } else if (place.name === 'Little India') {
        primaryCategory = 'Heritage & Culture';
        subCategories = ['Cultural & Heritage', 'Little India', 'Heritage & Culture'];
      }

      const cleanName = place.name.toLowerCase();
      const searchKeywords = Array.from(new Set([
        cleanName,
        ...subCategories.map(s => s.toLowerCase()),
        'heritage',
        'george town',
        ...cleanName.replace(/[()（）]/g, ' ').split(/\s+/).filter(w => w.length > 2)
      ]));

      // 寻找现有地点 (兼容 Pasar Chowrasta Market 等别名)
      const existing = await PlaceNew.findOne({
        $or: [
          { name: place.name },
          { name: new RegExp('^' + place.name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'i') },
          ...(place.name === 'Chowrasta Market' ? [{ name: /Chowrasta/i }] : [])
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
        primary_category: primaryCategory,
        sub_categories: subCategories,
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
    console.log("----- Sites/景点数据同步到 places_new 完成 -----");
    console.log(`总计处理: ${placesData.length} 个地点`);
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
  seedSites();
}

module.exports = seedSites;