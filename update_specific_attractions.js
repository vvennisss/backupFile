/**
 * Script to update:
 * 1. Khoo Kongsi ("Leong San Tong Khoo Kongsi") and Cheah Kongsi ("Seh Tek Tong Cheah Kongsi") -> Free
 * 2. Penang State Museum @ Farquhar -> RM 3-25
 *
 * Usage:
 *   node update_specific_attractions.js
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
  console.log(' 🛠️  Kia Kia Penang: Updating Specific Attraction Price Levels');
  console.log('='.repeat(75));
  console.log('Connecting to MongoDB Atlas...');

  try {
    await mongoose.connect(mongoUri, { serverSelectionTimeoutMS: 12000 });
    console.log(' Connected to MongoDB!\n');

    const db = mongoose.connection.db;
    const placesCol = db.collection('places_new');

    // 1. Update Khoo Kongsi & Cheah Kongsi to Free
    console.log('─'.repeat(75));
    console.log('📌 TASK 1: Updating Khoo Kongsi & Cheah Kongsi to "Free"');
    console.log('─'.repeat(75));

    const khooCheahFilter = {
      $or: [
        { name: 'Leong San Tong Khoo Kongsi' },
        { name: 'Seh Tek Tong Cheah Kongsi' }
      ]
    };

    const targetKhooCheah = await placesCol.find(khooCheahFilter).toArray();
    console.log(`Found ${targetKhooCheah.length} places to update to Free:`);
    targetKhooCheah.forEach(p => {
      console.log(`  • "${p.name}" (Current price: "${p.place_information?.price_level}")`);
    });

    const resKhooCheah = await placesCol.updateMany(khooCheahFilter, {
      $set: {
        'place_information.price_level': 'Free',
        price_level: 0,
        updatedAt: new Date()
      }
    });
    console.log(`✅ Updated ${resKhooCheah.modifiedCount} places to "Free".`);

    // 2. Update Penang State Museum @ Farquhar to RM 3-25
    console.log('\n' + '─'.repeat(75));
    console.log('📌 TASK 2: Updating Penang State Museum @ Farquhar to "RM 3-25"');
    console.log('─'.repeat(75));

    const museumFilter = {
      name: 'Penang State Museum @ Farquhar'
    };

    const targetMuseum = await placesCol.findOne(museumFilter);
    if (targetMuseum) {
      console.log(`Found "${targetMuseum.name}" (Current price: "${targetMuseum.place_information?.price_level}")`);
      const resMuseum = await placesCol.updateOne(museumFilter, {
        $set: {
          'place_information.price_level': 'RM 3-25',
          price_level: 1,
          updatedAt: new Date()
        }
      });
      console.log(`✅ Updated "${targetMuseum.name}" to "RM 3-25" (modified: ${resMuseum.modifiedCount}).`);
    } else {
      console.warn('⚠️ Could not find "Penang State Museum @ Farquhar".');
    }

    // 3. Verification
    console.log('\n' + '='.repeat(75));
    console.log('🔍 VERIFICATION');
    console.log('='.repeat(75));

    const verified = await placesCol.find({
      $or: [
        { name: 'Leong San Tong Khoo Kongsi' },
        { name: 'Seh Tek Tong Cheah Kongsi' },
        { name: 'Penang State Museum @ Farquhar' }
      ]
    }).toArray();

    verified.forEach(p => {
      console.log(`  • Name        : ${p.name}`);
      console.log(`    Price Level : ${p.place_information?.price_level} (root: ${p.price_level})\n`);
    });

    console.log('='.repeat(75));
    console.log('🎉 UPDATES COMPLETED SUCCESSFULLY!');
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

