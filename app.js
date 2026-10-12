/**
 * Kia Kia Penang - Travel Companion Web App Engine
 * Implements 4 Core Screens:
 * 1. Join Screen (Digit code validation, companion nickname, auto-focus, persistent sessions)
 * 2. Dashboard / Map Screen (Interactive Leaflet map, GPS geolocation, route polyline, drawer timeline)
 * 3. Action & SOS Panel (1-Tap broadcasts: Lost, Safe, Assist, Arrived, lead broadcast orders)
 * 4. Settings Screen (GPS toggle, offline cache storage, leave trip)
 */

// --- Mock / Live Datasets for Trips ---
const TRIP_DATABASE = {
  '888888': {
    code: '888888',
    title: 'Penang Heritage Explorer Trail',
    leader: 'Vivian (Lead Traveler)',
    leadLocation: { lat: 5.4182, lng: 100.3400, name: 'Lead Traveler: Vivian' },
    nextStopCountdownMinutes: 24,
    stops: [
      {
        id: 1,
        title: 'Cheong Fatt Tze - The Blue Mansion',
        time: '09:30 AM - 10:30 AM',
        stay: '60 min',
        category: 'Heritage Landmark',
        area: 'George Town',
        lat: 5.4215,
        lng: 100.3347,
        tip: 'Arrive 10 min early for the guided heritage courtyard architecture tour.',
        isCurrent: false
      },
      {
        id: 2,
        title: 'Penang Peranakan Mansion',
        time: '11:00 AM - 12:15 PM',
        stay: '75 min',
        category: 'Cultural Museum',
        area: 'George Town',
        lat: 5.4180,
        lng: 100.3409,
        tip: 'Marvel at over 1,000 Straits Chinese antique jewelry and woodcarvings.',
        isCurrent: true
      },
      {
        id: 3,
        title: 'Armenian Street & Street Art',
        time: '12:45 PM - 02:00 PM',
        stay: '75 min',
        category: 'Street Art & Culture',
        area: 'George Town',
        lat: 5.4150,
        lng: 100.3364,
        tip: 'Spot the iconic "Kids on Bicycle" mural and grab refreshing ice ball.',
        isCurrent: false
      },
      {
        id: 4,
        title: 'Clan Jetties (Chew Jetty)',
        time: '02:30 PM - 03:45 PM',
        stay: '75 min',
        category: 'Historic Waterfront',
        area: 'Weld Quay',
        lat: 5.4128,
        lng: 100.3398,
        tip: 'Wooden stilt houses over water with authentic handmade durian pastries.',
        isCurrent: false
      }
    ],
    initialLeaderCommand: 'Regroup at Penang Peranakan Mansion main gate at 12:15 PM.'
  },
  '666666': {
    code: '666666',
    title: 'Penang Foodie & Hawker Paradise',
    leader: 'Samantha (Lead Traveler)',
    leadLocation: { lat: 5.4170, lng: 100.3310, name: 'Lead Traveler: Samantha' },
    nextStopCountdownMinutes: 15,
    stops: [
      {
        id: 1,
        title: 'Toh Soon Cafe (Campbell St)',
        time: '08:30 AM - 09:45 AM',
        stay: '45 min',
        category: 'Traditional Breakfast',
        area: 'George Town',
        lat: 5.4187,
        lng: 100.3323,
        tip: 'Famous charcoal-toasted kaya bread and Hainanese robust black coffee.',
        isCurrent: false
      },
      {
        id: 2,
        title: 'Chowrasta Market Heritage Stalls',
        time: '10:00 AM - 11:30 AM',
        stay: '90 min',
        category: 'Local Market',
        area: 'Penang Road',
        lat: 5.4173,
        lng: 100.3308,
        tip: 'Try freshly pickled nutmeg and traditional Tambun biscuits.',
        isCurrent: true
      },
      {
        id: 3,
        title: 'Kimberley Street Duck Kway Chap',
        time: '12:00 PM - 01:15 PM',
        stay: '60 min',
        category: 'Penang Street Food',
        area: 'Kimberley Street',
        lat: 5.4162,
        lng: 100.3325,
        tip: 'Pair tender braised herbal duck with a cooling bowl of four-fruit soup.',
        isCurrent: false
      }
    ],
    initialLeaderCommand: 'Table secured at Chowrasta coffee shop! Come grab a seat.'
  }
};

