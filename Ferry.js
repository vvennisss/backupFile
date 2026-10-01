const mongoose = require('mongoose');

const FerrySchema = new mongoose.Schema({
  name: {
    type: String,
    required: true,
    trim: true // "Pangkalan Sultan Abdul Halim" 或 "Pangkalan Raja Tun Uda"
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
  operator: {
    type: String,
    default: 'Penang Port'
  },
  phone: {
    type: String,
    default: '019-473 2363'
  },
  website: {
    type: String,
    default: 'https://www.penangport.com.my'
  },
  schedule: {
    firstFerry: String,
    lastFerry: String,
    weekdayDepartures: [String],
    weekendDepartures: [String]
  },
  isAvailable: {
    type: Boolean,
    default: true
  }
}, {
  timestamps: true
});

module.exports = mongoose.model('Ferry', FerrySchema);