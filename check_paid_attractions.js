/**
 * Script to check attractions in MongoDB collection 'places_new'
 * where "ticket_fee": { "is_free": false }.
 *
 * Usage:
 *   node check_paid_attractions.js
 */

const path = require('path');
const fs = require('fs');

// Helper to resolve modules from admin_web/node_modules if running from root
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
  console.log('='.repeat(65));
  console.log(' 🔍 Kia Kia Penang: Checking "places_new" for Paid Attractions');
  console.log('    Filter: "ticket_fee.is_free": false');
  console.log('='.repeat(65));
  console.log('Connecting to MongoDB Atlas...');

  try {
    await mongoose.connect(mongoUri, { serverSelectionTimeoutMS: 10000 });
    console.log(' Connected to MongoDB!\n');

    const db = mongoose.connection.db;
    const placesCol = db.collection('places_new');

    const totalInCollection = await placesCol.countDocuments();
    const totalWithTicketField = await placesCol.countDocuments({
      ticket_fee: { $exists: true, $ne: null }
    });

    // Query for is_free: false (supporting boolean false or string "false")
    const query = {
      $or: [
        { 'ticket_fee.is_free': false },
        { 'ticket_fee.is_free': 'false' }
      ]
    };

    const paidAttractions = await placesCol.find(query).sort({ name: 1 }).toArray();
    const count = paidAttractions.length;

    console.log('─'.repeat(65));
    console.log('📋 MATCHING ATTRACTIONS:');
    console.log('─'.repeat(65));

    if (count === 0) {
      console.log('  (No attractions found where "ticket_fee.is_free" is false)');
    } else {
      paidAttractions.forEach((place, index) => {
        const num = String(index + 1).padStart(3, ' ');
        const name = place.name || 'Unnamed Place';
        const category = place.primary_category ? ` [${place.primary_category}]` : '';
        let feeInfo = '';
        if (place.ticket_fee && place.ticket_fee.amount_myr !== undefined) {
          const val = String(place.ticket_fee.amount_myr).trim();
          feeInfo = val.startsWith('RM') ? ` (Fee: ${val})` : ` (Fee: RM ${val})`;
        }
        console.log(`  ${num}. ${name}${category}${feeInfo}`);
      });
    }

    console.log('─'.repeat(65));
    console.log(`📊 TOTAL COUNT: ${count}`);
    console.log('='.repeat(65));
    console.log(
      `ℹ️  Database Summary: Checked ${totalInCollection} total records in 'places_new'.`
    );
    console.log(
      `    ${totalWithTicketField} places have a 'ticket_fee' object (${totalWithTicketField - count} are marked is_free: true).\n`
    );
  } catch (error) {
    console.error('\n❌ MongoDB Query Failed:', error.message);
  } finally {
    try {
      await mongoose.connection.close();
    } catch (_) {}
    process.exit(0);
  }
}

main();