// --- Firebase Configuration (Same as Kia Kia Penang Flutter App) ---
const FIREBASE_CONFIG = {
  apiKey: 'AIzaSyDS7GpZjoEvTJpj2GgPcXU6PQXz0Xa-P9I',
  appId: '1:152568659819:web:52173f3ac1117dd0d5162e',
  messagingSenderId: '152568659819',
  projectId: 'kiakiapenang-fyp',
  authDomain: 'kiakiapenang-fyp.firebaseapp.com',
  storageBucket: 'kiakiapenang-fyp.firebasestorage.app',
  measurementId: 'G-9W99F0TYTG'
};

let db = null;
try {
  if (typeof firebase !== 'undefined') {
    firebase.initializeApp(FIREBASE_CONFIG);
    db = firebase.firestore();
    console.log('Firebase Firestore initialized successfully in Companion Web.');
  }
} catch (e) {
  console.warn('Firebase initialization warning:', e);
}

// --- Mapbox Configuration (Identical to Flutter Kia-Kia App) ---
const MAPBOX_ACCESS_TOKEN = 'pk.eyJ1Ijoid2VpeHVuY2hlb25nIiwiYSI6ImNtcW9vazNzYTIyMGoyeHE2dDNhd3YzOWoifQ.V8mrHCQf3KSjJYp0eUvtaQ';
const MAPBOX_STYLES = {
  STREETS: 'mapbox://styles/mapbox/streets-v12',
  OUTDOORS: 'mapbox://styles/mapbox/outdoors-v12'
};

// --- Application State ---
let currentSession = {
  tripCode: null,
  nickname: null,
  isGpsSharing: true,
  myLocation: { lat: 5.4175, lng: 100.3385 },
  joinTimestamp: null
};

let activeTripData = null;
let mapboxMap = null;
let userMarker = null;
let leaderMarker = null;
let stopMarkers = [];
let isTerrainView = false;
let watchId = null;
let countdownInterval = null;

// ====================================================================
// INITIALIZATION
// ====================================================================
document.addEventListener('DOMContentLoaded', () => {
  setupDigitCodeInputs();
  checkUrlParamsForCode();
  restoreSavedSession();
  setupSimulationIntervals();
});

// Check URL query parameters (e.g. ?code=278950) to auto-fill passcode from shared link
function checkUrlParamsForCode() {
  const urlParams = new URLSearchParams(window.location.search);
  const codeParam = urlParams.get('code');
  if (codeParam && codeParam.trim().length === 6) {
    const cleanDigits = codeParam.trim().replace(/[^0-9]/g, '');
    const codeBoxes = document.querySelectorAll('.code-box');
    cleanDigits.split('').forEach((d, i) => {
      if (codeBoxes[i]) codeBoxes[i].value = d;
    });
    // Focus nickname input directly
    const nickInput = document.getElementById('companion-nickname');
    if (nickInput) nickInput.focus();
    showToast(`Trip code #${cleanDigits} loaded from shared link! Enter your nickname to join.`, 'success');
  }
}

// Setup 6-digit input keyboard navigation and paste support
function setupDigitCodeInputs() {
  const codeBoxes = document.querySelectorAll('.code-box');
  codeBoxes.forEach((box, index) => {
    box.addEventListener('input', (e) => {
      const val = e.target.value.replace(/[^0-9]/g, '');
      box.value = val;
      if (val && index < codeBoxes.length - 1) {
        codeBoxes[index + 1].focus();
      }
    });

    box.addEventListener('keydown', (e) => {
      if (e.key === 'Backspace' && !box.value && index > 0) {
        codeBoxes[index - 1].focus();
      }
    });

    box.addEventListener('paste', (e) => {
      e.preventDefault();
      const pasteData = (e.clipboardData || window.clipboardData).getData('text').trim();
      const digits = pasteData.replace(/[^0-9]/g, '').slice(0, 6);
      digits.split('').forEach((digit, i) => {
        if (codeBoxes[i]) codeBoxes[i].value = digit;
      });
      if (codeBoxes[Math.min(digits.length, 5)]) {
        codeBoxes[Math.min(digits.length, 5)].focus();
      }
    });
  });
}

