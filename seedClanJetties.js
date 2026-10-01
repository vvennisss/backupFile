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
  if (!hourStr || typeof hourStr !== 'string') return { is_closed: false, open: '09:00', close: '21:00' };
  const clean = hourStr.replace(/[\u202f\u00a0]/g, ' ').trim();
  if (/closed/i.test(clean)) {
    return { is_closed: true, open: '00:00', close: '00:00' };
  }
  if (/no information/i.test(clean)) {
    return { is_closed: false, open: '09:00', close: '21:00' };
  }
  const parts = clean.split(/[–\-]/);
  if (parts.length === 2) {
    const open = parseTime(parts[0]);
    const close = parseTime(parts[1]);
    if (open && close) {
      return { is_closed: false, open, close };
    }
  }
  return { is_closed: false, open: '09:00', close: '21:00' };
}

function formatReadableHours(businessHours) {
  if (!businessHours || typeof businessHours !== 'object') return '9:00 AM – 9:00 PM';
  const days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
  const cleaned = days.map(d => (businessHours[d] ? businessHours[d].replace(/[\u202f\u00a0]/g, ' ').replace(/\s*[–\-]\s*/g, ' – ').trim() : ''));
  const valid = cleaned.filter(h => h && !/no information/i.test(h));

  if (valid.length === 0) {
    return '9:00 AM – 9:00 PM (Visiting hours)';
  }
  if (new Set(cleaned).size === 1) {
    return `Mon–Sun: ${cleaned[0]}`;
  }
  return 'Mon–Sun: 9:00 AM – 9:00 PM';
}

