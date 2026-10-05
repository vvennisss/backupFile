const mongoose = require('mongoose');
require('dotenv').config({ path: 'C:/Users/Vennis/OneDrive/Desktop/0824-setup-mongoDB-places-table-nodejs/.env' });

function determineAccurateArea(place) {
    if (!place) return null;
    const addr = (place.address || place.place_address || '').toLowerCase();
    const name = (place.name || place.place_name || '').toLowerCase();

    // 1. Teluk Bahang landmarks / addresses
    if (addr.includes('teluk bahang') || addr.includes('11050') || name.includes('escape') || name.includes('entopia') || name.includes('tropical spice') || name.includes('taman negara')) {
        return 'Teluk Bahang';
    }

    // 2. Air Itam landmarks / addresses
    if ((addr.includes('air itam') || addr.includes('ayer itam') || addr.includes('11500') || name.includes('kek lok si') || name.includes('penang hill') || name.includes('bukit bendera')) && !addr.includes('11000') && !addr.includes('11010')) {
        return 'Air Itam';
    }

    // 3. Balik Pulau addresses (MUST contain Balik Pulau or Balik Pulau postcodes without saying Bayan Lepas)
    if (addr.includes('balik pulau') || (name.includes('balik pulau') && !addr.includes('11500'))) {
        return 'Balik Pulau';
    }
    if ((addr.includes('11000') || addr.includes('11010') || addr.includes('11020')) && !addr.includes('bayan lepas') && !addr.includes('air itam') && !addr.includes('ayer itam')) {
        return 'Balik Pulau';
    }

    // 4. Bayan Lepas addresses
    if (addr.includes('bayan lepas') || addr.includes('bayan baru') || addr.includes('11900') || addr.includes('11920') || addr.includes('11950') || addr.includes('11960') || addr.includes('teluk kumbar') || addr.includes('gertak sanggul') || addr.includes('sungai ara') || addr.includes('relau') || addr.includes('bukit jambul') || addr.includes('batu maung')) {
        return 'Bayan Lepas';
    }

    // 5. Batu Ferringhi addresses
    if (addr.includes('batu ferringhi') || addr.includes('batu feringghi') || addr.includes('11100')) {
        return 'Batu Ferringhi';
    }

    // 6. Tanjung Bungah addresses
    if (addr.includes('tanjung bungah') || addr.includes('tanjung bunga') || addr.includes('11200')) {
        return 'Tanjung Bungah';
    }

    // 7. Tanjung Tokong addresses
    if (addr.includes('tanjung tokong') || addr.includes('straits quay') || addr.includes('10470')) {
        return 'Tanjung Tokong';
    }

    // 8. Pulau Tikus addresses
    if (addr.includes('pulau tikus') || addr.includes('10350')) {
        return 'Pulau Tikus';
    }

    // 9. George Town addresses
    if (addr.includes('george town') || addr.includes('georgetown') || addr.includes('10000') || addr.includes('10050') || addr.includes('10100') || addr.includes('10150') || addr.includes('10200') || addr.includes('10300') || addr.includes('10400') || addr.includes('10450')) {
        return 'George Town';
    }

    return null;
}

async function run() {
    await mongoose.connect(process.env.MONGODB_URI);
    const col = mongoose.connection.db.collection('places_new');

    const allPlaces = await col.find({ status: 'active' }).toArray();
    let updatedCount = 0;

    for (const p of allPlaces) {
        const accurate = determineAccurateArea(p);
        if (accurate && accurate !== p.area) {
            const oldArea = p.area;
            const updateDoc = { area: accurate };

            // Update summary if it references old area
            if (p.summary && typeof p.summary === 'string' && oldArea) {
                const oldRegex = new RegExp(`\\bin ${oldArea}\\b`, 'gi');
                if (oldRegex.test(p.summary)) {
                    updateDoc.summary = p.summary.replace(oldRegex, `in ${accurate}`);
                }
            }

            // Update description if it references old area
            if (p.description && typeof p.description === 'string' && oldArea) {
                const oldRegex = new RegExp(`\\bin ${oldArea}\\b`, 'gi');
                if (oldRegex.test(p.description)) {
                    updateDoc.description = p.description.replace(oldRegex, `in ${accurate}`);
                }
            }

            // Update search_keywords
            if (Array.isArray(p.search_keywords)) {
                updateDoc.search_keywords = p.search_keywords.map(kw => {
                    if (kw.toLowerCase() === oldArea.toLowerCase()) return accurate.toLowerCase();
                    return kw;
                });
            }

            await col.updateOne({ _id: p._id }, { $set: updateDoc });
            updatedCount++;
        }
    }

    console.log(`✅ Successfully calibrated ${updatedCount} places in places_new.`);

    // Verify Gemuruh Beach and Tasik Teluk Bayu
    const gem = await col.findOne({ name: 'Gemuruh Beach' });
    console.log('Gemuruh Beach:', { area: gem.area, summary: gem.summary });
    const tasik = await col.findOne({ name: 'Tasik Teluk Bayu' });
    console.log('Tasik Teluk Bayu:', { area: tasik.area, summary: tasik.summary });

    await mongoose.disconnect();
}
run();