function getEnteredCode() {
  const codeBoxes = document.querySelectorAll('.code-box');
  let code = '';
  codeBoxes.forEach(b => code += b.value.trim());
  return code;
}

// Check Local Storage for active session
async function restoreSavedSession() {
  try {
    const saved = localStorage.getItem('kiapenang_companion_session');
    if (saved) {
      const parsed = JSON.parse(saved);
      if (parsed.tripCode) {
        currentSession = parsed;
        const trip = await fetchTripData(parsed.tripCode);
        if (trip) {
          enterTripDashboard(currentSession.tripCode, currentSession.nickname, false, trip);
        }
      }
    }
  } catch (err) {
    console.warn('Session restoration failed:', err);
  }
}

// Fetch trip data from Firebase Firestore or fallback to demo TRIP_DATABASE ONLY if code is '888888' or '666666'
async function fetchTripData(code) {
  // 1. If user entered specific mock demo codes '888888' or '666666', allow demo mock data
  if (code === '888888' || code === '666666') {
    console.log(`Demo code #${code} detected: loading demo mock itinerary.`);
    return TRIP_DATABASE[code] || null;
  }

  // 2. Real specific code: ALWAYS fetch from Firebase Firestore (NO mock data fallback)
  if (db) {
    try {
      const doc = await db.collection('sharedTrips').doc(code).get();
      if (doc.exists) {
        console.log(`Real Trip #${code} fetched from Firebase Firestore:`, doc.data());
        return doc.data();
      } else {
        console.warn(`Trip #${code} does not exist in Firebase Firestore.`);
        return null;
      }
    } catch (err) {
      console.error('Firestore query failed:', err);
      throw new Error('Unable to connect to Firebase. Check internet connection.');
    }
  } else {
    throw new Error('Firebase service not initialized.');
  }
}

// ====================================================================
// 1. JOIN SCREEN LOGIC
// ====================================================================
async function joinTrip() {
  const code = getEnteredCode();
  const nicknameInput = document.getElementById('companion-nickname');
  const nickname = nicknameInput.value.trim();
  const errorBox = document.getElementById('join-error');
  const errorText = document.getElementById('join-error-text');
  const btnEnter = document.getElementById('btn-enter-trip');

  if (code.length < 6) {
    showJoinError('Please complete entering all 6 digits of the trip code.');
    return;
  }

  if (!nickname) {
    showJoinError('Please enter your nickname so your team can spot you.');
    return;
  }

  // Show loading on Join button
  const originalBtnHtml = btnEnter.innerHTML;
  btnEnter.innerHTML = '<i class="fa-solid fa-spinner fa-spin"></i> Verifying Code...';
  btnEnter.disabled = true;

  try {
    const trip = await fetchTripData(code);

    if (!trip) {
      showJoinError(`Trip code #${code} not found. Please ensure the lead traveler generated this code in the app.`);
      btnEnter.innerHTML = originalBtnHtml;
      btnEnter.disabled = false;
      return;
    }

    // Success: Clear error & save session
    errorBox.classList.add('hidden');
    currentSession.tripCode = code;
    currentSession.nickname = nickname;
    currentSession.joinTimestamp = new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });

    localStorage.setItem('kiapenang_companion_session', JSON.stringify(currentSession));
    enterTripDashboard(code, nickname, true, trip);
  } catch (err) {
    showJoinError(`Error verifying trip: ${err.message}`);
  } finally {
    btnEnter.innerHTML = originalBtnHtml;
    btnEnter.disabled = false;
  }
}

function showJoinError(msg) {
  const errorBox = document.getElementById('join-error');
  const errorText = document.getElementById('join-error-text');
  errorText.textContent = msg;
  errorBox.classList.remove('hidden');
}

