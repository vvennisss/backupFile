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
  if (!hourStr || typeof hourStr !== 'string') return { is_closed: false, open: '00:00', close: '23:59' };
  const clean = hourStr.replace(/[\u202f\u00a0]/g, ' ').trim();
  if (/closed/i.test(clean)) {
    return { is_closed: true, open: '00:00', close: '00:00' };
  }
  if (/open 24 hours/i.test(clean) || /no information/i.test(clean)) {
    return { is_closed: false, open: '00:00', close: '23:59' };
  }
  const parts = clean.split(/[–\-]/);
  if (parts.length === 2) {
    const open = parseTime(parts[0]);
    const close = parseTime(parts[1]);
    if (open && close) {
      return { is_closed: false, open, close };
    }
  }
  return { is_closed: false, open: '00:00', close: '23:59' };
}

function formatReadableHours(businessHours) {
  if (!businessHours || typeof businessHours !== 'object') return 'Open 24 hours';
  const days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
  const cleaned = days.map(d => (businessHours[d] ? businessHours[d].trim() : ''));
  const valid = cleaned.filter(h => h && !/no information/i.test(h));

  if (valid.length === 0 || valid[0].toLowerCase().includes('24 hours')) {
    return 'Open 24 hours';
  }
  return 'Open 24 hours';
}

