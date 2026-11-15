/**
 * Script to inspect and display all primary_category and sub_categories
 * from the 'places_new' collection in MongoDB Atlas.
 *
 * Usage:
 *   node check_categories.js
 *   node check_categories.js --category "Heritage & Culture"
 *   node check_categories.js --json
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

// Command line arguments
const args = process.argv.slice(2);
const isJsonOutput = args.includes('--json');
const catArgIndex = args.findIndex(a => a === '--category' || a === '-c');
const categoryFilter = catArgIndex !== -1 && args[catArgIndex + 1] ? args[catArgIndex + 1].toLowerCase() : null;

async function main() {
  if (!isJsonOutput) {
    console.log('='.repeat(75));
    console.log(' 🏷️  Kia Kia Penang: Primary & Sub-Categories in "places_new"');
    console.log('='.repeat(75));
    console.log('Connecting to MongoDB Atlas...');
  }

  try {
    await mongoose.connect(mongoUri, { serverSelectionTimeoutMS: 10000 });
    if (!isJsonOutput) console.log(' Connected to MongoDB!\n');

    const db = mongoose.connection.db;
    const placesCol = db.collection('places_new');

    const totalPlaces = await placesCol.countDocuments();

    // Fetch all places with primary_category and sub_categories
    const docs = await placesCol
      .find({}, { projection: { primary_category: 1, sub_categories: 1 } })
      .toArray();

    // Data structures for grouping
    // primaryMap: { [primaryCategory]: { totalPlaces: number, subCategories: { [sub]: count } } }
    const primaryMap = {};
    const globalSubCategories = {}; // { [sub]: totalPlaces }

    for (const doc of docs) {
      const primary = (doc.primary_category && String(doc.primary_category).trim()) || 'Uncategorized';

      if (!primaryMap[primary]) {
        primaryMap[primary] = {
          totalPlaces: 0,
          subCategories: {}
        };
      }
      primaryMap[primary].totalPlaces += 1;

      // Normalize sub_categories: could be array, string, or undefined/null
      let subs = [];
      if (Array.isArray(doc.sub_categories)) {
        subs = doc.sub_categories.map(s => String(s).trim()).filter(Boolean);
      } else if (typeof doc.sub_categories === 'string' && doc.sub_categories.trim()) {
        subs = [doc.sub_categories.trim()];
      }

      if (subs.length === 0) {
        primaryMap[primary].subCategories['(None)'] = (primaryMap[primary].subCategories['(None)'] || 0) + 1;
      } else {
        // Track unique sub_categories per document so a place doesn't count twice for same sub
        const uniqueSubsInDoc = [...new Set(subs)];
        for (const sub of uniqueSubsInDoc) {
          primaryMap[primary].subCategories[sub] = (primaryMap[primary].subCategories[sub] || 0) + 1;
          globalSubCategories[sub] = (globalSubCategories[sub] || 0) + 1;
        }
      }
    }

    // JSON output mode
    if (isJsonOutput) {
      console.log(JSON.stringify({
        totalPlaces,
        uniquePrimaryCategoriesCount: Object.keys(primaryMap).length,
        uniqueSubCategoriesCount: Object.keys(globalSubCategories).length,
        categoriesHierarchy: primaryMap,
        allUniqueSubCategories: Object.keys(globalSubCategories).sort()
      }, null, 2));
      return;
    }

    // Filter categories if user specified --category
    let primaryKeys = Object.keys(primaryMap).sort();
    if (categoryFilter) {
      primaryKeys = primaryKeys.filter(k => k.toLowerCase().includes(categoryFilter));
    }

    console.log('┌' + '─'.repeat(73) + '┐');
    console.log('│ 📁 HIERARCHICAL TAXONOMY (Primary Category ➔ Sub-Categories)           │');
    console.log('└' + '─'.repeat(73) + '┘\n');

    primaryKeys.forEach((primary, idx) => {
      const data = primaryMap[primary];
      const subEntries = Object.entries(data.subCategories).sort((a, b) => b[1] - a[1]);

      console.log(`[${idx + 1}] 📂 ${primary.toUpperCase()} (${data.totalPlaces} places)`);

      if (subEntries.length === 0) {
        console.log(`    └── (No sub-categories assigned)\n`);
      } else {
        subEntries.forEach(([sub, cnt], sIdx) => {
          const isLast = sIdx === subEntries.length - 1;
          const branch = isLast ? '└──' : '├──';
          const pct = ((cnt / data.totalPlaces) * 100).toFixed(1);
          console.log(`    ${branch} 🏷️  ${sub.padEnd(28)} : ${String(cnt).padStart(4, ' ')} places (${pct}%)`);
        });
        console.log('');
      }
    });

    // If not filtering, show global unique lists
    if (!categoryFilter) {
      console.log('='.repeat(75));
      console.log('📋 GLOBAL SUMMARY LISTS');
      console.log('='.repeat(75));

      console.log(`\n1️⃣  All Unique Primary Categories (${Object.keys(primaryMap).length} total):`);
      console.log('─'.repeat(55));
      Object.keys(primaryMap).sort().forEach((cat, i) => {
        const cnt = primaryMap[cat].totalPlaces;
        console.log(`  ${String(i + 1).padStart(2, ' ')}. ${cat.padEnd(30)} (${cnt} places)`);
      });

      const allUniqueSubs = Object.keys(globalSubCategories).sort();
      console.log(`\n2️⃣  All Unique Sub-Categories (${allUniqueSubs.length} total):`);
      console.log('─'.repeat(55));
      allUniqueSubs.forEach((sub, i) => {
        const cnt = globalSubCategories[sub];
        console.log(`  ${String(i + 1).padStart(2, ' ')}. ${sub.padEnd(30)} (${cnt} places)`);
      });

      console.log('\n' + '='.repeat(75));
      console.log(`📊 TOTAL OVERVIEW:`);
      console.log(`   • Total Places in places_new  : ${totalPlaces}`);
      console.log(`   • Unique Primary Categories   : ${Object.keys(primaryMap).length}`);
      console.log(`   • Unique Sub-Categories       : ${allUniqueSubs.length}`);
      console.log('='.repeat(75));
      console.log('💡 TIP:');
      console.log('   - Filter to a single category: node check_categories.js --category "Heritage"');
      console.log('   - Output as JSON:              node check_categories.js --json');
      console.log('   - Save to a file:              node check_categories.js > categories_report.txt\n');
    }

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

