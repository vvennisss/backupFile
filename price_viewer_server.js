/**
 * Web Interface Server: Kia Kia Penang - places_new Price Level Explorer
 *
 * Usage:
 *   node price_viewer_server.js
 *
 * Then open your browser at:
 *   http://localhost:4040
 */

const http = require('http');
const path = require('path');
const fs = require('fs');

// Helper to resolve dependencies from admin_web/node_modules
function resolveModule(moduleName) {
  try {
    return require(moduleName);
  } catch (err) {
    const adminPath = path.resolve(__dirname, 'admin_web/node_modules', moduleName);
    if (fs.existsSync(adminPath)) {
      return require(adminPath);
    }
    throw new Error(
      `Could not locate "${moduleName}". Please ensure dependencies in "admin_web" are installed (npm install).`
    );
  }
}

// Load environment variables
const dotenv = resolveModule('dotenv');
const envCandidate = path.resolve(__dirname, 'admin_web/.env');
if (fs.existsSync(envCandidate)) {
  dotenv.config({ path: envCandidate });
} else {
  dotenv.config();
}

const mongoose = resolveModule('mongoose');
const express = resolveModule('express');
const cors = resolveModule('cors');

const app = express();
const PORT = process.env.PRICE_EXPLORER_PORT || 4040;
const mongoUri =
  process.env.MONGODB_URI ||
  'mongodb+srv://weixun:VennisFYP2026@cluster0.tohpl4e.mongodb.net/test?appName=Cluster0';

app.use(cors());
app.use(express.json());

let isDbConnected = false;
let placesCol = null;

// Connect to MongoDB
mongoose
  .connect(mongoUri, { serverSelectionTimeoutMS: 12000 })
  .then(() => {
    isDbConnected = true;
    placesCol = mongoose.connection.db.collection('places_new');
    console.log(`✅ Connected to MongoDB Atlas! Serving places_new on http://localhost:${PORT}`);
  })
  .catch((err) => {
    console.error('⚠️ MongoDB connection error:', err.message);
  });

// Helper: Normalize place document & extract price_level
function normalizePlace(doc) {
  let price = null;
  let source = null;

  if (doc.place_information && doc.place_information.price_level !== undefined && doc.place_information.price_level !== null) {
    const str = String(doc.place_information.price_level).trim();
    if (str.length > 0 && str.toLowerCase() !== 'n/a' && str.toLowerCase() !== 'null') {
      price = str;
      source = 'place_information';
    }
  }

  // Fallback to root price_level if place_information didn't have a valid value
  if (!price && doc.price_level !== undefined && doc.price_level !== null) {
    const str = String(doc.price_level).trim();
    if (str.length > 0 && str.toLowerCase() !== 'null') {
      price = str;
      source = 'root';
    }
  }

  let subs = [];
  if (Array.isArray(doc.sub_categories)) {
    subs = doc.sub_categories.map((s) => String(s).trim()).filter(Boolean);
  } else if (typeof doc.sub_categories === 'string' && doc.sub_categories.trim()) {
    subs = [doc.sub_categories.trim()];
  }

  return {
    _id: String(doc._id),
    name: doc.name || 'Unnamed Place',
    primary_category: (doc.primary_category && String(doc.primary_category).trim()) || 'Uncategorized',
    sub_categories: subs,
    price_level: price,
    has_price_value: !!price,
    price_source: source,
    rating: (doc.place_information && doc.place_information.rating) || doc.rating || 0,
    reviews_count: (doc.place_information && doc.place_information.reviews_count) || 0,
    area: doc.area || 'Penang',
    address: doc.address || '',
    raw_hours_text: doc.raw_hours_text || '',
    ticket_fee: doc.ticket_fee || null
  };
}