async function seedClanJetties() {
  if (!MONGO_URI) {
    console.error("错误: 找不到 MongoDB URI，请检查环境变量。");
    return;
  }

  try {
    await mongoose.connect(MONGO_URI);
    console.log("✅ 成功连接到 MongoDB");

    const placesData = [
      {
        name: "Yeoh Jetty 姓杨桥",
        place_category: "clan jetty",
        place_address: "114, Pintasan Pengkalan 1, George Town, 10300 George Town, Pulau Pinang",
        place_location: { type: "Point", coordinates: [100.3413, 5.4131] },
        place_summary: "Built in the late 19th century, the Yeoh Jetty was established by Hokkien immigrants from the Yeoh clan. Unlike the highly commercialized jetties, it retains a quiet, residential charm that gives a true glimpse into the traditional waterfront lifestyle. Fun fact: The jetty originally had a much longer wooden walkway extending deep into the sea, but parts of it were dismantled over the years due to coastal development and the construction of the nearby highway.",
        place_information: { rating: 4.3, reviews_count: 170, price_level: "N/A", phone: "", website: "" },
        place_business_hours: { monday: "No Information", tuesday: "No Information", wednesday: "No Information", thursday: "No Information", friday: "No Information", saturday: "No Information", sunday: "No Information" },
        place_media: { 
          thumbnail: "/images/places/ChIJhn7CeLJUEkGebPriSi5KiJL.jpg", 
          photos: ["/images/places/ChIJhn7CeLJUEkGebPriSi5KiJL.jpg", "https://gtwhi.com.my/wp-content/uploads/2019/04/Yeoh-Jetty-e1554184054460.jpg", "/images/places/Yeoh Jetty.jpg"] 
        }
      },
      {
        name: "Mixed Surname Jetty (New Jetty) 杂姓桥",
        place_category: "clan jetty",
        place_address: "New Jetty, Pengkalan Weld, Georgetown, 10300 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.3413, 5.4131] },
        place_summary: "Known locally as 'Chap Seh Keo' (Mixed Surname Jetty), this settlement was established much later in the 1960s. It was formed by families of various surnames who did not belong to the other major single-surname jetties. Fun fact: Because it was built more recently compared to the 19th-century jetties, it is often referred to as the 'New Jetty' (or Peng Aun Jetty) and stands as the only clan jetty in Penang that isn't dominated by a single extended family lineage.",
        place_information: { rating: 3.9, reviews_count: 30, price_level: "N/A", phone: "", website: "" },
        place_business_hours: { monday: "No Information", tuesday: "No Information", wednesday: "No Information", thursday: "No Information", friday: "No Information", saturday: "No Information", sunday: "No Information" },
        place_media: { 
          thumbnail: "/images/places/ChIJyRHoEnptjvSFVaPHis4VmH8.jpg", 
          photos: ["/images/places/ChIJyRHoEnptjvSFVaPHis4VmH8.jpg", "https://gtwhi.com.my/wp-content/uploads/2019/04/Mixed-Surname-Jetty-New-Jetty_2-e1554185829450.jpg", "/images/places/Mixed Surname Jetty (New Jetty).jpg"] 
        }
      },
      {
        name: "Lee Jetty 姓李桥",
        place_category: "clan jetty",
        place_address: "57-58, Pengkalan Weld, 10300 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.3376, 5.4101] },
        place_summary: "Established in the mid-19th century by immigrants bearing the Lee surname from Quanzhou, China. The Lee Jetty is well-known for its neat layout, straight wooden paths, and beautiful lighting at the entrance. Fun fact: In the old days, the Lee clan members were primarily involved in the barter trade and boat handling. Today, their jetty is distinctively characterized by a very uniform row of wooden houses that makes it one of the most orderly-looking jetties on the waterfront.",
        place_information: { rating: 4.2, reviews_count: 613, price_level: "N/A", phone: "", website: "" },
        place_business_hours: { monday: "No Information", tuesday: "No Information", wednesday: "No Information", thursday: "No Information", friday: "No Information", saturday: "No Information", sunday: "No Information" },
        place_media: { 
          thumbnail: "/images/places/ChIJJXjQMVYdMxtOgORwsCfhLWE.jpg", 
          photos: ["/images/places/ChIJJXjQMVYdMxtOgORwsCfhLWE.jpg", "https://gtwhi.com.my/wp-content/uploads/2019/04/Lee-Jetty-e1554860173997.jpg", "/images/places/Lee Jetty.jpg"] 
        }
      },
      {
        name: "Tan Jetty 姓陈桥",
        place_category: "clan jetty",
        place_address: "Pengkalan Weld, 10300 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.3379, 5.4107] },
        place_summary: "Founded by the Tan clan from Quanzhou, China, this jetty is a favorite among photographers. It is famous for having a long, narrow wooden pier extending far out into the sea, offering stunning and unobstructed views of the mainland. Fun fact: At the very end of this long wooden boardwalk sits a small, picturesque red shrine dedicated to Mazu (Goddess of the Sea). It is arguably the best spot among all the jetties to capture the sunrise or sunset.",
        place_information: { rating: 4.2, reviews_count: 1274, price_level: "N/A", phone: "", website: "" },
        place_business_hours: { monday: "No Information", tuesday: "No Information", wednesday: "No Information", thursday: "No Information", friday: "No Information", saturday: "No Information", sunday: "No Information" },
        place_media: { 
          thumbnail: "/images/places/ChIJSB4hGmrnUgrhx82V9aAU2H4.jpg", 
          photos: ["/images/places/ChIJSB4hGmrnUgrhx82V9aAU2H4.jpg", "https://gtwhi.com.my/wp-content/uploads/2019/04/Tan-Jetty-1-e1554185112887.jpg", "/images/places/Tan Jetty.jpg"] 
        }
      },
      {
        name: "Chew Jetty 姓周桥",
        place_category: "clan jetty",
        place_address: "59A, Pengkalan Weld, 10300 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.3385, 5.4116] },
        place_summary: "Established in the mid-19th century, Chew Jetty is the largest, most intact, and most famous of the Clan Jetties. It was founded by the Chew clan from Xinlin village in Fujian province and has since evolved into a vibrant tourist hub. Fun fact: It famously hosts an enormous and spectacular Jade Emperor God (Thnee Kong) birthday celebration on the 8th night of Chinese New Year, drawing tens of thousands of devotees and tourists to its waterfront.",
        place_information: { rating: 4.1, reviews_count: 10579, price_level: "N/A", phone: "+6011-6246 2884", website: "" },
        place_business_hours: { monday: "9 am–9 pm", tuesday: "9 am–9 pm", wednesday: "9 am–9 pm", thursday: "9 am–9 pm", friday: "9 am–9 pm", saturday: "9 am–9 pm", sunday: "9 am–9 pm" },
        place_media: { 
          thumbnail: "/images/places/ChIJqJmKrdrMzP7UMUDxrqNxjPI.jpg", 
          photos: ["/images/places/ChIJqJmKrdrMzP7UMUDxrqNxjPI.jpg", "https://gtwhi.com.my/wp-content/uploads/2019/04/Chew-Jetty-e1554185975361.jpg", "/images/places/Chew Jetty.jpg"] 
        }
      },
      {
        name: "Lim Jetty 姓林桥",
        place_category: "clan jetty",
        place_address: "37, Pengkalan Weld, 10300 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.3389, 5.4124] },
        place_summary: "Lim Jetty is one of the oldest clan jetties in Penang, established in the mid-19th century by immigrants of the Lim surname from Fujian, China. It is the closest jetty to the Swettenham Pier Cruise Terminal. Fun fact: Historically, the Lim Jetty members were tough coolies and boatmen who dominated the cargo loading operations in their specific sector of the port. A beautiful traditional community temple greets visitors right at the entrance of the jetty.",
        place_information: { rating: 4.2, reviews_count: 304, price_level: "N/A", phone: "", website: "" },
        place_business_hours: { monday: "9 am–9 pm", tuesday: "9 am–9 pm", wednesday: "9 am–9 pm", thursday: "9 am–9 pm", friday: "9 am–9 pm", saturday: "9 am–9 pm", sunday: "9 am–9 pm" },
        place_media: { 
          thumbnail: "/images/places/ChIJMEanmOSdC1XAal7jV0TOjOo.jpg", 
          photos: ["/images/places/ChIJMEanmOSdC1XAal7jV0TOjOo.jpg", "https://gtwhi.com.my/ms/wp-content/uploads/2019/04/Lim-Jetty-e1554186084777.jpg", "/images/places/Lim Jetty.jpg"] 
        }
      },
      {
        name: "Ong Jetty 姓王桥",
        place_category: "clan jetty",
        place_address: "Pengkalan Weld, 10300 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.3370, 5.4082] },
        place_summary: "The Ong Jetty was once part of the bustling waterfront settlements for Chinese immigrants. However, unlike the larger jetties that survived, it has largely been lost to urban development, land reclamation, and the construction of flats over the decades. Fun fact: Today, the original sprawling wooden stilt houses of the Ong Jetty are gone. Only a small remnant, including a community temple, remains to mark the historical spot where the clan once lived and worked on the mudflats.",
        place_information: { rating: 5.0, reviews_count: 1, price_level: "N/A", phone: "", website: "" },
        place_business_hours: { monday: "No Information", tuesday: "No Information", wednesday: "No Information", thursday: "No Information", friday: "No Information", saturday: "No Information", sunday: "No Information" },
        place_media: { 
          thumbnail: "/images/places/ChIJLTHbZZE2xXE03xcqGfE60pe.jpg", 
          photos: ["/images/places/ChIJLTHbZZE2xXE03xcqGfE60pe.jpg", "https://gtwhi.com.my/wp-content/uploads/2019/04/Ong-Jetty-e1554186294190.jpg", "/images/places/Ong Jetty.jpg"] 
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

      const engName = place.name.replace(/[\u4e00-\u9fa5]/g, '').trim();
      const cleanName = place.name.toLowerCase();
      const searchKeywords = Array.from(new Set([
        cleanName,
        engName.toLowerCase(),
        'clan jetty',
        'clan jetties',
        '姓氏桥',
        'weld quay',
        'waterfront',
        'heritage & culture',
        'heritage',
        'george town',
        ...cleanName.replace(/[()（）]/g, ' ').split(/\s+/).filter(w => w.length > 1)
      ]));

      const existing = await PlaceNew.findOne({
        $or: [
          { name: place.name },
          { name: engName },
          { name: new RegExp('^' + engName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'i') }
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
        primary_category: 'Heritage & Culture',
        sub_categories: ['Clan Jetties', 'Clan Jetty', 'Heritage & Culture'],
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
    console.log("----- 姓氏桥数据同步到 places_new 完成 -----");
    console.log(`总计处理: ${placesData.length} 座姓氏桥`);
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
  seedClanJetties();
}

module.exports = seedClanJetties;