function enterTripDashboard(code, nickname, showWelcomeToast = true, tripData = null) {
  activeTripData = tripData;
  const isDemoCode = (code === '888888' || code === '666666');

  // Update Header UI with real trip metadata
  document.getElementById('header-trip-code').textContent = `TRIP #${code}`;
  document.getElementById('header-trip-name').textContent = activeTripData.title || 'Penang Trip Itinerary';
  document.getElementById('info-trip-code').textContent = code;
  document.getElementById('info-join-time').textContent = currentSession.joinTimestamp || 'Just now';
  document.getElementById('settings-nickname-display').textContent = `Displaying as: ${nickname}`;

  // Update Lead Traveler info
  const leaderNameEl = document.querySelector('.leader-name');
  if (leaderNameEl) {
    leaderNameEl.innerHTML = `<i class="fa-solid fa-crown"></i> Leader (${activeTripData.leader || 'Organizer'})`;
  }
  const cmdTextEl = document.getElementById('leader-command-text');
  if (cmdTextEl) {
    cmdTextEl.textContent = `"${activeTripData.initialLeaderCommand || 'Welcome to the trip! Regroup at the upcoming stop.'}"`;
  }

  // Switch Screens
  document.getElementById('screen-join').classList.remove('active');
  document.getElementById('app-shell').classList.remove('hidden');
  switchTab('dashboard');

  // Initialize Map & Timeline Drawer
  setTimeout(() => {
    initMapboxMap();
    renderItineraryDrawer();
    startCountdownTimer(activeTripData.nextStopCountdownMinutes || 30);
    populateBroadcastHistory();
    startGpsTracking();
  }, 100);

  if (showWelcomeToast) {
    showToast(`Welcome ${nickname}! Connected to ${activeTripData.title || 'trip'}.`, 'success');
  }
}

// ====================================================================
// 2. DASHBOARD / MAP SCREEN LOGIC (Mapbox GL Engine)
// ====================================================================
function initMapboxMap() {
  if (mapboxMap) {
    mapboxMap.resize();
    return;
  }

  mapboxgl.accessToken = MAPBOX_ACCESS_TOKEN;

  // Default coordinate for Penang
  const defaultCenter = [100.3380, 5.4180]; // [lng, lat] for Mapbox

  mapboxMap = new mapboxgl.Map({
    container: 'map-view',
    style: isTerrainView ? MAPBOX_STYLES.OUTDOORS : MAPBOX_STYLES.STREETS,
    center: defaultCenter,
    zoom: 15,
    pitch: 25, // Slight perspective angle
    attributionControl: false
  });

  // Navigation zoom & rotation controls
  mapboxMap.addControl(new mapboxgl.NavigationControl({ showCompass: true }), 'bottom-right');

  mapboxMap.on('load', () => {
    // Draw route line layer
    addRouteLayer();
    // Plot destination stops
    plotItineraryMarkers();
    // Plot Lead Traveler pin
    plotLeadTravelerMarker();
    // Plot My Marker
    plotMyMarker();
  });
}

// Toggle between Mapbox Streets and Outdoors (Terrain) view
function toggleMapStyle() {
  if (!mapboxMap) return;
  isTerrainView = !isTerrainView;
  const newStyle = isTerrainView ? MAPBOX_STYLES.OUTDOORS : MAPBOX_STYLES.STREETS;
  
  mapboxMap.setStyle(newStyle);
  
  // Re-add route layer after style reload
  mapboxMap.once('style.load', () => {
    addRouteLayer();
  });

  showToast(`Switched map to ${isTerrainView ? 'Outdoors / Terrain' : 'Streets'} style`, 'info');
}

