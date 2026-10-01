const mongoose = require('mongoose');

const uri = 'mongodb+srv://weixun:VennisFYP2026@cluster0.tohpl4e.mongodb.net/?appName=Cluster0';

async function main() {
  await mongoose.connect(uri, { dbName: 'test' });
  const db = mongoose.connection.db;
  const col = db.collection('places_new');

  const areas = [
    'George Town',
    'Air Itam',
    'Batu Ferringhi',
    'Gurney Drive',
    'Tanjung Tokong',
    'Tanjung Bungah',
    'Pulau Tikus',
    'Teluk Bahang',
    'Balik Pulau',
    'Bayan Lepas',
    'Bayan Baru',
    'Jelutong',
    'Gelugor',
    'Butterworth',
    'Seberang Perai'
  ];

  const results = {};

  for (const area of areas) {
    const places = await col.find({
      $or: [
        { area: new RegExp('^' + area + '$', 'i') },
        { area: new RegExp(area, 'i') },
        { address: new RegExp(area, 'i') }
      ]
    })
    .sort({ rating: -1, review_count: -1 })
    .limit(6)
    .project({
      name: 1,
      primary_category: 1,
      place_category: 1,
      rating: 1,
      review_count: 1,
      summary: 1,
      area: 1
    })
    .toArray();

    results[area] = places.map(p => ({
      name: p.name,
      category: p.primary_category || p.place_category || 'Attraction',
      rating: p.rating,
      reviews: p.review_count,
      summary: p.summary ? p.summary.substring(0, 120) + '...' : ''
    }));
  }

  console.log(JSON.stringify(results, null, 2));
  process.exit(0);
}

main().catch(console.error);
