const mongoose = require('mongoose');

const AccommodationSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true,
    trim: true
  },
  type: {
    type: String,
    enum: ['Hotel', 'Resort', 'Homestay', 'Hostel', 'Villa'],
    default: 'Hotel'
  },
  address: {
    type: String,
    required: true
  },
  city: {
    type: String,
    default: 'Penang'
  },
  images: [{
    type: String // 存放图片 URL 或 assets 路径
  }],
  facilities: [{
    type: String // 例如 ['Free WiFi', 'Swimming Pool', 'Parking', 'Air Conditioning']
  }],
  coordinates: {
    lat: { type: Number, required: true },
    lng: { type: Number, required: true }
  },
  description: {
    type: String,
    default: ''
  },
  phone: {
    type: String,
    default: ''
  },
  website: {
    type: String,
    default: ''
  },
  isAvailable: {
    type: Boolean,
    default: true
  }
}, {
  timestamps: true // 自动添加 createdAt 和 updatedAt
});

module.exports = mongoose.model('Accommodation', AccommodationSchema);