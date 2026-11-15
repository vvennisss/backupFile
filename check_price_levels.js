/**
 * Script to check 'place_information.price_level' for all places in MongoDB collection 'places_new',
 * grouped and displayed by primary category ('primary_category').
 *
 * Usage:
 *   node check_price_levels.js                   (Shows category breakdown & all places)
 *   node check_price_levels.js --summary         (Shows only category price distribution summary)
 *   node check_price_levels.js --category Cafes  (Filter to a specific primary category)
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

// Parse command line arguments
const args = process.argv.slice(2);
const isSummaryOnly = args.includes('--summary');
const catArgIndex = args.findIndex(a => a === '--category' || a === '-c');
const categoryFilter = catArgIndex !== -1 && args[catArgIndex + 1] ? args[catArgIndex + 1].toLowerCase() : null;

async function main() {
  console.log('='.repeat(75));
  console.log(' 🔍 Kia Kia Penang: Checking places_new price_level by Primary Category');
  console.log('='.repeat(75));
  console.log('Connecting to MongoDB Atlas...');

  try {
    await mongoose.connect(mongoUri, { serverSelectionTimeoutMS: 10000 });
    console.log(' Connected to MongoDB!\n');

    const db = mongoose.connection.db;
    const placesCol = db.collection('places_new');

    // Fetch places with primary_category, name, and place_information.price_level
    const query = {};
    if (categoryFilter) {
      query.primary_category = { $regex: new RegExp(categoryFilter, 'i') };
    }

    const places = await placesCol
      .find(query, {
        projection: {
          name: 1,
          primary_category: 1,
          'place_information.price_level': 1,
          price_level: 1
        }
      })
      .sort({ primary_category: 1, name: 1 })
      .toArray();

    if (places.length === 0) {
      console.log('⚠️ No places found matching criteria.');
      return;
    }

    // Group places by primary_category
    const categoryGroups = {};
    for (const place of places) {
      const category = (place.primary_category && place.primary_category.trim()) || 'Uncategorized';
      if (!categoryGroups[category]) {
        categoryGroups[category] = [];
      }
      categoryGroups[category].push(place);
    }

    const sortedCategories = Object.keys(categoryGroups).sort();
    let grandTotal = 0;

    for (const cat of sortedCategories) {
      const group = categoryGroups[cat];
      grandTotal += group.length;

      // Calculate price distribution within category
      const distribution = {};
      for (const p of group) {
        const pLevel =
          (p.place_information && p.place_information.price_level !== undefined && p.place_information.price_level !== '')
            ? String(p.place_information.price_level).trim()
            : (p.price_level !== undefined ? `[root] ${p.price_level}` : '(Not Set)');
        distribution[pLevel] = (distribution[pLevel] || 0) + 1;
      }

      console.log('┌' + '─'.repeat(73) + '┐');
      console.log(`│ 📂 CATEGORY: ${cat.toUpperCase().padEnd(40)} (Total: ${String(group.length).padStart(4, ' ')} places) │`);
      console.log('├' + '─'.repeat(73) + '┤');

      // Price distribution summary for this category
      console.log('│  📊 Price Level Distribution:');
      const distEntries = Object.entries(distribution).sort((a, b) => b[1] - a[1]);
      for (const [lvl, cnt] of distEntries) {
        const pct = ((cnt / group.length) * 100).toFixed(1);
        console.log(`│     • ${lvl.padEnd(25)} : ${String(cnt).padStart(4, ' ')} places (${pct}%)`);
      }

      // If not summary only, print individual places
      if (!isSummaryOnly) {
        console.log('│' + ' '.repeat(73) + '│');
        console.log('│  📋 Place Breakdown:');
        group.forEach((p, idx) => {
          const num = String(idx + 1).padStart(4, ' ');
          const name = (p.name || 'Unnamed Place').padEnd(42).substring(0, 42);
          const pLevel =
            (p.place_information && p.place_information.price_level !== undefined && p.place_information.price_level !== '')
              ? String(p.place_information.price_level)
              : (p.price_level !== undefined ? `[root] ${p.price_level}` : '(Not Set)');
          console.log(`│   ${num}. ${name} -> ${pLevel}`);
        });
      }

      console.log('└' + '─'.repeat(73) + '┘\n');
    }

    console.log('='.repeat(75));
    console.log(`📊 TOTAL SUMMARY:`);
    console.log(`   Total Categories : ${sortedCategories.length}`);
    console.log(`   Total Places     : ${grandTotal}`);
    console.log('='.repeat(75));
    console.log('💡 TIP:');
    console.log('   - Run with --summary to see only category distribution without the place list:');
    console.log('       node check_price_levels.js --summary');
    console.log('   - Run with --category <name> to inspect a specific category (e.g. Cafes):');
    console.log('       node check_price_levels.js --category "Cafes"');
    console.log('   - Output can be redirected to a file:');
    console.log('       node check_price_levels.js > price_levels_report.txt\n');

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

