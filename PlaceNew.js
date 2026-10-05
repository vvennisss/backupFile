const mongoose = require('mongoose');
const path = require('path');
const fs = require('fs');

const IMAGES_DIR = path.join(__dirname, '../public/images/places');

// Helper to convert base64 image string to file on disk and return relative URL
function persistBase64Image(val, identifier = 'place', suffix = '') {
  if (!val || typeof val !== 'string' || !val.startsWith('data:image')) {
    return val;
  }
  try {
    if (!fs.existsSync(IMAGES_DIR)) {
      fs.mkdirSync(IMAGES_DIR, { recursive: true });
    }
    const cleanId = String(identifier).replace(/[^a-zA-Z0-9_-]/g, '_');
    const filename = `${cleanId}${suffix}.jpg`;
    const fullPath = path.join(IMAGES_DIR, filename);
    const dataPart = val.replace(/^data:image\/\w+;base64,/, '');
    fs.writeFileSync(fullPath, Buffer.from(dataPart, 'base64'));
    return `/images/places/${filename}`;
  } catch (err) {
    console.error('Failed to convert base64 to image file:', err.message);
    return val;
  }
}

const noBase64Validator = {
  validator: function(v) {
    if (!v || typeof v !== 'string') return true;
    return !v.startsWith('data:image');
  },
  message: () => 'Base64 image strings must not be stored in places_new. Save image as a URL instead.'
};

// 1. 结构化单日营业时间子 Schema
const DayScheduleSchema = new mongoose.Schema({
  is_closed: { type: Boolean, default: false },
  open: { type: String, default: '09:00' },
  close: { type: String, default: '18:00' }
}, { _id: false });

// 2. 媒体图片子 Schema
const MediaImageSchema = new mongoose.Schema({
  url: { type: String, required: true, validate: noBase64Validator },
  caption: { type: String, default: '' },
  is_cover: { type: Boolean, default: false },
  source: { type: String, default: 'user' }
}, { _id: false });

// 3. 生产级 PlaceNew Schema
const placeNewSchema = new mongoose.Schema({
  // --- 外部 Google 地图 ID 与唯一标识 ---
  external_place_id: { type: String, unique: true, sparse: true, index: true }, // Google 地图 ID (如 ChIJ...)
  slug: { type: String, unique: true, sparse: true, index: true },

  // --- 命名体系 ---
  name: { type: String, required: [true, 'Place name is required'], trim: true, index: true },
  local_names: {
    zh: { type: String, default: '' },
    ms: { type: String, default: '' }
  },

  // --- 分类体系 ---
  primary_category: { 
    type: String, 
    required: true, 
    enum: [
      'Cafes',
      'Food & Dining',
      'Nightlife & Speakeasies',
      'Heritage & Culture',
      'Arts & Workshops',
      'Religious Sites',
      'Nature & Parks',
      'Family & Adventure',
      'Shopping & Markets',
      'Local Souvenirs',
      'Boutique Stays',
      'Wellness & Spa',
      'Entertainment',
      'Others'
    ],
    index: true 
  },
  sub_categories: [{ type: String, trim: true }],
  
  // --- 槟城区域区划 ---
  area: { 
    type: String, 
    required: true, 
    enum: [
      'George Town', 
      'Air Itam', 
      'Batu Ferringhi', 
      'Bayan Lepas', 
      'Gurney', 
      'Tanjung Tokong', 
      'Balik Pulau', 
      'Butterworth', 
      'Seberang Perai', 
      'Other'
    ],
    index: true 
  },
  address: { type: String, default: '', trim: true },

  // --- 地理空间坐标 (GeoJSON Point 规范) ---
  location: {
    type: {
      type: String,
      enum: ['Point'],
      required: true,
      default: 'Point'
    },
    coordinates: {
      type: [Number], // [经度, 纬度]
      required: true
    }
  },
  geofence_radius: { type: Number, default: 50 },

  // --- 介绍与推荐语 ---
  summary: { type: String, default: '' },
  description: { type: String, default: '' },
  summary_zh: { type: String, default: '' },
  description_zh: { type: String, default: '' },
  translated_at: { type: Date, default: null },
  translation_model: { type: String, default: null },
  avg_duration_minutes: { type: Number, default: 60 },

  // --- 结构化多媒体与 thumbnail ---
  place_media: {
    thumbnail: { type: String, required: true, default: '', validate: noBase64Validator },
    photos: [{ type: String, validate: noBase64Validator }]
  },
  cover_image: { type: String, default: '', validate: noBase64Validator },
  images: [MediaImageSchema],

  // --- 街景与 360° 全景更新状态 ---
  hasStreetView: { type: Boolean, default: false },
  isPano: { type: Boolean, default: false }, // 是否为 360° 全景
  mapillaryImageId: { type: String, default: null },
  streetViewUpdatedAt: { type: Date, default: null }, // 街景更新时间戳

  // --- 核心地点信息与联系方式 (place_information) ---
  place_information: {
    phone: { type: String, default: '' },
    website: { type: String, default: '' },
    rating: { type: Number, default: 4.5 },
    reviews_count: { type: Number, default: 0 },
    price_level: { type: String, default: 'RM 15–35' }
  },

  // --- 营业时间 ---
  opening_hours: {
    is_24_hours: { type: Boolean, default: false },
    monday: { type: DayScheduleSchema, default: () => ({}) },
    tuesday: { type: DayScheduleSchema, default: () => ({}) },
    wednesday: { type: DayScheduleSchema, default: () => ({}) },
    thursday: { type: DayScheduleSchema, default: () => ({}) },
    friday: { type: DayScheduleSchema, default: () => ({}) },
    saturday: { type: DayScheduleSchema, default: () => ({}) },
    sunday: { type: DayScheduleSchema, default: () => ({}) }
  },
  place_business_hours: { type: Object, default: {} },
  raw_hours_text: { type: String, default: '9:00 AM – 6:00 PM' },

  // --- 商业指标 ---
  rating: { type: Number, default: 4.5, min: 0, max: 5.0, index: true },
  review_count: { type: Number, default: 0 },
  popularity_score: { type: Number, default: 0, index: true },
  price_level: { type: Number, enum: [0, 1, 2, 3, 4], default: 1 },

  // --- 特色标签 ---
  features: {
    is_halal: { type: Boolean, default: false },
    is_vegetarian_friendly: { type: Boolean, default: false },
    has_aircon: { type: Boolean, default: true },
    is_wheelchair_accessible: { type: Boolean, default: true },
    has_parking: { type: Boolean, default: false },
    is_michelin: { type: Boolean, default: false },
    specialty_coffee: { type: Boolean, default: false },
    wifi_available: { type: Boolean, default: true }
  },
  search_keywords: [{ type: String, lowercase: true, trim: true }],

  status: { 
    type: String, 
    enum: ['active', 'draft', 'closed_permanently'], 
    default: 'active',
    index: true 
  },
  embedding: { type: [Number], select: false }
}, { 
  timestamps: true,
  collection: 'places_new',
  toJSON: { virtuals: true },
  toObject: { virtuals: true }
});