function addRouteLayer() {
  if (!activeTripData || !mapboxMap) return;

  const coordinates = activeTripData.stops.map(s => [s.lng, s.lat]);

  // Remove existing source/layer if exists
  if (mapboxMap.getLayer('route-line-layer')) mapboxMap.removeLayer('route-line-layer');
  if (mapboxMap.getSource('route-line-source')) mapboxMap.removeSource('route-line-source');

  mapboxMap.addSource('route-line-source', {
    type: 'geojson',
    data: {
      type: 'Feature',
      properties: {},
      geometry: {
        type: 'LineString',
        coordinates: coordinates
      }
    }
  });

  mapboxMap.addLayer({
    id: 'route-line-layer',
    type: 'line',
    source: 'route-line-source',
    layout: {
      'line-join': 'round',
      'line-cap': 'round'
    },
    paint: {
      'line-color': '#304FFE', // Kia Kia Penang primary indigo
      'line-width': 4.5,
      'line-dasharray': [2, 2]
    }
  });
}

function plotItineraryMarkers() {
  if (!activeTripData || !mapboxMap) return;

  // Clear previous markers
  stopMarkers.forEach(m => m.remove());
  stopMarkers = [];

  activeTripData.stops.forEach((stop) => {
    const isNext = stop.isCurrent;

    // Create custom DOM element for stop marker
    const el = document.createElement('div');
    el.className = `custom-pin-stop ${isNext ? 'next-dest' : ''}`;
    el.innerHTML = `${stop.id}`;

    const popupHtml = `
      <div class="popup-content">
        <h4>Stop ${stop.id}: ${stop.title}</h4>
        <p><i class="fa-regular fa-clock"></i> ${stop.time}</p>
        <p><i class="fa-solid fa-lightbulb"></i> ${stop.tip}</p>
        <button class="popup-btn" onclick="openGoogleNavigationTo(${stop.lat}, ${stop.lng})">
          <i class="fa-solid fa-diamond-turn-right"></i> Navigate Here
        </button>
      </div>
    `;

    const popup = new mapboxgl.Popup({ offset: 25, closeButton: false }).setHTML(popupHtml);

    const marker = new mapboxgl.Marker({ element: el })
      .setLngLat([stop.lng, stop.lat])
      .setPopup(popup)
      .addTo(mapboxMap);

    stopMarkers.push(marker);

    // Update Quick Banner for Current/Next stop
    if (isNext) {
      document.getElementById('quick-stop-title').textContent = stop.title;
      document.getElementById('quick-stop-time').innerHTML = `<i class="fa-regular fa-clock"></i> ${stop.time.split('-')[0].trim()} • Current Stage`;
    }
  });
}

function plotLeadTravelerMarker() {
  if (!activeTripData || !mapboxMap) return;
  const lead = activeTripData.leadLocation;

  if (leaderMarker) leaderMarker.remove();

  const el = document.createElement('div');
  el.className = 'custom-pin-lead';
  el.title = `Lead Traveler: ${activeTripData.leader}`;
  el.innerHTML = '<i class="fa-solid fa-crown"></i>';

  const popupHtml = `
    <div class="popup-content">
      <h4><i class="fa-solid fa-crown" style="color:#EAB308;"></i> ${activeTripData.leader}</h4>
      <p>Group Organizer & Real-time Guide</p>
      <p style="font-size:10px; color:#10B981;"><i class="fa-solid fa-circle"></i> Live Signal Active</p>
    </div>
  `;

  const popup = new mapboxgl.Popup({ offset: 25, closeButton: false }).setHTML(popupHtml);

  leaderMarker = new mapboxgl.Marker({ element: el })
    .setLngLat([lead.lng, lead.lat])
    .setPopup(popup)
    .addTo(mapboxMap);
}

function plotMyMarker() {
  if (!mapboxMap || !currentSession.isGpsSharing) return;

  if (userMarker) userMarker.remove();

  const el = document.createElement('div');
  el.className = 'custom-pin-user';
  el.title = `You: ${currentSession.nickname}`;
  el.innerHTML = `
    <div class="user-pulse-ring"></div>
    <i class="fa-solid fa-person-walking"></i>
  `;

  const popupHtml = `
    <div class="popup-content">
      <h4>${currentSession.nickname} (You)</h4>
      <p><i class="fa-solid fa-satellite-dish"></i> GPS Accuracy: High</p>
    </div>
  `;

  const popup = new mapboxgl.Popup({ offset: 25, closeButton: false }).setHTML(popupHtml);

  userMarker = new mapboxgl.Marker({ element: el })
    .setLngLat([currentSession.myLocation.lng, currentSession.myLocation.lat])
    .setPopup(popup)
    .addTo(mapboxMap);
}

