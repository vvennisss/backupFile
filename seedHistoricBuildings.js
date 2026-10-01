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
  if (/open 24 hours/i.test(clean)) {
    return { is_closed: false, open: '00:00', close: '23:59' };
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

async function seedHistoricBuildings() {
  if (!MONGO_URI) {
    console.error("错误: 找不到 MongoDB URI，请检查环境变量。");
    return;
  }

  try {
    await mongoose.connect(MONGO_URI);
    console.log("✅ 成功连接到 MongoDB");

    const placesData = [
      {
        name: "Syed Alatas Mansion",
        place_category: "historic buildings",
        place_address: "128, Lebuh Armenian, 10200 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.3371, 5.4154] },
        place_summary: "Built in the 1860s, this is a rare surviving mid-19th century Muslim bungalow. It was the residence of Syed Mohamed Alatas, a wealthy Acehnese merchant and leader of the Red Flag secret society. Fun fact: The mansion blends Islamic, European, and Indian architectural styles, and was heavily involved in the 1867 Penang Riots between rival secret societies.",
        place_information: { rating: 3.7, reviews_count: 15, price_level: "N/A", phone: "", website: "" },
        place_business_hours: { monday: "No Information", tuesday: "No Information", wednesday: "No Information", thursday: "No Information", friday: "No Information", saturday: "No Information", sunday: "No Information" },
        place_media: { 
          thumbnail: "/images/places/ChIJH4tRXMUfYOohCX9CTEsq4dz.jpg", 
          photos: ["/images/places/ChIJH4tRXMUfYOohCX9CTEsq4dz.jpg", "https://gtwhi.com.my/wp-content/uploads/2019/04/Syed-Alatas-Mansion-e1554188536288.jpg", "/images/places/Syed Alatas Mansion.jpg"] 
        }
      },
      {
        name: "Standard Chartered Building",
        place_category: "historic buildings",
        place_address: "2, Lebuh Pantai, 10300 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.3421, 5.4172] },
        place_summary: "This imposing Palladian-style building on Beach Street was constructed in 1930 to house the Standard Chartered Bank. Fun fact: Standard Chartered was the very first bank to open a branch in Penang back in 1875 to finance the booming tin and rubber trades. Its massive columns and sturdy design were meant to project financial invulnerability.",
        place_information: { rating: 4.2, reviews_count: 25, price_level: "N/A", phone: "", website: "" },
        place_business_hours: { monday: "Permanently closed", tuesday: "Permanently closed", wednesday: "Permanently closed", thursday: "Permanently closed", friday: "Permanently closed", saturday: "Permanently closed", sunday: "Permanently closed" },
        place_media: { 
          thumbnail: "/images/places/ChIJ6QWl78m1gg4D0ymqtL7Mn5D.jpg", 
          photos: ["/images/places/ChIJ6QWl78m1gg4D0ymqtL7Mn5D.jpg", "https://gtwhi.com.my/wp-content/uploads/2019/04/Standard-Chartered-Bank-e1554188815756.jpg", "/images/places/Standard Chartered Building.jpg"] 
        }
      },
      {
        name: "Poe Choo Seah",
        place_category: "historic buildings",
        place_address: "51, King Street, George Town, 10200 George Town, Pulau Pinang, Malaysia",
        place_location: { type: "Point", coordinates: [100.3392, 5.4184] },
        place_summary: "A historical association building in George Town that historically served parts of the Chinese community. Fun fact: Associations like Poe Choo Seah were pivotal in the 19th and early 20th centuries, functioning as social clubs, welfare centers, and hubs for religious festivals for the Straits Chinese and early immigrants in the bustling port city.",
        place_information: { rating: 4.3, reviews_count: 7, price_level: "N/A", phone: "+6011-2386 3015", website: "" },
        place_business_hours: { monday: "No Information", tuesday: "No Information", wednesday: "No Information", thursday: "No Information", friday: "No Information", saturday: "No Information", sunday: "No Information" },
        place_media: { 
          thumbnail: "/images/places/ChIJ382KNu9bWtnmsscd2zGATmf.jpg", 
          photos: ["/images/places/ChIJ382KNu9bWtnmsscd2zGATmf.jpg", "https://gtwhi.com.my/wp-content/uploads/2019/04/Poe-Choo-Seah-e1554189105611.jpg", "/images/places/Poe Choo Seah.jpg"] 
        }
      },
      {
        name: "Pinang Peranakan Mansion",
        place_category: "historic buildings",
        place_address: "29, Church St, 10200 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.3406, 5.4178] },
        place_summary: "A stunning recreation of a typical wealthy 19th-century Baba Nyonya (Peranakan) home, filled with over 1,000 antiques. Fun fact: The mansion didn't originally belong to a Peranakan! It was built by Kapitan Cina Chung Keng Quee, a Hakka secret society leader who loved the Straits Chinese architectural style so much he built his home in it. It famously featured in the TV series 'The Little Nyonya'.",
        place_information: { rating: 4.5, reviews_count: 6456, price_level: "RM 18 - 30", phone: "+60 4-264 2929", website: "http://www.pinangperanakanmansion.com.my/" },
        place_business_hours: { monday: "9:30 am–5:30 pm", tuesday: "9:30 am–5:30 pm", wednesday: "9:30 am–5:30 pm", thursday: "9:30 am–5:30 pm", friday: "9:30 am–5:30 pm", saturday: "9:30 am–5:30 pm", sunday: "9:30 am–5:30 pm" },
        place_media: { 
          thumbnail: "/images/places/Pinang Peranakan Mansion.jpg", 
          photos: ["/images/places/Pinang Peranakan Mansion.jpg", "/images/places/ChIJCWvz3I_DSjAR5hveCXjdfIs.jpg"] 
        }
      },
      {
        name: "Penang Town Hall",
        place_category: "historic buildings",
        place_address: "Lot 70, Jalan Padang Kota Lama, 10200 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.3401, 5.4215] },
        place_summary: "Completed in the 1880s, this yellow-and-white British administrative building served as a premier social venue for the colonial elite. Fun fact: In 1906, it became the very first building in Penang to be fitted with electric lights! It was also featured in the 1999 Hollywood film 'Anna and the King'.",
        place_information: { rating: 4.5, reviews_count: 237, price_level: "N/A", phone: "", website: "" },
        place_business_hours: { monday: "No Information", tuesday: "No Information", wednesday: "No Information", thursday: "No Information", friday: "No Information", saturday: "No Information", sunday: "No Information" },
        place_media: { 
          thumbnail: "/images/places/ChIJj1PCd7cdf0j8D2SUPW4fbbB.jpg", 
          photos: ["/images/places/ChIJj1PCd7cdf0j8D2SUPW4fbbB.jpg", "https://gtwhi.com.my/wp-content/uploads/2019/04/Penang-Town-Hall-e1554188948622.jpg"] 
        }
      },
      {
        name: "Penang State Museum @ Farquhar",
        place_category: "historic buildings",
        place_address: "Lebuh Farquhar, 10450 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.3381, 5.4213] },
        place_summary: "Housed in the former Penang Free School building (built in 1821), this museum showcases the diverse history and cultures of Penang. Fun fact: If you look closely at the building, it seems asymmetrical. That's because the entire right wing of the building was destroyed by Allied bombing during World War II and was never rebuilt!",
        place_information: { rating: 3.8, reviews_count: 404, price_level: "RM 1.00", phone: "+6 04-226 1439", website: "penangmuseum.gov.my" },
        place_business_hours: { monday: "9 am–5 pm", tuesday: "9 am–5 pm", wednesday: "9 am–5 pm", thursday: "9 am–5 pm", friday: "Closed", saturday: "9 am–5 pm", sunday: "9 am–5 pm" },
        place_media: { 
          thumbnail: "/images/places/ChIJpbeveSU51Dwi67LtewPPiul.jpg", 
          photos: ["/images/places/ChIJpbeveSU51Dwi67LtewPPiul.jpg", "https://gtwhi.com.my/wp-content/uploads/2019/04/Penang-State-Museum-@-Farquhar-e1554860434386.jpg"] 
        }
      },
      {
        name: "Penang State Assembly Building",
        place_category: "historic buildings",
        place_address: "Lebuh Light, 10200 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.3392, 5.4208] },
        place_summary: "Featuring striking Anglo-Indian classical architecture, this building currently houses the Penang State Legislative Assembly. It was originally built in the 19th century. Fun fact: Before becoming the seat of the state government, this building functioned as the Recorder's Court and the Police Court, where some of Penang's most notorious early criminals were tried.",
        place_information: { rating: 4.4, reviews_count: 13, price_level: "N/A", phone: "+6 04-261 1955", website: "" },
        place_business_hours: { monday: "No Information", tuesday: "No Information", wednesday: "No Information", thursday: "No Information", friday: "No Information", saturday: "No Information", sunday: "No Information" },
        place_media: { 
          thumbnail: "/images/places/ChIJ8adDSRxQir9eqaUQkG3EnqX.jpg", 
          photos: ["/images/places/ChIJ8adDSRxQir9eqaUQkG3EnqX.jpg", "https://gtwhi.com.my/wp-content/uploads/2019/04/Penang-State-Assembly-Building-e1554188345474.jpg"] 
        }
      },
      {
        name: "Penang High Court",
        place_category: "historic buildings",
        place_address: "2, Lebuh Light, 10200 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.3398, 5.4206] },
        place_summary: "A magnificent Palladian-style building opened in 1903, serving as the highest court in Penang. Fun fact: The current building replaced the original 1809 courthouse on the same site. During its construction, Logan's Monument had to be relocated to its current spot to make way for this massive judicial complex.",
        place_information: { rating: 3.6, reviews_count: 20, price_level: "N/A", phone: "+604-251 4000", website: "" },
        place_business_hours: { monday: "No Information", tuesday: "No Information", wednesday: "No Information", thursday: "No Information", friday: "No Information", saturday: "No Information", sunday: "No Information" },
        place_media: { 
          thumbnail: "/images/places/ChIJoK3nkUfrTT4CNE6EFkAgPoI.jpg", 
          photos: ["/images/places/ChIJoK3nkUfrTT4CNE6EFkAgPoI.jpg", "https://gtwhi.com.my/wp-content/uploads/2019/04/Penang-High-Court-e1554188630535.jpg"] 
        }
      },
      {
        name: "Penang City Hall",
        place_category: "historic buildings",
        place_address: "Jalan Padang Kota Lama, 10200 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.3408, 5.4218] },
        place_summary: "Built in 1903 in a grand Edwardian Baroque style, this pristine white building sits proudly beside the Esplanade. It houses the Penang Island City Council. Fun fact: It was built mainly because the adjacent Town Hall had become too cramped and noisy for municipal office work. A monument to the victims of World War I stands directly in front of it.",
        place_information: { rating: 4.3, reviews_count: 265, price_level: "N/A", phone: "+604- 263 8818", website: "" },
        place_business_hours: { monday: "8 am–5 pm", tuesday: "8 am–5 pm", wednesday: "8 am–5 pm", thursday: "8 am–5 pm", friday: "8 am–5 pm", saturday: "Closed", sunday: "Closed" },
        place_media: { 
          thumbnail: "/images/places/ChIJPs2922VFBExuruAUwdgYVS3.jpg", 
          photos: ["/images/places/ChIJPs2922VFBExuruAUwdgYVS3.jpg", "https://gtwhi.com.my/wp-content/uploads/2019/04/Penang-Town-Hall-e1554188948622.jpg"] 
        }
      },
      {
        name: "Masjid Nagore Dargah Sheriff",
        place_category: "historic buildings",
        place_address: "68, Lebuh Chulia, 10200 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.3354, 5.4168] },
        place_summary: "Built in the early 1800s by the Chulia (Indian Muslim) community, this uniquely structured shrine is dedicated to Syed Abdul Kadir, a revered saint from Nagore, India. Fun fact: The architecture of the shrine is highly unusual for Penang, heavily influenced by Southern Indian styles without a dome, featuring instead a striking, multi-tiered square minaret with arched windows.",
        place_information: { rating: 4.7, reviews_count: 42, price_level: "N/A", phone: "", website: "" },
        place_business_hours: { monday: "No Information", tuesday: "No Information", wednesday: "No Information", thursday: "No Information", friday: "No Information", saturday: "No Information", sunday: "No Information" },
        place_media: { 
          thumbnail: "/images/places/ChIJLhTIxgRvZ3HOTUk3kiHci40.jpg", 
          photos: ["/images/places/ChIJLhTIxgRvZ3HOTUk3kiHci40.jpg", "https://gtwhi.com.my/wp-content/uploads/2019/04/Nagore-Durgha-Shrine-e1554188283619.jpg", "/images/places/Nagore Durgha Shrine.jpg"] 
        }
      },
      {
        name: "Meng Eng Soo Temple 名英祠",
        place_category: "historic buildings",
        place_address: "48, Jalan Pintal Tali (Rope Walk), 10100 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.3338, 5.4165] },
        place_summary: "Built in 1890, this temple serves as a memorial hall for early Chinese pioneers and heroes. Fun fact: Behind its peaceful exterior lies a violent history. Meng Eng Soo was originally the headquarters of the notorious Ghee Hin secret society! When the British banned secret societies in 1890, the society handed over its property to a board of trustees, transforming its headquarters into this memorial temple.",
        place_information: { rating: 4.5, reviews_count: 26, price_level: "N/A", phone: "", website: "" },
        place_business_hours: { monday: "No Information", tuesday: "No Information", wednesday: "No Information", thursday: "No Information", friday: "No Information", saturday: "No Information", sunday: "No Information" },
        place_media: { 
          thumbnail: "/images/places/ChIJWwbaoxiEnmZEc8Pi125a4rP.jpg", 
          photos: ["/images/places/ChIJWwbaoxiEnmZEc8Pi125a4rP.jpg", "https://gtwhi.com.my/wp-content/uploads/2019/04/Meng-Eng-Soo-Temple-e1554189049829.jpg"] 
        }
      },
      {
        name: "Malayan Railway Building",
        place_category: "historic buildings",
        place_address: "10, Gat Lebuh China, 10300 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.3428, 5.4156] },
        place_summary: "Built in the early 1900s, this massive colonial building with its prominent clock tower served as the Federated Malay States (FMS) Railway Station. Fun fact: It was arguably the only railway station in the world where no trains actually stopped! Passengers would buy their train tickets here, then board a ferry across the strait to Butterworth to catch their actual train.",
        place_information: { rating: 4.0, reviews_count: 1, price_level: "N/A", phone: "", website: "" },
        place_business_hours: { monday: "No Information", tuesday: "No Information", wednesday: "No Information", thursday: "No Information", friday: "No Information", saturday: "No Information", sunday: "No Information" },
        place_media: { 
          thumbnail: "/images/places/ChIJM0IBc8A2q4DDnSIHfJeCOk8.jpg", 
          photos: ["/images/places/ChIJM0IBc8A2q4DDnSIHfJeCOk8.jpg", "https://gtwhi.com.my/ms/wp-content/uploads/2019/04/Malayan-Railway-Building-e1554860308326.jpg", "/images/places/Malayan Railway Building.jpg"] 
        }
      },
      {
        name: "India House",
        place_category: "historic buildings",
        place_address: "Gat Lebuh Gereja, George Town, 10200 George Town, Pulau Pinang, Malaysia",
        place_location: { type: "Point", coordinates: [100.3420, 5.4169] },
        place_summary: "A beautiful Art Deco building constructed in 1937, featuring distinct Indian architectural motifs. It was originally an office for the Indian chettiars (money lenders). Fun fact: During the Japanese occupation of Penang in World War II, India House was taken over and used as the headquarters for the Hong Kong and Shanghai Banking Corporation.",
        place_information: { rating: 4.3, reviews_count: 11, price_level: "N/A", phone: "", website: "" },
        place_business_hours: { monday: "No Information", tuesday: "No Information", wednesday: "No Information", thursday: "No Information", friday: "No Information", saturday: "No Information", sunday: "No Information" },
        place_media: { 
          thumbnail: "/images/places/ChIJMBq1Oa5O8HN0rwswnkYYnY4.jpg", 
          photos: ["/images/places/ChIJMBq1Oa5O8HN0rwswnkYYnY4.jpg", "https://gtwhi.com.my/wp-content/uploads/2019/04/India-House-e1554188715912.jpg", "/images/places/India House.jpg"] 
        }
      },
      {
        name: "Government House",
        place_category: "historic buildings",
        place_address: "Jalan Residency, 10450 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.3389, 5.42273] },
        place_summary: "Known today as Seri Mutiara, this grand colonial mansion was completed in 1890 to serve as the official residence of the British Resident Councillor. Fun fact: It has survived multiple regime changes and bombings. Today, it serves as the official residence of the Governor (Yang di-Pertua Negeri) of Penang and remains highly guarded, opening to the public only on rare special occasions.",
        place_information: { rating: 4.2, reviews_count: 65, price_level: "N/A", phone: "", website: "" },
        place_business_hours: { monday: "No Information", tuesday: "No Information", wednesday: "No Information", thursday: "No Information", friday: "No Information", saturday: "No Information", sunday: "No Information" },
        place_media: { 
          thumbnail: "/images/places/ChIJR292ZXJubWVudCBIb3Vz.jpg", 
          photos: ["/images/places/ChIJR292ZXJubWVudCBIb3Vz.jpg", "https://gtwhi.com.my/wp-content/uploads/2019/04/Government-House-e1554188064984.jpg"] 
        }
      },
      {
        name: "George Town Dispensary",
        place_category: "historic buildings",
        place_address: "39, Lebuh Pantai, 10300 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.3418, 5.4170] },
        place_summary: "Built in 1923, this striking corner building was once one of the earliest and most prominent modern dispensaries and pharmacies in Penang. Fun fact: In the early 20th century, European and wealthy local elites relied heavily on this dispensary for imported medicines. Although it has since closed, its beautiful arcades and colonial façade make it a favorite subject for urban sketchers.",
        place_information: { rating: 4.3, reviews_count: 6, price_level: "N/A", phone: "", website: "" },
        place_business_hours: { monday: "No Information", tuesday: "No Information", wednesday: "No Information", thursday: "No Information", friday: "No Information", saturday: "No Information", sunday: "No Information" },
        place_media: { 
          thumbnail: "/images/places/ChIJllp2iJg7rNGxMtazJyfvM4q.jpg", 
          photos: ["/images/places/ChIJllp2iJg7rNGxMtazJyfvM4q.jpg", "https://gtwhi.com.my/wp-content/uploads/2019/04/George-Town-Dispensary-e1554188110558.jpg"] 
        }
      },
      {
        name: "Dato Koyah Shrine",
        place_category: "historic buildings",
        place_address: "Jalan Dato Koyah, 10050 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.3315, 5.4200] },
        place_summary: "A small but highly significant shrine built in the 1840s. It is dedicated to Syed Mustapha Idris (Dato Koyah), a revered holy man from Malabar. Fun fact: Dato Koyah was greatly respected by the Indian Muslim convict laborers brought in by the British. Legend has it that he possessed healing powers and provided spiritual comfort to the convicts building the early infrastructure of George Town.",
        place_information: { rating: 4.2, reviews_count: 10, price_level: "N/A", phone: "+6019- 478 7293", website: "https://mypenang.gov.my/all/directory/388/?lg=en" },
        place_business_hours: { monday: "Open 24 hours", tuesday: "Open 24 hours", wednesday: "Open 24 hours", thursday: "Open 24 hours", friday: "Open 24 hours", saturday: "Open 24 hours", sunday: "Open 24 hours" },
        place_media: { 
          thumbnail: "/images/places/ChIJjfrNmyI2Yp3qd2o5eCTEaMq.jpg", 
          photos: ["/images/places/ChIJjfrNmyI2Yp3qd2o5eCTEaMq.jpg", "https://gtwhi.com.my/wp-content/uploads/2019/04/Dato-Koyah-Shrine.jpg"] 
        }
      },
      {
        name: "Convent Light Street School",
        place_category: "historic buildings",
        place_address: "Lebuh Light, 10200 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.3385, 5.4221] },
        place_summary: "Founded in 1852 by the Sisters of the Holy Infant Jesus, this is the oldest girls' school in Southeast Asia. It boasts beautiful Anglo-French architecture. Fun fact: During World War II, this prestigious girls' school was seized and utilized by the Japanese Navy as a base. It famously sits adjacent to Government House, originally the home of Captain Francis Light, founder of modern Penang.",
        place_information: { rating: 4.4, reviews_count: 50, price_level: "N/A", phone: "+604-263 3894", website: "" },
        place_business_hours: { monday: "No Information", tuesday: "No Information", wednesday: "No Information", thursday: "No Information", friday: "No Information", saturday: "No Information", sunday: "No Information" },
        place_media: { 
          thumbnail: "/images/places/ChIJS4EXVrsmWfc4ia9bCyLabYP.jpg", 
          photos: ["/images/places/ChIJS4EXVrsmWfc4ia9bCyLabYP.jpg", "https://gtwhi.com.my/wp-content/uploads/2019/04/Convent-Light-Street-School-e1554187868681.jpg"] 
        }
      },
      {
        name: "Cheong Fatt Tze Mansion (Blue Mansion)",
        place_category: "historic buildings",
        place_address: "14, Leith St, 10200 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.3340, 5.4215] },
        place_summary: "Built in the 1880s by the powerful Hakka merchant Cheong Fatt Tze, this 38-room mansion is famous for its striking indigo-blue exterior and immaculate Feng Shui. Fun fact: It is one of the only three traditional Chinese mansions of its kind left in the world outside China! It was famously used as the iconic Mahjong scene location in the Hollywood blockbuster 'Crazy Rich Asians'.",
        place_information: { rating: 4.4, reviews_count: 5577, price_level: "RM 12.50 - 25", phone: "+60 4-262 0006", website: "https://www.cheongfatttzemansion.com/thebluemansion/discover/daily-tours/" },
        place_business_hours: { monday: "11 am–6 pm", tuesday: "11 am–6 pm", wednesday: "11 am–6 pm", thursday: "11 am–6 pm", friday: "11 am–6 pm", saturday: "11 am–6 pm", sunday: "11 am–6 pm" },
        place_media: { 
          thumbnail: "/images/places/Cheong Fatt Tze Mansion.jpg", 
          photos: ["/images/places/Cheong Fatt Tze Mansion.jpg", "/images/places/ChIJf8OLYcor7HPLbFvj0vXMybN.jpg"] 
        }
      },
      {
        name: "Central Fire Station (Lebuh Pantai Fire Station)",
        place_category: "historic buildings",
        place_address: "Lebuh Pantai, 10300 George Town, Penang, Malaysia",
        place_location: { type: "Point", coordinates: [100.3390, 5.4140] },
        place_summary: "Built in 1908, this striking red-and-white colonial building is the oldest active fire station in Penang. Fun fact: It features a distinctive four-story watchtower. Before the invention of modern telecommunications, firemen had to take shifts standing at the top of this tower, scanning the skyline of George Town day and night for any signs of smoke!",
        place_information: { rating: 4.7, reviews_count: 116, price_level: "N/A", phone: "+60 4-261 4444", website: "" },
        place_business_hours: { monday: "8 am–5 pm", tuesday: "8 am–5 pm", wednesday: "8 am–5 pm", thursday: "8 am–5 pm", friday: "8 am–5 pm", saturday: "8 am–5 pm", sunday: "8 am–5 pm" },
        place_media: { 
          thumbnail: "/images/places/ChIJISGlQLrJ1wld3NLSPQzPLsr.jpg", 
          photos: ["/images/places/ChIJISGlQLrJ1wld3NLSPQzPLsr.jpg", "https://gtwhi.com.my/wp-content/uploads/2019/04/Central-Fire-Station-Lebuh-Pantai-Fire-Station-e1554187771746.jpg", "/images/places/Central Fire Station (Lebuh Pantai Fire Station).jpg"] 
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
        'historic buildings',
        'historic building',
        'heritage & culture',
        'heritage',
        'colonial building',
        'george town',
        ...cleanName.replace(/[()（）@]/g, ' ').split(/\s+/).filter(w => w.length > 1)
      ]));

      // 寻找现有地点 (兼容 Seri Mutiara 等别名)
      const existing = await PlaceNew.findOne({
        $or: [
          { name: place.name },
          { name: engName },
          { name: new RegExp('^' + engName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'i') },
          ...(place.name === 'Government House' ? [{ name: /Seri Mutiara/i }] : [])
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
        sub_categories: ['Historic Buildings', 'Historic Building', 'Heritage & Culture'],
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
    console.log("----- 历史建筑数据同步到 places_new 完成 -----");
    console.log(`总计处理: ${placesData.length} 座历史建筑`);
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
  seedHistoricBuildings();
}

module.exports = seedHistoricBuildings;