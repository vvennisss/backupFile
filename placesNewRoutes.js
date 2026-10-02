const express = require('express');
const router = express.Router();
const PlaceNew = require('../models/PlaceNew');

/**
 * 1. 关键词与多维度搜索接口
 * GET /api/v2/places/search?q=laksa&category=Food%20%26%20Dining&area=Air%20Itam&limit=20
 */
router.get('/search', async (req, res) => {
  try {
    const { q, category, area, limit = 20, page = 1 } = req.query;
    const filter = { status: 'active' };

    if (category) {
      filter.primary_category = category;
    }

    if (area) {
      filter.area = area;
    }

    if (q && q.trim()) {
      const words = q.trim().split(/\s+/).filter(Boolean);
      // 复合文本与正则多词匹配
      filter.$and = words.map(w => ({
        $or: [
          { name: { $regex: w, $options: 'i' } },
          { summary: { $regex: w, $options: 'i' } },
          { search_keywords: { $regex: w, $options: 'i' } },
          { address: { $regex: w, $options: 'i' } }
        ]
      }));
    }

    const pageSize = Math.min(Number(limit) || 20, 100);
    const skip = (Math.max(Number(page) || 1, 1) - 1) * pageSize;

    const [places, total] = await Promise.all([
      PlaceNew.find(filter)
        .sort({ popularity_score: -1, rating: -1 })
        .skip(skip)
        .limit(pageSize),
      PlaceNew.countDocuments(filter)
    ]);

    res.json({
      status: 'success',
      total,
      page: Number(page) || 1,
      limit: pageSize,
      count: places.length,
      data: places
    });
  } catch (error) {
    console.error('Error in /api/v2/places/search:', error);
    res.status(500).json({ status: 'error', message: error.message });
  }
});

/**
 * 2. 附近地点搜索（基于真实 2dsphere 索引的高性能距离计算）
 * GET /api/v2/places/nearby?lng=100.3327&lat=5.4164&radius=3000&category=Food%20%26%20Dining
 */
router.get('/nearby', async (req, res) => {
  try {
    const { lng, lat, radius = 3000, category, limit = 20 } = req.query;

    if (!lng || !lat) {
      return res.status(400).json({ status: 'error', message: 'Missing required query params: lng and lat' });
    }

    const parsedLng = parseFloat(lng);
    const parsedLat = parseFloat(lat);
    const parsedRadius = parseFloat(radius);

    const geoNearOptions = {
      near: { type: 'Point', coordinates: [parsedLng, parsedLat] },
      distanceField: 'distance_meters',
      maxDistance: parsedRadius,
      spherical: true,
      query: { status: 'active' }
    };

    if (category) {
      geoNearOptions.query.primary_category = category;
    }

    const places = await PlaceNew.aggregate([
      { $geoNear: geoNearOptions },
      { $limit: Math.min(Number(limit) || 20, 100) }
    ]);

    res.json({
      status: 'success',
      count: places.length,
      data: places
    });
  } catch (error) {
    console.error('Error in /api/v2/places/nearby:', error);
    res.status(500).json({ status: 'error', message: error.message });
  }
});

/**
 * 3. 按槟城区域聚合/查询接口
 * GET /api/v2/places/by-area?area=George%20Town&limit=30
 */
router.get('/by-area', async (req, res) => {
  try {
    const { area, limit = 30 } = req.query;
    if (!area) {
      return res.status(400).json({ status: 'error', message: 'Missing area parameter' });
    }

    const places = await PlaceNew.find({ area, status: 'active' })
      .sort({ rating: -1, popularity_score: -1 })
      .limit(Number(limit) || 30);

    res.json({
      status: 'success',
      area,
      count: places.length,
      data: places
    });
  } catch (error) {
    console.error('Error in /api/v2/places/by-area:', error);
    res.status(500).json({ status: 'error', message: error.message });
  }
});

/**
 * 4. 单一地点详情接口
 * GET /api/v2/places/:id
 */
router.get('/:id', async (req, res) => {
  try {
    const place = await PlaceNew.findById(req.params.id);
    if (!place) {
      return res.status(404).json({ status: 'error', message: 'Place not found' });
    }
    res.json({
      status: 'success',
      data: place
    });
  } catch (error) {
    console.error('Error in /api/v2/places/:id:', error);
    res.status(500).json({ status: 'error', message: error.message });
  }
});

module.exports = router;
