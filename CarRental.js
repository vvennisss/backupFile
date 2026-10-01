const mongoose = require('mongoose');

const CarRentalSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true,
    trim: true
  },
  address: {
    type: String,
    default: 'Penang, Malaysia'
  },
  city: {
    type: String,
    default: 'Penang'
  },
  coordinates: {
    lat: { type: Number, required: true },
    lng: { type: Number, required: true }
  },
  phone: {
    type: String,
    default: ''
  },
  website: {
    type: String,
    default: ''
  },
  description: {
    type: String,
    default: ''
  },
  images: [{
    type: String
  }],
  isAvailable: {
    type: Boolean,
    default: true
  }
}, {
  timestamps: true
});

module.exports = mongoose.model('CarRental', CarRentalSchema);