function centerMapOnMe() {
  if (mapboxMap && currentSession.myLocation) {
    mapboxMap.flyTo({
      center: [currentSession.myLocation.lng, currentSession.myLocation.lat],
      zoom: 17,
      essential: true
    });
    showToast('Centered on your position', 'success');
  }
}

function fitMapToRoute() {
  if (mapboxMap && activeTripData) {
    const bounds = new mapboxgl.LngLatBounds();
    activeTripData.stops.forEach(s => bounds.extend([s.lng, s.lat]));
    bounds.extend([activeTripData.leadLocation.lng, activeTripData.leadLocation.lat]);
    bounds.extend([currentSession.myLocation.lng, currentSession.myLocation.lat]);
    
    mapboxMap.fitBounds(bounds, { padding: 50, maxZoom: 17 });
  }
}

// Render Itinerary Timeline inside Bottom Sheet
function renderItineraryDrawer() {
  const listEl = document.getElementById('itinerary-stops-list');
  const countBadge = document.getElementById('stops-count-badge');
  if (!listEl || !activeTripData) return;

  countBadge.textContent = `${activeTripData.stops.length} Stops`;
  listEl.innerHTML = '';

  activeTripData.stops.forEach((stop, idx) => {
    const isLast = idx === activeTripData.stops.length - 1;
    const item = document.createElement('div');
    item.className = `timeline-item ${stop.isCurrent ? 'current-stop' : ''}`;
    item.onclick = () => focusStopOnMap(stop);

    item.innerHTML = `
      <div class="timeline-left">
        <div class="stop-marker-num">${stop.id}</div>
        ${!isLast ? '<div class="timeline-line"></div>' : ''}
      </div>
      <div class="timeline-content">
        <div class="stop-time-tag">${stop.time} (${stop.stay})</div>
        <div class="stop-name">${stop.title}</div>
        <div class="stop-meta">
          <span><i class="fa-solid fa-tag"></i> ${stop.category}</span>
          <span><i class="fa-solid fa-map-pin"></i> ${stop.area}</span>
        </div>
        <div class="stop-tip"><i class="fa-solid fa-circle-info"></i> ${stop.tip}</div>
      </div>
    `;
    listEl.appendChild(item);
  });
}

function toggleItineraryDrawer() {
  const drawer = document.getElementById('itinerary-drawer');
  const toggleText = document.getElementById('drawer-toggle-text');
  if (drawer.classList.contains('collapsed')) {
    drawer.classList.remove('collapsed');
    drawer.classList.add('expanded');
    toggleText.textContent = 'Collapse';
  } else {
    drawer.classList.remove('expanded');
    drawer.classList.add('collapsed');
    toggleText.textContent = 'Expand';
  }
}

function focusStopOnMap(stop) {
  if (mapboxMap) {
    mapboxMap.flyTo({
      center: [stop.lng, stop.lat],
      zoom: 17.5,
      essential: true
    });
    // Open its popup
    const marker = stopMarkers[stop.id - 1];
    if (marker && marker.getPopup()) marker.togglePopup();
  }
}

function openGoogleNavigation() {
  if (!activeTripData) return;
  const curr = activeTripData.stops.find(s => s.isCurrent) || activeTripData.stops[0];
  openGoogleNavigationTo(curr.lat, curr.lng);
}

function openGoogleNavigationTo(lat, lng) {
  const url = `https://www.google.com/maps/dir/?api=1&destination=${lat},${lng}&travelmode=walking`;
  window.open(url, '_blank');
}

