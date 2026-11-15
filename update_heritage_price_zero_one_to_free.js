/**
 * Script to update all places under 'Heritage & Culture' whose price level is 0 or 1 to 'Free'.
 *
 * Usage:
 *   node update_heritage_price_zero_one_to_free.js
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
  console.log(' 🛠️  Kia Kia Penang: Updating Heritage & Culture (Price 0 & 1 -> Free)');
  console.log('='.repeat(75));
  console.log('Connecting to MongoDB Atlas...');

  try {
    await mongoose.connect(mongoUri, { serverSelectionTimeoutMS: 12000 });
    console.log(' Connected to MongoDB!\n');

    const db = mongoose.connection.db;
    const placesCol = db.collection('places_new');

    // Known paid prices that should NOT be overwritten (e.g. Khoo Kongsi, Cheah Kongsi)
    const paidPrices = [
      'RM 10',
      'RM 17',
      'RM 20',
      'RM 35–80',
      'RM 20–40',
      'RM 20–50',
      'RM 12.50 - 25',
      'RM 18 - 30',
      'RM 1.00',
      'Free'
    ];

    const filter = {
      primary_category: /Heritage & Culture/i,
      $or: [
        { price_level: { $in: [0, 1, '0', '1'] } },
        { 'place_information.price_level': { $in: [0, 1, '0', '1'] } }
      ],
      'place_information.price_level': { $nin: paidPrices }
    };

    const targetPlaces = await placesCol.find(filter).sort({ name: 1 }).toArray();
    console.log(`Found ${targetPlaces.length} places under "Heritage & Culture" with price level 0 or 1:`);
    targetPlaces.forEach((p, i) => {
      console.log(`  ${String(i + 1).padStart(2, ' ')}. ${p.name.padEnd(45)} (info: "${p.place_information?.price_level}", root: "${p.price_level}")`);
    });

    if (targetPlaces.length === 0) {
      console.log('\n⚠️ No matching places found to update.');
      return;
    }

    console.log(`\nUpdating ${targetPlaces.length} places to "Free" (place_information.price_level: 'Free', price_level: 0)...`);

    const updateResult = await placesCol.updateMany(filter, {
      $set: {
        'place_information.price_level': 'Free',
        price_level: 0,
        updatedAt: new Date()
      }
    });

    console.log(`\n✅ Successfully updated ${updateResult.modifiedCount} places to "Free"!`);

    // Verification
    console.log('\n' + '='.repeat(75));
    console.log('🔍 VERIFICATION IN HERITAGE & CULTURE');
    console.log('='.repeat(75));

    const totalFree = await placesCol.countDocuments({
      primary_category: /Heritage & Culture/i,
      'place_information.price_level': 'Free'
    });

    const remaining0or1 = await placesCol.countDocuments(filter);
    console.log(`  • Remaining with price 0 or 1 without Free status : ${remaining0or1} (Expected: 0)`);
    console.log(`  • Total Heritage & Culture places marked as Free   : ${totalFree}\n`);

    console.log('='.repeat(75));
    console.log('🎉 UPDATE COMPLETE!');
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

