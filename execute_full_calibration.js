const mongoose = require('mongoose');
require('dotenv').config({ path: 'C:/Users/Vennis/OneDrive/Desktop/0824-setup-mongoDB-places-table-nodejs/.env' });

const CHINESE_AREA_NAMES = {
    'George Town': '乔治市',
    'Pulau Tikus': '浮罗池滑',
    'Tanjung Tokong': '丹绒道光',
    'Tanjung Bungah': '丹绒武雅',
    'Batu Ferringhi': '峇都丁宜',
    'Teluk Bahang': '直落巴巷',
    'Balik Pulau': '浮罗山背',
    'Air Itam': '亚依淡',
    'Bayan Lepas': '峇六拜',
    'Butterworth': '北海',
    'Bukit Mertajam': '大山脚'
};

const ALL_AREAS = Object.keys(CHINESE_AREA_NAMES);

function determineAccurateArea(place) {
    const rawAddr = (place.address || place.place_address || '').trim();
    const rawName = (place.name || place.place_name || '').trim();
    const addr = rawAddr.toLowerCase();
    const name = rawName.toLowerCase();

    // 0. Foreign check (scraped places outside Malaysia)
    if (/Daniel Webster Highway|Cleveland, Ohio|Markham, Ontario|Roman Road, London|Foster City Boulevard|Yarra Street, Geelong/i.test(rawAddr) ||
        /United States|Canada|United Kingdom|Australia/i.test(rawAddr) ||
        (!place.location?.coordinates && !addr.includes('penang') && !addr.includes('pulau pinang') && !addr.includes('malaysia') && !addr.includes('perai'))) {
        return null;
    }

    // Coordinates
    const coords = (place.location && Array.isArray(place.location.coordinates) && place.location.coordinates.length === 2)
        ? place.location.coordinates : null;
    const lng = coords ? coords[0] : null;
    const lat = coords ? coords[1] : null;

    // 1. HARD SPATIAL BOUNDARIES:
    // A. Mainland: Any place with longitude > 100.36 is geographically in Seberang Perai (Mainland)
    if (lng && lng > 100.36) {
        if (addr.includes('butterworth') || addr.includes('bagan') || addr.includes('kepala batas') || addr.includes('bertam') || addr.includes('tasek gelugor')) {
            return 'Butterworth';
        }
        if (addr.includes('bukit mertajam') || addr.includes('perai') || addr.includes('nibong tebal') || addr.includes('simpang ampat') || addr.includes('batu kawan') || addr.includes('juru')) {
            return 'Bukit Mertajam';
        }
        return (lat && lat >= 5.38) ? 'Butterworth' : 'Bukit Mertajam';
    }

    // B. Island Extreme South: South of lat 5.295 is Bayan Lepas (Gertak Sanggul / Teluk Kumbar / Teluk Bayu / Gemuruh / Pasir Belanda)
    if (lat && lat < 5.295 && !addr.includes('pulau betong')) {
        return 'Bayan Lepas';
    }

    // C. Island Extreme Northwest: North of lat 5.435 and West of lng 100.235 is Teluk Bahang
    if (lat && lng && lat >= 5.435 && lng < 100.235) {
        return 'Teluk Bahang';
    }

    // 2. Specific landmark overrides
    if (name.includes('escape') || name.includes('entopia') || name.includes('tropical spice') || 
        name.includes('penang national park') || name.includes('taman negara pulau pinang') ||
        name.includes('monkey beach') || name.includes('pantai kerachut') || name.includes('teluk kampi')) {
        return 'Teluk Bahang';
    }
    if (name.includes('kek lok si') || name.includes('penang hill') || name.includes('the habitat') || 
        name.includes('bukit bendera') || name.includes('air itam laksa') || name.includes('air itam dam')) {
        return 'Air Itam';
    }
    if (name.includes('snake temple') || name.includes('penang war museum') || 
        name.includes('gertak sanggul') || name.includes('tanjung asam')) {
        return 'Bayan Lepas';
    }
    if (name.includes('starbucks - batu ferringhi') || name.includes('natsu bar')) {
        return 'Batu Ferringhi';
    }
    if (name === 'tanjung tokong') {
        return 'Tanjung Tokong';
    }

    // 2. Postal Code & Postal Town matching (Highest Precision for Malaysian addresses)
    const postalMatch = rawAddr.match(/\b(1\d{4})\s+([A-Za-z\s]{3,30}?)(?:,|$)/);
    if (postalMatch) {
        const pc = postalMatch[1];
        const town = postalMatch[2].trim().toLowerCase();

        if (town.includes('balik pulau')) return 'Balik Pulau';
        if (town.includes('bayan lepas') || town.includes('batu maung')) return 'Bayan Lepas';
        if (town.includes('batu ferringhi') || town.includes('batu feringgi') || town.includes('batu feringghi')) return 'Batu Ferringhi';
        if (town.includes('air itam') || town.includes('ayer itam') || town.includes('ayer hitam') || town.includes('bukit bendera')) return 'Air Itam';
        if (town.includes('tanjung tokong') || town.includes('tanjong tokong')) return 'Tanjung Tokong';
        if (town.includes('teluk bahang') || town.includes('telok bahang')) return 'Teluk Bahang';
        if (town.includes('tanjung bungah') || town.includes('tanjong bungah') || town.includes('tanjung bunga')) {
            if (pc === '11050' || addr.includes('teluk bahang')) return 'Teluk Bahang';
            return 'Tanjung Bungah';
        }
        if (town.includes('pulau tikus')) return 'Pulau Tikus';
        if (town.includes('butterworth') || town.includes('seberang jaya') || town.includes('kepala batas') || town.includes('permatang pauh') || town.includes('tasek gelugor')) {
            return 'Butterworth';
        }
        if (town.includes('bukit mertajam') || town.includes('perai') || town.includes('nibong tebal') || town.includes('simpang ampat') || town.includes('batu kawan') || town.includes('sungai jawi')) {
            return 'Bukit Mertajam';
        }
        if (town.includes('george town') || town.includes('georgetown') || town.includes('jelutong') || town.includes('gelugor')) {
            if (pc === '11050') return 'Teluk Bahang';
            if (pc === '11500' || pc === '11400' || pc === '11060') return 'Air Itam';
            if (pc === '10350') return 'Pulau Tikus';
            if (pc === '10470') return 'Tanjung Tokong';
            if (pc === '11100') return 'Batu Ferringhi';
            if (pc === '11200') return 'Tanjung Bungah';
            if (pc === '11000' || pc === '11010' || pc === '11020') return 'Balik Pulau';
            if (pc.startsWith('119')) return 'Bayan Lepas';
            return 'George Town';
        }
    }

    // Extract 5-digit postcode standalone
    const pcMatch = rawAddr.match(/\b(1\d{4})\b/);
    const pc = pcMatch ? pcMatch[1] : null;

    // 3. Postcode Standalone rules
    if (pc === '11050') return 'Teluk Bahang';
    if (pc === '11100') return 'Batu Ferringhi';
    if (pc === '11200') return 'Tanjung Bungah';
    if (pc === '10470') return 'Tanjung Tokong';
    if (pc === '10350') return 'Pulau Tikus';
    if (pc === '11500' || pc === '11400' || pc === '11060') return 'Air Itam';
    if (pc === '11900' || pc === '11910' || pc === '11920' || pc === '11950' || pc === '11960') return 'Bayan Lepas';
    if (pc === '11010' || pc === '11020') return 'Balik Pulau';
    if (pc === '11000') {
        if (addr.includes('bayan lepas') || addr.includes('gertak sanggul') || addr.includes('teluk kumbar')) return 'Bayan Lepas';
        if (addr.includes('batu ferringhi')) return 'Batu Ferringhi';
        return 'Balik Pulau';
    }
    if (pc && (pc.startsWith('12') || pc === '13000' || pc === '13050' || pc === '13100' || pc === '13200' || pc === '13300' || pc === '13400' || pc === '13500' || pc === '13800')) {
        return 'Butterworth';
    }
    if (pc && (pc.startsWith('14') || pc === '13600' || pc === '13700')) {
        return 'Bukit Mertajam';
    }
    if (pc === '11600' || pc === '11700' || (pc && pc.startsWith('10'))) {
        return 'George Town';
    }

    // 4. Address text keywords (fallback when no postcode)
    if (addr.includes('teluk bahang') || addr.includes('telok bahang')) return 'Teluk Bahang';
    if (addr.includes('batu ferringhi') || addr.includes('batu feringgi') || addr.includes('batu feringghi') || addr.includes('miami beach')) return 'Batu Ferringhi';
    if (addr.includes('tanjung bungah') || addr.includes('tanjung bunga') || addr.includes('tanjong bungah') || addr.includes('lembah permai')) return 'Tanjung Bungah';
    if (addr.includes('tanjung tokong') || addr.includes('tanjong tokong') || addr.includes('straits quay') || addr.includes('seri tanjung pinang')) return 'Tanjung Tokong';
    if (addr.includes('pulau tikus') || addr.includes('cantonment') || addr.includes('moulmein') || addr.includes('kelawai') || addr.includes('kelawei')) return 'Pulau Tikus';
    if (addr.includes('air itam') || addr.includes('ayer itam') || addr.includes('farlim') || addr.includes('paya terubong') || addr.includes('paya terubung')) return 'Air Itam';
    if (addr.includes('balik pulau') || addr.includes('sungai rusa') || addr.includes('pulau betong') || addr.includes('kuala sungai burung') || addr.includes('pantai malindo')) {
        if (lat && lng && lat >= 5.435 && lng < 100.235) return 'Teluk Bahang';
        if (lat && lng && lat < 5.295 && !addr.includes('pulau betong')) return 'Bayan Lepas';
        return 'Balik Pulau';
    }
    if (addr.includes('bayan lepas') || addr.includes('bayan baru') || addr.includes('teluk kumbar') || addr.includes('gertak sanggul') || addr.includes('sungai ara') || addr.includes('batu maung') || addr.includes('bukit jambul') || addr.includes('relau') || addr.includes('queensbay')) return 'Bayan Lepas';
    if (addr.includes('butterworth') || addr.includes('raja uda') || addr.includes('bagan') || addr.includes('seberang jaya') || addr.includes('kepala batas') || addr.includes('tasek gelugor') || addr.includes('bertam')) return 'Butterworth';
    if (addr.includes('bukit mertajam') || addr.includes('perai') || addr.includes('nibong tebal') || addr.includes('simpang ampat') || addr.includes('juru') || addr.includes('batu kawan') || addr.includes('alma') || addr.includes('seberang perai') || addr.includes('auto city')) return 'Bukit Mertajam';
    if (addr.includes('george town') || addr.includes('georgetown') || addr.includes('jelutong') || addr.includes('gelugor')) return 'George Town';

    // 5. Place name keywords (fallback when address is generic e.g. "Penang, Malaysia")
    if (name.includes('batu ferringhi') || name.includes('batu feringgi')) return 'Batu Ferringhi';
    if (name.includes('teluk bahang')) return 'Teluk Bahang';
    if (name.includes('tanjung bungah') || name.includes('tanjong bungah')) return 'Tanjung Bungah';
    if (name.includes('tanjung tokong') || name.includes('tanjong tokong')) return 'Tanjung Tokong';
    if (name.includes('pulau tikus')) return 'Pulau Tikus';
    if (name.includes('air itam') || name.includes('ayer itam')) return 'Air Itam';
    if (name.includes('balik pulau')) return 'Balik Pulau';
    if (name.includes('bayan lepas') || name.includes('bayan baru')) return 'Bayan Lepas';
    if (name.includes('butterworth') || name.includes('seberang jaya')) return 'Butterworth';
    if (name.includes('bukit mertajam') || name.includes('batu kawan') || name.includes('nibong tebal')) return 'Bukit Mertajam';
    if (name.includes('george town') || name.includes('georgetown')) return 'George Town';

    // 6. Geographic coordinates fallback
    if (lat && lng) {
        if (lng > 100.36) {
            return lat >= 5.38 ? 'Butterworth' : 'Bukit Mertajam';
        }
        if (lat >= 5.435 && lng < 100.235) return 'Teluk Bahang';
        if (lat >= 5.460 && lng >= 100.235 && lng < 100.280) return 'Batu Ferringhi';
        if (lat >= 5.450 && lng >= 100.280 && lng < 100.305) return 'Tanjung Bungah';
        if (lat >= 5.440 && lng >= 100.300 && lng < 100.315) return 'Tanjung Tokong';
        if (lat >= 5.420 && lat < 5.440 && lng >= 100.305 && lng < 100.320) return 'Pulau Tikus';
        if (lat >= 5.380 && lat < 5.430 && lng >= 100.260 && lng < 100.295) return 'Air Itam';
        if (lat < 5.410 && lat >= 5.295 && lng < 100.240) return 'Balik Pulau';
        if (lat < 5.360) return 'Bayan Lepas';
        return 'George Town';
    }

    return place.area || 'George Town';
}

