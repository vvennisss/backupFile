const mongoose = require('mongoose');

const placeSchema = new mongoose.Schema({
  place_name: { type: String, required: true },
  place_summary: { type: String, default: '' },
  place_category: { type: String, default: 'General', index: true },
  place_address: { type: String, default: '' },
  place_location: {
    type: {
      type: String,
      enum: ['Point'],
      required: true,
      default: 'Point'
    },
    coordinates: {
      type: [Number], // Stored as [longitude, latitude]
      required: true
    }
  },
  place_business_hours: { type: Object, default: {} },
  place_media: { type: Object, default: {} },
  place_geofence_radius: { type: Number, default: 50 }, // default 50 meters
  place_information: { type: Object, default: {} },
  // External reference ID to prevent duplicates on repeated runs
  external_place_id: { type: String, unique: true, sparse: true },
  hasStreetView: { type: Boolean, default: false },
  mapillaryImageId: { type: String, default: null },
  embedding: { type: [Number], default: undefined }
}, { timestamps: true });

// Geospatial index for radius and distance queries
placeSchema.index({ place_location: '2dsphere' });

placeSchema.index({ place_name: 'text', place_category: 'text', place_summary: 'text' });

module.exports = mongoose.model('Place', placeSchema);