// Countdown timer to next stop
function startCountdownTimer(initialMinutes) {
  if (countdownInterval) clearInterval(countdownInterval);
  let secondsRemaining = initialMinutes * 60;

  const timerEl = document.getElementById('countdown-timer');

  const updateDisplay = () => {
    const mins = Math.floor(secondsRemaining / 60);
    const secs = secondsRemaining % 60;
    timerEl.textContent = `${mins}m ${secs < 10 ? '0' : ''}${secs}s`;
    if (secondsRemaining <= 0) {
      timerEl.textContent = 'Time Up!';
      clearInterval(countdownInterval);
    }
  };

  updateDisplay();
  countdownInterval = setInterval(() => {
    secondsRemaining--;
    updateDisplay();
  }, 1000);
}

// Geolocation real-time watcher
function startGpsTracking() {
  if ('geolocation' in navigator) {
    watchId = navigator.geolocation.watchPosition(
      (position) => {
        if (!currentSession.isGpsSharing) return;
        currentSession.myLocation.lat = position.coords.latitude;
        currentSession.myLocation.lng = position.coords.longitude;
        if (userMarker) {
          userMarker.setLngLat([position.coords.longitude, position.coords.latitude]);
        }
      },
      (err) => {
        console.warn('Geolocation sensor fallback (simulation coords active):', err.message);
      },
      { enableHighAccuracy: true, maximumAge: 10000, timeout: 5000 }
    );
  }
}

// ====================================================================
// 3. ACTION & SOS PANEL LOGIC
// ====================================================================
const BROADCAST_LOGS = [
  {
    id: 1,
    author: 'Vivian (Leader)',
    type: 'DIRECTIVE',
    badgeClass: 'badge-arrived',
    text: 'Regroup at the main entrance in 10 minutes. Photo session starting!',
    time: '11:05 AM'
  },
  {
    id: 2,
    author: 'Ken',
    type: 'ARRIVED',
    badgeClass: 'badge-safe',
    text: 'At the ticket counter. Got brochures for everyone.',
    time: '11:02 AM'
  }
];

function populateBroadcastHistory() {
  const feed = document.getElementById('broadcast-feed-list');
  if (!feed) return;
  feed.innerHTML = '';

  BROADCAST_LOGS.forEach(log => {
    const item = document.createElement('div');
    item.className = 'feed-item';
    item.innerHTML = `
      <div class="feed-avatar">${log.author.charAt(0)}</div>
      <div class="feed-body">
        <span class="feed-author">${log.author}</span>
        <span class="feed-badge ${log.badgeClass}">${log.type}</span>
        <div class="feed-text">${log.text}</div>
        <div class="feed-time">${log.time}</div>
      </div>
    `;
    feed.appendChild(item);
  });
}

function triggerBroadcast(type, message) {
  const now = new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  const nick = currentSession.nickname || 'Companion';

  let badgeClass = 'badge-safe';
  let toastType = 'success';

  if (type === 'LOST') {
    badgeClass = 'badge-lost';
    toastType = 'danger';
  } else if (type === 'ASSIST') {
    badgeClass = 'badge-assist';
    toastType = 'warning';
  } else if (type === 'ARRIVED') {
    badgeClass = 'badge-arrived';
  }

  const newLog = {
    id: Date.now(),
    author: `${nick} (You)`,
    type: type,
    badgeClass: badgeClass,
    text: message,
    time: now
  };

  BROADCAST_LOGS.unshift(newLog);
  populateBroadcastHistory();

  showToast(`Status: "${type}" recorded for ${nick}`, toastType);

  // If in demo mode (888888 / 666666) and LOST is triggered, simulate a demo leader response
  const isDemo = (currentSession.tripCode === '888888' || currentSession.tripCode === '666666');
  if (isDemo && type === 'LOST') {
    setTimeout(() => {
      receiveLeaderCommand('Stay where you are! Lead traveler is navigating towards your coordinates.');
    }, 4000);
  }
}

function receiveLeaderCommand(newInstruction) {
  const box = document.getElementById('leader-command-text');
  const time = document.getElementById('leader-command-time');
  const unreadDot = document.getElementById('action-unread-dot');

  if (box) box.textContent = `"${newInstruction}"`;
  if (time) time.textContent = 'Just now';

  // Show badge on Action Tab if not active
  const activeTab = document.querySelector('.nav-tab.active');
  if (activeTab && activeTab.id !== 'tab-action') {
    unreadDot.classList.remove('hidden');
  }

  showToast(`Leader Directive: ${newInstruction}`, 'warning');
}

