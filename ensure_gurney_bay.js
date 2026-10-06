require('dotenv').config({ path: '../.env' });
const mongoose = require('mongoose');
const uri = process.env.MONGODB_URI;

mongoose.connect(uri).then(async () => {
  const coll = mongoose.connection.collection('places_new');

  const existing = await coll.findOne({ name: { $regex: 'Gurney Bay', $options: 'i' } });
  if (!existing) {
    console.log('Inserting Gurney Bay Waterfront Promenade...');
    const doc = {
      name: 'Gurney Bay Waterfront Promenade',
      area: 'George Town',
      primary_category: 'Nature & Parks',
      category: 'Nature & Parks',
      sub_categories: ['Nature & Parks', 'Attraction'],
      search_keywords: ['gurney bay waterfront promenade', 'gurney bay', 'nature & parks', 'george town', 'gurney drive', 'promenade'],
      place_location: {
        type: 'Point',
        coordinates: [100.3120, 5.4385]
      },
      address: 'Gurney Drive, 10250 George Town, Penang, Malaysia',
      summary: 'A premier waterfront park and vibrant public recreational space on the seafront of Gurney Drive featuring expansive walking tracks, children playgrounds, skate parks, and tranquil seaside viewing pavilions.',
      description: 'Gurney Bay Waterfront Promenade is a flagship seaside urban park stretching across the iconic Gurney foreshore. Featuring lush landscaped gardens, scenic walking tracks, skate parks, play areas, and stunning panoramic views of the Malacca Strait, it serves as a top open-air destination for evening strolls and sunset viewings.',
      opening_hours: {
        is_24_hours: true,
        monday: { is_closed: false, open: '00:00', close: '24:00' },
        tuesday: { is_closed: false, open: '00:00', close: '24:00' },
        wednesday: { is_closed: false, open: '00:00', close: '24:00' },
        thursday: { is_closed: false, open: '00:00', close: '24:00' },
        friday: { is_closed: false, open: '00:00', close: '24:00' },
        saturday: { is_closed: false, open: '00:00', close: '24:00' },
        sunday: { is_closed: false, open: '00:00', close: '24:00' }
      },
      raw_hours_text: 'Open 24 Hours',
      features: {
        has_aircon: false,
        is_wheelchair_accessible: true,
        has_parking: true,
        free_entry: true,
        wifi_available: false,
        is_halal: false,
        is_vegetarian_friendly: false,
        specialty_coffee: false,
        pet_friendly: true
      },
      ticket_fee: {
        is_free: true,
        amount_myr: 0
      },
      status: 'active',
      popularity_score: 95,
      rating: 4.6,
      reviews_count: 2450
    };
    await coll.insertOne(doc);
    console.log('Inserted Gurney Bay successfully!');
  } else {
    console.log('Gurney Bay already exists:', existing.name);
  }

  process.exit(0);
});
