const mongoose = require('mongoose');

const RapidBusSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true,
    trim: true // 例如: "Hab Rapid Penang Weld Quay" 或 "Komtar Bus Terminal"
  },
  type: {
    type: String,
    enum: ['Bus Stop', 'Bus Terminal'],
    default: 'Bus Stop'
  },
  ref: {
    type: String, // 巴士站编号或经过的路线 (例如: "101, 102, 201")
    default: ''
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
    default: 'Rapid Penang'
  },
  isAvailable: {
    type: Boolean,
    default: true
  }
}, {
  timestamps: true
});

module.exports = mongoose.model('RapidBus', RapidBusSchema);