/**
 * Script to:
 * 1. Remove non-heritage / utility entries from 'places_new':
 *    - Klinik Kesihatan Bandar Baru Air Itam
 *    - Laundry Bar
 *    - Jeti Baru
 *    - Masjid Bandar Baru Air Itam
 *    - Pencawang Pembahagian Utama Bandar Baru Air Itam
 * 2. Update price level of "Yeng Keng Hotel Gateway" to "Free" (and price_level: 0)
 *
 * Usage:
 *   node remove_and_update_places.js
 */

const path = require('path');
const fs = require('fs');

// Helper to resolve dependencies from admin_web/node_modules
function resolveModule(moduleName) {
  try {
    return require(moduleName);
  } catch (err) {
    const adminPath = path.resolve(__dirname, 'admin_web/node_modules', moduleName);
    if (fs.existsSync(adminPath)) {
      return require(adminPath);
    }
    throw new Error(
      `Could not locate "${moduleName}". Please ensure dependencies in "admin_web" are installed (npm install).`
    );
  }
}

// Load environment variables
const dotenv = resolveModule('dotenv');
const envCandidate = path.resolve(__dirname, 'admin_web/.env');
if (fs.existsSync(envCandidate)) {
  dotenv.config({ path: envCandidate });
} else {
  dotenv.config();
}

const mongoose = resolveModule('mongoose');

const mongoUri =
  process.env.MONGODB_URI ||
  'mongodb+srv://weixun:VennisFYP2026@cluster0.tohpl4e.mongodb.net/test?appName=Cluster0';

async function main() {
  console.log('='.repeat(75));
  console.log(' 🛠️  Kia Kia Penang: Remove Places & Update Yeng Keng Hotel Gateway');
  console.log('='.repeat(75));
  console.log('Connecting to MongoDB Atlas...');

  try {
    await mongoose.connect(mongoUri, { serverSelectionTimeoutMS: 12000 });
    console.log(' Connected to MongoDB!\n');

    const db = mongoose.connection.db;
    const placesCol = db.collection('places_new');

    // =========================================================================
    // TASK 1: Remove Specified 5 Places
    // =========================================================================
    console.log('─'.repeat(75));
    console.log('📌 TASK 1: Removing 5 Non-Heritage Entries from "places_new"');
    console.log('─'.repeat(75));

    const namesToRemove = [
      'Klinik Kesihatan Bandar Baru Air Itam',
      'Laundry Bar',
      'Jeti Baru',
      'Masjid Bandar Baru Air Itam',
      'Pencawang Pembahagian Utama Bandar Baru Air Itam'
    ];

    const removeFilter = {
      name: { $in: namesToRemove.map(n => new RegExp(`^${n}$`, 'i')) }
    };

    const placesToDelete = await placesCol.find(removeFilter).toArray();
    console.log(`Found ${placesToDelete.length} matching places to remove:`);
    placesToDelete.forEach((p, idx) => {
      console.log(`  ${idx + 1}. "${p.name}" (ID: ${p._id}, Category: ${p.primary_category})`);
    });

    if (placesToDelete.length > 0) {
      const deleteResult = await placesCol.deleteMany(removeFilter);
      console.log(`\n✅ Successfully deleted ${deleteResult.deletedCount} documents from "places_new".`);
    } else {
      console.log('\n⚠️ No matching documents found to delete.');
    }

    // =========================================================================
    // TASK 2: Update "Yeng Keng Hotel Gateway" price level to Free
    // =========================================================================
    console.log('\n' + '─'.repeat(75));
    console.log('📌 TASK 2: Updating "Yeng Keng Hotel Gateway" Price Level to "Free"');
    console.log('─'.repeat(75));

    const yengKengFilter = { name: /Yeng Keng Hotel Gateway/i };
    const targetYengKeng = await placesCol.findOne(yengKengFilter);

    if (targetYengKeng) {
      console.log(`Found "${targetYengKeng.name}":`);
      console.log(`  • Current info price: "${targetYengKeng.place_information?.price_level}", root price: "${targetYengKeng.price_level}"`);

      const updateResult = await placesCol.updateOne(yengKengFilter, {
        $set: {
          'place_information.price_level': 'Free',
          price_level: 0,
          updatedAt: new Date()
        }
      });
      console.log(`\n✅ Successfully updated "${targetYengKeng.name}" to Free (modified: ${updateResult.modifiedCount}).`);
    } else {
      console.warn('⚠️ Could not find "Yeng Keng Hotel Gateway".');
    }

    // =========================================================================
    // VERIFICATION
    // =========================================================================
    console.log('\n' + '='.repeat(75));
    console.log('🔍 VERIFICATION');
    console.log('='.repeat(75));

    const remainingDeleted = await placesCol.countDocuments(removeFilter);
    console.log(`  • Remaining deleted places in DB: ${remainingDeleted} (Expected: 0)`);

    const verifiedYengKeng = await placesCol.findOne(yengKengFilter);
    if (verifiedYengKeng) {
      console.log(`  • Verified "${verifiedYengKeng.name}":`);
      console.log(`    place_information.price_level: ${verifiedYengKeng.place_information?.price_level}`);
      console.log(`    root price_level: ${verifiedYengKeng.price_level}`);
    }

    const totalInPlacesNew = await placesCol.countDocuments();
    console.log(`\n  • Total live places in places_new collection: ${totalInPlacesNew}`);

    console.log('='.repeat(75));
    console.log('🎉 OPERATIONS COMPLETED SUCCESSFULLY!');
    console.log('='.repeat(75));

  } catch (error) {
    console.error('\n❌ Operation Failed:', error.message);
  } finally {
    try {
      await mongoose.connection.close();
    } catch (_) {}
    process.exit(0);
  }
}

main();

