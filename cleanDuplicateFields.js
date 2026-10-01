const mongoose = require('mongoose');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

const MONGODB_URI = process.env.MONGODB_URI;

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
  if (!hourStr || typeof hourStr !== 'string') return null;
  const clean = hourStr.replace(/[\u202f\u00a0]/g, ' ').trim();
  if (/closed/i.test(clean)) {
    return { is_closed: true, open: '00:00', close: '00:00' };
  }
  if (/open 24 hours/i.test(clean)) {
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
  return null;
}

function formatReadableHours(businessHours, openingHours) {
  if (businessHours && typeof businessHours === 'object' && Object.keys(businessHours).length > 0) {
    const days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    
    const cleaned = days.map(d => (businessHours[d] ? businessHours[d].replace(/[\u202f\u00a0]/g, ' ').replace(/\s*[–\-]\s*/g, ' – ').trim() : ''));
    const valid = cleaned.filter(Boolean);
    
    if (valid.length > 0 && new Set(valid).size === 1) {
      return `Mon–Sun: ${valid[0]}`;
    }
    
    const weekdaySet = new Set(cleaned.slice(0, 5).filter(Boolean));
    const weekendSet = new Set(cleaned.slice(5).filter(Boolean));
    if (weekdaySet.size === 1 && weekendSet.size === 1) {
      const wd = [...weekdaySet][0];
      const we = [...weekendSet][0];
      if (wd === we) return `Mon–Sun: ${wd}`;
      return `Mon–Fri: ${wd}; Sat–Sun: ${we}`;
    }

    const summary = days.map((d, i) => `${dayLabels[i]}: ${cleaned[i] || 'Closed'}`).join(', ');
    return summary;
  }

  if (openingHours && typeof openingHours === 'object') {
    if (openingHours.is_24_hours) return 'Open 24 hours';
    const m = openingHours.monday;
    if (m && !m.is_closed && m.open && m.close) {
      return `Mon–Sun: ${m.open} – ${m.close}`;
    }
  }

  return '10:00 AM – 10:00 PM';
}

async function cleanCollection() {
  try {
    console.log('🔄 Connecting to MongoDB Atlas...');
    await mongoose.connect(MONGODB_URI);
    console.log('✅ Connected successfully!');

    const db = mongoose.connection.db;
    const col = db.collection('places_new');

    const totalDocs = await col.countDocuments();
    console.log(`📦 Total documents in places_new: ${totalDocs}`);

    const cursor = col.find({});
    let batch = [];
    let processed = 0;
    const batchSize = 200;

    while (await cursor.hasNext()) {
      const doc = await cursor.next();

      const name = (doc.name || doc.place_name || 'Penang Place').trim();
      const address = (doc.address || doc.place_address || '').trim();
      const primaryCategory = (doc.primary_category || doc.place_category || 'Others').trim();
      const location = (doc.location?.coordinates && doc.location.coordinates.length === 2 && doc.location.coordinates[0] !== 0)
        ? doc.location
        : (doc.place_location || { type: 'Point', coordinates: [100.3327, 5.4164] });
      const geofenceRadius = doc.geofence_radius || doc.place_geofence_radius || 50;
      const summary = (doc.summary && doc.summary.trim()) || (doc.place_summary && doc.place_summary.trim()) || (doc.description && doc.description.trim()) || '';
      const description = (doc.description && doc.description.trim()) || summary;
      const hasStreetView = Boolean(doc.hasStreetView !== undefined ? doc.hasStreetView : doc.has_street_view);
      const mapillaryImageId = doc.mapillaryImageId || doc.mapillary_image_id || null;
      const thumbnail = doc.place_media?.thumbnail || doc.cover_image || '';
      const rating = doc.rating || doc.place_information?.rating || 4.5;
      const reviewCount = doc.review_count || doc.place_information?.reviews_count || 0;

      // Fix raw_hours_text & opening_hours
      let rawHoursText = doc.raw_hours_text;
      let openingHours = doc.opening_hours || { is_24_hours: false };

      if (doc.place_business_hours && typeof doc.place_business_hours === 'object' && Object.keys(doc.place_business_hours).length > 0) {
        const days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
        for (const day of days) {
          const dayStr = doc.place_business_hours[day];
          if (dayStr) {
            const parsed = parseDaySchedule(dayStr);
            if (parsed) {
              openingHours[day] = parsed;
            }
          }
        }
      }

      if (!rawHoursText || rawHoursText === '[object Object]' || rawHoursText === 'Check online') {
        rawHoursText = formatReadableHours(doc.place_business_hours, openingHours);
      }

      const updateOp = {
        updateOne: {
          filter: { _id: doc._id },
          update: {
            $set: {
              name,
              address,
              primary_category: primaryCategory,
              location,
              geofence_radius: geofenceRadius,
              summary,
              description,
              hasStreetView,
              mapillaryImageId,
              cover_image: thumbnail,
              'place_media.thumbnail': thumbnail,
              'place_information.rating': rating,
              'place_information.reviews_count': reviewCount,
              raw_hours_text: rawHoursText,
              opening_hours: openingHours
            },
            $unset: {
              place_name: "",
              place_address: "",
              place_category: "",
              place_location: "",
              place_geofence_radius: "",
              place_summary: "",
              has_street_view: "",
              mapillary_image_id: ""
            }
          }
        }
      };

      batch.push(updateOp);

      if (batch.length >= batchSize) {
        await col.bulkWrite(batch, { ordered: false });
        processed += batch.length;
        process.stdout.write(`\r🚀 Processed ${processed}/${totalDocs} documents...`);
        batch = [];
      }
    }

    if (batch.length > 0) {
      await col.bulkWrite(batch, { ordered: false });
      processed += batch.length;
      console.log(`\r🚀 Processed ${processed}/${totalDocs} documents...`);
    }

    console.log('\n✅ Data cleanup successfully committed to MongoDB Atlas!');

    // Clean up outdated indexes
    console.log('\n🧹 Checking and dropping redundant indexes...');
    const indexes = await col.indexes();
    const indexNames = indexes.map(i => i.name);

    if (indexNames.includes('place_location_2dsphere')) {
      await col.dropIndex('place_location_2dsphere');
      console.log('✅ Dropped redundant index: place_location_2dsphere');
    }
    if (indexNames.includes('place_category_1')) {
      await col.dropIndex('place_category_1');
      console.log('✅ Dropped redundant index: place_category_1');
    }

    // Verify sample document
    const sample = await col.findOne({ external_place_id: 'ChIJ44t014_DSjAR5P0cuMob9sM' });
    console.log('\n✨ Verified sample document (The Alley, 5 Stewart Lane):');
    console.log(JSON.stringify(sample, null, 2));

    await mongoose.disconnect();
    console.log('\n🔌 Disconnected from MongoDB.');
  } catch (error) {
    console.error('❌ Error during cleanup:', error);
    process.exit(1);
  }
}

cleanCollection();