function cleanTextForNewArea(text, oldArea, newArea) {
    if (!text || typeof text !== 'string') return text;
    let res = text;
    if (oldArea && oldArea !== newArea) {
        const inRegex = new RegExp(`\\b(in|at|around|within|across|near|shores of|heart of|streets of|charm of)\\s+${oldArea}\\b`, 'gi');
        res = res.replace(inRegex, `$1 ${newArea}`);

        const ofRegex = new RegExp(`\\b(of)\\s+${oldArea}\\b`, 'gi');
        res = res.replace(ofRegex, `$1 ${newArea}`);
    }
    return res;
}

function cleanChineseText(text, oldArea, newArea) {
    if (!text || typeof text !== 'string') return text;
    let res = text;
    const oldZh = CHINESE_AREA_NAMES[oldArea];
    const newZh = CHINESE_AREA_NAMES[newArea];
    if (oldZh && newZh && oldZh !== newZh) {
        const zhRegex = new RegExp(`${oldZh}`, 'g');
        res = res.replace(zhRegex, newZh);
    }
    return res;
}

async function executeFullCalibration() {
    console.log('Connecting to MongoDB...');
    await mongoose.connect(process.env.MONGODB_URI);
    const col = mongoose.connection.db.collection('places_new');
    const allPlaces = await col.find({}).toArray();
    console.log(`Loaded ${allPlaces.length} places from places_new.`);

    const bulkOps = [];
    let inactiveCount = 0;
    let areaChangeCount = 0;
    let textUpdatedCount = 0;
    const newAreaCounts = {};

    for (const place of allPlaces) {
        const accurateArea = determineAccurateArea(place);

        // Foreign scraped places outside Malaysia
        if (!accurateArea) {
            inactiveCount++;
            bulkOps.push({
                updateOne: {
                    filter: { _id: place._id },
                    update: { $set: { status: 'inactive', updatedAt: new Date() } }
                }
            });
            continue;
        }

        newAreaCounts[accurateArea] = (newAreaCounts[accurateArea] || 0) + 1;

        const oldArea = place.area;
        const isAreaChanged = (oldArea !== accurateArea);
        if (isAreaChanged) {
            areaChangeCount++;
        }

        // Clean search_keywords
        let keywords = Array.isArray(place.search_keywords) ? [...place.search_keywords] : [];
        if (oldArea && oldArea !== accurateArea) {
            keywords = keywords.filter(k => k.toLowerCase() !== oldArea.toLowerCase());
        }
        if (!keywords.map(k => k.toLowerCase()).includes(accurateArea.toLowerCase())) {
            keywords.push(accurateArea.toLowerCase());
        }

        // Text corrections for summary, description, and Chinese translations
        let newSummary = place.summary;
        let newDescription = place.description;
        let newSummaryZh = place.summary_zh;
        let newDescriptionZh = place.description_zh;

        // Clean against old area or other wrong area references if applicable
        const areasToCheck = isAreaChanged ? [oldArea] : ALL_AREAS.filter(a => a !== accurateArea);

        let modifiedText = false;
        for (const candidateOldArea of areasToCheck) {
            if (!candidateOldArea) continue;

            const updatedSummary = cleanTextForNewArea(newSummary, candidateOldArea, accurateArea);
            const updatedDesc = cleanTextForNewArea(newDescription, candidateOldArea, accurateArea);
            const updatedSummaryZh = cleanChineseText(newSummaryZh, candidateOldArea, accurateArea);
            const updatedDescZh = cleanChineseText(newDescriptionZh, candidateOldArea, accurateArea);

            if (updatedSummary !== newSummary || updatedDesc !== newDescription ||
                updatedSummaryZh !== newSummaryZh || updatedDescZh !== newDescriptionZh) {
                newSummary = updatedSummary;
                newDescription = updatedDesc;
                newSummaryZh = updatedSummaryZh;
                newDescriptionZh = updatedDescZh;
                modifiedText = true;
            }
        }

        if (modifiedText) {
            textUpdatedCount++;
        }

        const updateDoc = {
            area: accurateArea,
            search_keywords: keywords,
            status: place.status === 'inactive' ? 'active' : (place.status || 'active'),
            updatedAt: new Date()
        };

        if (newSummary !== undefined) updateDoc.summary = newSummary;
        if (newDescription !== undefined) updateDoc.description = newDescription;
        if (newSummaryZh !== undefined) updateDoc.summary_zh = newSummaryZh;
        if (newDescriptionZh !== undefined) updateDoc.description_zh = newDescriptionZh;

        bulkOps.push({
            updateOne: {
                filter: { _id: place._id },
                update: { $set: updateDoc }
            }
        });
    }

    console.log(`Prepared ${bulkOps.length} bulk operations:`);
    console.log(`- Places marked inactive (foreign): ${inactiveCount}`);
    console.log(`- Places with area field changes: ${areaChangeCount}`);
    console.log(`- Places with text/description updates: ${textUpdatedCount}`);

    console.log('\nExecuting bulkWrite to MongoDB...');
    const result = await col.bulkWrite(bulkOps, { ordered: false });
    console.log(`bulkWrite completed successfully!`);
    console.log(`Matched: ${result.matchedCount}, Modified: ${result.modifiedCount}`);

    console.log('\nFinal Area Distribution in places_new:');
    console.table(newAreaCounts);

    await mongoose.disconnect();
    console.log('MongoDB connection closed.');
}

executeFullCalibration().catch(err => {
    console.error('Fatal error during calibration:', err);
    process.exit(1);
});
