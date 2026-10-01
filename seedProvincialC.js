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
  if (!hourStr || typeof hourStr !== 'string') return { is_closed: false, open: '09:00', close: '17:00' };
  const clean = hourStr.replace(/[\u202f\u00a0]/g, ' ').trim();
  if (/closed/i.test(clean)) {
    return { is_closed: true, open: '00:00', close: '00:00' };
  }
  if (/no information/i.test(clean)) {
    return { is_closed: false, open: '09:00', close: '17:00' };
  }
  const parts = clean.split(/[–\-]/);
  if (parts.length === 2) {
    const open = parseTime(parts[0]);
    const close = parseTime(parts[1]);
    if (open && close) {
      return { is_closed: false, open, close };
    }
  }
  return { is_closed: false, open: '09:00', close: '17:00' };
}

function formatReadableHours(businessHours) {
  if (!businessHours || typeof businessHours !== 'object') return '9:00 AM – 5:00 PM';
  const days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
  const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  const cleaned = days.map(d => (businessHours[d] ? businessHours[d].replace(/[\u202f\u00a0]/g, ' ').replace(/\s*[–\-]\s*/g, ' – ').trim() : ''));
  const valid = cleaned.filter(h => h && !/no information/i.test(h));

  if (valid.length === 0) {
    return '9:00 AM – 5:00 PM (Visiting hours)';
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

async function seedProvincialAssociations() {
  if (!MONGO_URI) {
    console.error("错误: 找不到 MongoDB URI，请检查环境变量。");
    return;
  }

  try {
    await mongoose.connect(MONGO_URI);
    console.log("✅ 成功连接到 MongoDB");

    const placesData = [
      {
        name: "Tsen Lung Fui Kon",
        place_category: "provincial associations",
        place_address: "22, King Street, 10200 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.34038, 5.41889] },
        place_summary: "Established by Hakka immigrants from the Zenglong district of Guangdong, this district association serves the Tsen Lung community. It is situated on King Street, an area historically dense with various clan and district associations. Fun fact: King Street was traditionally segregated into different sections by dialect groups, and this Hakka association stands right next to the Kar Yin Association, showcasing the close-knit nature of early Hakka immigrants.",
        place_information: { rating: 4.5, reviews_count: 6, price_level: "N/A", phone: "", website: "" },
        place_business_hours: { monday: "No Information", tuesday: "No Information", wednesday: "No Information", thursday: "No Information", friday: "No Information", saturday: "No Information", sunday: "No Information" },
        place_media: { 
          thumbnail: "/images/places/ChIJT6PEL8PsTUidFw3tj3TqtfM.jpg", 
          photos: ["/images/places/ChIJT6PEL8PsTUidFw3tj3TqtfM.jpg", "https://gtwhi.com.my/wp-content/uploads/2019/04/Tseng-Lung-Fui-Kon-e1554859874646.jpg"] 
        }
      },
      {
        name: "Toi Shan Ningyang Wui Kwon",
        place_category: "provincial associations",
        place_address: "36 & 38, King Street, 10200 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.3400, 5.4182] },
        place_summary: "A prominent district association serving the Toi Shan (Taishan) community who originated from the Canton province. It was built to foster solidarity among Taishanese immigrants. Fun fact: Taishanese people were among the earliest Chinese diaspora globally. In 19th-century Penang, associations like this functioned not just as temples, but as vital immigrant receiving centers, employment agencies, and dispute mediation halls.",
        place_information: { rating: 4.0, reviews_count: 61, price_level: "N/A", phone: "+604-262 5295", website: "" },
        place_business_hours: { monday: "No Information", tuesday: "No Information", wednesday: "No Information", thursday: "No Information", friday: "No Information", saturday: "No Information", sunday: "No Information" },
        place_media: { 
          thumbnail: "/images/places/ChIJpev0a1vhx1hjWfaLhF3aZLG.jpg", 
          photos: ["/images/places/ChIJpev0a1vhx1hjWfaLhF3aZLG.jpg", "https://gtwhi.com.my/wp-content/uploads/2019/04/Toi-Shan-Ningyang-Wui-Kwon.jpg"] 
        }
      },
      {
        name: "Thean Hou Temple (Hainan Association and Temple)",
        place_category: "provincial associations",
        place_address: "93, Lebuh Muntri, 10450 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.33462, 5.42009] },
        place_summary: "Founded in 1866 and completed in 1895, this Hainanese temple and association is dedicated to Mazu, the Goddess of the Sea. It was built by Hainanese immigrants who were mostly seafarers and renowned cooks. Fun fact: The exquisite sung-dynasty style stone carvings on the temple's facade were crafted by artisans brought directly from China in 1995 to commemorate the building's centenary.",
        place_information: { rating: 4.6, reviews_count: 155, price_level: "N/A", phone: "+604-262 3752", website: "" },
        place_business_hours: { monday: "8 am–5 pm", tuesday: "8 am–5 pm", wednesday: "8 am–5 pm", thursday: "8 am–5 pm", friday: "8 am–5 pm", saturday: "8 am–5 pm", sunday: "8 am–5 pm" },
        place_media: { 
          thumbnail: "/images/places/ChIJdmKCNgJIC1lMLSC8d7r4Fov.jpg", 
          photos: ["/images/places/ChIJdmKCNgJIC1lMLSC8d7r4Fov.jpg", "https://gtwhi.com.my/wp-content/uploads/2019/04/Thean-Hou-Temple-Hainan-Association-and-Temple-e1554859044418.jpg"] 
        }
      },
      {
        name: "Sun Wui Wui Koon",
        place_category: "provincial associations",
        place_address: "38, Lebuh Bishop, 10200 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.3396, 5.4178] },
        place_summary: "Established in the 1870s, this is a district association for the Cantonese migrants from the Xinhui (Sun Wui) district. Featuring distinctive gray brick walls and grand granite gate posts, it serves both as a cultural hub and a temple. Fun fact: The main altar is dedicated to Guan Gong (the God of War), and the association's classic Cantonese architecture makes it one of the most underrated, photogenic heritage gems in George Town.",
        place_information: { rating: 4.6, reviews_count: 20, price_level: "N/A", phone: "+60 4-261 5918", website: "" },
        place_business_hours: { monday: "No Information", tuesday: "No Information", wednesday: "No Information", thursday: "No Information", friday: "No Information", saturday: "No Information", sunday: "No Information" },
        place_media: { 
          thumbnail: "/images/places/ChIJO6QA3UzSXKDNMCj2DNwbS9A.jpg", 
          photos: ["/images/places/ChIJO6QA3UzSXKDNMCj2DNwbS9A.jpg", "https://gtwhi.com.my/wp-content/uploads/2019/04/Sun-Wui-Wui-Koon-e1554859279585.jpg"] 
        }
      },
      {
        name: "Soon Tuck Wooi Kwon",
        place_category: "provincial associations",
        place_address: "51, Love Lane, 10200 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.3364, 5.4190] },
        place_summary: "Founded in 1838, this association was established to provide a network, welfare, and community support for immigrants hailing from the Shunde (Soon Tuck) district of Guangdong. Fun fact: Located on the famous Love Lane, this association sits amidst a street that was historically a melting pot of Eurasian, Chinese, and Indian communities, showing how district associations integrated into the diverse urban fabric of colonial Penang.",
        place_information: { rating: 4.4, reviews_count: 7, price_level: "N/A", phone: "", website: "" },
        place_business_hours: { monday: "9 am-1 pm", tuesday: "9 am-1 pm", wednesday: "9 am-1 pm", thursday: "9 am-1 pm", friday: "9 am-1 pm", saturday: "Closed", sunday: "9 am-1 pm" },
        place_media: { 
          thumbnail: "/images/places/ChIJljtbUvh7bPs1WWIl08MAcSo.jpg", 
          photos: ["/images/places/ChIJljtbUvh7bPs1WWIl08MAcSo.jpg", "https://gtwhi.com.my/wp-content/uploads/2019/04/Soon-Tuck-Wooi-Kwon-e1554190421182.jpg"] 
        }
      },
      {
        name: "Ng Fook Tong",
        place_category: "provincial associations",
        place_address: "407, Lebuh Chulia, 10200 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.3343, 5.4193] },
        place_summary: "Built in 1898, this century-old Cantonese Guild Hall (also known as Ng Fook Thong Temple) originally served as an academy and gathering place for Chinese immigrants. Fun fact: It is one of the rare overseas buildings that functioned as a traditional Chinese academy. Inside, visitors can still find ancient Chinese honor rolls and deep, imposing double-courtyards that exude a dignified, scholarly character.",
        place_information: { rating: 4.4, reviews_count: 20, price_level: "N/A", phone: "+604-261 8620", website: "" },
        place_business_hours: { monday: "9 am–5 pm", tuesday: "9 am–5 pm", wednesday: "9 am–5 pm", thursday: "9 am–5 pm", friday: "9 am–5 pm", saturday: "9 am–5 pm", sunday: "Closed" },
        place_media: { 
          thumbnail: "/images/places/ChIJyNg62ApLGypySWu3U8Sg4ca.jpg", 
          photos: ["/images/places/ChIJyNg62ApLGypySWu3U8Sg4ca.jpg", "https://gtwhi.com.my/wp-content/uploads/2019/04/Ng-Fook-Tong.jpg"] 
        }
      },
      {
        name: "Nam Hooi Wooi Koon",
        place_category: "provincial associations",
        place_address: "463, Lebuh Chulia, 10200 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.33364, 5.41925] },
        place_summary: "Founded in 1827 (or 1828), this is the oldest overseas Nanhai Association in the world, serving immigrants from the Nanhai district of Guangdong. The building is exceptionally deep, stretching 200 feet from Chulia Street to Kampung Malabar. Fun fact: Devotees here uniquely pray to the 'White Tiger God' for protection against bad luck, and during specific times of the year, they rub the tiger deity's mouth with a piece of raw lard for good fortune!",
        place_information: { rating: 4.4, reviews_count: 8, price_level: "N/A", phone: "", website: "" },
        place_business_hours: { monday: "No Information", tuesday: "No Information", wednesday: "No Information", thursday: "No Information", friday: "No Information", saturday: "No Information", sunday: "No Information" },
        place_media: { 
          thumbnail: "/images/places/ChIJ5f7A9QeQITdGF4VhhI07sGq.jpg", 
          photos: ["/images/places/ChIJ5f7A9QeQITdGF4VhhI07sGq.jpg", "https://gtwhi.com.my/wp-content/uploads/2019/04/Nam-Hooi-Wooi-Koon.jpg"] 
        }
      },
      {
        name: "Kwangtung and Tengchow Association",
        place_category: "provincial associations",
        place_address: "50, Lebuh Penang, 10200 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.34065, 5.41826] },
        place_summary: "Tracing its roots back to 1795 to manage communal cemeteries, this association acts as an umbrella body for 18 different Guangdong and Fujian organizations. The current headquarters was completed in 1941. Fun fact: Unlike traditional Chinese temples, this building was designed by London-born architect Charles Geoffrey Boutcher in a stout, fortress-like Art Deco style, complete with two flanking towers, just before the Japanese invasion of Penang.",
        place_information: { rating: 4.5, reviews_count: 11, price_level: "N/A", phone: "+6 04-261 0339", website: "" },
        place_business_hours: { monday: "No Information", tuesday: "No Information", wednesday: "No Information", thursday: "No Information", friday: "No Information", saturday: "No Information", sunday: "No Information" },
        place_media: { 
          thumbnail: "/images/places/ChIJL_yqITrDSjARxnkZzBt4tHk.jpg", 
          photos: ["/images/places/ChIJL_yqITrDSjARxnkZzBt4tHk.jpg", "https://gtwhi.com.my/wp-content/uploads/2019/04/Kwangtung-and-Tengchow-Association-e1554190152267.jpg"] 
        }
      },
      {
        name: "Kar Yin Fee Kuan (Kar Yin Association)",
        place_category: "provincial associations",
        place_address: "24, King Street, 10200 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.34038, 5.41889] },
        place_summary: "Established in the early 1800s, this district association represents Hakka clansmen from the Jiaying (Kar Yin) prefecture in Guangdong province. Fun fact: Kar Yin Hakka immigrants were highly regarded for their skills in traditional Chinese medicine and textiles. Sitting right next to the Tsen Lung Fui Kon, it exemplifies how different Hakka districts clustered closely together for mutual protection and business networking.",
        place_information: { rating: 4.7, reviews_count: 6, price_level: "N/A", phone: "+6 04-261 4652", website: "" },
        place_business_hours: { monday: "9 am-12 pm", tuesday: "9 am-12 pm", wednesday: "9 am-12 pm", thursday: "9 am-12 pm", friday: "9 am-12 pm", saturday: "9 am-12 pm", sunday: "Closed" },
        place_media: { 
          thumbnail: "/images/places/ChIJM1k032Zi6uM8F9eF8TGvrQj.jpg", 
          photos: ["/images/places/ChIJM1k032Zi6uM8F9eF8TGvrQj.jpg", "https://gtwhi.com.my/wp-content/uploads/2019/04/Kar-Yin-Fee-Kuan-Kar-Yin-Association-1-e1554859732577.jpg"] 
        }
      },
      {
        name: "Han Jiang Ancestral Temple",
        place_category: "provincial associations",
        place_address: "127, Lebuh Chulia, 10200 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.33814, 5.41669] },
        place_summary: "Formed in 1855 by six Teochew migrants, this stunning temple was completed in 1870. It serves as the community heart for the Penang Teochew Association. Fun fact: The temple boasts a traditional 'four-point gold' (si dian jing) quadrangle design. Because of its meticulous and faithful restoration, it proudly won the prestigious UNESCO Asia-Pacific Heritage Award for Culture Heritage Conservation in 2006.",
        place_information: { rating: 4.3, reviews_count: 102, price_level: "N/A", phone: "+60 4-262 5629", website: "" },
        place_business_hours: { monday: "8.30 am-4.30 pm", tuesday: "8.30 am-4.30 pm", wednesday: "8.30 am-4.30 pm", thursday: "8.30 am-4.30 pm", friday: "8.30 am-4.30 pm", saturday: "8.30 am-4.30 pm", sunday: "8.30 am-12.30 pm" },
        place_media: { 
          thumbnail: "/images/places/ChIJGcn58KV3d02mHHW7ysTQmrS.jpg", 
          photos: ["/images/places/ChIJGcn58KV3d02mHHW7ysTQmrS.jpg", "https://gtwhi.com.my/wp-content/uploads/2019/04/Han-Jiang-Ancestral-Temple.jpg"] 
        }
      },
      {
        name: "Eng Tai Hooi Kuan (Yong Da Guan)",
        place_category: "provincial associations",
        place_address: "Lorong Toh Aka, George Town, 10450, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.33659, 5.41302] },
        place_summary: "Founded in 1840, this association (also known as Yong Da Guan) represents the Hakka dialect groups originating from Yongding (Eng Teng) and Dabu (Tai Pu) counties in China. Fun fact: The Hakka people from these regions were famous for their unique earthen roundhouses (Tulou) back in China. In Penang, they established this association to maintain their distinct cultural identity and provide mutual aid to newly arrived Hakka traders and laborers.",
        place_information: { rating: 4.5, reviews_count: 10, price_level: "N/A", phone: "", website: "" },
        place_business_hours: { monday: "No Information", tuesday: "No Information", wednesday: "No Information", thursday: "No Information", friday: "No Information", saturday: "No Information", sunday: "No Information" },
        place_media: { 
          thumbnail: "/images/places/ChIJIicp3zonk8vns9sOdMCcK8q.jpg", 
          photos: ["/images/places/ChIJIicp3zonk8vns9sOdMCcK8q.jpg", "https://gtwhi.com.my/wp-content/uploads/2019/04/Eng-Tai-Hooi-Kuan-Yong-Da-Guan-e1554859819911.jpg"] 
        }
      },
      {
        name: "Chung San Wooi Koon",
        place_category: "provincial associations",
        place_address: "30, King Street, 10200 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.3401, 5.4185] },
        place_summary: "Established in the late 19th century, this historic cultural landmark is deeply rooted in Penang's Chinese community, specifically serving those who trace their ancestry to Zhongshan in Guangdong. Fun fact: Zhongshan is the birthplace of Dr. Sun Yat-sen, the founding father of the Republic of China. Associations like this played a pivotal role in the early 20th century by discreetly supporting his revolutionary activities and fundraising efforts overseas.",
        place_information: { rating: 4.4, reviews_count: 5, price_level: "N/A", phone: "+604-261 3097", website: "" },
        place_business_hours: { monday: "No Information", tuesday: "No Information", wednesday: "No Information", thursday: "No Information", friday: "No Information", saturday: "No Information", sunday: "No Information" },
        place_media: { 
          thumbnail: "/images/places/Chung San Wooi Koon.jpg", 
          photos: ["/images/places/Chung San Wooi Koon.jpg"] 
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

      const cleanName = place.name.toLowerCase();
      const searchKeywords = Array.from(new Set([
        cleanName,
        'provincial associations',
        'provincial association',
        'association',
        '会馆',
        'guild hall',
        'heritage & culture',
        'heritage',
        'george town',
        ...cleanName.replace(/[()（）]/g, ' ').split(/\s+/).filter(w => w.length > 2)
      ]));

      // 寻找现有地点 (兼容 Kwangtung & Tengchow Association heritage building 等)
      const existing = await PlaceNew.findOne({
        $or: [
          { name: place.name },
          { name: new RegExp('^' + place.name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'i') },
          { name: new RegExp(place.name.replace(/ and /i, ' &? '), 'i') }
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
        sub_categories: ['Provincial Associations', 'Provincial Association', 'Guild Hall', 'Heritage & Culture'],
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
    console.log("----- 地缘会馆数据同步到 places_new 完成 -----");
    console.log(`总计处理: ${placesData.length} 个地缘会馆`);
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
  seedProvincialAssociations();
}

module.exports = seedProvincialAssociations;