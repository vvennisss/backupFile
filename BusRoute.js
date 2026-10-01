const mongoose = require('mongoose');

const busRouteSchema = new mongoose.Schema({
  bus_number: String,
  zone: String,
  origin: String,
  destination: String,
  first_trip: String,
  last_trip: String,
  frequency: String,
  shapes: mongoose.Schema.Types.Mixed,
  stops: mongoose.Schema.Types.Mixed
}, { timestamps: true });

module.exports = mongoose.models.BusRoute || mongoose.model('BusRoute', busRouteSchema);