async function seedMonuments() {
  if (!MONGO_URI) {
    console.error("错误: 找不到 MongoDB URI，请检查环境变量。");
    return;
  }

  try {
    await mongoose.connect(MONGO_URI);
    console.log("✅ 成功连接到 MongoDB");

    const placesData = [
      {
        name: "Yeng Keng Hotel Gateway",
        place_category: "monuments",
        place_address: "362 & 366, Lebuh Chulia, 10200 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.3341, 5.4187] },
        place_summary: "A beautifully preserved traditional Chinese archway standing proudly on Chulia Street. It marks the entrance to the Yeng Keng Hotel, which was originally built as a private Anglo-Indian bungalow in the mid-19th century before becoming a hotel in the early 1900s. Fun fact: This gateway is one of the few surviving independent Chinese archways in George Town, showcasing exquisite plaster stucco decorations that reflect the immense wealth of early Chinese tycoons.",
        place_information: { rating: 4.6, reviews_count: 362, price_level: "N/A", phone: "+604-262 2177", website: "https://www.yengkenghotel.com/" },
        place_business_hours: { monday: "Open 24 hours", tuesday: "Open 24 hours", wednesday: "Open 24 hours", thursday: "Open 24 hours", friday: "Open 24 hours", saturday: "Open 24 hours", sunday: "Open 24 hours" },
        place_media: { 
          thumbnail: "/images/places/ChIJ5WKkkTs4DHvsjDf4XNHgNow.jpg", 
          photos: ["/images/places/ChIJ5WKkkTs4DHvsjDf4XNHgNow.jpg", "https://gtwhi.com.my/wp-content/uploads/2019/04/Yeng-Keng-Hotel-Gateway-e1554194073938.jpg"] 
        }
      },
      {
        name: "Queen Victoria Memorial Clock Tower",
        place_category: "monuments",
        place_address: "Lebuh Light, 10200 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.3440, 5.4168] },
        place_summary: "Commissioned in 1897 by local Penang millionaire Cheah Chen Eok to commemorate Queen Victoria's Diamond Jubilee, this stunning Moorish-style clock tower was completed in 1902. Fun fact: The tower is exactly 60 feet tall, with each foot representing one year of the Queen's reign up to her Jubilee. Due to Allied bombing during WWII, the tower actually leans slightly to one side!",
        place_information: { rating: 4.2, reviews_count: 1514, price_level: "N/A", phone: "", website: "" },
        place_business_hours: { monday: "Open 24 hours", tuesday: "Open 24 hours", wednesday: "Open 24 hours", thursday: "Open 24 hours", friday: "Open 24 hours", saturday: "Open 24 hours", sunday: "Open 24 hours" },
        place_media: { 
          thumbnail: "/images/places/Queen Victoria Memorial Clock Tower.jpg", 
          photos: ["/images/places/Queen Victoria Memorial Clock Tower.jpg", "/images/places/ChIJ_Y9zS4_DSjARnxALwqb4vw8.jpg"] 
        }
      },
      {
        name: "Logan Memorial",
        place_category: "monuments",
        place_address: "Lebuh Light, 10200 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.3396, 5.4206] },
        place_summary: "Erected in memory of James Richardson Logan, a Scottish lawyer who passionately defended the rights of the non-European communities in Penang against the British East India Company. He passed away in 1869. Fun fact: Because the monument looks so grand, many locals historically mistook him for a powerful Governor, rather than a fiercely independent lawyer who fought for the common people!",
        place_information: { rating: 4.3, reviews_count: 22, price_level: "N/A", phone: "", website: "" },
        place_business_hours: { monday: "Open 24 hours", tuesday: "Open 24 hours", wednesday: "Open 24 hours", thursday: "Open 24 hours", friday: "Open 24 hours", saturday: "Open 24 hours", sunday: "Open 24 hours" },
        place_media: { 
          thumbnail: "/images/places/ChIJtmZhqEOlm7aOCtzFT2dgrqD.jpg", 
          photos: ["/images/places/ChIJtmZhqEOlm7aOCtzFT2dgrqD.jpg", "https://gtwhi.com.my/wp-content/uploads/2019/04/Logan-Memorial-e1554861110708.jpg", "/images/places/Logan Memorial.jpg"] 
        }
      },
      {
        name: "Koh Seang Tat Fountain",
        place_category: "monuments",
        place_address: "Jalan Tun Syed Sheh Barakbah, 10200 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.3404, 5.4215] },
        place_summary: "This elegant cast-iron fountain was presented to the Municipal Council in 1883 by Koh Seang Tat, a wealthy local merchant and the great-grandson of Captain Francis Light's business partner, Koh Lay Huan. Fun fact: It was originally installed near the Town Hall but fell into disrepair and disappeared for decades, before being meticulously restored and reinstated by the Penang Heritage Trust in modern times.",
        place_information: { rating: 3.8, reviews_count: 4, price_level: "N/A", phone: "", website: "" },
        place_business_hours: { monday: "Open 24 hours", tuesday: "Open 24 hours", wednesday: "Open 24 hours", thursday: "Open 24 hours", friday: "Open 24 hours", saturday: "Open 24 hours", sunday: "Open 24 hours" },
        place_media: { 
          thumbnail: "/images/places/ChIJZY2Zy2l3HKHg2NUzcFk4gsn.jpg", 
          photos: ["/images/places/ChIJZY2Zy2l3HKHg2NUzcFk4gsn.jpg", "https://gtwhi.com.my/wp-content/uploads/2019/04/Koh-Seang-Tat-Fountain-e1554861140722.jpg", "/images/places/Koh Seang Tat Fountain.jpg"] 
        }
      },
      {
        name: "Francis Light Memorial",
        place_category: "monuments",
        place_address: "Jalan Sultan Ahmad Shah, 10050 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.3332, 5.4231] },
        place_summary: "Located within the Protestant Cemetery, this beautiful classical domed pavilion was erected to honor Captain Francis Light, the British founder of modern Penang. Fun fact: Visitors often mistake this grand structure for Francis Light's actual grave. In reality, his remains are buried under a surprisingly modest and plain stone slab just a few steps away from this memorial.",
        place_information: { rating: 4.3, reviews_count: 11, price_level: "N/A", phone: "", website: "" },
        place_business_hours: { monday: "No Information", tuesday: "No Information", wednesday: "No Information", thursday: "No Information", friday: "No Information", saturday: "No Information", sunday: "No Information" },
        place_media: { 
          thumbnail: "/images/places/ChIJcVOLfDFhhnXgbmFe2G7H1K2.jpg", 
          photos: ["/images/places/ChIJcVOLfDFhhnXgbmFe2G7H1K2.jpg", "https://gtwhi.com.my/wp-content/uploads/2019/04/Francis-Light-Memorial-Copy-e1554194031719.jpg", "/images/places/Francis Light Memorial.jpg"] 
        }
      },
      {
        name: "Cenotaph War Memorial",
        place_category: "monuments",
        place_address: "Esplanade, Jalan Tun Syed Sheh Barakbah, 10200 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.3411, 5.4212] },
        place_summary: "Situated at the Esplanade, this memorial originally commemorated the Allied soldiers from Penang who died during World War I. Later plaques were added to honor the fallen of WWII, the Malayan Emergency, and the Indonesian Confrontation. Fun fact: The original Cenotaph was completely destroyed by Allied bombs during WWII. In 1948, a local architectural firm rebuilt it to look exactly like the original structure from 1929.",
        place_information: { rating: 4.3, reviews_count: 139, price_level: "N/A", phone: "", website: "" },
        place_business_hours: { monday: "Open 24 hours", tuesday: "Open 24 hours", wednesday: "Open 24 hours", thursday: "Open 24 hours", friday: "Open 24 hours", saturday: "Open 24 hours", sunday: "Open 24 hours" },
        place_media: { 
          thumbnail: "/images/places/Cenotaph War Memorial.jpg", 
          photos: ["/images/places/Cenotaph War Memorial.jpg", "/images/places/ChIJpp0yo62rXHnUK62Q9hzvslu.jpg"] 
        }
      },
      {
        name: "23LoveLane Hotel Gate",
        place_category: "monuments",
        place_address: "23, Lorong Love, 10200 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.3371, 5.4190] },
        place_summary: "A distinctive historic gateway leading into the courtyard of what is now the 23LoveLane boutique hotel. The property dates back to the 1800s and incorporates a mix of Anglo-Indian and Chinese architectural styles. Fun fact: Love Lane got its romantic name because wealthy Straits Chinese tycoons and European merchants who lived on nearby Muntri Street historically kept their mistresses in this quieter, tucked-away alley!",
        place_information: { rating: 4.5, reviews_count: 45, price_level: "N/A", phone: "+604 -262 1323", website: "https://www.23lovelane.com/" },
        place_business_hours: { monday: "Open 24 hours", tuesday: "Open 24 hours", wednesday: "Open 24 hours", thursday: "Open 24 hours", friday: "Open 24 hours", saturday: "Open 24 hours", sunday: "Open 24 hours" },
        place_media: { 
          thumbnail: "/images/places/ChIJ7DoXcqdpUYtYnvS1JbncVkv.jpg", 
          photos: ["/images/places/ChIJ7DoXcqdpUYtYnvS1JbncVkv.jpg", "https://gtwhi.com.my/wp-content/uploads/2019/04/23LoveLane-Hotel-Gate-e1554861230196.jpg"] 
        }
      }
    ];

    let updatedCount = 0;
    let insertedCount = 0;

    for (const place of placesData) {
      const openingHours = { is_24_hours: true };
      const days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
      for (const day of days) {
        openingHours[day] = parseDaySchedule(place.place_business_hours[day]);
      }
      const rawHoursText = formatReadableHours(place.place_business_hours);

      const cleanName = place.name.toLowerCase();
      const searchKeywords = Array.from(new Set([
        cleanName,
        'monuments',
        'monument',
        'memorial',
        'historic landmark',
        'heritage & culture',
        'heritage',
        'george town',
        ...cleanName.replace(/[()（）]/g, ' ').split(/\s+/).filter(w => w.length > 2)
      ]));

      const existing = await PlaceNew.findOne({
        $or: [
          { name: place.name },
          { name: new RegExp('^' + place.name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'i') }
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
        sub_categories: ['Monuments', 'Monument', 'Memorial', 'Heritage & Culture'],
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
    console.log("----- 纪念碑古迹数据同步到 places_new 完成 -----");
    console.log(`总计处理: ${placesData.length} 座纪念碑古迹`);
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
  seedMonuments();
}

module.exports = seedMonuments;