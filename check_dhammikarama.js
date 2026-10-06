require('dotenv').config({ path: '../.env' });
const mongoose = require('mongoose');
const uri = process.env.MONGODB_URI;

mongoose.connect(uri).then(async () => {
  const coll = mongoose.connection.collection('places_new');
  const p = await coll.findOne({ name: { $regex: 'Dhammikarama', $options: 'i' } });
  console.log('--- Place doc ---');
  console.log('Name:', p.name);
  console.log('Summary:', p.summary);
  console.log('Keywords:', p.search_keywords);
  console.log('Address:', p.address);
  console.log('Status:', p.status);

  // Test the filter with "Dhammikarama Burmese Buddhist Temple"
  const q = "Dhammikarama Burmese Buddhist Temple";
  const words = q.trim().split(/\s+/).filter(Boolean);
  const filter = {
    status: 'active',
    $and: words.map(w => ({
      $or: [
        { name: { $regex: w, $options: 'i' } },
        { summary: { $regex: w, $options: 'i' } },
        { search_keywords: { $regex: w, $options: 'i' } },
        { address: { $regex: w, $options: 'i' } }
      ]
    }))
  };
  const match = await coll.findOne(filter);
  console.log('Did "Dhammikarama Burmese Buddhist Temple" match?', !!match);
  if (!match) {
    for (const w of words) {
      const singleMatch = await coll.findOne({
        _id: p._id,
        $or: [
          { name: { $regex: w, $options: 'i' } },
          { summary: { $regex: w, $options: 'i' } },
          { search_keywords: { $regex: w, $options: 'i' } },
          { address: { $regex: w, $options: 'i' } }
        ]
      });
      console.log(`Word "${w}" matches:`, !!singleMatch);
    }
  }

  process.exit(0);
});