// -------------------------------------------------------------
// API: Categories list with counts
// -------------------------------------------------------------
app.get('/api/categories', async (req, res) => {
  try {
    if (!isDbConnected || !placesCol) {
      return res.status(503).json({ error: 'Database not connected yet' });
    }

    const categories = await placesCol.aggregate([
      {
        $group: {
          _id: { $ifNull: ['$primary_category', 'Uncategorized'] },
          total: { $sum: 1 },
          hasPrice: {
            $sum: {
              $cond: [
                {
                  $or: [
                    {
                      $and: [
                        { $ne: ['$place_information.price_level', null] },
                        { $ne: ['$place_information.price_level', ''] },
                        { $ne: ['$place_information.price_level', 'N/A'] }
                      ]
                    },
                    {
                      $and: [
                        { $ne: ['$price_level', null] },
                        { $ne: ['$price_level', ''] }
                      ]
                    }
                  ]
                },
                1,
                0
              ]
            }
          }
        }
      },
      { $sort: { _id: 1 } }
    ]).toArray();

    res.json({
      success: true,
      data: categories.map((c) => ({
        name: c._id,
        total: c.total,
        hasPrice: c.hasPrice
      }))
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// -------------------------------------------------------------
// API: Places with flexible filtering
// -------------------------------------------------------------
app.get('/api/places', async (req, res) => {
  try {
    if (!isDbConnected || !placesCol) {
      return res.status(503).json({ error: 'Database not connected yet' });
    }

    const { category, has_price = 'true', price_level, search } = req.query;

    const mongoQuery = {};

    if (category && category !== 'ALL') {
      mongoQuery.primary_category = category;
    }

    if (search && search.trim()) {
      const regex = new RegExp(search.trim(), 'i');
      mongoQuery.$or = [
        { name: regex },
        { area: regex },
        { address: regex },
        { sub_categories: regex }
      ];
    }

    const rawDocs = await placesCol.find(mongoQuery).sort({ primary_category: 1, name: 1 }).toArray();
    let normalized = rawDocs.map(normalizePlace);

    // Filter by has_price_value (default true as requested)
    if (has_price === 'true' || has_price === '1') {
      normalized = normalized.filter((p) => p.has_price_value);
    } else if (has_price === 'false' || has_price === '0') {
      normalized = normalized.filter((p) => !p.has_price_value);
    }

    // Filter by specific price_level if requested
    if (price_level && price_level !== 'ALL') {
      normalized = normalized.filter((p) => p.price_level === price_level);
    }

    // Generate price level distribution for current filtered set
    const priceDistribution = {};
    for (const p of normalized) {
      const lvl = p.price_level || '(No Value)';
      priceDistribution[lvl] = (priceDistribution[lvl] || 0) + 1;
    }

    res.json({
      success: true,
      totalCount: normalized.length,
      priceDistribution,
      data: normalized
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// -------------------------------------------------------------
// Serve Web UI Single Page App
// -------------------------------------------------------------
app.get('/', (req, res) => {
  res.send(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Kia Kia Penang - Places Price Level Explorer</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=JetBrains+Mono:wght@500;600&display=swap" rel="stylesheet">
  <style>
    :root {
      --primary: #304FFE; /* Indigo Accent 700 */
      --primary-hover: #1e3bb3;
      --primary-light: #eef2ff;
      --amber: #f59e0b; /* Rich Amber */
      --amber-dark: #b45309;
      --amber-light: #fef3c7;
      --bg: #f8fafc;
      --card-bg: #ffffff;
      --border: #e2e8f0;
      --text-main: #1e293b;
      --text-muted: #64748b;
      --radius: 12px;
      --shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.05), 0 2px 4px -2px rgba(0, 0, 0, 0.05);
      --shadow-lg: 0 10px 15px -3px rgba(0, 0, 0, 0.08), 0 4px 6px -4px rgba(0, 0, 0, 0.04);
    }

    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: 'Plus Jakarta Sans', system-ui, -apple-system, sans-serif;
      background: var(--bg);
      color: var(--text-main);
      line-height: 1.5;
      padding-bottom: 50px;
    }

    /* Top Nav */
    header {
      background: #ffffff;
      border-bottom: 1px solid var(--border);
      position: sticky;
      top: 0;
      z-index: 100;
      box-shadow: 0 1px 3px rgba(0,0,0,0.03);
    }
    .header-inner {
      max-width: 1400px;
      margin: 0 auto;
      padding: 16px 24px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 16px;
      flex-wrap: wrap;
    }
    .brand {
      display: flex;
      align-items: center;
      gap: 12px;
    }
    .brand-icon {
      width: 42px;
      height: 42px;
      background: var(--primary);
      color: white;
      border-radius: 10px;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 22px;
      font-weight: 800;
      box-shadow: 0 4px 10px rgba(48, 79, 254, 0.3);
    }
    .brand-text h1 {
      font-size: 19px;
      font-weight: 800;
      letter-spacing: -0.02em;
      color: #0f172a;
    }
    .brand-text p {
      font-size: 12px;
      color: var(--text-muted);
      font-weight: 500;
    }
    .status-badge {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      padding: 6px 12px;
      border-radius: 20px;
      background: #ecfdf5;
      color: #047857;
      font-size: 12px;
      font-weight: 600;
      border: 1px solid #a7f3d0;
    }
    .pulse-dot {
      width: 8px;
      height: 8px;
      background: #10b981;
      border-radius: 50%;
      animation: pulse 1.5s infinite;
    }
    @keyframes pulse {
      0% { transform: scale(0.95); opacity: 0.8; }
      50% { transform: scale(1.3); opacity: 1; }
      100% { transform: scale(0.95); opacity: 0.8; }
    }

    /* Main Container */
    .container {
      max-width: 1400px;
      margin: 24px auto;
      padding: 0 24px;
    }

    /* Control Panel Card */
    .controls-card {
      background: var(--card-bg);
      border-radius: var(--radius);
      padding: 20px 24px;
      border: 1px solid var(--border);
      box-shadow: var(--shadow);
      margin-bottom: 24px;
    }
    .filter-grid {
      display: grid;
      grid-template-columns: 2fr 1.5fr 2fr auto;
      gap: 16px;
      align-items: end;
    }
    @media (max-width: 960px) {
      .filter-grid { grid-template-columns: 1fr 1fr; }
    }
    @media (max-width: 640px) {
      .filter-grid { grid-template-columns: 1fr; }
    }

    .form-group {
      display: flex;
      flex-direction: column;
      gap: 6px;
    }
    .form-group label {
      font-size: 13px;
      font-weight: 700;
      color: #334155;
    }
    select, input[type="text"] {
      padding: 10px 14px;
      border-radius: 8px;
      border: 1.5px solid var(--border);
      font-size: 14px;
      font-family: inherit;
      color: var(--text-main);
      background: white;
      transition: all 0.15s ease;
      outline: none;
    }
    select:focus, input[type="text"]:focus {
      border-color: var(--primary);
      box-shadow: 0 0 0 3px rgba(48, 79, 254, 0.15);
    }

    /* Checkbox Switch */
    .toggle-group {
      display: flex;
      align-items: center;
      gap: 10px;
      padding: 10px 14px;
      background: #f1f5f9;
      border-radius: 8px;
      height: 44px;
      cursor: pointer;
      user-select: none;
    }
    .toggle-group input[type="checkbox"] {
      width: 18px;
      height: 18px;
      accent-color: var(--primary);
      cursor: pointer;
    }
    .toggle-group span {
      font-size: 13px;
      font-weight: 700;
      color: #1e293b;
    }

    /* Price Pills Bar */
    .distribution-bar {
      margin-top: 18px;
      padding-top: 16px;
      border-top: 1px dashed var(--border);
    }
    .distribution-title {
      font-size: 12px;
      font-weight: 700;
      color: var(--text-muted);
      text-transform: uppercase;
      letter-spacing: 0.05em;
      margin-bottom: 10px;
    }
    .pill-list {
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
    }
    .pill-btn {
      background: #f8fafc;
      border: 1px solid var(--border);
      padding: 5px 12px;
      border-radius: 20px;
      font-size: 12px;
      font-weight: 600;
      color: #334155;
      cursor: pointer;
      transition: all 0.15s ease;
      display: inline-flex;
      align-items: center;
      gap: 6px;
    }
    .pill-btn:hover {
      border-color: var(--primary);
      background: var(--primary-light);
      color: var(--primary);
    }
    .pill-btn.active {
      background: var(--primary);
      color: white;
      border-color: var(--primary);
      box-shadow: 0 2px 6px rgba(48, 79, 254, 0.3);
    }
    .pill-count {
      background: rgba(0,0,0,0.06);
      padding: 1px 6px;
      border-radius: 10px;
      font-size: 11px;
    }
    .pill-btn.active .pill-count {
      background: rgba(255,255,255,0.25);
      color: white;
    }

    /* Stats & Toolbar */
    .stats-toolbar {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 16px;
      flex-wrap: wrap;
      gap: 12px;
    }
    .stats-counter {
      font-size: 15px;
      font-weight: 700;
      color: #0f172a;
    }
    .stats-counter span {
      color: var(--primary);
    }
    .actions-group {
      display: flex;
      gap: 10px;
    }
    .btn {
      padding: 8px 16px;
      border-radius: 8px;
      font-size: 13px;
      font-weight: 600;
      font-family: inherit;
      cursor: pointer;
      display: inline-flex;
      align-items: center;
      gap: 6px;
      transition: all 0.15s ease;
      border: none;
    }
    .btn-outline {
      background: white;
      border: 1.5px solid var(--border);
      color: #334155;
    }
    .btn-outline:hover {
      background: #f1f5f9;
      border-color: #cbd5e1;
    }
    .btn-primary {
      background: var(--primary);
      color: white;
    }
    .btn-primary:hover {
      background: var(--primary-hover);
    }

    /* Data Table Card */
    .table-card {
      background: var(--card-bg);
      border-radius: var(--radius);
      border: 1px solid var(--border);
      box-shadow: var(--shadow);
      overflow: hidden;
    }
    .table-responsive {
      overflow-x: auto;
    }
    table {
      width: 100%;
      border-collapse: collapse;
      text-align: left;
      font-size: 13.5px;
    }
    thead {
      background: #f8fafc;
      border-bottom: 1.5px solid var(--border);
    }
    th {
      padding: 14px 16px;
      font-size: 12px;
      font-weight: 700;
      color: #475569;
      text-transform: uppercase;
      letter-spacing: 0.04em;
      white-space: nowrap;
    }
    td {
      padding: 14px 16px;
      border-bottom: 1px solid var(--border);
      vertical-align: middle;
    }
    tr:hover td {
      background: #f8fafc;
    }

    /* Badges */
    .badge {
      display: inline-flex;
      align-items: center;
      gap: 4px;
      padding: 3px 8px;
      border-radius: 6px;
      font-size: 12px;
      font-weight: 600;
      white-space: nowrap;
    }
    .badge-primary {
      background: var(--primary-light);
      color: var(--primary);
      border: 1px solid #c7d2fe;
    }
    .badge-amber {
      background: var(--amber-light);
      color: var(--amber-dark);
      border: 1px solid #fde68a;
    }
    .badge-price {
      font-family: 'JetBrains Mono', monospace;
      font-size: 12.5px;
      font-weight: 700;
      padding: 4px 10px;
      border-radius: 6px;
    }
    .price-free {
      background: #dcfce7;
      color: #15803d;
      border: 1px solid #86efac;
    }
    .price-paid {
      background: #fef3c7;
      color: #b45309;
      border: 1px solid #fcd34d;
    }
    .price-high {
      background: #fee2e2;
      color: #b91c1c;
      border: 1px solid #fca5a5;
    }
    .price-none {
      background: #f1f5f9;
      color: #94a3b8;
      border: 1px dashed #cbd5e1;
    }

    .sub-cat-pill {
      display: inline-block;
      font-size: 11px;
      background: #f1f5f9;
      color: #475569;
      padding: 2px 6px;
      border-radius: 4px;
      margin: 2px 2px 2px 0;
    }

    .rating-box {
      display: inline-flex;
      align-items: center;
      gap: 4px;
      font-weight: 700;
      color: #1e293b;
    }
    .rating-star { color: #f59e0b; }

    /* Empty state */
    .empty-state {
      text-align: center;
      padding: 60px 20px;
      color: var(--text-muted);
    }
    .empty-state h3 {
      font-size: 17px;
      font-weight: 700;
      color: #334155;
      margin-bottom: 6px;
    }

    /* Modal */
    .modal-backdrop {
      display: none;
      position: fixed;
      top: 0; left: 0; right: 0; bottom: 0;
      background: rgba(15, 23, 42, 0.5);
      z-index: 1000;
      backdrop-filter: blur(2px);
      align-items: center;
      justify-content: center;
      padding: 20px;
    }
    .modal-backdrop.show { display: flex; }
    .modal-box {
      background: white;
      border-radius: var(--radius);
      max-width: 600px;
      width: 100%;
      padding: 24px;
      box-shadow: var(--shadow-lg);
      max-height: 90vh;
      overflow-y: auto;
    }
    .modal-header {
      display: flex;
      justify-content: space-between;
      align-items: flex-start;
      margin-bottom: 16px;
      padding-bottom: 12px;
      border-bottom: 1px solid var(--border);
    }
    .modal-close {
      background: none;
      border: none;
      font-size: 20px;
      cursor: pointer;
      color: var(--text-muted);
    }
    .modal-row {
      display: flex;
      margin-bottom: 10px;
      font-size: 13.5px;
    }
    .modal-label {
      width: 140px;
      font-weight: 700;
      color: #64748b;
      flex-shrink: 0;
    }
    .modal-val {
      color: #1e293b;
      font-weight: 500;
      word-break: break-word;
    }
  </style>
</head>
<body>

  <!-- Top Navigation Header -->
  <header>
    <div class="header-inner">
      <div class="brand">
        <div class="brand-icon">🏷️</div>
        <div class="brand-text">
          <h1>Kia Kia Penang • Price Level Explorer</h1>
          <p>MongoDB Atlas &bull; places_new Collection Authority</p>
        </div>
      </div>
      <div class="status-badge">
        <div class="pulse-dot"></div>
        Live MongoDB Connected
      </div>
    </div>
  </header>

  <div class="container">

    <!-- Filter Control Card -->
    <div class="controls-card">
      <div class="filter-grid">
        
        <!-- Category Filter -->
        <div class="form-group">
          <label for="categorySelect">📁 Primary Category</label>
          <select id="categorySelect">
            <option value="ALL">All Categories (Loading...)</option>
          </select>
        </div>

        <!-- Price Level Filter -->
        <div class="form-group">
          <label for="priceSelect">💰 Specific Price Level</label>
          <select id="priceSelect">
            <option value="ALL">All Price Levels</option>
          </select>
        </div>

        <!-- Search Input -->
        <div class="form-group">
          <label for="searchInput">🔍 Search Name / Area</label>
          <input type="text" id="searchInput" placeholder="Type place name or keywords...">
        </div>

        <!-- Only Price Level Has Value Toggle -->
        <div class="form-group">
          <label>&nbsp;</label>
          <label class="toggle-group" title="When checked, hides places where price_level is missing, null, or empty">
            <input type="checkbox" id="hasPriceCheckbox" checked>
            <span>Only Has Value</span>
          </label>
        </div>

      </div>

      <!-- Quick Filter Pills for Price Levels -->
      <div class="distribution-bar">
        <div class="distribution-title">Current Filter Price Breakdown (Click to filter):</div>
        <div class="pill-list" id="pricePillsList">
          <span style="font-size: 13px; color: #94a3b8;">Loading price levels...</span>
        </div>
      </div>
    </div>

    <!-- Stats & Actions Toolbar -->
    <div class="stats-toolbar">
      <div class="stats-counter" id="statsCounter">
        Showing <span>0</span> places
      </div>
      <div class="actions-group">
        <button class="btn btn-outline" id="exportCsvBtn">📥 Export CSV</button>
        <button class="btn btn-outline" id="exportJsonBtn">📄 Export JSON</button>
        <button class="btn btn-primary" id="refreshBtn">🔄 Refresh</button>
      </div>
    </div>

    <!-- Places Table Card -->
    <div class="table-card">
      <div class="table-responsive">
        <table id="placesTable">
          <thead>
            <tr>
              <th style="width: 50px;">#</th>
              <th>Place Name</th>
              <th>Primary Category</th>
              <th>Sub-Categories</th>
              <th>Price Level</th>
              <th>Rating</th>
              <th>Area</th>
              <th style="text-align: center;">Details</th>
            </tr>
          </thead>
          <tbody id="placesTableBody">
            <tr>
              <td colspan="8" class="empty-state">
                <h3>Loading places from MongoDB...</h3>
                <p>Querying places_new collection</p>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

  </div>

  <!-- Place Detail Modal -->
  <div class="modal-backdrop" id="detailModal">
    <div class="modal-box">
      <div class="modal-header">
        <div>
          <h2 id="modalTitle" style="font-size: 18px; font-weight: 800;">Place Details</h2>
          <span id="modalCategory" class="badge badge-primary" style="margin-top: 4px;">Category</span>
        </div>
        <button class="modal-close" id="modalCloseBtn">&times;</button>
      </div>
      <div id="modalBody">
        <!-- Rendered by JS -->
      </div>
    </div>
  </div>

  <script>
    // State
    let categoriesList = [];
    let currentPlaces = [];
    let activePricePill = 'ALL';

    const categorySelect = document.getElementById('categorySelect');
    const priceSelect = document.getElementById('priceSelect');
    const searchInput = document.getElementById('searchInput');
    const hasPriceCheckbox = document.getElementById('hasPriceCheckbox');
    const pricePillsList = document.getElementById('pricePillsList');
    const placesTableBody = document.getElementById('placesTableBody');
    const statsCounter = document.getElementById('statsCounter');
    const refreshBtn = document.getElementById('refreshBtn');
    const exportCsvBtn = document.getElementById('exportCsvBtn');
    const exportJsonBtn = document.getElementById('exportJsonBtn');

    const detailModal = document.getElementById('detailModal');
    const modalCloseBtn = document.getElementById('modalCloseBtn');
    const modalTitle = document.getElementById('modalTitle');
    const modalCategory = document.getElementById('modalCategory');
    const modalBody = document.getElementById('modalBody');

    // Init
    async function init() {
      await loadCategories();
      await loadPlaces();
    }

    // Load Categories from API
    async function loadCategories() {
      try {
        const res = await fetch('/api/categories');
        const json = await res.json();
        if (json.success) {
          categoriesList = json.data;
          categorySelect.innerHTML = '<option value="ALL">All Categories (' + json.data.reduce((a,b)=>a+b.total, 0) + ' places)</option>';
          json.data.forEach(c => {
            const opt = document.createElement('option');
            opt.value = c.name;
            opt.textContent = c.name + ' (' + c.hasPrice + ' with price / ' + c.total + ' total)';
            categorySelect.appendChild(opt);
          });
        }
      } catch (err) {
        console.error('Error loading categories:', err);
      }
    }

    // Load Places from API
    async function loadPlaces() {
      placesTableBody.innerHTML = '<tr><td colspan="8" class="empty-state"><h3>Loading places...</h3></td></tr>';
      
      const category = categorySelect.value;
      const hasPrice = hasPriceCheckbox.checked;
      const priceVal = activePricePill !== 'ALL' ? activePricePill : priceSelect.value;
      const search = searchInput.value;

      const params = new URLSearchParams();
      if (category !== 'ALL') params.set('category', category);
      params.set('has_price', hasPrice ? 'true' : 'all');
      if (priceVal && priceVal !== 'ALL') params.set('price_level', priceVal);
      if (search.trim()) params.set('search', search.trim());

      try {
        const res = await fetch('/api/places?' + params.toString());
        const json = await res.json();
        if (json.success) {
          currentPlaces = json.data;
          renderPricePills(json.priceDistribution);
          renderTable(json.data);
          updatePriceSelectOptions(json.priceDistribution);
          statsCounter.innerHTML = 'Showing <span>' + json.totalCount.toLocaleString() + '</span> places (Category: <b>' + (category === 'ALL' ? 'All' : category) + '</b>)';
        }
      } catch (err) {
        placesTableBody.innerHTML = '<tr><td colspan="8" class="empty-state" style="color:red"><h3>Error loading data</h3><p>' + err.message + '</p></td></tr>';
      }
    }

    // Render Price Filter Pills
    function renderPricePills(dist) {
      pricePillsList.innerHTML = '';
      const totalInDist = Object.values(dist).reduce((a,b)=>a+b, 0);

      // 'ALL' Pill
      const allPill = document.createElement('button');
      allPill.className = 'pill-btn' + (activePricePill === 'ALL' ? ' active' : '');
      allPill.innerHTML = 'All Values <span class="pill-count">' + totalInDist + '</span>';
      allPill.onclick = () => {
        activePricePill = 'ALL';
        priceSelect.value = 'ALL';
        loadPlaces();
      };
      pricePillsList.appendChild(allPill);

      // Distinct price pills
      const entries = Object.entries(dist).sort((a,b) => b[1] - a[1]);
      entries.forEach(([price, count]) => {
        const pill = document.createElement('button');
        pill.className = 'pill-btn' + (activePricePill === price ? ' active' : '');
        pill.innerHTML = price + ' <span class="pill-count">' + count + '</span>';
        pill.onclick = () => {
          activePricePill = (activePricePill === price) ? 'ALL' : price;
          priceSelect.value = activePricePill;
          loadPlaces();
        };
        pricePillsList.appendChild(pill);
      });
    }

    // Update Dropdown options
    function updatePriceSelectOptions(dist) {
      const currentSelected = priceSelect.value;
      const opts = ['<option value="ALL">All Price Levels</option>'];
      Object.keys(dist).sort().forEach(lvl => {
        opts.push('<option value="' + lvl + '">' + lvl + ' (' + dist[lvl] + ')</option>');
      });
      priceSelect.innerHTML = opts.join('');
      if (activePricePill !== 'ALL') {
        priceSelect.value = activePricePill;
      } else {
        priceSelect.value = currentSelected;
      }
    }

    // Render Table Rows
    function renderTable(places) {
      if (!places || places.length === 0) {
        placesTableBody.innerHTML = '<tr><td colspan="8" class="empty-state"><h3>No matching places found</h3><p>Try switching category or unchecking "Only Has Value".</p></td></tr>';
        return;
      }

      const rows = places.map((p, index) => {
        // Price Badge Styling
        let priceBadgeClass = 'price-none';
        let priceText = p.price_level || 'No Value';
        if (p.price_level) {
          const lower = p.price_level.toLowerCase();
          if (lower.includes('free') || p.price_level === 'RM 0') {
            priceBadgeClass = 'price-free';
          } else if (lower.includes('$') || lower.includes('100') || lower.includes('200')) {
            priceBadgeClass = 'price-high';
          } else {
            priceBadgeClass = 'price-paid';
          }
        }

        // Sub categories pills
        const subPills = (p.sub_categories && p.sub_categories.length > 0)
          ? p.sub_categories.slice(0, 3).map(s => '<span class="sub-cat-pill">' + s + '</span>').join('') +
            (p.sub_categories.length > 3 ? '<span class="sub-cat-pill">+' + (p.sub_categories.length - 3) + '</span>' : '')
          : '<span style="color:#94a3b8; font-size:11px;">(None)</span>';

        // Rating
        const ratingHtml = p.rating > 0
          ? '<span class="rating-box"><span class="rating-star">★</span> ' + p.rating.toFixed(1) + (p.reviews_count ? ' <span style="font-size:11px; color:#94a3b8">(' + p.reviews_count + ')</span>' : '') + '</span>'
          : '<span style="color:#94a3b8; font-size:12px;">-</span>';

        return '<tr>' +
          '<td style="color:#94a3b8; font-size:12px;">' + (index + 1) + '</td>' +
          '<td><strong style="color:#0f172a;">' + escapeHtml(p.name) + '</strong></td>' +
          '<td><span class="badge badge-primary">' + escapeHtml(p.primary_category) + '</span></td>' +
          '<td>' + subPills + '</td>' +
          '<td><span class="badge badge-price ' + priceBadgeClass + '">' + escapeHtml(priceText) + '</span></td>' +
          '<td>' + ratingHtml + '</td>' +
          '<td><span style="font-size:13px; color:#475569;">' + escapeHtml(p.area) + '</span></td>' +
          '<td style="text-align: center;"><button class="btn btn-outline" style="padding: 4px 10px; font-size: 11px;" onclick="viewDetails(\\'' + p._id + '\\')">View</button></td>' +
        '</tr>';
      });

      placesTableBody.innerHTML = rows.join('');
    }

    // Modal Details
    window.viewDetails = function(placeId) {
      const place = currentPlaces.find(p => p._id === placeId);
      if (!place) return;

      modalTitle.textContent = place.name;
      modalCategory.textContent = place.primary_category;

      modalBody.innerHTML = 
        '<div class="modal-row"><div class="modal-label">Price Level:</div><div class="modal-val"><strong>' + (place.price_level || 'None') + '</strong>' + (place.price_source ? ' <span style="font-size:11px; color:#64748b;">(from ' + place.price_source + ')</span>' : '') + '</div></div>' +
        '<div class="modal-row"><div class="modal-label">Sub-Categories:</div><div class="modal-val">' + (place.sub_categories.join(', ') || 'None') + '</div></div>' +
        '<div class="modal-row"><div class="modal-label">Rating & Reviews:</div><div class="modal-val">' + (place.rating ? '★ ' + place.rating + ' (' + place.reviews_count + ' reviews)' : 'N/A') + '</div></div>' +
        '<div class="modal-row"><div class="modal-label">Area / Location:</div><div class="modal-val">' + (place.area || 'Penang') + '</div></div>' +
        '<div class="modal-row"><div class="modal-label">Address:</div><div class="modal-val">' + (place.address || 'N/A') + '</div></div>' +
        '<div class="modal-row"><div class="modal-label">Operating Hours:</div><div class="modal-val">' + (place.raw_hours_text || 'N/A') + '</div></div>' +
        '<div class="modal-row"><div class="modal-label">Ticket Fee:</div><div class="modal-val">' + (place.ticket_fee ? JSON.stringify(place.ticket_fee) : 'Not specified') + '</div></div>' +
        '<div class="modal-row"><div class="modal-label">Document ID:</div><div class="modal-val" style="font-family:monospace; font-size:11px;">' + place._id + '</div></div>';

      detailModal.classList.add('show');
    };

    modalCloseBtn.onclick = () => detailModal.classList.remove('show');
    detailModal.onclick = (e) => { if (e.target === detailModal) detailModal.classList.remove('show'); };

    // Events
    categorySelect.onchange = () => { activePricePill = 'ALL'; loadPlaces(); };
    priceSelect.onchange = () => { activePricePill = priceSelect.value; loadPlaces(); };
    hasPriceCheckbox.onchange = () => { activePricePill = 'ALL'; loadPlaces(); };
    refreshBtn.onclick = () => loadPlaces();

    let debounceTimer;
    searchInput.oninput = () => {
      clearTimeout(debounceTimer);
      debounceTimer = setTimeout(loadPlaces, 250);
    };

    // Export CSV
    exportCsvBtn.onclick = () => {
      if (!currentPlaces.length) return alert('No data to export');
      const headers = ['Name', 'Primary Category', 'Sub Categories', 'Price Level', 'Rating', 'Area', 'Address'];
      const rows = currentPlaces.map(p => [
        '"' + (p.name || '').replace(/"/g, '""') + '"',
        '"' + (p.primary_category || '').replace(/"/g, '""') + '"',
        '"' + (p.sub_categories.join(', ') || '').replace(/"/g, '""') + '"',
        '"' + (p.price_level || '').replace(/"/g, '""') + '"',
        p.rating || 0,
        '"' + (p.area || '').replace(/"/g, '""') + '"',
        '"' + (p.address || '').replace(/"/g, '""') + '"'
      ]);
      const csv = [headers.join(','), ...rows.map(r => r.join(','))].join('\\n');
      downloadFile(csv, 'places_price_levels.csv', 'text/csv;charset=utf-8;');
    };

    // Export JSON
    exportJsonBtn.onclick = () => {
      if (!currentPlaces.length) return alert('No data to export');
      const dataStr = JSON.stringify(currentPlaces, null, 2);
      downloadFile(dataStr, 'places_price_levels.json', 'application/json');
    };

    function downloadFile(content, fileName, mimeType) {
      const blob = new Blob([content], { type: mimeType });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = fileName;
      a.click();
      URL.revokeObjectURL(url);
    }

    function escapeHtml(str) {
      if (!str) return '';
      return String(str)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
    }

    init();
  </script>
</body>
</html>`);
});

app.listen(PORT, () => {
  console.log(`=================================================================`);
  console.log(`🚀 Kia Kia Penang: Price Level Web Explorer is running!`);
  console.log(`👉 Open your browser at: http://localhost:${PORT}`);
  console.log(`=================================================================`);
});

