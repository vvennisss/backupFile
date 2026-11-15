/**
 * Script to execute database updates on 'places_new':
 * 1. Change primary_category of "Home Bakery & Cake House" and "Kenny Hills Bakers" to 'Cafes'.
 * 2. Change price_level of all places under 'Heritage & Culture' with 'RM 15-35' to 'Free' (and price_level 0).
 *
 * Usage:
 *   node update_places.js
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
  console.log(' 🛠️  Kia Kia Penang: Updating "places_new" Collection');
  console.log('='.repeat(75));
  console.log('Connecting to MongoDB Atlas...');

  try {
    await mongoose.connect(mongoUri, { serverSelectionTimeoutMS: 12000 });
    console.log(' Connected to MongoDB!\n');

    const db = mongoose.connection.db;
    const placesCol = db.collection('places_new');

    // =========================================================================
    // TASK 1: Update Home Bakery & Cake House, Kenny Hills Bakers to 'Cafes'
    // =========================================================================
    console.log('─'.repeat(75));
    console.log('📌 TASK 1: Updating Bakeries to Primary Category "Cafes"');
    console.log('─'.repeat(75));

    const bakeryQuery = {
      name: { $in: [/Home Bakery & Cake House/i, /Kenny Hills Bakers/i] }
    };

    const targetBakeries = await placesCol.find(bakeryQuery).toArray();
    console.log(`Found ${targetBakeries.length} matching bakery records:`);
    targetBakeries.forEach(b => {
      console.log(`  • "${b.name}" (Current Category: "${b.primary_category}")`);
    });

    const bakeryUpdateResult = await placesCol.updateMany(bakeryQuery, {
      $set: {
        primary_category: 'Cafes',
        updatedAt: new Date()
      },
      $addToSet: {
        sub_categories: 'Cafes'
      }
    });

    console.log(`\n✅ Task 1 Completed: Modified ${bakeryUpdateResult.modifiedCount} places.`);

    // =========================================================================
    // TASK 2: Change Heritage & Culture places with 'RM 15-35' to 'Free'
    // =========================================================================
    console.log('\n' + '─'.repeat(75));
    console.log('📌 TASK 2: Updating "Heritage & Culture" with price "RM 15-35" to "Free"');
    console.log('─'.repeat(75));

    const heritageQuery = {
      primary_category: /Heritage & Culture/i,
      $or: [
        { 'place_information.price_level': /RM\s*15\s*[-–]\s*35/i },
        { price_level: /RM\s*15\s*[-–]\s*35/i }
      ]
    };

    const matchingHeritage = await placesCol.find(heritageQuery).toArray();
    console.log(`Found ${matchingHeritage.length} places under "Heritage & Culture" with "RM 15-35".`);

    const heritageUpdateResult = await placesCol.updateMany(heritageQuery, {
      $set: {
        'place_information.price_level': 'Free',
        price_level: 0,
        updatedAt: new Date()
      }
    });

    console.log(`\n✅ Task 2 Completed: Modified ${heritageUpdateResult.modifiedCount} places to "Free".`);

    // =========================================================================
    // VERIFICATION
    // =========================================================================
    console.log('\n' + '='.repeat(75));
    console.log('🔍 VERIFICATION & SUMMARY OF UPDATED DATA');
    console.log('='.repeat(75));

    // Verify Bakeries
    const verifiedBakeries = await placesCol.find({
      name: { $in: [/Home Bakery & Cake House/i, /Kenny Hills Bakers/i] }
    }).toArray();

    console.log('\n1️⃣  Verified Bakeries:');
    verifiedBakeries.forEach(b => {
      console.log(`  • Name             : ${b.name}`);
      console.log(`    Primary Category : ${b.primary_category}`);
      console.log(`    Sub-Categories   : ${JSON.stringify(b.sub_categories)}`);
      console.log(`    Price Level      : ${b.place_information?.price_level || b.price_level}\n`);
    });

    // Verify Heritage & Culture remaining RM 15-35
    const remainingRM15_35 = await placesCol.countDocuments(heritageQuery);
    const heritageFreeCount = await placesCol.countDocuments({
      primary_category: /Heritage & Culture/i,
      'place_information.price_level': 'Free'
    });

    console.log('2️⃣  Heritage & Culture Price Level Status:');
    console.log(`  • Remaining with "RM 15-35" : ${remainingRM15_35} (Expected: 0)`);
    console.log(`  • Total marked as "Free"   : ${heritageFreeCount}`);

    // Summary of distinct price levels in Heritage & Culture now
    const currentHeritagePrices = await placesCol.distinct('place_information.price_level', {
      primary_category: /Heritage & Culture/i
    });
    console.log(`  • Current distinct price levels: ${JSON.stringify(currentHeritagePrices)}\n`);

    console.log('='.repeat(75));
    console.log('🎉 ALL REQUESTED UPDATES HAVE BEEN APPLIED SUCCESSFULLY!');
    console.log('='.repeat(75));

  } catch (error) {
    console.error('\n❌ Update Operation Failed:', error.message);
  } finally {
    try {
      await mongoose.connection.close();
    } catch (_) {}
    process.exit(0);
  }
}

main();