// --- 生产级核心索引 ---
placeNewSchema.index({ location: '2dsphere' });
placeNewSchema.index({ area: 1, primary_category: 1, rating: -1 });
placeNewSchema.index({ 
  name: 'text', 
  summary: 'text', 
  search_keywords: 'text' 
}, {
  weights: { name: 10, search_keywords: 5, summary: 2 }
});

// --- 向后兼容虚拟属性 (Virtuals for Backward Compatibility) ---
placeNewSchema.virtual('place_name').get(function() {
  return this.name;
});
placeNewSchema.virtual('place_category').get(function() {
  return this.primary_category;
});
placeNewSchema.virtual('place_address').get(function() {
  return this.address;
});
placeNewSchema.virtual('place_location').get(function() {
  return this.location;
});
placeNewSchema.virtual('place_geofence_radius').get(function() {
  return this.geofence_radius;
});
placeNewSchema.virtual('place_summary').get(function() {
  return this.summary;
});
placeNewSchema.virtual('has_street_view').get(function() {
  return this.hasStreetView;
});
placeNewSchema.virtual('mapillary_image_id').get(function() {
  return this.mapillaryImageId;
});

// --- 虚拟属性：当前是否营业 ---
placeNewSchema.virtual('is_open_now').get(function() {
  if (!this.opening_hours) return true;
  if (this.opening_hours.is_24_hours) return true;
  
  const days = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
  const now = new Date();
  const todayKey = days[now.getDay()];
  const todaySchedule = this.opening_hours[todayKey];
  
  if (!todaySchedule || todaySchedule.is_closed) return false;
  
  const currentMinutes = now.getHours() * 60 + now.getMinutes();
  const [openH, openM] = (todaySchedule.open || '09:00').split(':').map(Number);
  const [closeH, closeM] = (todaySchedule.close || '18:00').split(':').map(Number);
  
  return currentMinutes >= (openH * 60 + openM) && currentMinutes <= (closeH * 60 + closeM);
});

// --- 核心安全屏障：在存盘前自动拦截并持久化任何 Base64 图片，确保数据库只存 URL ---
placeNewSchema.pre('validate', function() {
  const id = this.external_place_id || this._id?.toString() || 'place_' + Date.now();
  if (this.place_media && this.place_media.thumbnail) {
    this.place_media.thumbnail = persistBase64Image(this.place_media.thumbnail, id);
  }
  if (this.cover_image) {
    this.cover_image = persistBase64Image(this.cover_image, id);
  }
  if (Array.isArray(this.images)) {
    this.images.forEach((img, idx) => {
      if (img && img.url) {
        img.url = persistBase64Image(img.url, id, idx > 0 ? `_${idx}` : '');
        if (img.source === 'base64') img.source = 'local';
      }
    });
  }
  if (this.place_media && Array.isArray(this.place_media.photos)) {
    this.place_media.photos = this.place_media.photos.map((p, idx) => {
      return persistBase64Image(p, id, idx > 0 ? `_p${idx}` : '');
    });
  }
});

placeNewSchema.pre(['findOneAndUpdate', 'updateOne'], function() {
  const update = this.getUpdate();
  if (update) {
    const target = update.$set || update;
    const id = target.external_place_id || this.getQuery()?._id || 'place_' + Date.now();
    if (target['place_media.thumbnail']) {
      target['place_media.thumbnail'] = persistBase64Image(target['place_media.thumbnail'], id);
    }
    if (target.place_media?.thumbnail) {
      target.place_media.thumbnail = persistBase64Image(target.place_media.thumbnail, id);
    }
    if (target.cover_image) {
      target.cover_image = persistBase64Image(target.cover_image, id);
    }
    if (Array.isArray(target.images)) {
      target.images.forEach((img, idx) => {
        if (img && img.url) {
          img.url = persistBase64Image(img.url, id, idx > 0 ? `_${idx}` : '');
          if (img.source === 'base64') img.source = 'local';
        }
      });
    }
  }
});

module.exports = mongoose.model('PlaceNew', placeNewSchema);
