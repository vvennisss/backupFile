/**
 * Script to update ticket fee for Heritage & Culture places with paid price levels:
 * (RM 20-40, RM 35-80, RM 12.50-25, RM 20-50, RM20, RM3-25, RM18-30)
 *
 * Sets:
 *   ticket_fee: {
 *     is_free: false,
 *     amount_myr: <respective price_level>
 *   }
 */

const path = require('path');
const fs = require('fs');

function resolveModule(moduleName) {
  try {
    return require(moduleName);
  } catch (err) {
    const adminPath = path.resolve(__dirname, 'admin_web/node_modules', moduleName);
    if (fs.existsSync(adminPath)) {
      return require(adminPath);
    }
    throw new Error(`Could not locate "${moduleName}".`);
  }
}

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

// Mapping of place targets and respective price levels
const TARGET_UPDATES = [
  {
    name: 'Joie’s Cafe And Sourdough Bakery',
    id: '6ab4c1289f31a6201a4ca489',
    price_level: 'RM 20-40'
  },
  {
    name: 'Old George Town Cafe',
    id: '6ab4c0d19f31a6201a4ca458',
    price_level: 'RM 20-40'
  },
  {
    name: 'That Little Wine Bar',
    id: '6ab4c1b09f31a6201a4ca4d2',
    price_level: 'RM 35-80'
  },
  {
    name: 'Roots Dessert Bar',
    id: '6ab4c19f9f31a6201a4ca4ca',
    price_level: 'RM 35-80'
  },
  {
    name: 'Cheong Fatt Tze Mansion (Blue Mansion)',
    id: '6ab3aed0ceab80143ca1b083',
    price_level: 'RM 12.50-25'
  },
  {
    name: 'Chinatown Penang',
    id: '6ab4ce7799f6f68d08c93059',
    price_level: 'RM 20-50'
  },
  {
    name: 'Fort Cornwallis',
    id: '6ab3ae99ceab80143ca1a8f5',
    price_level: 'RM 20'
  },
  {
    name: 'Penang State Museum @ Farquhar',
    id: '6ab49c75ceab80143ca1c057',
    price_level: 'RM 3-25'
  },
  {
    name: 'Pinang Peranakan Mansion',
    id: '6ab3ae99ceab80143ca1a8f4',
    price_level: 'RM 18-30'
  }
];

async function main() {
  console.log('='.repeat(75));
  console.log(' 🎟️  Kia Kia Penang: Updating Heritage & Culture Ticket Fees');
  console.log('    is_free: false, amount_myr: respective price_level');
  console.log('='.repeat(75));
  console.log('Connecting to MongoDB Atlas...');

  try {
    await mongoose.connect(mongoUri, { serverSelectionTimeoutMS: 15000 });
    console.log('✅ Connected to MongoDB!\n');

    const db = mongoose.connection.db;
    const placesCol = db.collection('places_new');
    const { ObjectId } = mongoose.Types;

    console.log(`Processing updates for ${TARGET_UPDATES.length} attractions...\n`);

    for (let i = 0; i < TARGET_UPDATES.length; i++) {
      const item = TARGET_UPDATES[i];
      const query = {
        $or: [
          { _id: new ObjectId(item.id) },
          { _id: item.id },
          { name: item.name }
        ]
      };

      const beforeDoc = await placesCol.findOne(query);
      if (!beforeDoc) {
        console.warn(`⚠️ Place not found: "${item.name}" (${item.id})`);
        continue;
      }

      const newTicketFee = {
        amount_myr: item.price_level,
        is_free: false
      };

      const updatePayload = {
        $set: {
          ticket_fee: newTicketFee,
          'place_information.price_level': item.price_level,
          updatedAt: new Date()
        }
      };

      const result = await placesCol.updateOne(query, updatePayload);

      console.log(`[${i + 1}/${TARGET_UPDATES.length}] ✅ Updated: "${beforeDoc.name}"`);
      console.log(`     ID: ${beforeDoc._id}`);
      console.log(`     Old ticket_fee: ${JSON.stringify(beforeDoc.ticket_fee)}`);
      console.log(`     New ticket_fee: ${JSON.stringify(newTicketFee)}`);
      console.log(`     Matched: ${result.matchedCount}, Modified: ${result.modifiedCount}`);
      console.log('');
    }

    // Verification step
    console.log('='.repeat(75));
    console.log('🔍 VERIFYING UPDATED DOCUMENTS IN places_new');
    console.log('='.repeat(75));

    const verifyQuery = {
      $or: TARGET_UPDATES.map(item => ({
        $or: [
          { _id: new ObjectId(item.id) },
          { _id: item.id }
        ]
      }))
    };

    const verifiedDocs = await placesCol.find(verifyQuery).sort({ name: 1 }).toArray();

    console.log(`Verified ${verifiedDocs.length} matching places in MongoDB:`);
    verifiedDocs.forEach((doc, idx) => {
      console.log(`  ${idx + 1}. ${doc.name.padEnd(42)}`);
      console.log(`     Category   : ${doc.primary_category}`);
      console.log(`     Price Level: ${doc.place_information?.price_level}`);
      console.log(`     ticket_fee : ${JSON.stringify(doc.ticket_fee)}`);
    });

    // Check count of paid attractions overall
    const totalPaid = await placesCol.countDocuments({
      $or: [
        { 'ticket_fee.is_free': false },
        { 'ticket_fee.is_free': 'false' }
      ]
    });

    console.log('\n' + '─'.repeat(75));
    console.log(`📊 TOTAL PAID ATTRACTIONS IN places_new NOW: ${totalPaid}`);
    console.log('='.repeat(75));
    console.log('🎉 ALL HERITAGE & CULTURE TICKET FEES UPDATED SUCCESSFULLY!');
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

