require('dotenv').config({ path: '../.env' });
const mongoose = require('mongoose');
const uri = process.env.MONGODB_URI;

function escapeRegex(text) {
  return text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

mongoose.connect(uri).then(async () => {
  const coll = mongoose.connection.collection('places_new');

  async function search(q) {
    const cleanQ = q.trim();
    const escapedFull = escapeRegex(cleanQ);
    const words = cleanQ
      .replace(/[()[\]{},;:]/g, ' ')
      .split(/\s+/)
      .filter(w => w.length >= 2)
      .map(escapeRegex);

    const baseFilter = { status: 'active' };

    // Strategy A: Full match
    let places = await coll.find({
      ...baseFilter,
      $or: [
        { name: { $regex: escapedFull, $options: 'i' } },
        { search_keywords: { $regex: escapedFull, $options: 'i' } }
      ]
    }).limit(3).toArray();

    // Strategy B: All words $and
    if (places.length === 0 && words.length > 0) {
      places = await coll.find({
        ...baseFilter,
        $and: words.map(w => ({
          $or: [
            { name: { $regex: w, $options: 'i' } },
            { summary: { $regex: w, $options: 'i' } },
            { search_keywords: { $regex: w, $options: 'i' } },
            { address: { $regex: w, $options: 'i' } }
          ]
        }))
      }).limit(3).toArray();
    }

    // Strategy C: Distinctive words
    if (places.length === 0 && words.length > 0) {
      const commonStops = ['temple', 'park', 'drive', 'hall', 'road', 'street', 'center', 'centre', 'waterfront', 'penang', 'buddhist', 'george', 'town', 'pulau'];
      const distinctiveWords = words.filter(w => !commonStops.includes(w.toLowerCase()) && w.length >= 3);
      const searchWords = distinctiveWords.length > 0 ? distinctiveWords : words;

      places = await coll.find({
        ...baseFilter,
        $or: searchWords.map(w => ({
          $or: [
            { name: { $regex: w, $options: 'i' } },
            { search_keywords: { $regex: w, $options: 'i' } }
          ]
        }))
      }).limit(3).toArray();
    }

    console.log(`Query: "${q}" -> Found ${places.length}:`);
    places.forEach(p => console.log('  -> Name:', p.name, '| raw_hours:', p.raw_hours_text || JSON.stringify(p.opening_hours)));
  }

  await search("Dhammikarama Burmese Buddhist Temple");
  await search("Penang Bird Park (Seberang Jaya)");
  await search("Gurney Drive Hawker Center");
  await search("Butterworth Art Walk");

  process.exit(0);
});
