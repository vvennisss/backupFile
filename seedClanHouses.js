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

async function seedClanHouses() {
  if (!MONGO_URI) {
    console.error("错误: 找不到 MongoDB URI，请检查环境变量。");
    return;
  }

  try {
    await mongoose.connect(MONGO_URI);
    console.log("✅ 成功连接到 MongoDB");

    const placesData = [
      {
        name: "Teoh Si Cheng Hoe Tong",
        place_category: "clan houses",
        place_address: "260, Lebuh Carnarvon, George Town, 10100 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.3345, 5.4150] },
        place_summary: "Founded in 1891 by the Hakka tycoon Cheong Fatt Tze (whose Hokkien name was Teoh Thiaw Siat), this clan house serves the Teoh clansmen. Housed in a Straits Eclectic style building constructed in 1931, the clan temple is on the upper floor. Fun fact: Legend has it that the Teoh surname was bestowed by Emperor Huang to his grandson Hui, who invented a bow and pellet to defend the nation; the character for Teoh (Zhang) is a combination of the pictograms for 'bow' and 'long'.",
        place_information: { rating: 4.0, reviews_count: 6, price_level: "N/A", phone: "", website: "" },
        place_business_hours: { monday: "No information", tuesday: "No information", wednesday: "No information", thursday: "No information", friday: "No information", saturday: "No information", sunday: "No information" },
        place_media: { 
          thumbnail: "/images/places/ChIJwfQrN8VyU10410t39rWoEPS.jpg", 
          photos: ["/images/places/ChIJwfQrN8VyU10410t39rWoEPS.jpg", "https://gtwhi.com.my/wp-content/uploads/2019/04/Teoh-Si-Cheng-Hoe-Tong-1-e1554858124591.jpg"] 
        }
      },
      {
        name: "Tay Koon Oh Kongsi",
        place_category: "clan houses",
        place_address: "70, Lebuh Penang, George Town, 10200 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.3402, 5.4187] },
        place_summary: "Located along Penang Street, this historic Chinese clan association serves the Oh (or Hu) clan members. Like many clan houses established in the 19th century, it was a crucial welfare center for new immigrants arriving from China. Fun fact: Clan associations like this one were essential for survival, offering not just a place for ancestral worship, but acting as an employment agency and dispute settlement center for early migrants.",
        place_information: { rating: 4.5, reviews_count: 2, price_level: "N/A", phone: "+60 4-262 0480", website: "" },
        place_business_hours: { monday: "No information", tuesday: "No information", wednesday: "No information", thursday: "No information", friday: "No information", saturday: "No information", sunday: "No information" },
        place_media: { 
          thumbnail: "/images/places/ChIJdkcxZzWO3qYHyr4dNzumrrc.jpg", 
          photos: ["/images/places/ChIJdkcxZzWO3qYHyr4dNzumrrc.jpg", "https://gtwhi.com.my/wp-content/uploads/2019/04/Tay-Koon-Oh-Kongsi-e1554858177337-849x1024.jpg"] 
        }
      },
      {
        name: "Seh Tek Tong Cheah Kongsi",
        place_category: "clan houses",
        place_address: "8, Lebuh Armenian, George Town, 10200 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.3386, 5.4149] },
        place_summary: "Established in 1810 by the Cheah clan from Sek Tong Village in Fujian, this is the oldest of the 'Five Big Clans' in Penang. The architecture is a fascinating hybrid: it features a traditional Chinese ritual layout and roofs crowded with southern Chinese ornaments, but incorporates Malay-style stilt pillars and European-style lion heads. Fun fact: The compound was originally built like a self-contained village and is the first clan house in Malaysia to feature its own Interpretation Centre.",
        place_information: { rating: 4.2, reviews_count: 349, price_level: "RM 10", phone: "+60 4-261 3837", website: "https://cheahkongsi.org/" },
        place_business_hours: { monday: "9:30 am–4:30 pm", tuesday: "9:30 am–4:30 pm", wednesday: "9:30 am–4:30 pm", thursday: "9:30 am–4:30 pm", friday: "9:30 am–4:30 pm", saturday: "9:30 am–4:30 pm", sunday: "9:30 am–4:30 pm" },
        place_media: { 
          thumbnail: "/images/places/ChIJCVgLDi0w6PWveXcFCosXZUn.jpg", 
          photos: ["/images/places/ChIJCVgLDi0w6PWveXcFCosXZUn.jpg", "https://gtwhi.com.my/wp-content/uploads/2019/04/Seh-Tek-Tong-Cheah-Kongsi-1.jpg"] 
        }
      },
      {
        name: "Ng See Kah Miew (Ng Ancestral Temple)",
        place_category: "clan houses",
        place_address: "40, Lebuh King, George Town, 10200 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.3396, 5.4179] },
        place_summary: "Established in the early 19th century, the Ng Family Ancestral Temple boasts an ancient inner structure dating back to 1830. Around 1910, a newly constructed facade was built to encase the original building. Fun fact: The exterior of the temple features beautiful European Art Nouveau tiles, showcasing the unique cultural blending of Straits Eclectic architecture that was popular among wealthy Chinese clans in early Penang.",
        place_information: { rating: 4.3, reviews_count: 12, price_level: "N/A", phone: "+604-262 5557", website: "" },
        place_business_hours: { monday: "9 am–5 pm", tuesday: "9 am–5 pm", wednesday: "9 am–5 pm", thursday: "9 am–5 pm", friday: "9 am–5 pm", saturday: "9 am–5 pm", sunday: "Closed" },
        place_media: { 
          thumbnail: "/images/places/ChIJWTaH4keF6E9OWiPbVumlpPm.jpg", 
          photos: ["/images/places/ChIJWTaH4keF6E9OWiPbVumlpPm.jpg", "https://gtwhi.com.my/wp-content/uploads/2019/04/Ng-See-Kah-Miew-Ng-Ancestral-Temple-e1554859955251-849x1024.jpg"] 
        }
      },
      {
        name: "Moey She Temple",
        place_category: "clan houses",
        place_address: "31, Lebuh Penang, George Town, 10200 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.3407, 5.4179] },
        place_summary: "A lesser-known gem located in the Little India district, this Cantonese-style Taishanese clan temple was built in 1905 (with origins tracing back to 1841). It serves the Moey (or Boey, Mui) clansmen. Fun fact: Though the temple is only one story high, its imposing walls are built to the height of a two-story building. Its front gate is guarded by a pair of striking ceramic lions instead of the usual stone lions.",
        place_information: { rating: 4.9, reviews_count: 9, price_level: "N/A", phone: "+604-262 7519", website: "" },
        place_business_hours: { monday: "No information", tuesday: "No information", wednesday: "No information", thursday: "No information", friday: "No information", saturday: "No information", sunday: "No information" },
        place_media: { 
          thumbnail: "/images/places/ChIJDnr15S7wGJlds4E3qP2a8TL.jpg", 
          photos: ["/images/places/ChIJDnr15S7wGJlds4E3qP2a8TL.jpg", "https://gtwhi.com.my/wp-content/uploads/2019/04/Moey-She-Temple123-e1554862497848.jpg"] 
        }
      },
      {
        name: "Leong See Kah Miew",
        place_category: "clan houses",
        place_address: "65, Jln Perak, 10150 George Town, Pulau Pinang",
        place_location: { type: "Point", coordinates: [100.3347, 5.4201] },
        place_summary: "Tucked along the historic Muntri Street, Leong See Kah Miew serves as the ancestral temple for the Leong clan. The building features fine Chinese craftsmanship, especially in its woodwork and roof ridge ornamentation. Fun fact: Muntri Street itself was home to many wealthy Chinese merchants, and maintaining a clan house here was a symbol of the Leong family's status and solidarity in the bustling colonial port.",
        place_information: { rating: 5.0, reviews_count: 2, price_level: "N/A", phone: "+604-226 3346", website: "" },
        place_business_hours: { monday: "No information", tuesday: "No information", wednesday: "No information", thursday: "No information", friday: "No information", saturday: "No information", sunday: "No information" },
        place_media: { 
          thumbnail: "/images/places/ChIJ4zUWLYuRbFPxKeoIZ5xF0E1.jpg", 
          photos: ["/images/places/ChIJ4zUWLYuRbFPxKeoIZ5xF0E1.jpg", "https://gtwhi.com.my/wp-content/uploads/2019/04/Leong-See-Kah-Miew-e1554858035802.jpg"] 
        }
      },
      {
        name: "Leong San Tong Khoo Kongsi",
        place_category: "clan houses",
        place_address: "18, Cannon Square, George Town, 10450 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.3371, 5.4143] },
        place_summary: "Established in 1851, this is arguably the grandest clan temple in Malaysia. Hidden in Cannon Square, it was built by the Khoos from Sin Kang Village in Fujian. Fun fact: The original temple built in 1901 was so lavish that it allegedly angered the gods and burned down on Chinese New Year's Eve! The current scaled-down (but still incredibly magnificent) version was completed in 1906, featuring intricate stone carvings, woodworks, and roof dragons.",
        place_information: { rating: 4.4, reviews_count: 2070, price_level: "RM 17", phone: "+60 4-261 4609", website: "khookongsi.com.my" },
        place_business_hours: { monday: "9 am–5 pm", tuesday: "9 am–5 pm", wednesday: "9 am–5 pm", thursday: "9 am–5 pm", friday: "9 am–5 pm", saturday: "9 am–5 pm", sunday: "9 am–5 pm" },
        place_media: { 
          thumbnail: "/images/places/ChIJny-BJpLDSjARtmEDgFcyASw.jpg", 
          photos: ["/images/places/ChIJny-BJpLDSjARtmEDgFcyASw.jpg", "https://upload.wikimedia.org/wikipedia/commons/4/47/Khoo_Kongsi_%28I%29.jpg"] 
        }
      },
      {
        name: "Lee Sih Chong Soo",
        place_category: "clan houses",
        place_address: "182-A, Jalan Burma, 10050 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.3235, 5.4228] },
        place_summary: "Also known as the Lee Clan Association (Long Say Tong), this prominent clan house is located slightly outside the core heritage zone on Burmah Road. It serves the vast Lee clan in Penang. Fun fact: The temple's formal name 'Long Say' (Longxi) traces the Lee surname's ancient roots back to the Longxi Commandery in Gansu province, China, honoring their deep ancestral lineage.",
        place_information: { rating: 4.3, reviews_count: 63, price_level: "N/A", phone: "+604-226 7634", website: "" },
        place_business_hours: { monday: "No information", tuesday: "No information", wednesday: "No information", thursday: "No information", friday: "No information", saturday: "No information", sunday: "No information" },
        place_media: { 
          thumbnail: "/images/places/ChIJkdAGmtegfbUCOTR4LqQUZ4G.jpg", 
          photos: ["/images/places/ChIJkdAGmtegfbUCOTR4LqQUZ4G.jpg", "https://gtwhi.com.my/wp-content/uploads/2019/04/Lee-Sih-Chong-Soo-1.jpg"] 
        }
      },
      {
        name: "Koong Har Tong Wong Si Chong Chi",
        place_category: "clan houses",
        place_address: "Jalan Jelutong, George Town, 11600 George Town, Pulau Pinang",
        place_location: { type: "Point", coordinates: [100.3409, 5.4172] },
        place_summary: "Serving the Wong (Ooi/Huang) clan, this association on Penang Street traces its roots to the ancient Jiangxia commandery. Fun fact: 'Koong Har' (Jiangxia) is the most famous ancestral hall name for the Huangs. According to legend, a vast golden cloud appeared when the emperor bestowed the surname, meaning 'yellow cloud', hence the deep pride the clan holds in their Jiangxia origins.",
        place_information: { rating: 3.7, reviews_count: 3, price_level: "N/A", phone: "+6011-6444 8153", website: "" },
        place_business_hours: { monday: "No information", tuesday: "No information", wednesday: "No information", thursday: "No information", friday: "No information", saturday: "No information", sunday: "No information" },
        place_media: { 
          thumbnail: "/images/places/ChIJGlTpiKNreBsUwZ1FnbVjL7q.jpg", 
          photos: ["/images/places/ChIJGlTpiKNreBsUwZ1FnbVjL7q.jpg", "https://gtwhi.com.my/wp-content/uploads/2019/04/Koong-Har-Tong-Wong-Si-Chong-Chi-e1554191547291.jpg"] 
        }
      },
      {
        name: "Koo Saing Wooi Koon",
        place_category: "clan houses",
        place_address: "67, Lebuh King, 10200 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.3395, 5.4175] },
        place_summary: "Dating back to 1872, this is believed to be the oldest combined-clan temple in Malaysia. Uniquely, it does not serve one surname, but four: Lau, Kuan, Teoh, and Teo. Fun fact: The association's name is inspired by the famous classic novel 'Romance of the Three Kingdoms', celebrating the legendary brotherhood and loyalty sworn by Liu Bei (Lau), Guan Yu (Kuan), and Zhang Fei (Teoh) at the Peach Garden.",
        place_information: { rating: 3.8, reviews_count: 6, price_level: "N/A", phone: "+604-261 7886", website: "" },
        place_business_hours: { monday: "No information", tuesday: "No information", wednesday: "No information", thursday: "No information", friday: "No information", saturday: "No information", sunday: "No information" },
        place_media: { 
          thumbnail: "/images/places/ChIJQODqAM4Hp5Zquyb0i2ZAN1C.jpg", 
          photos: ["/images/places/ChIJQODqAM4Hp5Zquyb0i2ZAN1C.jpg", "https://gtwhi.com.my/wp-content/uploads/2019/04/Koo-Saing-Wooi-Koon-1-e1554858377956.jpg"] 
        }
      },
      {
        name: "Kew Leong Tong Lim Kongsi",
        place_category: "clan houses",
        place_address: "Lebuh Ah Quee, George Town, 10450 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.3382, 5.4158] },
        place_summary: "Established in 1863, this is the main clan house for the Lim family, one of the two most common surnames in Penang. Fun fact: The name 'Kew Leong Tong' translates to 'Hall of the Nine Dragons'. It honors an ancient Lim ancestor from the Tang Dynasty whose nine sons were all promoted to the position of chief magistrates!",
        place_information: { rating: 5.0, reviews_count: 1, price_level: "N/A", phone: "", website: "" },
        place_business_hours: { monday: "No information", tuesday: "No information", wednesday: "No information", thursday: "No information", friday: "No information", saturday: "No information", sunday: "No information" },
        place_media: { 
          thumbnail: "/images/places/ChIJJ3VKOkbKVmpb7QY5EaYRK1x.jpg", 
          photos: ["/images/places/ChIJJ3VKOkbKVmpb7QY5EaYRK1x.jpg", "https://gtwhi.com.my/wp-content/uploads/2019/04/Kew-Leong-Tong-Lim-Kongsi_2-e1554191490950.jpg"] 
        }
      },
      {
        name: "Har Yang Sit Teik Tong Yeoh Kongsi",
        place_category: "clan houses",
        place_address: "3, Chulia St Ghaut, 10200 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.3398, 5.4155] },
        place_summary: "Founded in 1836, this is one of Penang's 'Big Five' Hokkien clan associations. The current temple was built in 1841. Fun fact: When it was first built, the temple sat right on the waterfront and even possessed its own private jetty! Land reclamation in the late 19th century eventually pushed the shoreline further out, creating Victoria Street in front of it.",
        place_information: { rating: 5.0, reviews_count: 1, price_level: "N/A", phone: "+60 11-1223 3990", website: "" },
        place_business_hours: { monday: "Closed", tuesday: "Closed", wednesday: "8 am-9 am", thursday: "8 am-9 am", friday: "Closed", saturday: "Closed", sunday: "Closed" },
        place_media: { 
          thumbnail: "/images/places/ChIJtaASHQ8oBa877WVb53Mit5n.jpg", 
          photos: ["/images/places/ChIJtaASHQ8oBa877WVb53Mit5n.jpg", "https://gtwhi.com.my/wp-content/uploads/2019/04/Har-Yang-Sit-Teik-Tong-Yeoh-Kongsi-e1554191238714.jpg"] 
        }
      },
      {
        name: "Eng Chuan Tong Tan Kongsi",
        place_category: "clan houses",
        place_address: "28, Seh Tan Court, Beach Street, 10300 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.3363, 5.4131] },
        place_summary: "Founded in the early 19th century by the Tan family from Zhangzhou, this is claimed to be the oldest clan house in Penang. The main structure standing today was erected in 1878. Fun fact: The temple is devoted to Kai Zhang Sheng Wang (Tan Goan-kong), a famous Tang dynasty general who founded Zhangzhou. In the early 1900s, it also housed a school that taught Confucian classics.",
        place_information: { rating: 4.5, reviews_count: 203, price_level: "N/A", phone: "", website: "" },
        place_business_hours: { monday: "9 am–5 pm", tuesday: "9 am–5 pm", wednesday: "9 am–5 pm", thursday: "9 am–5 pm", friday: "9 am–5 pm", saturday: "Closed", sunday: "Closed" },
        place_media: { 
          thumbnail: "/images/places/ChIJLQUtqmGIaajhROgTm6Re28V.jpg", 
          photos: ["/images/places/ChIJLQUtqmGIaajhROgTm6Re28V.jpg"] 
        }
      },
      {
        name: "Chin Si Thoong Soo",
        place_category: "clan houses",
        place_address: "64, Lebuh King, 10200 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.3394, 5.4175] },
        place_summary: "Located on King Street, Chin Si Thoong Soo is the ancestral temple representing the Chin (or Chen) clan. King Street is famous for housing multiple clan and district associations back to back. Fun fact: Because so many clan houses and temples are squeezed onto this street, local Hokkiens used to refer to different sections of King Street by different dialect nicknames based on which clan dominated that block.",
        place_information: { rating: 5.0, reviews_count: 6, price_level: "N/A", phone: "", website: "" },
        place_business_hours: { monday: "No information", tuesday: "No information", wednesday: "No information", thursday: "No information", friday: "No information", saturday: "No information", sunday: "No information" },
        place_media: { 
          thumbnail: "/images/places/ChIJovpESLAuXhHs2XmXyxZHXae.jpg", 
          photos: ["/images/places/ChIJovpESLAuXhHs2XmXyxZHXae.jpg", "https://gtwhi.com.my/wp-content/uploads/2019/04/Chin-Si-Thoong-Soo-e1554191429790.jpg"] 
        }
      },
      {
        name: "Boon San Tong Khoo Kongsi",
        place_category: "clan houses",
        place_address: "117-A, Lebuh Victoria, 10300 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.3377, 5.4136] },
        place_summary: "Built in 1878, Boon San Tong is the lesser-known 'brother' to the magnificent Leong San Tong Khoo Kongsi. It is one of the two ancestral temples belonging to the Khoo clan in Penang. Fun fact: While Leong San Tong was built for the entire Khoo clan, Boon San Tong was specifically built as a sub-clan house for a specific branch of the Khoo family, demonstrating the immense wealth and complex hierarchy of the Khoos in the 19th century.",
        place_information: { rating: 4.5, reviews_count: 65, price_level: "N/A", phone: "04-261 7054", website: "" },
        place_business_hours: { monday: "9:30 am–4:30 pm", tuesday: "9:30 am–4:30 pm", wednesday: "9:30 am–4:30 pm", thursday: "9:30 am–4:30 pm", friday: "9:30 am–4:30 pm", saturday: "9:30 am–4:30 pm", sunday: "9:30 am–4:30 pm" },
        place_media: { 
          thumbnail: "/images/places/ChIJce2zBaASpxxqUVEEDdVkRlQ.jpg", 
          photos: ["/images/places/ChIJce2zBaASpxxqUVEEDdVkRlQ.jpg", "https://travel2penang.org/wp-content/uploads/2022/04/Khoo-Kongsi-Boon-San-Tong-Kho-768x1024.jpg"] 
        }
      }
    ];

    let updatedCount = 0;
    let insertedCount = 0;

    for (const place of placesData) {
      // 1. 结构化营业时间
      const openingHours = { is_24_hours: false };
      const days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
      for (const day of days) {
        openingHours[day] = parseDaySchedule(place.place_business_hours[day]);
      }
      const rawHoursText = formatReadableHours(place.place_business_hours);

      // 2. 搜索关键词
      const cleanName = place.name.toLowerCase();
      const searchKeywords = Array.from(new Set([
        cleanName,
        'clan houses',
        'clan house',
        'kongsi',
        'clan temple',
        'ancestral temple',
        'heritage & culture',
        'heritage',
        'george town',
        ...cleanName.replace(/[()]/g, ' ').split(/\s+/).filter(w => w.length > 2)
      ]));

      // 3. 查找现有记录以保留高价值元数据 (如 external_place_id, streetView, 评分等)
      const existing = await PlaceNew.findOne({ name: place.name });

      const finalRating = existing && existing.rating > 0 
        ? Math.max(existing.rating, place.place_information.rating || 0)
        : (place.place_information.rating || 4.5);

      const finalReviewsCount = existing && existing.review_count > 0
        ? Math.max(existing.review_count, place.place_information.reviews_count || 0)
        : (place.place_information.reviews_count || 0);

      const thumbnail = place.place_media.thumbnail;

      const updateDoc = {
        name: place.name,
        primary_category: 'Heritage & Culture',
        sub_categories: ['Clan Houses', 'Clan House', 'Kongsi', 'Heritage & Culture'],
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

      const result = await PlaceNew.updateOne(
        { name: place.name },
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
    console.log("----- 宗祠数据同步到 places_new 完成 -----");
    console.log(`总计处理: ${placesData.length} 个宗祠`);
    console.log(`✅ 新增数量: ${insertedCount} 个`);
    console.log(`🔄 更新数量: ${updatedCount} 个`);
    console.log("========================================\n");

  } catch (error) {
    console.error("执行时发生错误:", error);
  } finally {
    await mongoose.connection.close();
  }
}

// 允许命令行直接执行: node seedClanHouses.js
if (require.main === module) {
  seedClanHouses();
}

module.exports = seedClanHouses;