// ====================================================================
// 4. SETTINGS & PRIVACY LOGIC
// ====================================================================
function toggleGpsSharing(enabled) {
  currentSession.isGpsSharing = enabled;
  localStorage.setItem('kiapenang_companion_session', JSON.stringify(currentSession));

  if (!enabled) {
    if (userMarker) userMarker.remove();
    showToast('GPS Location sharing paused. You are now invisible to team.', 'warning');
  } else {
    plotMyMarker();
    showToast('Real-time GPS Location sharing re-enabled.', 'success');
  }
}

function editNickname() {
  const current = currentSession.nickname;
  const newName = prompt('Enter new companion nickname for this trip:', current);
  if (newName && newName.trim().length > 0) {
    currentSession.nickname = newName.trim();
    localStorage.setItem('kiapenang_companion_session', JSON.stringify(currentSession));
    document.getElementById('settings-nickname-display').textContent = `Displaying as: ${currentSession.nickname}`;
    plotMyMarker();
    showToast(`Nickname updated to ${currentSession.nickname}`, 'success');
  }
}

function confirmExitTrip() {
  const ok = confirm('Are you sure you want to leave this trip session? You will be disconnected from live group radar.');
  if (ok) {
    localStorage.removeItem('kiapenang_companion_session');
    if (watchId) navigator.geolocation.clearWatch(watchId);
    if (countdownInterval) clearInterval(countdownInterval);

    // Reset Session
    currentSession = {
      tripCode: null,
      nickname: null,
      isGpsSharing: true,
      myLocation: { lat: 5.4175, lng: 100.3385 },
      joinTimestamp: null
    };

    // Return to Join Screen
    document.getElementById('app-shell').classList.add('hidden');
    document.getElementById('screen-join').classList.add('active');
    
    // Clear code boxes
    document.querySelectorAll('.code-box').forEach(b => b.value = '');
    document.getElementById('companion-nickname').value = '';

    showToast('Disconnected from trip session.', 'info');
  }
}

// ====================================================================
// NAVIGATION & UTILITIES
// ====================================================================
function switchTab(tabId) {
  // Update Tab Buttons
  document.querySelectorAll('.nav-tab').forEach(b => b.classList.remove('active'));
  document.getElementById(`tab-${tabId}`).classList.add('active');

  // Update Content Screens
  document.querySelectorAll('.content-screen').forEach(s => s.classList.remove('active'));
  document.getElementById(`screen-${tabId}`).classList.add('active');

  // Clear unread dot when entering Action tab
  if (tabId === 'action') {
    document.getElementById('action-unread-dot').classList.add('hidden');
  }

  // Invalidate map size when returning to Dashboard
  if (tabId === 'dashboard' && mapboxMap) {
    setTimeout(() => mapboxMap.resize(), 200);
  }
}

function showToast(message, type = 'normal') {
  const banner = document.getElementById('toast-banner');
  const msgEl = document.getElementById('toast-message');

  msgEl.textContent = message;
  banner.className = `toast-banner ${type}`;
  banner.classList.remove('hidden');

  setTimeout(() => {
    banner.classList.add('hidden');
  }, 3500);
}

// Background simulation: slight movement of leader pin for live feel in DEMO codes (888888 / 666666) only
function setupSimulationIntervals() {
  setInterval(() => {
    const isDemo = (currentSession.tripCode === '888888' || currentSession.tripCode === '666666');
    if (isDemo && activeTripData && leaderMarker && mapboxMap) {
      const deltaLat = (Math.random() - 0.5) * 0.00015;
      const deltaLng = (Math.random() - 0.5) * 0.00015;
      activeTripData.leadLocation.lat += deltaLat;
      activeTripData.leadLocation.lng += deltaLng;
      leaderMarker.setLngLat([activeTripData.leadLocation.lng, activeTripData.leadLocation.lat]);
    }
  }, 8000);
}
