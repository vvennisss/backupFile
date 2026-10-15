const express = require('express');
const fs = require('fs');
const path = require('path');
const cors = require('cors');
const { exec } = require('child_process');
const axios = require('axios');

const app = express();
app.use(cors());
app.use(express.json());

// ==========================================
// 1. 天气数据状态与配置 (Weather State & Config)
// ==========================================
const penangLocations = [
  'Batu Ferringhi', 'George Town', 'Georgetown', 'Air Itam', 'Ayer Itam',
  'Bayan Lepas', 'Tanjung Bungah', 'Tanjung Tokong', 'Gurney', 'Pulau Tikus',
  'Gelugor', 'Balik Pulau', 'Teluk Bahang', 'Butterworth', 'Bukit Mertajam',
  'Seberang Perai', 'Nibong Tebal', 'Kepala Batas'
];

const weatherOptions = [
  { value: 'sunny', label: '晴天 (Sunny)', defaultTemp: 34 },
  { value: 'cloudy', label: '多云 / 阴天 (Cloudy)', defaultTemp: 29 },
  { value: 'rainy', label: '下雨 / 阵雨 (Rainy)', defaultTemp: 26 },
  { value: 'thunderstorm', label: '暴雨 / 雷阵雨 (Thunderstorm)', defaultTemp: 25 }
];


// ==========================================
// Weather Payload & Severe Event Evaluator
// Light rain: < 2.5 mm/hr | Moderate: 2.5 - 7.6 mm/hr | Heavy: > 7.6 - 10 mm/hr
// Severe Event triggered if Rain > 7.6 mm/hr OR Temperature > 37°C
// ==========================================

// ==========================================
// Penang Indoor Malls & Shelters Database
// ==========================================
const penangMalls = [
  { name: '1st Avenue Mall', nameEn: '1st Avenue Mall', lat: 5.41320, lng: 100.33120, area: 'George Town' },
  { name: 'Prangin Mall', nameEn: 'Prangin Mall', lat: 5.41450, lng: 100.33150, area: 'George Town' },
  { name: 'Komtar ICT Mall', nameEn: 'Komtar ICT Mall', lat: 5.41430, lng: 100.32980, area: 'George Town' },
  { name: 'Gurney Plaza', nameEn: 'Gurney Plaza', lat: 5.43770, lng: 100.30970, area: 'Gurney Drive' },
  { name: 'Gurney Paragon', nameEn: 'Gurney Paragon', lat: 5.43580, lng: 100.31150, area: 'Gurney Drive' },
  { name: 'Botanica Centre Balik Pulau', nameEn: 'Botanica Centre Balik Pulau', lat: 5.3620, lng: 100.2220, area: 'Balik Pulau' },
  { name: 'Eden Parade Mall', nameEn: 'Eden Parade Batu Ferringhi', lat: 5.4715, lng: 100.2460, area: 'Batu Ferringhi' },
  { name: 'Sunshine Farlim Mall', nameEn: 'Sunshine Farlim Mall', lat: 5.3945, lng: 100.2865, area: 'Air Itam' },
  { name: 'Queensbay Mall', nameEn: 'Queensbay Mall', lat: 5.33320, lng: 100.30680, area: 'Bayan Lepas' }
];

function computeWeatherPayload({ location, condition, temperature, humidity, rain_rate_mm_hr, rain_category }) {
  let rainRate = Number(rain_rate_mm_hr);
  let category = rain_category;

  if (isNaN(rainRate)) {
    if (category === 'light') rainRate = 1.5;
    else if (category === 'moderate') rainRate = 5.0;
    else if (category === 'heavy') rainRate = 8.5;
    else if (condition === 'rainy') rainRate = 4.0;
    else if (condition === 'thunderstorm') rainRate = 8.5;
    else rainRate = 0.0;
  }

  if (!category || category === 'auto') {
    if (rainRate <= 0.0) category = 'none';
    else if (rainRate < 2.5) category = 'light';
    else if (rainRate <= 7.6) category = 'moderate';
    else category = 'heavy';
  }

  const tempNum = Number(temperature) || 32;
  const isSevereRain = rainRate > 7.6;
  const isSevereHeat = tempNum > 37.0;
  const isSevere = isSevereRain || isSevereHeat || condition === 'heavy_rain';

  let alertTitle = 'Normal Travel Weather';
  let alertMessage = 'Weather conditions are suitable for travel.';
  let severeType = 'none';

  if (isSevereRain) {
    severeType = 'heavy_rain';
    alertTitle = `Severe Weather Warning: Heavy Rainstorm (${rainRate.toFixed(1)} mm/hr)`;
    alertMessage = `Heavy rainfall of ${rainRate.toFixed(1)} mm/hr detected in ${location}. Flash flood and slippery road hazards. Indoor shelter recommended.`;
  } else if (isSevereHeat) {
    severeType = 'extreme_heat';
    alertTitle = `Severe Weather Advisory: Extreme Heatwave (${tempNum}°C)`;
    alertMessage = `Extreme heat of ${tempNum}°C recorded in ${location}. High UV and heat exhaustion risk. Seek air-conditioned indoor shelter.`;
  } else if (category === 'moderate') {
    alertTitle = `Moderate Rain Notice (${rainRate.toFixed(1)} mm/hr)`;
    alertMessage = `Moderate rain in ${location}. Rain showers expected, carry an umbrella.`;
  } else if (category === 'light') {
    alertTitle = `Light Rain Drizzle (${rainRate.toFixed(1)} mm/hr)`;
    alertMessage = `Light rain (< 2.5 mm/hr) in ${location}. Minimal travel impact.`;
  }

  const shelterAlternatives = (typeof penangMalls !== "undefined" && Array.isArray(penangMalls)) ? penangMalls.slice(0, 4) : [];

  return {
    location: String(location || 'George Town'),
    condition: String(condition || 'sunny'),
    temperature: tempNum,
    humidity: Number(humidity) || 75,
    rainfall_mm: Number(rainRate.toFixed(2)),
    rain_rate_mm_hr: Number(rainRate.toFixed(2)),
    rain_category: category,
    rain_description: category === 'light'
      ? 'Light rain: Less than 2.5 mm per hour'
      : (category === 'moderate'
        ? 'Moderate rain: 2.5 mm to 7.6 mm per hour'
        : (category === 'heavy'
          ? 'Heavy rain: Greater than 7.6 mm to 10 mm per hour'
          : 'Clear / No Rain')),
    is_severe: isSevere,
    severe_trigger_type: severeType,
    alert_title: alertTitle,
    alert_message: alertMessage,
    suggested_indoor_shelters: shelterAlternatives,
    timestamp: new Date().toISOString()
  };
}

let currentWeather = computeWeatherPayload({
  location: "George Town",
  condition: "sunny",
  temperature: 34,
  humidity: 70,
  rain_rate_mm_hr: 0.0,
  rain_category: "none"
});

let sendHistory = [];

// ==========================================
// 2. 实时报文监视器 (Telemetry Logs)
// ==========================================
const MAX_TELEMETRY = 150;
let telemetryLogs = [];

function addTelemetry(type, title, details, payload = null) {
  const time = new Date().toLocaleTimeString();
  const entry = {
    id: Date.now() + Math.random(),
    time,
    type, // 'adb' | 'weather' | 'routing' | 'incident'
    title,
    details,
    payload: payload ? JSON.stringify(payload, null, 2) : null
  };
  telemetryLogs.unshift(entry);
  if (telemetryLogs.length > MAX_TELEMETRY) {
    telemetryLogs.pop();
  }
}

// ==========================================
// 3. 模拟旅行核心引擎 (Travel Simulation Engine)
// ==========================================
const defaultStops = [
  {
    id: 0,
    name: 'Hotel Jen George Town (Departure / 出发地)',
    nameEn: 'Hotel Jen (Departure)',
    nameZh: '今旅酒店 (出发点)',
    lat: 5.4134,
    lng: 100.3298,
    stayMinutes: 0,
    plannedArrive: '10:00 AM',
    plannedDepart: '10:00 AM'
  },
  {
    id: 1,
    name: 'Armenian Street Murals (Stop 1 / 壁画街)',
    nameEn: 'Armenian Street (Stop 1)',
    nameZh: '本头公巷壁画街 (第1站)',
    lat: 5.4141,
    lng: 100.3364,
    stayMinutes: 65, // 10:15 - 11:20
    plannedArrive: '10:15 AM',
    plannedDepart: '11:20 AM'
  },
  {
    id: 2,
    name: 'Chew Jetty (Stop 2 / 姓周桥)',
    nameEn: 'Chew Jetty (Stop 2)',
    nameZh: '姓周桥 (第2站)',
    lat: 5.4125,
    lng: 100.3400,
    stayMinutes: 40,
    plannedArrive: '11:36 AM',
    plannedDepart: '12:16 PM'
  },
  {
    id: 3,
    name: 'Khoo Kongsi (Stop 3 / 龙山堂邱公司)',
    nameEn: 'Khoo Kongsi (Stop 3)',
    nameZh: '龙山堂邱公司 (第3站)',
    lat: 5.4150,
    lng: 100.3380,
    stayMinutes: 45,
    plannedArrive: '12:26 PM',
    plannedDepart: '01:11 PM'
  },
  {
    id: 4,
    name: 'Penang Road Teochew Chendul (Stop 4 / 潮州煎粿)',
    nameEn: 'Penang Road Teochew Chendul (Stop 4)',
    nameZh: '槟榔律驰名潮州煎粿 (第4站)',
    lat: 5.4172,
    lng: 100.3307,
    stayMinutes: 30,
    plannedArrive: '01:25 PM',
    plannedDepart: '01:55 PM'
  }
];

let travelState = {
  isPlaying: false,
  playbackSpeed: 10, // 1x, 5x, 10x, 30x, 60x
  travelMode: 'walking', // 'walking' (~4.5 km/h) or 'driving' (~35 km/h)
  virtualTime: new Date(2026, 9, 9, 10, 0, 0), // 10:00:00 AM
  currentLat: defaultStops[0].lat,
  currentLng: defaultStops[0].lng,
  currentStopIndex: 1, // Heading towards Stop 1
  stopStatuses: ['completed', 'enroute', 'waiting', 'waiting', 'waiting'],
  isStaying: false,
  staySecondsRemaining: 0,
  activeLegWaypoints: [],
  currentWaypointIndex: 0,
  remainingDistanceMeters: 0,
  totalDistanceMeters: 0,
  remainingDurationSeconds: 0,
  activeIncident: null,
  startHotel: null,
  adbConnected: true,
  lastAdbOutput: 'Ready'
};


// Penang Area Hotel Locations (Matching Flutter MockHotelRegistry for accurate origin departures)
let incidentClearTimer = null;
function setActiveIncident(text) {
  travelState.activeIncident = text;
  if (incidentClearTimer) {
    clearTimeout(incidentClearTimer);
    incidentClearTimer = null;
  }
  if (text) {
    incidentClearTimer = setTimeout(() => {
      travelState.activeIncident = null;
      console.log('⏰ Active incident auto-cleared after 30 seconds');
    }, 30000); // Only show for 30 seconds
  }
}

const areaHotels = [
  { area: 'Georgetown', name: 'Eastern & Oriental Hotel', lat: 5.4233, lng: 100.3359 },
  { area: 'Batu Ferringhi', name: 'Rasa Sayang Resort & Spa by Shangri-La', lat: 5.4781, lng: 100.2536 },
  { area: 'Gurney Drive', name: 'Ascott Gurney Penang', lat: 5.4318, lng: 100.3192 },
  { area: 'Air Itam', name: 'Harris Hotel & Conventions Sunshine Penang', lat: 5.3988, lng: 100.2874 },
  { area: 'Teluk Bahang', name: 'Angsana Teluk Bahang', lat: 5.4622, lng: 100.2200 },
  { area: 'Balik Pulau', name: 'Audi Guest House', lat: 5.3122, lng: 100.2068 },
  { area: 'Bayan Lepas', name: 'Amari SPICE Penang', lat: 5.3302, lng: 100.2813 },
  { area: 'Tanjung Bungah', name: 'Hompton by the Beach Penang', lat: 5.4635, lng: 100.3052 },
  { area: 'Butterworth', name: 'Crowne Plaza Penang Straits City', lat: 5.4042, lng: 100.3683 },
];

function getAreaHotelCoords(area) {
  if (!area) return areaHotels[0];
  const normalized = area.toLowerCase().replace(/[\s\-_]/g, '');
  const found = areaHotels.find(h => {
    const hNorm = h.area.toLowerCase().replace(/[\s\-_]/g, '');
    return normalized.includes(hNorm) || hNorm.includes(normalized);
  });
  return found || areaHotels[0];
}

let cachedPhonePlans = [];

let currentStops = [...defaultStops];
let currentPlanTitle = "Penang Journey (Default / 默认行程)";

// 从已连接的 Android 手机读取用户在 App 内保存的真实 Plan

const ACTIVE_TRIP_CACHE_FILE = path.join(__dirname, 'active_trip_cache.json');
let latestActiveTripFromPhone = null;
try {
  if (fs.existsSync(ACTIVE_TRIP_CACHE_FILE)) {
    latestActiveTripFromPhone = JSON.parse(fs.readFileSync(ACTIVE_TRIP_CACHE_FILE, 'utf8'));
  }
} catch (e) {}

function parsePlanStartDate(plan) {
  if (!plan || !plan.travelDateRange) return null;
  const raw = plan.travelDateRange.trim();
  const iso = raw.match(/(\d{4})[-/](\d{1,2})[-/](\d{1,2})/);
  if (iso) return new Date(parseInt(iso[1]), parseInt(iso[2]) - 1, parseInt(iso[3]));
  const months = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
  const textMatch = raw.match(/(\d{1,2})\s+([a-zA-Z]{3,9})\s+(\d{4})/);
  if (textMatch) {
    const day = parseInt(textMatch[1]);
    const monthStr = textMatch[2].substring(0, 3).toLowerCase();
    const year = parseInt(textMatch[3]);
    const mIdx = months.indexOf(monthStr);
    if (mIdx !== -1) return new Date(year, mIdx, day);
  }
  return null;
}

function findMostUpcomingPlan(plans) {
  if (!plans || plans.length === 0) return null;
  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  let bestPlan = null;
  let minDiff = Infinity;
  for (const plan of plans) {
    const start = parsePlanStartDate(plan);
    if (!start) continue;
    const diffDays = Math.round((start - today) / (1000 * 60 * 60 * 24));
    if (diffDays >= 0 && diffDays < minDiff) {
      minDiff = diffDays;
      bestPlan = plan;
    }
  }
  return bestPlan || plans[0];
}

function syncTripPlansFromPhone() {
  return new Promise((resolve) => {
    exec('adb shell "run-as com.example.kiapenang_fypnewdev cat shared_prefs/FlutterSharedPreferences.xml"', (err, stdout, stderr) => {
      if (err) {
        return resolve({ success: false, msg: 'ADB connection or app permission error: ' + err.message });
      }
      try {
        // 1. Check if an active running trip plan exists
        let activeTripPlan = null;
        const activeMatch = stdout.match(/<string name="flutter\.kiapenang_active_trip_plan">([\s\S]*?)<\/string>/);
        if (activeMatch && activeMatch[1]) {
          try {
            let actRaw = activeMatch[1].trim();
            if (actRaw.startsWith('!')) actRaw = actRaw.substring(1).trim();
            actRaw = actRaw.replace(/&quot;/g, '"').replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>');
            activeTripPlan = JSON.parse(actRaw);
          } catch (e) {
            console.error('Error parsing active trip plan:', e);
          }
        }

        // 2. Check selected plan ID
        let selectedPlanId = null;
        const selMatch = stdout.match(/<string name="flutter\.kiapenang_selected_plan_id">([\s\S]*?)<\/string>/);
        if (selMatch && selMatch[1]) {
          selectedPlanId = selMatch[1].trim().replace(/^!/, '').replace(/&quot;/g, '"');
        }

        // 3. Parse saved trip plans list
        const match = stdout.match(/<string name="flutter\.kiapenang_saved_trip_plans">([\s\S]*?)<\/string>/);
        let plans = [];
        if (match && match[1]) {
          let rawContent = match[1].trim();
          const prefix = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu";
          if (rawContent.startsWith(prefix)) {
            rawContent = rawContent.substring(prefix.length).trim();
          }
          if (rawContent.startsWith('!')) {
            rawContent = rawContent.substring(1).trim();
          }
          // HTML unescape
          rawContent = rawContent.replace(/&quot;/g, '"').replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>');
          const list = JSON.parse(rawContent);
          if (Array.isArray(list)) {
            plans = list.map(item => typeof item === 'string' ? JSON.parse(item) : item);
          }
        }

        if (!activeTripPlan && plans.length === 0) {
          return resolve({ success: false, msg: 'Phone has 0 saved plans. Please save a plan in the App first!' });
        }

        cachedPhonePlans = plans;
        return resolve({ success: true, activeTripPlan, selectedPlanId, plans });
      } catch (parseErr) {
        return resolve({ success: false, msg: 'Parse error: ' + parseErr.message });
      }
    });
  });
}

// Reusable engine to activate a full plan with correct stop order and departure origin
async function activatePlan(plan, options = {}) {
  if (!plan || !Array.isArray(plan.stops) || plan.stops.length === 0) {
    throw new Error('Plan has no valid stops.');
  }

  currentPlanTitle = plan.title || plan.cleanTitle || 'Penang Trip Plan';

  if (options.virtualStartTime || plan.virtualStartTime) {
    const parsedTime = parseVirtualTime(options.virtualStartTime || plan.virtualStartTime);
    if (!isNaN(parsedTime.getTime())) {
      travelState.virtualTime = parsedTime;
    }
  }

  currentStops = plan.stops.map((s, idx) => {
    let stayMins = 30;
    if (s.stayDuration) {
      const match = s.stayDuration.match(/\d+/);
      if (match) stayMins = parseInt(match[0]);
    }
    return {
      id: s.stopNumber || (idx + 1),
      name: s.placeName || `Stop ${idx + 1}`,
      nameEn: s.placeName || `Stop ${idx + 1}`,
      nameZh: s.placeName || `Stop ${idx + 1}`,
      area: s.area || 'George Town',
      lat: s.lat || 5.414,
      lng: s.lng || 100.328,
      stayMinutes: stayMins,
      plannedArrive: s.timeSlot ? s.timeSlot.split('-')[0].trim() : '10:00 AM',
      plannedDepart: s.timeSlot && s.timeSlot.includes('-') ? s.timeSlot.split('-')[1].trim() : '11:00 AM'
    };
  });

  let targetStopIndex = options.currentStopIndex !== undefined
    ? Number(options.currentStopIndex)
    : (plan.currentStopIndex !== undefined ? Number(plan.currentStopIndex) : 0);

  if (targetStopIndex < 0 || targetStopIndex >= currentStops.length) {
    targetStopIndex = 0;
  }

  let startLat = options.startLat || plan.startLat;
  let startLng = options.startLng || plan.startLng;
  let originName = options.originName || plan.originName;

  if (!startLat || !startLng) {
    const firstArea = (currentStops[0] && currentStops[0].area) || (plan.stops && plan.stops[0] && plan.stops[0].area) || plan.travelArea || 'Georgetown';
    const hotel = getAreaHotelCoords(firstArea);
    startLat = hotel.lat;
    startLng = hotel.lng;
    originName = hotel.name;
  } else {
    startLat = Number(startLat);
    startLng = Number(startLng);
  }

  travelState.isPlaying = false;
  travelState.currentStopIndex = targetStopIndex;
  travelState.startHotel = {
    name: originName || 'Starting Hotel',
    nameEn: originName || 'Starting Hotel',
    nameZh: originName || '出发酒店',
    lat: startLat,
    lng: startLng
  };
  travelState.currentLat = startLat;
  travelState.currentLng = startLng;
  const initialArrived = options.isArrived === true || plan.isArrived === true;
  travelState.isStaying = initialArrived;
  travelState.stopStatuses = currentStops.map((_, i) =>
    i < targetStopIndex ? 'completed' : (i === targetStopIndex ? (initialArrived ? 'arrived' : 'enroute') : 'waiting')
  );
  travelState.activeLegWaypoints = [];
  travelState.isStaying = false;

  try {
    if (currentStops.length > 0) {
      await planCurrentLeg();
      travelState.isPlaying = true;
    }
  } catch (err) {
    console.error('Auto plan error on activatePlan:', err);
  }

  addTelemetry('incident', '🔄 [PLAN SYNCED]', `Loaded "${currentPlanTitle}" with ${currentStops.length} stops! Starting at ${originName || 'Departure Point'} (${startLat.toFixed(4)}, ${startLng.toFixed(4)}) heading to Stop ${targetStopIndex + 1}: ${currentStops[targetStopIndex].nameEn}.`);

  return {
    planTitle: currentPlanTitle,
    stops: currentStops,
    currentStopIndex: targetStopIndex,
    startLat,
    startLng,
    originName
  };
}

// 工具函数：计算两点直线距离 (米)
function calculateHaversine(lat1, lon1, lat2, lon2) {
  const R = 6371e3;
  const φ1 = lat1 * Math.PI / 180;
  const φ2 = lat2 * Math.PI / 180;
  const Δφ = (lat2 - lat1) * Math.PI / 180;
  const Δλ = (lon2 - lon1) * Math.PI / 180;
  const a = Math.sin(Δφ/2) * Math.sin(Δφ/2) +
            Math.cos(φ1) * Math.cos(φ2) *
            Math.sin(Δλ/2) * Math.sin(Δλ/2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
  return R * c;
}

// 调用 OSRM API 获取真实路网路线 (带降级方案)
async function fetchOsrmRoute(startLat, startLng, endLat, endLng, mode = 'walking') {
  const osrmProfile = mode === 'driving' ? 'driving' : 'walking';
  const url = `http://router.project-osrm.org/route/v1/${osrmProfile}/${startLng},${startLat};${endLng},${endLat}?overview=full&geometries=geojson`;
  
  try {
    const res = await axios.get(url, { timeout: 3500 });
    if (res.data && res.data.routes && res.data.routes.length > 0) {
      const route = res.data.routes[0];
      const coords = route.geometry.coordinates.map(pt => ({ lng: pt[0], lat: pt[1] }));
      return {
        distance: route.distance, // 米
        duration: route.duration, // 秒
        waypoints: coords,
        source: 'OSRM Official Road Network'
      };
    }
  } catch (err) {
    // 网络受限时使用高保真路网插值降级
  }

  // 降级：高质量插值
  const straightDist = calculateHaversine(startLat, startLng, endLat, endLng);
  const roadFactor = 1.28; // 真实城市街道曲折系数
  const actualDist = straightDist * roadFactor;
  const speedMps = mode === 'driving' ? 9.5 : 1.25; // 34 km/h vs 4.5 km/h
  const duration = actualDist / speedMps;
  
  const steps = Math.max(8, Math.floor(actualDist / (mode === 'driving' ? 30 : 10)));
  const waypoints = [];
  for (let i = 0; i <= steps; i++) {
    const ratio = i / steps;
    const lat = startLat + (endLat - startLat) * ratio;
    const lng = startLng + (endLng - startLng) * ratio;
    waypoints.push({ lat, lng });
  }

  return {
    distance: actualDist,
    duration: duration,
    waypoints,
    source: 'Urban Street Interpolation (Fallback)'
  };
}

// 执行 ADB 模拟位置命令并记录报文
function sendAdbGeo(lat, lng) {
  const cmd = `adb emu geo fix ${lng.toFixed(5)} ${lat.toFixed(5)}`;
  exec(cmd, (err, stdout, stderr) => {
    if (err) {
      travelState.lastAdbOutput = `Emulated (Real Phone / No emu daemon): ${cmd}`;
    } else {
      travelState.lastAdbOutput = `ADB OK: ${cmd}`;
    }
  });

  addTelemetry('adb', '📍 [ADB MOCK GPS DISPATCH]', cmd, {
    latitude: Number(lat.toFixed(5)),
    longitude: Number(lng.toFixed(5)),
    virtualTime: formatVirtualTime(travelState.virtualTime),
    mode: travelState.travelMode,
    target: currentStops[travelState.currentStopIndex]?.nameEn || 'Detour Destination'
  });
}

function formatVirtualTime(date) {
  const dObj = (date instanceof Date && !isNaN(date.getTime())) ? date : new Date(date);
  const y = dObj.getFullYear();
  const m = String(dObj.getMonth() + 1).padStart(2, '0');
  const d = String(dObj.getDate()).padStart(2, '0');
  const rawH = dObj.getHours();
  const h12 = rawH % 12 === 0 ? 12 : rawH % 12;
  const hourStr = String(h12).padStart(2, '0');
  const minStr = String(dObj.getMinutes()).padStart(2, '0');
  const secStr = String(dObj.getSeconds()).padStart(2, '0');
  const ampm = rawH >= 12 ? 'PM' : 'AM';
  return `${y}-${m}-${d}, ${hourStr}:${minStr}:${secStr} ${ampm}`;
}

// Parses string or Date into Date object matching identical format
function parseVirtualTime(val) {
  if (!val) return new Date();
  if (val instanceof Date) return val;
  if (typeof val === 'string') {
    const match = val.match(/^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2}),?\s*(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(AM|PM)$/i);
    if (match) {
      const y = parseInt(match[1]);
      const m = parseInt(match[2]) - 1;
      const d = parseInt(match[3]);
      let h = parseInt(match[4]);
      const min = parseInt(match[5]);
      const sec = match[6] ? parseInt(match[6]) : 0;
      const isPm = match[7].toUpperCase() === 'PM';
      if (isPm && h < 12) h += 12;
      if (!isPm && h === 12) h = 0;
      return new Date(y, m, d, h, min, sec);
    }
    const d = new Date(val);
    if (!isNaN(d.getTime())) return d;
  }
  return new Date();
}

// 规划前往当前目标的航线
async function planCurrentLeg(overrideTarget = null) {
  const target = overrideTarget || currentStops[travelState.currentStopIndex];
  if (!target) return;

  const result = await fetchOsrmRoute(
    travelState.currentLat,
    travelState.currentLng,
    target.lat,
    target.lng,
    travelState.travelMode
  );

  travelState.activeLegWaypoints = result.waypoints;
  travelState.currentWaypointIndex = 0;
  travelState.remainingDistanceMeters = Math.round(result.distance);
  travelState.totalDistanceMeters = Math.round(result.distance);
  travelState.remainingDurationSeconds = Math.round(result.duration);

  addTelemetry('routing', '🧭 [ROUTE ENGINE COMPUTATION]', `${result.source}`, {
    from: `(${travelState.currentLat.toFixed(4)}, ${travelState.currentLng.toFixed(4)})`,
    to: target.nameEn || target.name,
    distanceMeters: Math.round(result.distance),
    transitTimeMinutes: (result.duration / 60).toFixed(1),
    travelMode: travelState.travelMode
  });
}

// 模拟主循环 (每秒触发一次)
setInterval(() => {
  if (!travelState.isPlaying) return;

  const speedMultiplier = travelState.playbackSpeed;
  // 虚拟时间向前推进
  travelState.virtualTime = new Date(travelState.virtualTime.getTime() + 1000 * speedMultiplier);

  // 如果处于停留状态 (Staying at stop)
  // 严格保持停留在当前站点，绝不自动跳转下一站！必须等待用户在 App 点击 Depart 或在 Dashboard 点击操作
  if (travelState.isStaying) {
    if (travelState.staySecondsRemaining > 0) {
      travelState.staySecondsRemaining -= 1 * speedMultiplier;
    }
    return;
  }

  // 行进中 (Moving along waypoints)
  if (travelState.activeLegWaypoints && travelState.activeLegWaypoints.length > 0) {
    const stepsToAdvance = Math.max(1, Math.floor(speedMultiplier * (travelState.travelMode === 'driving' ? 2 : 1)));
    travelState.currentWaypointIndex += stepsToAdvance;

    if (travelState.currentWaypointIndex >= travelState.activeLegWaypoints.length) {
      travelState.currentWaypointIndex = travelState.activeLegWaypoints.length - 1;
      const finalPt = travelState.activeLegWaypoints[travelState.currentWaypointIndex];
      travelState.currentLat = finalPt.lat;
      travelState.currentLng = finalPt.lng;
      sendAdbGeo(travelState.currentLat, travelState.currentLng);

      // 到达目的地判定
      const targetStop = currentStops[travelState.currentStopIndex];
      travelState.isStaying = true;
      const stayMins = targetStop?.stayMinutes || 15;
      travelState.staySecondsRemaining = stayMins * 60;
      travelState.stopStatuses[travelState.currentStopIndex] = 'arrived';
      travelState.remainingDistanceMeters = 0;
      travelState.remainingDurationSeconds = 0;

      addTelemetry('incident', `🎉 [ARRIVED / 成功抵达]`, `Reached ${targetStop?.nameEn || 'Waypoint'}! Staying for ${stayMins} mins.`);
    } else {
      const currentPt = travelState.activeLegWaypoints[travelState.currentWaypointIndex];
      travelState.currentLat = currentPt.lat;
      travelState.currentLng = currentPt.lng;
      sendAdbGeo(travelState.currentLat, travelState.currentLng);

      // 递减剩余距离与时间
      const remainingWaypoints = travelState.activeLegWaypoints.length - travelState.currentWaypointIndex;
      const totalWaypoints = travelState.activeLegWaypoints.length || 1;
      const totalDist = travelState.totalDistanceMeters || travelState.remainingDistanceMeters;
      travelState.remainingDistanceMeters = Math.max(0, Math.round(totalDist * (remainingWaypoints / totalWaypoints)));
      travelState.remainingDurationSeconds = Math.max(0, Math.round(travelState.remainingDurationSeconds - (1 * speedMultiplier)));
    }
  }
}, 1000);

// ==========================================
// 4. API 路由与接口 (API Endpoints)
// ==========================================

// --- 原有天气接口 (100% 保持原有逻辑) ---
app.get('/api/weather', (req, res) => {
  res.json({
    code: 200,
    msg: "success",
    data: currentWeather
  });
});

app.get('/api/history', (req, res) => {
  res.json({
    code: 200,
    data: sendHistory
  });
});

app.post('/api/weather', (req, res) => {
  const { location, condition, temperature, humidity, rain_rate_mm_hr, rain_category } = req.body;
  const tempNum = Number(temperature);

  if (isNaN(tempNum) || tempNum < 20 || tempNum > 45) {
    return res.status(400).json({
      code: 400,
      msg: "Temperature must be between 20°C and 45°C"
    });
  }

  currentWeather = computeWeatherPayload({
    location,
    condition,
    temperature: tempNum,
    humidity,
    rain_rate_mm_hr,
    rain_category
  });

  const recordId = Date.now();
  const startTime = new Date().toLocaleTimeString();

  const historyItem = {
    id: recordId,
    sendTime: startTime,
    location: currentWeather.location,
    condition: currentWeather.condition,
    temperature: currentWeather.temperature,
    humidity: currentWeather.humidity,
    rainRate: currentWeather.rain_rate_mm_hr,
    rainCategory: currentWeather.rain_category,
    isSevere: currentWeather.is_severe,
    status: 'pending'
  };
  sendHistory.unshift(historyItem);

  addTelemetry(
    'weather',
    currentWeather.is_severe ? '🚨 [SEVERE WEATHER BROADCAST]' : '📡 [WEATHER BROADCAST POST]',
    `${currentWeather.location}: ${currentWeather.condition} | ${currentWeather.temperature}°C | Rain: ${currentWeather.rain_rate_mm_hr} mm/h (${currentWeather.rain_category})`,
    currentWeather
  );

  setTimeout(() => {
    const targetItem = sendHistory.find(item => item.id === recordId);
    if (targetItem) {
      targetItem.status = 'received';
      targetItem.receiveTime = new Date().toLocaleTimeString();
    }
  }, 2 * 60 * 1000);

  res.json({
    code: 200,
    msg: "Weather data dispatched successfully!",
    data: currentWeather
  });
});

// --- 新增：从手机同步行程 (Sync from Phone) ---
app.post('/api/simulation/sync-from-phone', async (req, res) => {
  try {
    let chosenPlan = null;
    let syncOptions = {};

    if (req.body && Array.isArray(req.body.stops) && req.body.stops.length > 0) {
      // 1. Direct HTTP Push from Flutter App (Guaranteed Active Trip)
      chosenPlan = {
        id: req.body.planId,
        title: req.body.planTitle || 'Live Synced Trip Plan from Phone',
        stops: req.body.stops,
        travelDateRange: req.body.travelDateRange,
        travelSchedule: req.body.travelSchedule,
        travelArea: req.body.travelArea,
      };
      syncOptions = {
        currentStopIndex: req.body.currentStopIndex !== undefined ? req.body.currentStopIndex : 0,
        isArrived: req.body.isArrived !== undefined ? req.body.isArrived : false,
        startLat: req.body.startLat,
        startLng: req.body.startLng,
        originName: req.body.originName,
        virtualStartTime: req.body.virtualStartTime
      };
      latestActiveTripFromPhone = { ...chosenPlan, ...syncOptions };
      try {
        fs.writeFileSync(ACTIVE_TRIP_CACHE_FILE, JSON.stringify(latestActiveTripFromPhone, null, 2));
      } catch (e) {}
    } else {
      // 2. Triggered by web 'Sync from Phone' button
      const syncResult = await syncTripPlansFromPhone();
      if (syncResult.success) {
        const allPlans = syncResult.plans || [];
        cachedPhonePlans = allPlans;

        // Priority 1: User's running active trip in app
        if (syncResult.activeTripPlan && Array.isArray(syncResult.activeTripPlan.stops) && syncResult.activeTripPlan.stops.length > 0) {
          chosenPlan = syncResult.activeTripPlan;
          syncOptions = {
            currentStopIndex: syncResult.activeTripPlan.currentStopIndex !== undefined ? syncResult.activeTripPlan.currentStopIndex : 0,
            startLat: syncResult.activeTripPlan.startLat,
            startLng: syncResult.activeTripPlan.startLng,
            originName: syncResult.activeTripPlan.originName,
            virtualStartTime: syncResult.activeTripPlan.virtualStartTime
          };
        }
        // Priority 2: Selected plan ID from app
        else if (syncResult.selectedPlanId && allPlans.length > 0) {
          const found = allPlans.find(p => p.id === syncResult.selectedPlanId);
          if (found) {
            chosenPlan = found;
            syncOptions = { currentStopIndex: 0 };
          }
        }

        // Priority 3: Upcoming / Active plan matching today's date (closest to today)
        if (!chosenPlan && allPlans.length > 0) {
          chosenPlan = findMostUpcomingPlan(allPlans);
          syncOptions = { currentStopIndex: 0 };
        }

        if (chosenPlan) {
          latestActiveTripFromPhone = { ...chosenPlan, ...syncOptions };
          try {
            fs.writeFileSync(ACTIVE_TRIP_CACHE_FILE, JSON.stringify(latestActiveTripFromPhone, null, 2));
          } catch (e) {}
        }
      } else {
        // ADB unavailable (e.g. phone running wirelessly on LAN)
        if (latestActiveTripFromPhone && Array.isArray(latestActiveTripFromPhone.stops) && latestActiveTripFromPhone.stops.length > 0) {
          chosenPlan = latestActiveTripFromPhone;
          syncOptions = {
            currentStopIndex: latestActiveTripFromPhone.currentStopIndex !== undefined ? latestActiveTripFromPhone.currentStopIndex : 0,
            startLat: latestActiveTripFromPhone.startLat,
            startLng: latestActiveTripFromPhone.startLng,
            originName: latestActiveTripFromPhone.originName,
            virtualStartTime: latestActiveTripFromPhone.virtualStartTime
          };
        } else {
          return res.json({
            code: 400,
            msg: syncResult.msg || 'No active trip found on phone yet. Please start a trip in the Kia Kia app!'
          });
        }
      }
    }

    if (!chosenPlan || !chosenPlan.stops || chosenPlan.stops.length === 0) {
      return res.json({ code: 400, msg: 'No valid itinerary stops found to sync.' });
    }

    const activated = await activatePlan(chosenPlan, syncOptions);

    res.json({
      code: 200,
      msg: `Successfully synced active trip "${activated.planTitle}" (${activated.stops.length} stops) from phone! Heading to Stop ${activated.currentStopIndex + 1}: ${activated.stops[activated.currentStopIndex].nameEn}.`,
      data: {
        planTitle: activated.planTitle,
        stops: activated.stops,
        currentStopIndex: activated.currentStopIndex
      }
    });
  } catch (err) {
    console.error('Sync error:', err);
    res.json({ code: 500, msg: 'Sync error: ' + err.message });
  }
});

// 槟城主要室内大型商场地标库 (用于暴雨自动推荐避雨室内场所)

// --- 全槟城各区域真实咖啡馆与地道美食候选池 (覆盖乔治市、浮罗山背、峇都丁宜、亚依淡、峇六拜等) ---
const penangCafes = [
  // 乔治市 (George Town)
  { name: 'China House Cafe', nameEn: 'China House Cafe', lat: 5.4148, lng: 100.3392, area: 'Beach St, George Town' },
  { name: 'The Daily Dose Cafe', nameEn: 'The Daily Dose Cafe', lat: 5.4192, lng: 100.3361, area: 'Stewart Lane, George Town' },
  { name: 'Mugshot Cafe', nameEn: 'Mugshot Cafe', lat: 5.4183, lng: 100.3369, area: 'Chulia St, George Town' },
  { name: 'Urban Daybreak Cafe', nameEn: 'Urban Daybreak Cafe', lat: 5.4135, lng: 100.3371, area: 'Lebuh Pantai, George Town' },
  { name: 'Ounces Coffee', nameEn: 'Ounces Coffee', lat: 5.4155, lng: 100.3375, area: 'Armenian St, George Town' },
  { name: 'Narrow Marrow Cafe', nameEn: 'Narrow Marrow Cafe', lat: 5.4208, lng: 100.3352, area: 'Leith St, George Town' },
  // 浮罗山背 (Balik Pulau)
  { name: '2F Cranberry Bakery & Cafe', nameEn: '2F Cranberry Cafe', lat: 5.3518, lng: 100.2365, area: 'Balik Pulau Town' },
  { name: 'Bao Sheng Durian Farm & Cafe', nameEn: 'Bao Sheng Durian Cafe', lat: 5.3875, lng: 100.2158, area: 'Balik Pulau' },
  { name: 'Audi Dream Cafe', nameEn: 'Audi Dream Farm Cafe', lat: 5.3522, lng: 100.2045, area: 'Balik Pulau' },
  { name: 'Micro Bakery Cafe Balik Pulau', nameEn: 'Micro Bakery Cafe', lat: 5.3530, lng: 100.2370, area: 'Balik Pulau' },
  // 峇都丁宜 & 直落巴巷 (Batu Ferringhi & Teluk Bahang)
  { name: 'Bora Bora Beach Cafe', nameEn: 'Bora Bora Beach Cafe', lat: 5.4746, lng: 100.2482, area: 'Batu Ferringhi' },
  { name: 'Ferringhi Garden Cafe & Dining', nameEn: 'Ferringhi Garden Cafe', lat: 5.4725, lng: 100.2465, area: 'Batu Ferringhi' },
  { name: 'Escape Green Cafe Teluk Bahang', nameEn: 'Escape Green Cafe', lat: 5.4495, lng: 100.2162, area: 'Teluk Bahang' },
  // 亚依淡 & 升旗山 (Air Itam & Penang Hill)
  { name: "David Brown's Restaurant & Tea Terrace", nameEn: "David Brown's Tea Terrace", lat: 5.4243, lng: 100.2687, area: 'Penang Hill, Air Itam' },
  { name: 'Kuan Yin Vegetarian Cafe', nameEn: 'Kuan Yin Cafe', lat: 5.3995, lng: 100.2740, area: 'Air Itam' },
  // 峇六拜 (Bayan Lepas)
  { name: 'The Coffee Code SPICE', nameEn: 'The Coffee Code', lat: 5.3290, lng: 100.2835, area: 'Bayan Lepas' },
  { name: 'Coffeesmith Bayan Lepas', nameEn: 'Coffeesmith Bayan Lepas', lat: 5.3285, lng: 100.2820, area: 'Bayan Lepas' }
];

const penangFoodSpots = [
  // 乔治市 (George Town)
  { name: 'Lorong Selamat Char Koay Teow', nameEn: 'Lorong Selamat Char Koay Teow', lat: 5.4172, lng: 100.3248, area: 'Lorong Selamat, George Town' },
  { name: 'Kimberley St Duck Kway Chap', nameEn: 'Kimberley St Duck Kway Chap', lat: 5.4162, lng: 100.3332, area: 'Lebuh Kimberley, George Town' },
  { name: 'Penang Road Teochew Chendul & Laksa', nameEn: 'Penang Road Teochew Chendul', lat: 5.4172, lng: 100.3307, area: 'Jalan Penang, George Town' },
  { name: 'Line Clear Nasi Kandar', nameEn: 'Line Clear Nasi Kandar', lat: 5.4200, lng: 100.3328, area: 'Penang Road, George Town' },
  { name: 'New Lane Hawker Stalls', nameEn: 'New Lane Hawker Stalls', lat: 5.4149, lng: 100.3263, area: 'Lorong Baru, George Town' },
  { name: 'Chulia Street Night Hawker', nameEn: 'Chulia Street Night Hawker', lat: 5.4182, lng: 100.3364, area: 'Chulia St, George Town' },
  // 浮罗山背 (Balik Pulau)
  { name: 'Kim Laksa Balik Pulau', nameEn: 'Kim Laksa Balik Pulau', lat: 5.3521, lng: 100.2366, area: 'Balik Pulau Town' },
  { name: 'Nan Guang Coffee Shop (Balik Pulau Laksa)', nameEn: 'Nan Guang Kopitiam', lat: 5.3516, lng: 100.2363, area: 'Balik Pulau Town' },
  { name: 'Balik Pulau Hawker Food Court', nameEn: 'Balik Pulau Food Court', lat: 5.3508, lng: 100.2355, area: 'Balik Pulau' },
  { name: 'Karikalan Famous Roti Canai', nameEn: 'Karikalan Roti Canai', lat: 5.3535, lng: 100.2380, area: 'Balik Pulau' },
  // 峇都丁宜 & 直落巴巷 (Batu Ferringhi & Teluk Bahang)
  { name: 'Long Beach Hawker Centre', nameEn: 'Long Beach Hawker Centre', lat: 5.4735, lng: 100.2475, area: 'Batu Ferringhi' },
  { name: 'Living Room Seafood Restaurant', nameEn: 'Living Room Seafood', lat: 5.4740, lng: 100.2480, area: 'Batu Ferringhi' },
  { name: 'Teluk Bahang Seafood Village', nameEn: 'Teluk Bahang Seafood', lat: 5.4590, lng: 100.2110, area: 'Teluk Bahang' },
  // 亚依淡 (Air Itam)
  { name: 'Air Itam Sister Curry Mee', nameEn: 'Air Itam Sister Curry Mee', lat: 5.4018, lng: 100.2778, area: 'Air Itam' },
  { name: 'Air Itam Asam Laksa Pasar', nameEn: 'Air Itam Asam Laksa', lat: 5.4012, lng: 100.2770, area: 'Air Itam Pasar' },
  // 峇六拜 (Bayan Lepas)
  { name: 'Kapitan Restaurant Bayan Lepas', nameEn: 'Kapitan Bayan Lepas', lat: 5.3310, lng: 100.2840, area: 'Bayan Lepas' },
  { name: 'Pisa Corner Hawker Food Court', nameEn: 'Pisa Corner Food Court', lat: 5.3325, lng: 100.2855, area: 'Bayan Lepas' }
];

function findClosestCandidate(type, userLat, userLng) {
  const pool = type === 'cafe' ? penangCafes : penangFoodSpots;
  let closest = pool[0];
  let minDist = Infinity;
  for (const item of pool) {
    const d = calculateHaversine(userLat, userLng, item.lat, item.lng);
    if (d < minDist) {
      minDist = d;
      closest = item;
    }
  }
  return closest;
}

// (penangMalls declared at top of file)

function getNearestMall(userLat, userLng) {
  let nearest = null;
  let minDistance = Infinity;

  for (const mall of penangMalls) {
    const straightDist = calculateHaversine(userLat, userLng, mall.lat, mall.lng);
    const dist = straightDist * 1.25; // 真实城市街道路网距离折算
    if (dist < minDistance) {
      minDistance = dist;
      nearest = {
        name: mall.name,
        nameEn: mall.nameEn,
        lat: mall.lat,
        lng: mall.lng,
        area: mall.area,
        distanceMeters: Math.round(dist),
        durationMinutes: Math.max(1, Number((dist / (9.5 * 60)).toFixed(1))) // 预计乘车耗时(分钟)
      };
    }
  }
  return nearest;
}

// --- 新增：旅行模拟状态控制 API ---
app.get('/api/simulation/state', (req, res) => {
  const nearestMall = getNearestMall(travelState.currentLat, travelState.currentLng);
  res.json({
    code: 200,
    data: {
      ...travelState,
      virtualTimeString: formatVirtualTime(travelState.virtualTime),
      stops: currentStops,
      planTitle: currentPlanTitle,
      nearestMall
    }
  });
});

app.post('/api/simulation/control', async (req, res) => {
  const { action, value } = req.body;

  if (action === 'play') {
    travelState.isPlaying = true;
    if (travelState.activeLegWaypoints.length === 0) {
      await planCurrentLeg();
    }
    addTelemetry('incident', '▶ [PLAY / 开始模拟]', `Simulation started at speed ${travelState.playbackSpeed}x`);
  } else if (action === 'pause') {
    travelState.isPlaying = false;
    addTelemetry('incident', '⏸ [PAUSE / 暂停模拟]', 'Simulation paused');
  } else if (action === 'clearIncident') {
    setActiveIncident(null);
    addTelemetry('incident', '🧹 [CLEAR INCIDENT]', 'Incident alert cleared.');
  } else if (action === 'setSpeed') {
    travelState.playbackSpeed = Number(value);
    addTelemetry('incident', '⏩ [SPEED CHANGE / 切换倍速]', `Playback speed set to ${value}x`);
  } else if (action === 'setMode') {
    travelState.travelMode = value; // 'walking' | 'driving'
    await planCurrentLeg();
    addTelemetry('incident', '🚗 [TRANSPORT MODE / 交通方式切换]', `Switched to ${value === 'walking' ? 'Walking 🚶' : 'Driving 🚗'}`);
  } else if (action === 'skipStay') {
    if (travelState.isStaying) {
      travelState.staySecondsRemaining = 0;
      travelState.isStaying = false;
      addTelemetry('incident', '⏩ [SKIP STAY / 跳过当前停留]', 'User departing immediately for next destination!');
    }
  } else if (action === 'skipStop') {
    if (travelState.currentStopIndex < currentStops.length - 1) {
      travelState.stopStatuses[travelState.currentStopIndex] = 'skipped';
      travelState.currentStopIndex++;
      travelState.stopStatuses[travelState.currentStopIndex] = 'enroute';
      await planCurrentLeg();
      addTelemetry('incident', '⏭️ [SKIP STOP / 跳过站点]', `Skipped to ${currentStops[travelState.currentStopIndex].nameEn}`);
    }
  } else if (action === 'teleport') {
    const stop = currentStops[value];
    if (stop) {
      travelState.currentLat = stop.lat;
      travelState.currentLng = stop.lng;
      travelState.currentStopIndex = value;
      sendAdbGeo(stop.lat, stop.lng);
      addTelemetry('incident', '⚡ [TELEPORT / 瞬移到位]', `Jumped to ${stop.nameEn}`);
    }
  } else if (action === 'updateJourneyState') {
    if (value) {
      if (value.currentStopIndex !== undefined) {
        const idx = Number(value.currentStopIndex);
        if (idx >= 0 && idx < currentStops.length) {
          travelState.currentStopIndex = idx;
        }
      }
      if (value.isArrived !== undefined) {
        const isArr = Boolean(value.isArrived);
        travelState.isStaying = isArr;
        travelState.stopStatuses = currentStops.map((_, i) =>
          i < travelState.currentStopIndex ? 'completed' : (i === travelState.currentStopIndex ? (isArr ? 'arrived' : 'enroute') : 'waiting')
        );
      }
      if (value.currentLat && value.currentLng) {
        travelState.currentLat = Number(value.currentLat);
        travelState.currentLng = Number(value.currentLng);
      }
      if (value.remainingDistanceMeters !== undefined) {
        travelState.remainingDistanceMeters = Math.max(0, Math.round(Number(value.remainingDistanceMeters)));
      }
      if (value.remainingDurationSeconds !== undefined) {
        travelState.remainingDurationSeconds = Math.max(0, Math.round(Number(value.remainingDurationSeconds)));
      }
      if (value.virtualTimeString) {
        const p = parseVirtualTime(value.virtualTimeString);
        if (!isNaN(p.getTime())) travelState.virtualTime = p;
      }
      sendAdbGeo(travelState.currentLat, travelState.currentLng);
    }
  } else if (action === 'visitStop') {
    // 用户直接点击任意 Stop 的 VISIT 按钮：将该站点设为当前目标，并重新从当前 GPS 规划导航
    const targetIdx = Number(value);
    if (targetIdx >= 0 && targetIdx < currentStops.length) {
      for (let i = 0; i < currentStops.length; i++) {
        if (i !== targetIdx && travelState.stopStatuses[i] === 'enroute') {
          travelState.stopStatuses[i] = i < targetIdx ? 'completed' : 'waiting';
        }
      }
      travelState.currentStopIndex = targetIdx;
      travelState.stopStatuses[targetIdx] = 'enroute';
      travelState.isPlaying = true;
      travelState.isStaying = false;
      await planCurrentLeg(currentStops[targetIdx]);
      addTelemetry('incident', '🎯 [TARGET OVERRIDE: VISIT STOP]', `User tapped VISIT on Stop ${targetIdx + 1}: ${currentStops[targetIdx].nameEn}! Re-routed from GPS (${travelState.currentLat.toFixed(4)}, ${travelState.currentLng.toFixed(4)}).`);
    }
  } else if (action === 'moveStopUp') {
    // 向上调换站点顺序
    const idx = Number(value);
    if (idx > 0 && idx < currentStops.length) {
      const temp = currentStops[idx - 1];
      currentStops[idx - 1] = currentStops[idx];
      currentStops[idx] = temp;
      await planCurrentLeg();
      addTelemetry('incident', '🔀 [RESEQUENCE: MOVED UP]', `Moved stop ${currentStops[idx-1].nameEn} up in sequence.`);
    }
  } else if (action === 'moveStopDown') {
    // 向下调换站点顺序
    const idx = Number(value);
    if (idx >= 0 && idx < currentStops.length - 1) {
      const temp = currentStops[idx + 1];
      currentStops[idx + 1] = currentStops[idx];
      currentStops[idx] = temp;
      await planCurrentLeg();
      addTelemetry('incident', '🔀 [RESEQUENCE: MOVED DOWN]', `Moved stop ${currentStops[idx+1].nameEn} down in sequence.`);
    }
  } else if (action === 'setVirtualTime') {
    const parsedTime = parseVirtualTime(value);
    if (!isNaN(parsedTime.getTime())) {
      travelState.virtualTime = parsedTime;
      addTelemetry('incident', '⏰ [VIRTUAL TIME SET]', `Updated virtual clock to ${formatVirtualTime(travelState.virtualTime)}`);
    }
  } else if (action === 'overstay') {
    const mins = Number(value) || 15;
    travelState.virtualTime = new Date(travelState.virtualTime.getTime() + mins * 60 * 1000);
    setActiveIncident(`⏳ Overstayed by +${mins} mins at current stop (拍照逗留超时 ${mins} 分钟)`);
    addTelemetry('incident', '⏳ [OVERSTAY APPLIED]', `Advanced virtual clock by ${mins} minutes. New Virtual Time: ${formatVirtualTime(travelState.virtualTime)}`);
  }

  res.json({ code: 200, data: travelState });
});

// --- 新增：根据用户当前模拟经纬度实时计算周边推荐 (Dynamic Nearby Places with Real OSRM Calculations) ---
app.get('/api/simulation/nearby', async (req, res) => {
  const type = req.query.type || 'cafe'; // 'cafe' | 'food'
  const userLat = Number(req.query.lat) || travelState.currentLat;
  const userLng = Number(req.query.lng) || travelState.currentLng;

  const candidatePool = type === 'cafe' ? penangCafes : penangFoodSpots;

  // 1. 根据当前 GPS 坐标进行距离排序
  const sorted = candidatePool.map(item => ({
    ...item,
    straightDist: calculateHaversine(userLat, userLng, item.lat, item.lng)
  })).sort((a, b) => a.straightDist - b.straightDist).slice(0, 3);

  // 2. 依次调用真实 OSRM 路由引擎，计算真实路网马路距离与通行用时
  const results = [];
  for (const place of sorted.slice(0, 2)) {
    const route = await fetchOsrmRoute(userLat, userLng, place.lat, place.lng, travelState.travelMode);
    results.push({
      name: place.name,
      nameEn: place.nameEn,
      lat: place.lat,
      lng: place.lng,
      area: place.area,
      distanceMeters: Math.round(route.distance),
      durationMinutes: Number((route.duration / 60).toFixed(1))
    });
  }

  res.json({
    success: true,
    userGps: { lat: userLat, lng: userLng },
    data: results
  });
});

// --- 新增：动态 Detour 自定义新目的地计算 API ---
app.post('/api/simulation/detour', async (req, res) => {
  const { name, lat, lng, mode } = req.body;
  const targetLat = Number(lat);
  const targetLng = Number(lng);

  if (isNaN(targetLat) || isNaN(targetLng)) {
    return res.status(400).json({ code: 400, msg: "Invalid latitude/longitude coordinates!" });
  }

  travelState.travelMode = mode || travelState.travelMode;
  
  // 插入到行程站点列表 (Travel Plan Stops)
  // 如果当前在站点停留中，插入到下一站；如果正在行进中，直接插入为当前目标站，原目标及后续站点全部顺延
  const insertIndex = travelState.isStaying 
    ? travelState.currentStopIndex + 1 
    : travelState.currentStopIndex;

  const detourStop = {
    id: `detour-${Date.now()}`,
    name: name || 'Custom Detour Place',
    nameEn: `[Detour] ${name || 'Custom Detour'}`,
    nameZh: `[改道] ${name || '临时景点'}`,
    lat: targetLat,
    lng: targetLng,
    stayMinutes: 20,
    plannedArrive: formatVirtualTime(travelState.virtualTime),
    plannedDepart: formatVirtualTime(new Date(travelState.virtualTime.getTime() + 20 * 60 * 1000)),
    isDetour: true
  };

  currentStops.splice(insertIndex, 0, detourStop);
  travelState.stopStatuses.splice(insertIndex, 0, 'enroute');
  travelState.currentStopIndex = insertIndex;

  const routeResult = await fetchOsrmRoute(
    travelState.currentLat,
    travelState.currentLng,
    targetLat,
    targetLng,
    travelState.travelMode
  );

  travelState.activeLegWaypoints = routeResult.waypoints;
  travelState.currentWaypointIndex = 0;
  travelState.remainingDistanceMeters = Math.round(routeResult.distance);
  travelState.remainingDurationSeconds = Math.round(routeResult.duration);
  travelState.isPlaying = true;
  travelState.isStaying = false;
  setActiveIncident(`🔀 Detour Active: Navigating to ${detourStop.nameEn} (改道前往新目的地)`);

  addTelemetry('routing', '🔀 [DETOUR ROUTE ACTIVATED / 确认偏航改道]', `Inserted "${detourStop.nameEn}" at Stop position ${insertIndex + 1}. All following stops shifted down.`, {
    roadDistanceMeters: Math.round(routeResult.distance),
    transitMinutes: (routeResult.duration / 60).toFixed(1),
    mode: travelState.travelMode
  });

  res.json({
    code: 200,
    data: {
      distance: Math.round(routeResult.distance),
      durationSeconds: Math.round(routeResult.duration),
      waypointsCount: routeResult.waypoints.length,
      stops: currentStops
    }
  });
});

// --- 新增：地理编码搜索接口 (Place Geocoding API - 自动根据地名获取经纬度) ---
app.get('/api/geocode', async (req, res) => {
  const query = (req.query.q || '').trim();
  if (!query) {
    return res.status(400).json({ success: false, msg: 'Query parameter "q" is required.' });
  }

  // 1. 清理字符串中的常见无用修饰符 (如 @, 标点)
  const cleanQuery = query.replace(/[@#]/g, ' ').replace(/\s+/g, ' ').trim();

  // 2. 预设精选槟城热门地点词典 (秒回)
  const penangKnownPlaces = {
    'urban daybreak': { name: 'Urban Daybreak Cafe', lat: 5.41347, lng: 100.33712, area: 'Lebuh Pantai, George Town' },
    'china house': { name: 'China House Cafe', lat: 5.41480, lng: 100.33920, area: 'Beach St, George Town' },
    '1st avenue': { name: '1st Avenue Mall', lat: 5.41320, lng: 100.33120, area: 'George Town' },
    'prangin mall': { name: 'Prangin Mall', lat: 5.41450, lng: 100.33150, area: 'George Town' },
    'gurney plaza': { name: 'Gurney Plaza', lat: 5.43770, lng: 100.30970, area: 'Gurney Drive' },
    'gurney bay': { name: 'Gurney Bay', lat: 5.43900, lng: 100.31200, area: 'Gurney' },
    'armenian': { name: 'Armenian Street Murals', lat: 5.41410, lng: 100.33640, area: 'George Town' },
    'chew jetty': { name: 'Chew Jetty', lat: 5.41250, lng: 100.34000, area: 'Weld Quay' },
    'khoo kongsi': { name: 'Khoo Kongsi', lat: 5.41500, lng: 100.33800, area: 'Cannon Square' },
    'kek lok si': { name: 'Kek Lok Si Temple', lat: 5.39950, lng: 100.27360, area: 'Air Itam' },
    'penang hill': { name: 'Penang Hill Funicular', lat: 5.40850, lng: 100.27730, area: 'Air Itam' },
    'batu ferringhi': { name: 'Batu Ferringhi Beach', lat: 5.47460, lng: 100.24680, area: 'Batu Ferringhi' },
    'lorong selamat': { name: 'Lorong Selamat Char Koay Teow', lat: 5.41720, lng: 100.32480, area: 'George Town' },
    'teochew chendul': { name: 'Penang Road Teochew Chendul', lat: 5.41720, lng: 100.33070, area: 'Penang Road' },
    'pinang peranakan': { name: 'Pinang Peranakan Mansion', lat: 5.41800, lng: 100.34060, area: 'Church St' }
  };

  const lowerQ = cleanQuery.toLowerCase();
  for (const [key, val] of Object.entries(penangKnownPlaces)) {
    if (lowerQ.includes(key)) {
      return res.json({
        success: true,
        data: {
          name: val.name,
          lat: val.lat,
          lng: val.lng,
          area: val.area,
          source: 'Verified Penang POI Directory'
        }
      });
    }
  }

  // 3. 调用 Photon (OpenStreetMap) 高速地理编码服务
  try {
    const photonResp = await axios.get('https://photon.komoot.io/api/', {
      params: {
        q: cleanQuery,
        lat: 5.414,
        lon: 100.328,
        bbox: '100.10,5.10,100.60,5.60',
        limit: 5
      },
      timeout: 5000
    });

    const features = photonResp.data?.features || [];
    if (features.length > 0) {
      const top = features[0];
      const coords = top.geometry.coordinates; // [lng, lat]
      const props = top.properties || {};
      const placeName = props.name || props.street || query;
      const area = [props.street, props.city, props.state].filter(Boolean).join(', ');

      return res.json({
        success: true,
        data: {
          name: placeName,
          lat: Number(coords[1].toFixed(5)),
          lng: Number(coords[0].toFixed(5)),
          area: area || 'Penang, Malaysia',
          source: 'Photon OpenStreetMap'
        }
      });
    }
  } catch (err) {
    // 降级使用 Mapbox
  }

  // 4. Mapbox Geocoding 备用
  try {
    const mapboxToken = 'pk.eyJ1Ijoid2VpeHVuY2hlb25nIiwiYSI6ImNtcW9vazNzYTIyMGoyeHE2dDNhd3YzOWoifQ.V8mrHCQf3KSjJYp0eUvtaQ';
    const mbResp = await axios.get(`https://api.mapbox.com/geocoding/v5/mapbox.places/${encodeURIComponent(cleanQuery + ' Penang')}.json`, {
      params: {
        proximity: '100.33,5.41',
        bbox: '100.1,5.1,100.6,5.6',
        access_token: mapboxToken,
        limit: 1
      },
      timeout: 5000
    });
    const feats = mbResp.data?.features || [];
    if (feats.length > 0) {
      const coords = feats[0].geometry.coordinates;
      return res.json({
        success: true,
        data: {
          name: feats[0].text || query,
          lat: Number(coords[1].toFixed(5)),
          lng: Number(coords[0].toFixed(5)),
          area: feats[0].place_name,
          source: 'Mapbox Places'
        }
      });
    }
  } catch (err) {}

  return res.json({
    success: false,
    msg: `Could not locate "${query}" in Penang. Please adjust keywords or enter Lat/Lng directly.`
  });
});

// --- 新增：10 大突发事件触发 API ---
app.post('/api/simulation/incident', async (req, res) => {
  const { scenarioId } = req.body;
  let incidentLabel = '';

  switch (scenarioId) {
    case 'rain_stick_plan': // 场景 1A: 暴雨坚持原计划
      currentWeather.condition = 'rainy';
      currentWeather.temperature = 26;
      setActiveIncident('🌧️ Rain Alert: Sticking to original outdoor plan (用户撑伞继续前往原景点)');
      incidentLabel = '🌧️ 暴雨预警：撑伞坚持原计划';
      addTelemetry('incident', '🌧️ [SCENARIO 1A: RAIN - STICK TO PLAN]', 'Heavy rain triggered. User continues original route with umbrella.');
      break;

    case 'rain_indoor_backup': { // 场景 1B: 暴雨切换最近的室内商场
      currentWeather.condition = 'thunderstorm';
      currentWeather.temperature = 25;
      travelState.travelMode = 'driving'; // 打车去商场
      const targetMall = req.body.mall || getNearestMall(travelState.currentLat, travelState.currentLng) || { name: '1st Avenue Mall', lat: 5.4132, lng: 100.3312 };
      setActiveIncident(`🏢 Rain Alert: Switched to ${targetMall.name} (改道室内商场避雨)`);
      incidentLabel = `🏢 暴雨改道：切换至 ${targetMall.name} 室内避雨`;
      await planCurrentLeg({ name: targetMall.name, nameEn: targetMall.name, lat: targetMall.lat, lng: targetMall.lng });
      travelState.isPlaying = true;
      travelState.isStaying = false;
      addTelemetry('incident', '🏢 [SCENARIO 1B: RAIN - INDOOR MALL]', `Switched destination to nearby ${targetMall.name} via Grab.`);
      break;
    }

    case 'rain_wait_out': // 场景 1C: 躲雨等待 (避雨 10 分钟)
      currentWeather.condition = 'rainy';
      travelState.isPlaying = false;
      travelState.isStaying = true;
      travelState.virtualTime = new Date(travelState.virtualTime.getTime() + 10 * 60 * 1000); // 虚拟时钟快进10分钟 (避雨10分钟)
      setActiveIncident(`☕ Rain Alert: Sheltered from rain for 10 mins (避雨等待 10 分钟，当前虚拟时间: ${formatVirtualTime(travelState.virtualTime)})`);
      incidentLabel = '☕ 暴雨避雨：原地避雨 10 分钟 (暂停行进)';
      addTelemetry('incident', '☕ [SCENARIO 1C: RAIN - SHELTER (10 MINS)]', `User sheltered under cover for 10 minutes. Advanced virtual time to ${formatVirtualTime(travelState.virtualTime)}.`);
      break;

    case 'rain_cleared': // 场景 1D: 雨停恢复 (避雨等待20分钟后放晴继续)
      currentWeather.condition = 'cloudy';
      currentWeather.temperature = 30;
      travelState.virtualTime = new Date(travelState.virtualTime.getTime() + 20 * 60 * 1000); // 虚拟时钟快进20分钟 (避雨20分钟)
      setActiveIncident(`☀️ Rain Cleared: Rain stopped after 20m wait; resuming trip (等待20分钟放晴，恢复原行程)`);
      incidentLabel = '☀️ 天气转晴 (等待20分钟)：恢复原行程路线';
      await planCurrentLeg();
      travelState.isPlaying = true;
      travelState.isStaying = false;
      addTelemetry('incident', '☀️ [WEATHER CLEARED (20 MINS WAIT)]', `Rain stopped after 20 mins wait. Advanced virtual time to ${formatVirtualTime(travelState.virtualTime)}. Resuming original trip.`);
      break;

    case 'cafe_detour': { // 场景 2: 绕路周边咖啡馆 (基于用户当前位置动态搜索最近咖啡馆)
      const closestCafe = findClosestCandidate('cafe', travelState.currentLat, travelState.currentLng);
      setActiveIncident(`☕ Detour: ${closestCafe.nameEn} (${closestCafe.area} / 喝茶小憩)`);
      incidentLabel = `☕ 临时绕路：前往附近 ${closestCafe.nameEn} (${closestCafe.area})`;
      await planCurrentLeg({ name: closestCafe.name, nameEn: closestCafe.nameEn, lat: closestCafe.lat, lng: closestCafe.lng });
      travelState.isPlaying = true;
      travelState.isStaying = false;
      addTelemetry('incident', '☕ [SCENARIO 2: CAFE DETOUR]', `Deviating route to nearest cafe based on current location: ${closestCafe.nameEn} (${closestCafe.area}).`);
      break;
    }

    case 'skip_crowded': // 场景 3: 景点排队爆满跳站
      travelState.stopStatuses[travelState.currentStopIndex] = 'skipped';
      travelState.currentStopIndex = Math.min(travelState.currentStopIndex + 1, currentStops.length - 1);
      travelState.stopStatuses[travelState.currentStopIndex] = 'enroute';
      setActiveIncident(`⏭️ Skipped Stop: Proceeding to ${currentStops[travelState.currentStopIndex].nameEn}`);
      incidentLabel = `⏭️ 跳过排队景点：直奔下一站 ${currentStops[travelState.currentStopIndex].nameEn}`;
      await planCurrentLeg();
      travelState.isPlaying = true;
      travelState.isStaying = false;
      addTelemetry('incident', '⏭️ [SCENARIO: SKIP OVERCROWDED STOP]', `Queuing too long. Directly routing to next attraction: ${currentStops[travelState.currentStopIndex].nameEn}`);
      break;

    case 'traffic_jam': // 场景 4: 高峰拥堵
      travelState.travelMode = 'driving';
      travelState.playbackSpeed = 1; // 减缓推进
      travelState.remainingDurationSeconds += 900; // +15分钟
      setActiveIncident('🚗 Traffic Jam: Heavy congestion (+15 mins ETA / 严重拥堵)');
      incidentLabel = '🚗 高峰严重拥堵：车速骤降，ETA 延后 15 分钟';
      addTelemetry('incident', '🚗 [SCENARIO: TRAFFIC JAM]', 'Traffic congestion simulated. Speed dropped to 5 km/h.');
      break;

    case 'road_closure': // 场景: 突发道路施工封路
      travelState.remainingDistanceMeters += 280;
      travelState.remainingDurationSeconds += 240; // +4分钟
      setActiveIncident('🚧 Road Closure: Obstacle ahead, detour reroute applied (+280m / 施工封路避让)');
      incidentLabel = '🚧 突发施工封路：前方道路封闭，导航自动绕行 (+280m)';
      await planCurrentLeg();
      travelState.isPlaying = true;
      addTelemetry('incident', '🚧 [SCENARIO: ROAD CLOSURE]', 'Road ahead blocked by construction. Rerouting via adjacent streets (+280m).');
      break;

    case 'heatwave': // 场景: 酷暑烈日预警 ➔ 强行转乘车
      currentWeather.temperature = 36;
      currentWeather.condition = 'sunny';
      travelState.travelMode = 'driving';
      setActiveIncident('☀️ Heatwave Alert: 36°C Switched to Grab Air-con car (酷暑避暑)');
      incidentLabel = '☀️ 36°C 酷暑预警：放弃步行，切换为 Grab 乘车避暑';
      await planCurrentLeg();
      travelState.isPlaying = true;
      addTelemetry('incident', '☀️ [SCENARIO: HEATWAVE WARNING]', 'Midday peak heat. Walking aborted; switched to Grab ride.');
      break;

    case 'food_detour': { // 场景 5: 临时地道美食打卡 (基于用户当前位置动态搜索最近地道美食)
      const closestFood = findClosestCandidate('food', travelState.currentLat, travelState.currentLng);
      setActiveIncident(`🍽️ Food Detour: ${closestFood.nameEn} (${closestFood.area} / 临时打卡美食)`);
      incidentLabel = `🍽️ 临时觅食：前往附近 ${closestFood.nameEn} (${closestFood.area})`;
      await planCurrentLeg({ name: closestFood.name, nameEn: closestFood.nameEn, lat: closestFood.lat, lng: closestFood.lng });
      travelState.isPlaying = true;
      travelState.isStaying = false;
      addTelemetry('incident', '🍽️ [SCENARIO 5: FOOD DETOUR]', `Inserted food stop based on current location: ${closestFood.nameEn} (${closestFood.area}).`);
      break;
    }

    case 'off_track': // 场景 7: 走错巷子偏航
      travelState.currentLat += 0.0018;
      travelState.currentLng -= 0.0015;
      sendAdbGeo(travelState.currentLat, travelState.currentLng);
      setActiveIncident('🗺️ Off-track: Deviated 180m off course (走错巷子偏航重算)');
      incidentLabel = '🗺️ 走错巷子偏航 180米：触发 App 偏航检测';
      await planCurrentLeg();
      addTelemetry('incident', '🗺️ [SCENARIO 7: OFF-TRACK / LOST]', 'Coordinates deviated from planned path to test rerouting.');
      break;

    case 'overstay': // 场景 7: 停留超时
    case 'overstay_15':
    case 'overstay_30':
    case 'overstay_60': {
      const mins = scenarioId === 'overstay_15' ? 15 : (scenarioId === 'overstay_30' ? 30 : (scenarioId === 'overstay_60' ? 60 : (Number(req.body.mins) || 15)));
      travelState.virtualTime = new Date(travelState.virtualTime.getTime() + mins * 60 * 1000);
      setActiveIncident(`⏳ Overstay Active: +${mins} mins at current stop! Virtual Time: ${formatVirtualTime(travelState.virtualTime)} (拍照逗留超时 ${mins} 分钟)`);
      incidentLabel = `⏳ 景点逗留超时已生效：+${mins} 分钟！当前虚拟时间: ${formatVirtualTime(travelState.virtualTime)}`;
      addTelemetry('incident', '⏳ [SCENARIO: OVERSTAY AT STOP]', `User spent +${mins} extra minutes. Advanced virtual time to ${formatVirtualTime(travelState.virtualTime)}.`);
      break;
    }

    case 'resequence': // 场景 9: 调换景点顺序
      if (currentStops.length >= 4) {
        const temp = currentStops[2];
        currentStops[2] = currentStops[3];
        currentStops[3] = temp;
        await planCurrentLeg();
        setActiveIncident(`🔀 Resequenced: Swapped ${currentStops[2].nameEn} & ${currentStops[3].nameEn}`);
        incidentLabel = `🔀 景点调序：互换第 3 站与第 4 站`;
        addTelemetry('incident', '🔀 [SCENARIO 9: RESEQUENCE STOPS]', 'Reordered itinerary stops based on user preference.');
      }
      break;

    case 'return_hotel': { // 场景 8: 提前回酒店 (返回用户本次出发的关联酒店)
      travelState.travelMode = 'driving';
      const hotel = travelState.startHotel || (currentStops[0] && getAreaHotelCoords(currentStops[0].area)) || { name: 'Eastern & Oriental Hotel', lat: 5.4233, lng: 100.3359 };
      setActiveIncident(`🏁 Trip Aborted: Returning to ${hotel.name} (身体疲劳提前回出发酒店)`);
      incidentLabel = `🏁 提前结束旅程：乘车返回出发酒店 (${hotel.name})`;
      await planCurrentLeg({
        name: hotel.name,
        nameEn: hotel.name,
        nameZh: hotel.name,
        lat: hotel.lat,
        lng: hotel.lng
      });
      travelState.isPlaying = true;
      travelState.isStaying = false;
      addTelemetry('incident', '🏁 [SCENARIO 8: RETURN TO HOTEL]', `User ended trip early. Routing back to relative hotel user started from: ${hotel.name} (${hotel.lat.toFixed(4)}, ${hotel.lng.toFixed(4)}).`);
      break;
    }
  }

  res.json({
    code: 200,
    msg: `Incident Activated: ${incidentLabel}`,
    label: incidentLabel,
    data: travelState
  });
});

// --- 新增：遥测日志 API ---
app.get('/api/telemetry', (req, res) => {
  res.json({ code: 200, data: telemetryLogs });
});

app.post('/api/telemetry/clear', (req, res) => {
  telemetryLogs = [];
  res.json({ code: 200, msg: "Cleared" });
});

// ==========================================
// 5. 整合型双语三栏 Dashboard 界面 (Bilingual UI)
// ==========================================
app.get('/', (req, res) => {
  res.send(`
    <!DOCTYPE html>
    <html lang="zh-CN">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Kia Kia Penang - Travel Simulation & Dynamic Incident Console</title>
      <style>
        :root {
          --primary: #2563eb;
          --primary-dark: #1d4ed8;
          --bg: #f8fafc;
          --card: #ffffff;
          --border: #e2e8f0;
          --text: #0f172a;
          --text-muted: #64748b;
          --success: #10b981;
          --warning: #f59e0b;
          --danger: #ef4444;
        }
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; background: var(--bg); color: var(--text); padding: 16px; }
        .wrapper { max-width: 1400px; margin: 0 auto; }
        
        /* Top Navigation Header */
        header { background: white; padding: 14px 20px; border-radius: 12px; box-shadow: 0 1px 3px rgba(0,0,0,0.06); display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; border: 1px solid var(--border); }
        .logo-group { display: flex; align-items: center; gap: 12px; }
        .logo-icon { font-size: 26px; }
        .logo-title { font-size: 18px; font-weight: 700; color: #1e293b; }
        .logo-sub { font-size: 12px; color: var(--text-muted); }
        .header-actions { display: flex; align-items: center; gap: 12px; }
        .lang-btn { background: #f1f5f9; border: 1px solid var(--border); padding: 6px 14px; border-radius: 20px; font-size: 13px; font-weight: 600; cursor: pointer; transition: all 0.2s; }
        .lang-btn:hover { background: #e2e8f0; }
        .adb-badge { background: #ecfdf5; color: #047857; border: 1px solid #a7f3d0; padding: 5px 12px; border-radius: 20px; font-size: 12px; font-weight: 600; display: flex; align-items: center; gap: 6px; }
        .adb-dot { width: 8px; height: 8px; background: #10b981; border-radius: 50%; }

        /* Tab Navigation Bar */
        .tabs-nav { display: flex; gap: 8px; margin-bottom: 16px; border-bottom: 2px solid var(--border); padding-bottom: 4px; }
        .tab-btn { background: transparent; border: none; padding: 10px 20px; font-size: 15px; font-weight: 600; color: var(--text-muted); cursor: pointer; border-radius: 8px 8px 0 0; transition: all 0.2s; display: flex; align-items: center; gap: 8px; }
        .tab-btn.active { color: var(--primary); border-bottom: 3px solid var(--primary); background: #eff6ff; }
        .tab-btn:hover:not(.active) { color: var(--text); background: #f1f5f9; }

        /* Tab Contents */
        .tab-content { display: none; }
        .tab-content.active { display: block; }

        /* Card Layouts */
        .grid-3 { display: grid; grid-template-columns: 340px 1fr 1fr; gap: 16px; }
        .grid-2 { display: grid; grid-template-columns: 1.1fr 0.9fr; gap: 16px; }
        .grid-full { display: grid; grid-template-columns: 1fr; gap: 16px; }
        @media (max-width: 1100px) {
          .grid-3, .grid-2 { grid-template-columns: 1fr; }
        }
        .card { background: white; padding: 18px; border-radius: 12px; box-shadow: 0 1px 3px rgba(0,0,0,0.05); border: 1px solid var(--border); margin-bottom: 16px; }
        .card h2 { font-size: 15px; font-weight: 700; color: #1e293b; margin-bottom: 14px; padding-bottom: 8px; border-bottom: 1px solid var(--border); display: flex; justify-content: space-between; align-items: center; }

        /* Form elements */
        .form-group { margin-bottom: 12px; }
        label { display: block; margin-bottom: 5px; font-size: 12px; font-weight: 600; color: var(--text-muted); }
        select, input { width: 100%; padding: 8px 10px; border: 1px solid var(--border); border-radius: 6px; font-size: 13px; outline: none; transition: border 0.2s; }
        select:focus, input:focus { border-color: var(--primary); }
        .hint { font-size: 11px; color: var(--text-muted); margin-top: 3px; }
        .btn { padding: 9px 14px; border-radius: 6px; border: none; font-size: 13px; font-weight: 600; cursor: pointer; transition: all 0.2s; display: inline-flex; align-items: center; justify-content: center; gap: 6px; }
        .btn-primary { background: var(--primary); color: white; }
        .btn-primary:hover { background: var(--primary-dark); }
        .btn-success { background: var(--success); color: white; }
        .btn-warning { background: var(--warning); color: white; }
        .btn-danger { background: var(--danger); color: white; }
        .btn-outline { background: white; border: 1px solid var(--border); color: var(--text); }
        .btn-outline:hover { background: #f8fafc; }
        .btn-block { width: 100%; }

        /* Control Strip for Simulation */
        .clock-strip { background: #0f172a; color: white; padding: 14px 18px; border-radius: 10px; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 12px; margin-bottom: 16px; }
        .virtual-time { font-family: monospace; font-size: 24px; font-weight: 700; color: #38bdf8; letter-spacing: 1px; }
        .clock-label { font-size: 11px; text-transform: uppercase; color: #94a3b8; letter-spacing: 0.5px; }
        .speed-badges { display: flex; gap: 6px; align-items: center; }
        .speed-btn { padding: 4px 10px; font-size: 12px; background: #334155; border: 1px solid #475569; color: white; border-radius: 4px; cursor: pointer; }
        .speed-btn.active { background: #0284c7; border-color: #38bdf8; font-weight: bold; }
        .mode-toggle { display: flex; gap: 6px; background: #1e293b; padding: 4px; border-radius: 6px; }
        .mode-btn { background: transparent; border: none; color: #94a3b8; padding: 4px 10px; font-size: 12px; border-radius: 4px; cursor: pointer; }
        .mode-btn.active { background: #3b82f6; color: white; font-weight: bold; }

        /* Stops Timeline */
        .stop-item { display: flex; gap: 12px; padding: 10px; border-radius: 8px; border: 1px solid var(--border); margin-bottom: 8px; background: #fcfcfd; align-items: center; justify-content: space-between; }
        .stop-item.enroute { border-color: #3b82f6; background: #eff6ff; }
        .stop-item.arrived { border-color: #10b981; background: #ecfdf5; }
        .stop-item.skipped { opacity: 0.6; text-decoration: line-through; }
        .stop-info { display: flex; align-items: center; gap: 10px; }
        .stop-badge { width: 24px; height: 24px; border-radius: 50%; background: #e2e8f0; display: flex; align-items: center; justify-content: center; font-size: 12px; font-weight: bold; }
        .stop-badge.active { background: var(--primary); color: white; }
        .stop-badge.done { background: var(--success); color: white; }

        /* Metric boxes */
        .metrics-bar { display: grid; grid-template-columns: repeat(4, 1fr); gap: 10px; margin-bottom: 14px; }
        .metric-card { background: #f8fafc; border: 1px solid var(--border); padding: 10px; border-radius: 8px; text-align: center; }
        .metric-val { font-size: 18px; font-weight: 700; color: #0f172a; }
        .metric-sub { font-size: 11px; color: var(--text-muted); margin-top: 2px; }

        /* 10 Incident Scenarios Grid */
        .scenarios-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(260px, 1fr)); gap: 10px; }
        .scenario-card { background: #f8fafc; border: 1px solid var(--border); border-radius: 8px; padding: 10px; transition: all 0.2s; }
        .scenario-card:hover { border-color: var(--primary); background: #ffffff; box-shadow: 0 2px 6px rgba(0,0,0,0.06); }
        .sc-title { font-size: 13px; font-weight: 700; color: #1e293b; margin-bottom: 4px; display: flex; align-items: center; gap: 6px; }
        .sc-desc { font-size: 11px; color: var(--text-muted); margin-bottom: 8px; line-height: 1.4; }
        .sc-actions { display: flex; gap: 6px; flex-wrap: wrap; }

        /* Terminal & JSON Viewer */
        pre { background: #0f172a; color: #38bdf8; padding: 12px; border-radius: 8px; font-size: 12px; height: 420px; overflow-y: auto; font-family: monospace; }
        .telemetry-item { padding: 8px 12px; border-bottom: 1px solid #1e293b; font-family: monospace; font-size: 12px; }
        .telemetry-time { color: #94a3b8; font-weight: 600; margin-right: 8px; }
        .telemetry-title { color: #f1f5f9; font-weight: 600; }
        .telemetry-body { color: #38bdf8; margin-top: 4px; white-space: pre-wrap; font-size: 11px; }

        .active-alert-box { padding: 10px 14px; background: #fef2f2; border: 1px solid #fecaca; border-radius: 8px; color: #991b1b; font-size: 13px; font-weight: 600; margin-bottom: 14px; display: none; }
      </style>
    </head>
    <body>
      <div class="wrapper">
        <!-- Header -->
        <header>
          <div class="logo-group">
            <span class="logo-icon">🏝️</span>
            <div>
              <div class="logo-title" id="t-main-title">Kia Kia Penang - Travel Simulation & Dynamic Incident Console</div>
              <div class="logo-sub" id="t-main-sub">Mock GPS Route Engine • 8 Travel Incident Injectors • Weather Controller • Live Telemetry</div>
            </div>
          </div>
          <div class="header-actions">
            <div class="adb-badge">
              <span class="adb-dot"></span>
              <span id="t-adb-status">ADB Daemon: Active</span>
            </div>
            <button class="lang-btn" onclick="toggleLang()" id="langBtn">🌐 English / 中文</button>
          </div>
        </header>

        <!-- Navigation Tabs -->
        <div class="tabs-nav">
          <button class="tab-btn active" onclick="switchTab('tab-travel')" id="t-tab-travel">
            🧭 Mock Travel & Incidents (行程与突发模拟)
          </button>
          <button class="tab-btn" onclick="switchTab('tab-weather')" id="t-tab-weather">
            🌦️ Weather Controller (天气控制台)
          </button>
          <button class="tab-btn" onclick="switchTab('tab-telemetry')" id="t-tab-telemetry">
            📡 Live Telemetry & API Inspector (报文监视器)
          </button>
        </div>

        <!-- ============================================== -->
        <!-- TAB 1: 🧭 MOCK TRAVEL & INCIDENTS (行程模拟) -->
        <!-- ============================================== -->
        <div id="tab-travel" class="tab-content active">
          <!-- Virtual Clock & Master Playback Bar -->
          <div class="clock-strip">
            <div>
              <div class="clock-label" id="t-clock-lbl">Simulated Virtual Time (模拟虚拟时间)</div>
              <div class="virtual-time" id="virtualTimeDisplay">10:00:00 AM</div>
            </div>
            <div style="display:flex; gap:8px; align-items:center;">
              <button class="btn btn-success" id="playBtn" onclick="controlSim('play')">▶ Start / 开始</button>
              <button class="btn btn-warning" id="pauseBtn" onclick="controlSim('pause')">⏸ Pause / 暂停</button>
              <button class="btn" style="background:#7c3aed; color:white; border:none; padding:8px 16px; font-weight:700; border-radius:6px; cursor:pointer; display:inline-flex; align-items:center; gap:6px; box-shadow:0 2px 8px rgba(124,58,237,0.3); transition:all 0.2s;" onmouseover="this.style.background='#6d28d9'" onmouseout="this.style.background='#7c3aed'" onclick="controlSim('skipStay')">⏩ Skip Stay / 立即出发</button>
            </div>
            <div>
              <div class="clock-label" id="t-speed-lbl">Time Warp (时间流速)</div>
              <div class="speed-badges">
                <button class="speed-btn" onclick="setSpeed(1)">1x</button>
                <button class="speed-btn" onclick="setSpeed(5)">5x</button>
                <button class="speed-btn active" id="spd10" onclick="setSpeed(10)">10x</button>
                <button class="speed-btn" onclick="setSpeed(30)">30x</button>
                <button class="speed-btn" onclick="setSpeed(60)">60x</button>
              </div>
            </div>
            <div>
              <div class="clock-label" id="t-mode-lbl">Transit Mode (出行方式)</div>
              <div class="mode-toggle">
                <button class="mode-btn active" id="modeWalk" onclick="setMode('walking')">🚶 Walk (4.5 km/h)</button>
                <button class="mode-btn" id="modeDrive" onclick="setMode('driving')">🚗 Drive (35 km/h)</button>
              </div>
            </div>
          </div>

          <div id="activeIncidentBanner" class="active-alert-box"></div>

          <!-- Real-time Metrics -->
          <div class="metrics-bar">
            <div class="metric-card">
              <div class="metric-val" id="metricDistance">0 m</div>
              <div class="metric-sub" id="t-metric-dist">Remaining Road Dist (剩余路距)</div>
            </div>
            <div class="metric-card">
              <div class="metric-val" id="metricDuration">0 min</div>
              <div class="metric-sub" id="t-metric-dur">Transit Time (预计通行用时)</div>
            </div>
            <div class="metric-card">
              <div class="metric-val" id="metricCurrentTarget">Stop 1</div>
              <div class="metric-sub" id="t-metric-target">Target Stop (当前目标站点)</div>
            </div>
            <div class="metric-card">
              <div class="metric-val" id="metricGps">5.4141, 100.3298</div>
              <div class="metric-sub" id="t-metric-coords">GPS Emulated (实时注入经纬度)</div>
            </div>
          </div>

          <div class="grid-2">
            <!-- Left: Stops List -->
            <div class="card">
              <h2>
                <span id="t-stops-title">Travel Plan Stops (行程站点列表)</span>
                <span style="font-size:12px; font-weight:normal;" id="tripStatusBadge">Departing</span>
              </h2>
              <div style="display:flex; justify-content:space-between; align-items:center; background:#f1f5f9; padding:8px 12px; border-radius:8px; margin-bottom:12px; flex-wrap:wrap; gap:8px;">
                <div>
                  <div style="display:flex; align-items:center; gap:8px;"><div style="font-size:14px; font-weight:700; color:#1e293b;" id="activePlanTitleDisplay">Penang Journey (Default / 默认行程)</div><span id="activeTripBadge" style="display:none; font-size:11px; padding:2px 8px; border-radius:12px; background:#dcfce7; color:#166534; font-weight:700; border:1px solid #bbf7d0;">🟢 Active Trip Synced</span></div>
                  <div style="font-size:11px; color:#64748b;" id="t-sync-hint">Sync live itinerary saved in user's phone / 同步手机保存的计划</div>
                </div>
                <div style="display:flex; gap:8px; align-items:center;">
                  <button class="btn btn-outline" style="font-size:12px; padding:6px 12px; border-color:#f59e0b; color:#d97706; background:#fffbeb; font-weight:700;" onclick="triggerIncident('skip_crowded')" title="Skip current overcrowded stop / 跳过排队爆满景点">
                    ⏭️ Skip Overcrowded Stop (跳过排队景点)
                  </button>
                  
                  <button class="btn btn-outline" style="font-size:12px; padding:6px 12px; border-color:#2563eb; color:#2563eb; background:white; font-weight:600;" onclick="syncFromPhone()" id="btnSyncPhone">
                    🔄 Sync from Phone (从手机同步)
                  </button>
                </div>
              </div>
              <div id="stopsContainer">Loading stops...</div>
            </div>

            <!-- Right: Dynamic Detour & Search Box -->
            <div class="card">
              <h2>
                <span id="t-detour-title">Dynamic Detour & POI Input (动态绕路与地点注入)</span>
                <span style="font-size:11px; color:#10b981;">OSRM Routing Powered</span>
              </h2>
              <p class="hint" style="margin-bottom:12px;" id="t-detour-desc">
                Input any custom Penang location to test real-time distance & transit time rerouting!
              </p>
              <div class="form-group">
                <label id="t-detour-name-lbl">Destination Name (目标地点名称) - <span style="color:#2563eb; font-weight:normal;">Type & tap Enter to get coords (输入后按回车自动获取经纬度)</span>:</label>
                <div style="display:flex; gap:8px;">
                  <input type="text" id="detourName" placeholder="e.g. Urban Daybreak Cafe @ George Town (Press Enter / 按回车)" value="Urban Daybreak Cafe @ George Town" onkeydown="if(event.key === 'Enter'){ event.preventDefault(); searchLocationCoords(); }">
                  <button type="button" class="btn btn-primary" style="white-space:nowrap; padding:8px 14px;" onclick="searchLocationCoords()" id="btnSearchCoords">🔍 Get Coords (获取坐标)</button>
                </div>
                <div id="geocodeStatusMsg" style="font-size:12px; margin-top:5px; font-weight:600; display:none;"></div>
              </div>
              <div style="display:grid; grid-template-columns: 1fr 1fr; gap:10px;">
                <div class="form-group">
                  <label id="t-detour-lat-lbl">Latitude (纬度):</label>
                  <input type="number" step="0.00001" id="detourLat" value="5.41347">
                </div>
                <div class="form-group">
                  <label id="t-detour-lng-lbl">Longitude (经度):</label>
                  <input type="number" step="0.00001" id="detourLng" value="100.33712">
                </div>
              </div>
              <div class="form-group">
                <label id="t-detour-mode-lbl">Travel Mode (交通方式):</label>
                <select id="detourMode">
                  <option value="walking">🚶 Walking / 步行 (4.5 km/h)</option>
                  <option value="driving" selected>🚗 Grab Driving / 乘车 (35 km/h)</option>
                </select>
              </div>
              <button class="btn btn-primary btn-block" onclick="submitDetour()" id="t-btn-detour">
                🚀 Reroute & Start Navigation (确认改道并立即行进)
              </button>
            </div>
          </div>

          <!-- Bottom: 8 Realistic Travel Incident Injector -->
          <div class="card">
            <h2>
              <span id="t-incidents-title">8 Dynamic Travel Incident Injectors (8 大突发事件注入器)</span>
              <span style="font-size:11px; color:#6366f1;">Test App Edge Cases & Weather Adaptation</span>
            </h2>
            <div class="scenarios-grid">
              <!-- 1. Sudden Heavy Rain -->
              <div class="scenario-card">
                <div class="sc-title">🌧️ 1. Sudden Heavy Rain (突降暴雨)</div>
                <div class="sc-desc">Tropical storm warning triggered. Test user choice: umbrella, nearby indoor mall, shelter or cleared:</div>
                <div class="sc-actions">
                  <button class="btn btn-outline" style="font-size:11px; padding:4px 8px;" onclick="triggerIncident('rain_stick_plan')">☂️ Stick to Plan (撑伞坚持)</button>
                  <button id="btnRainMall" class="btn btn-primary" style="font-size:11px; padding:4px 8px;" onclick="triggerIndoorMall()">🏢 1st Avenue Mall (420m / 0.42km)</button>
                  <button class="btn btn-warning" style="font-size:11px; padding:4px 8px;" onclick="triggerIncident('rain_wait_out')">☕ Shelter (Wait 10m / 避雨10分钟)</button>
                  <button class="btn btn-success" style="font-size:11px; padding:4px 8px;" onclick="triggerIncident('rain_cleared')">☀️ Cleared (Wait 20m & Resume / 等待20分钟放晴恢复)</button>
                </div>
              </div>

              <!-- 2. Mid-trip Cafe Detour (Dynamic nearby suggestions) -->
              <div class="scenario-card">
                <div class="sc-title">☕ 2. Nearby Cafe Detour (周边咖啡馆绕路)</div>
                <div class="sc-desc">Real-time nearby cafes calculated from user's current GPS location via OSRM (meters & km):</div>
                <div id="cafeSuggestionsContainer" style="display:flex; flex-direction:column; gap:6px; margin-top:6px;">
                  <button class="btn btn-outline" style="font-size:11px; padding:6px 10px; border-color:#3b82f6; color:#2563eb;" onclick="loadNearbySuggestions('cafe')">
                    🔍 Find 2 Nearby Cafes (根据当前位置实时搜索周边咖啡馆)
                  </button>
                </div>
              </div>

              <!-- 3. Traffic Congestion -->
              <div class="scenario-card">
                <div class="sc-title">🚗 3. Peak Traffic Jam (高峰拥堵)</div>
                <div class="sc-desc">Severe jam on Penang road. Speed drops to 6 km/h, extending transit time (+15 mins).</div>
                <div class="sc-actions">
                  <button class="btn btn-outline" style="font-size:11px; padding:4px 8px;" onclick="triggerIncident('traffic_jam')">🚗 Trigger Traffic Jam (触发道路拥堵)</button>
                </div>
              </div>

              <!-- 4. Sudden Road Closure / Construction -->
              <div class="scenario-card">
                <div class="sc-title">🚧 4. Sudden Road Closure (突发道路施工封路)</div>
                <div class="sc-desc">Forward street blocked. System detects obstacle and auto-reroutes around block (+280m).</div>
                <div class="sc-actions">
                  <button class="btn btn-warning" style="font-size:11px; padding:5px 10px; color:#1e293b; font-weight:700;" onclick="triggerIncident('road_closure')">🚧 Block Road & Auto-Reroute (封路避障绕行)</button>
                </div>
              </div>

              <!-- 5. Ad-hoc Food Detour (2 nearby options to pick) -->
              <div class="scenario-card">
                <div class="sc-title">🍽️ 5. Nearby Food Detour (周边地道美食绕路)</div>
                <div class="sc-desc">2 real hawker suggestions calculated from user's current GPS location via OSRM (meters & km):</div>
                <div id="foodSuggestionsContainer" style="display:flex; flex-direction:column; gap:6px; margin-top:6px;">
                  <button class="btn btn-outline" style="font-size:11px; padding:6px 10px; border-color:#f59e0b; color:#d97706;" onclick="loadNearbySuggestions('food')">
                    🍲 Find 2 Nearby Food Spots (实时搜索周边美食选项)
                  </button>
                </div>
              </div>

              <!-- 6. Off-track Deviation -->
              <div class="scenario-card">
                <div class="sc-title">🗺️ 6. Off-track / Lost (偏航走错小巷)</div>
                <div class="sc-desc">User deviates 180m into alleys. Tests app rerouting trigger.</div>
                <div class="sc-actions">
                  <button class="btn btn-outline" style="font-size:11px; padding:4px 8px;" onclick="triggerIncident('off_track')">🗺️ Stray Off-course (偏离预定路线)</button>
                </div>
              </div>

              <!-- 7. Overstay at Stop (Choose 15m, 30m, 1hr) -->
              <div class="scenario-card">
                <div class="sc-title">⏳ 7. Overstay at Stop (停留玩超时)</div>
                <div class="sc-desc">User overstays schedule at current attraction. Select duration to fast-forward:</div>
                <div class="sc-actions" style="gap:6px;">
                  <button id="btnOverstay15" class="btn btn-outline" style="font-size:11px; padding:4px 8px;" onclick="triggerOverstay(15)">⏳ +15 min</button>
                  <button id="btnOverstay30" class="btn btn-outline" style="font-size:11px; padding:4px 8px;" onclick="triggerOverstay(30)">⏳ +30 min</button>
                  <button id="btnOverstay60" class="btn btn-outline" style="font-size:11px; padding:4px 8px;" onclick="triggerOverstay(60)">⏳ +1 Hour</button>
                </div>
              </div>

              <!-- 8. Early Finish -->
              <div class="scenario-card">
                <div class="sc-title">🏁 8. Return to Hotel (提前回酒店)</div>
                <div class="sc-desc">Tired user ends journey early. Routes directly back to Hotel.</div>
                <div class="sc-actions">
                  <button class="btn btn-outline" style="font-size:11px; padding:4px 8px;" onclick="triggerIncident('return_hotel')">🏁 Return to Hotel (提前结束返程)</button>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- ============================================== -->
        <!-- TAB 2: 🌦️ WEATHER CONTROLLER (原有天气控制台) -->
        <!-- ============================================== -->
        <div id="tab-weather" class="tab-content">
          <div class="grid-3">
            <!-- 栏目 1: 表单卡片 -->
            <div class="card">
              <h2><span id="t-weather-form-title">传送天气数据 (Send Weather Data)</span></h2>
              <form id="weatherForm">
                <div class="form-group">
                  <label id="t-w-loc">Penang Location (地点):</label>
                  <select id="location">
                    ${penangLocations.map(loc => `<option value="${loc}">${loc}</option>`).join('')}
                  </select>
                </div>

                <div class="form-group">
                  <label id="t-w-cond">Weather Condition (天气状态):</label>
                  <select id="condition" onchange="onConditionChange(this.value)">
                    ${weatherOptions.map(opt => `<option value="${opt.value}">${opt.label}</option>`).join('')}
                  </select>
                </div>

                <!-- Rain Intensity Tiers -->
                <div class="form-group">
                  <label style="font-weight:bold; color:#1e293b;">🌧️ Rain Intensity Setting (降雨分级标准):</label>
                  <div style="display:grid; grid-template-columns:1fr 1fr; gap:8px; margin-top:6px;">
                    <button type="button" class="btn btn-outline rain-btn" onclick="setRainPreset('none', 0.0, 'sunny', 34)" style="font-size:12px; padding:6px 8px; text-align:left;">
                      ☀️ <b>None / Clear</b><br><span style="font-size:10.5px; color:#64748b;">0 mm/hr</span>
                    </button>
                    <button type="button" class="btn btn-outline rain-btn" onclick="setRainPreset('light', 1.5, 'rainy', 27)" style="font-size:12px; padding:6px 8px; text-align:left;">
                      🌦️ <b>Light rain</b><br><span style="font-size:10.5px; color:#64748b;">&lt; 2.5 mm/hr</span>
                    </button>
                    <button type="button" class="btn btn-outline rain-btn" onclick="setRainPreset('moderate', 5.0, 'rainy', 26)" style="font-size:12px; padding:6px 8px; text-align:left;">
                      🌧️ <b>Moderate rain</b><br><span style="font-size:10.5px; color:#64748b;">2.5 mm ~ 7.6 mm/hr</span>
                    </button>
                    <button type="button" class="btn btn-outline rain-btn" onclick="setRainPreset('heavy', 8.5, 'thunderstorm', 25)" style="font-size:12px; padding:6px 8px; text-align:left; border-color:#dc2626; color:#dc2626; background:#fef2f2;">
                      ⛈️ <b>Heavy rain</b> 🚨<br><span style="font-size:10.5px; color:#b91c1c;">&gt; 7.6 ~ 10 mm/hr (Trigger)</span>
                    </button>
                  </div>
                </div>

                <div class="form-group">
                  <label for="rainRate" style="display:flex; justify-content:space-between; align-items:center;">
                    <span>Rainfall Rate (降雨量数值 mm/hr):</span>
                    <span id="rainRateLabel" style="font-weight:bold; color:#0284c7;">0.0 mm/hr (Clear)</span>
                  </label>
                  <input type="number" id="rainRate" min="0" max="15" step="0.1" value="0.0" oninput="updateRainDisplay(this.value)">
                  <div class="hint">• Light: &lt; 2.5 mm/h | • Moderate: 2.5 ~ 7.6 mm/h | • Heavy: &gt; 7.6 ~ 10 mm/h</div>
                </div>

                <!-- Severe Weather Event Indicator Badge -->
                <div id="severeAlertBadge" style="display:none; padding:10px 14px; border-radius:8px; margin-bottom:14px; font-size:12px; font-weight:bold;"></div>

                <div class="form-group">
                  <label id="t-w-temp">Temperature (温度 °C):</label>
                  <input type="number" id="temperature" min="20" max="45" value="34" required oninput="checkSevereAlert()">
                  <div class="hint">Normal: 25°C ~ 35°C | Severe Heat Trigger: &gt; 37°C</div>
                </div>

                <div class="form-group">
                  <label id="t-w-hum">Humidity (湿度 %):</label>
                  <select id="humidity">
                    <option value="60">60% (Dry)</option>
                    <option value="75" selected>75% (Normal)</option>
                    <option value="90">90% (Humid / Rain)</option>
                  </select>
                </div>

                <button type="submit" class="btn btn-primary btn-block" id="t-w-submit">🚀 Send Weather Data (广播天气报文)</button>
              </form>

              <div id="timerNotice" style="display:none; margin-top:12px; padding:10px; background:#feebc8; color:#742a2a; border-radius:6px; font-size:13px; text-align:center;">
                ⏳ 已成功发送！Terminal 将在 <b id="secondsLeft">120</b> 秒后显示“用户收到天气数据”。
              </div>
            </div>

            <!-- 栏目 2: JSON 实时预览卡片 -->
            <div class="card">
              <h2><span id="t-w-json-title">App 当前可接收的 API 数据 (JSON)</span></h2>
              <pre id="jsonViewer">加载中...</pre>
            </div>

            <!-- 栏目 3: 发送历史记录 -->
            <div class="card">
              <h2>
                <span id="t-w-hist-title">发送历史记录 (Sending History)</span>
                <span style="font-size:12px; font-weight:normal; color:#718096;" id="historyCount">0 条记录</span>
              </h2>
              <div id="historyContainer" style="height:380px; overflow-y:auto;">
                <div style="text-align:center; color:#a0aec0; padding-top:50px;">暂无发送历史</div>
              </div>
            </div>
          </div>
        </div>

        <!-- ============================================== -->
        <!-- TAB 3: 📡 TELEMETRY INSPECTOR (实时报文监视器) -->
        <!-- ============================================== -->
        <div id="tab-telemetry" class="tab-content">
          <div class="card">
            <h2>
              <span id="t-telem-title">Live API & ADB Command Telemetry Stream (实时报文与命令流)</span>
              <button class="btn btn-outline" style="font-size:12px; padding:4px 10px;" onclick="clearTelemetry()">🗑️ Clear Logs / 清屏</button>
            </h2>
            <div style="background:#0f172a; border-radius:8px; height:500px; overflow-y:auto; padding:6px;" id="telemetryStream">
              <div style="color:#64748b; padding:20px; text-align:center;">Listening to outbound ADB and API events...</div>
            </div>
          </div>
        </div>

      </div>

      <script>
        let currentLang = 'bilingual'; // 'bilingual' | 'en' | 'zh'
        let simState = null;

        // Language Switcher
        function toggleLang() {
          currentLang = currentLang === 'bilingual' ? 'en' : (currentLang === 'en' ? 'zh' : 'bilingual');
          const btn = document.getElementById('langBtn');
          if (currentLang === 'en') btn.innerText = '🌐 English';
          else if (currentLang === 'zh') btn.innerText = '🌐 中文 (Chinese)';
          else btn.innerText = '🌐 English / 中文';
        }

        // Tab Switching
        function switchTab(tabId) {
          document.querySelectorAll('.tab-content').forEach(el => el.classList.remove('active'));
          document.querySelectorAll('.tab-btn').forEach(el => el.classList.remove('active'));
          document.getElementById(tabId).classList.add('active');
          event.currentTarget.classList.add('active');
        }

        // Simulation Controls
        async function controlSim(action, value = null) {
          const res = await fetch('/api/simulation/control', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ action, value })
          });
          simState = (await res.json()).data;
          renderSimUI();
        }

        function setSpeed(spd) {
          controlSim('setSpeed', spd);
          document.querySelectorAll('.speed-btn').forEach(b => b.classList.remove('active'));
          event.currentTarget.classList.add('active');
        }

        function setMode(mode) {
          controlSim('setMode', mode);
          document.getElementById('modeWalk').classList.toggle('active', mode === 'walking');
          document.getElementById('modeDrive').classList.toggle('active', mode === 'driving');
        }

        // 搜索地点坐标 (Geocoding by place name - 支持回车键触发)
        async function searchLocationCoords() {
          const nameInput = document.getElementById('detourName');
          const statusDiv = document.getElementById('geocodeStatusMsg');
          const btn = document.getElementById('btnSearchCoords');
          const query = nameInput.value.trim();
          if (!query) {
            alert('Please enter a destination name! / 请输入目的地名称！');
            return;
          }

          btn.innerText = '⏳ Searching...';
          btn.disabled = true;
          statusDiv.style.display = 'block';
          statusDiv.style.color = '#2563eb';
          statusDiv.innerText = '🔍 Searching coordinates for "' + query + '" in Penang...';

          try {
            const res = await fetch('/api/geocode?q=' + encodeURIComponent(query));
            const result = await res.json();
            if (result.success && result.data) {
              document.getElementById('detourLat').value = result.data.lat;
              document.getElementById('detourLng').value = result.data.lng;
              statusDiv.style.color = '#10b981';
              statusDiv.innerText = '✅ Found: ' + result.data.name + ' (Lat: ' + result.data.lat + ', Lng: ' + result.data.lng + ') [' + result.data.source + ']';
              showToast('📍 Coords updated for ' + result.data.name);
            } else {
              statusDiv.style.color = '#ef4444';
              statusDiv.innerText = '⚠️ ' + (result.msg || 'Location not found in Penang.');
            }
          } catch (err) {
            statusDiv.style.color = '#ef4444';
            statusDiv.innerText = 'Error: ' + err.message;
          } finally {
            btn.innerText = '🔍 Get Coords (获取坐标)';
            btn.disabled = false;
          }
        }

        // Detour Submit
        async function submitDetour() {
          const name = document.getElementById('detourName').value;
          const lat = document.getElementById('detourLat').value;
          const lng = document.getElementById('detourLng').value;
          const mode = document.getElementById('detourMode').value;

          const res = await fetch('/api/simulation/detour', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ name, lat, lng, mode })
          });
          const result = await res.json();
          showToast('🚀 Detour active to ' + name + '! Distance: ' + result.data.distance + 'm');
          refreshSimState();
          fetchTelemetry();
        }

        // Incident Trigger (突发事件触发器)
        async function triggerIncident(scenarioId, extraData = null) {
          try {
            const body = { scenarioId };
            if (extraData) body.mall = extraData;
            const res = await fetch('/api/simulation/incident', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify(body)
            });
            const result = await res.json();
            if (result.code === 200) {
              showToast(result.label || result.msg || '⚡ Incident Triggered!');
              refreshSimState();
              fetchTelemetry();
              if (scenarioId.startsWith('rain_')) {
                fetchCurrentJSON();
                fetchHistory();
              }
            }
          } catch(err) {
            alert('Failed to trigger incident: ' + err.message);
          }
        }

        function triggerIndoorMall() {
          const mall = simState ? simState.nearestMall : null;
          triggerIncident('rain_indoor_backup', mall);
        }

        // Floating Toast Feedback
        function showToast(msg) {
          let container = document.getElementById('toastContainer');
          if (!container) {
            container = document.createElement('div');
            container.id = 'toastContainer';
            container.style.cssText = 'position:fixed; top:20px; right:20px; z-index:9999; display:flex; flex-direction:column; gap:8px;';
            document.body.appendChild(container);
          }
          const toast = document.createElement('div');
          toast.style.cssText = 'background:#1e293b; color:#38bdf8; padding:12px 18px; border-radius:8px; box-shadow:0 10px 25px rgba(0,0,0,0.25); font-size:13px; font-weight:600; border-left:4px solid #3b82f6; transition:all 0.3s ease;';
          toast.innerText = msg;
          container.appendChild(toast);
          setTimeout(() => {
            toast.style.opacity = '0';
            toast.style.transform = 'translateY(-10px)';
            setTimeout(() => toast.remove(), 300);
          }, 3500);
        }

        // 从已连接手机同步真实行程
        async function syncFromPhone() {
          const btn = document.getElementById('btnSyncPhone');
          btn.innerText = '⏳ Syncing / 正在从手机读取...';
          btn.disabled = true;
          try {
            const res = await fetch('/api/simulation/sync-from-phone', { method: 'POST' });
            const result = await res.json();
            if (result.code === 200) {
              showToast('🎉 ' + result.msg);
              refreshSimState();
            } else {
              alert('⚠️ ' + result.msg);
            }
          } catch(e) {
            alert('Error connecting to phone: ' + e);
          } finally {
            btn.innerText = '🔄 Sync from Phone (从手机同步)';
            btn.disabled = false;
          }
        }

        async function refreshSimState() {
          try {
            const res = await fetch('/api/simulation/state');
            const result = await res.json();
            simState = result.data;
            renderSimUI();
          } catch(e) {}
        }

        function renderSimUI() {
          if (!simState) return;

          if (document.getElementById('activePlanTitleDisplay') && simState.planTitle) {
            document.getElementById('activePlanTitleDisplay').innerText = simState.planTitle;
          const badge = document.getElementById('activeTripBadge');
          if (badge) {
            const isDefault = simState.planTitle.includes('Default') || simState.planTitle.includes('默认');
            badge.style.display = isDefault ? 'none' : 'inline-block';
          }
          }
          document.getElementById('virtualTimeDisplay').innerText = simState.virtualTimeString;
          document.getElementById('metricDistance').innerText = simState.remainingDistanceMeters + ' m';
          document.getElementById('metricDuration').innerText = (simState.remainingDurationSeconds / 60).toFixed(1) + ' min';
          document.getElementById('metricGps').innerText = simState.currentLat.toFixed(4) + ', ' + simState.currentLng.toFixed(4);

          const curStop = simState.stops[simState.currentStopIndex];
          document.getElementById('metricCurrentTarget').innerText = curStop ? curStop.nameEn : 'Detour Point';

          // Update Top Status Badge
          const statusBadge = document.getElementById('tripStatusBadge');
          if (statusBadge) {
            if (simState.isStaying) {
              statusBadge.innerText = 'Arrived at Stop ' + (simState.currentStopIndex + 1);
              statusBadge.style.color = '#10b981';
            } else if (simState.isPlaying) {
              statusBadge.innerText = 'In Transit to Stop ' + (simState.currentStopIndex + 1);
              statusBadge.style.color = '#2563eb';
            } else {
              statusBadge.innerText = 'Paused';
              statusBadge.style.color = '#f59e0b';
            }
          }

          // Alert banner
          const banner = document.getElementById('activeIncidentBanner');
          if (simState.activeIncident) {
            banner.style.display = 'block';
            banner.innerText = simState.activeIncident;
          } else {
            banner.style.display = 'none';
          }

          // Render Stops
          const stopsHtml = simState.stops.map((stop, idx) => {
            const status = simState.stopStatuses[idx] || 'waiting';
            let badgeClass = '';
            if (status === 'completed') badgeClass = 'done';
            else if (status === 'enroute' || status === 'arrived') badgeClass = 'active';

            return '<div class="stop-item ' + status + '">' +
              '<div class="stop-info">' +
                '<span class="stop-badge ' + badgeClass + '">' + (idx + 1) + '</span>' +
                '<div>' +
                  '<div style="font-size:13px; font-weight:700;">' + stop.nameEn + ' <span style="font-weight:normal; color:#64748b;">(' + stop.nameZh + ')</span></div>' +
                  '<div style="font-size:11px; color:#64748b;">Plan: ' + stop.plannedArrive + ' - ' + stop.plannedDepart + ' | Status: <b style="color:' + (status === 'enroute' ? '#2563eb' : (status === 'completed' || status === 'arrived' ? '#10b981' : '#64748b')) + '">' + status.toUpperCase() + '</b></div>' +
                '</div>' +
              '</div>' +
              '<div style="display:flex; gap:4px; align-items:center;">' +
                '<button class="btn" style="font-size:11px; padding:4px 9px; font-weight:700; background:' + (status === 'enroute' ? '#10b981' : '#2563eb') + '; color:white;" onclick="controlSim(\\'visitStop\\', ' + idx + ')">🎯 VISIT ' + (status === 'enroute' ? '(ACTIVE)' : '') + '</button>' +
                '<button class="btn btn-outline" style="font-size:11px; padding:4px 6px;" title="Teleport to this stop / 瞬移到位" onclick="controlSim(\\'teleport\\', ' + idx + ')">⚡</button>' +
                '<button class="btn btn-outline" style="font-size:10px; padding:4px 5px;" title="Move Up / 向上调序" onclick="controlSim(\\'moveStopUp\\', ' + idx + ')" ' + (idx === 0 ? 'disabled' : '') + '>⬆</button>' +
                '<button class="btn btn-outline" style="font-size:10px; padding:4px 5px;" title="Move Down / 向下调序" onclick="controlSim(\\'moveStopDown\\', ' + idx + ')" ' + (idx === simState.stops.length - 1 ? 'disabled' : '') + '>⬇</button>' +
              '</div>' +
            '</div>';
          }).join('');

          document.getElementById('stopsContainer').innerHTML = stopsHtml;

          // 动态更新暴雨场景中就近室内商场的按钮文本 (显示商场名称与实时路网距离 m/km)
          const mallBtn = document.getElementById('btnRainMall');
          if (mallBtn && simState.nearestMall) {
            const m = simState.nearestMall;
            const km = (m.distanceMeters / 1000).toFixed(2);
            mallBtn.innerHTML = '🏢 ' + m.name + ' (' + m.distanceMeters + 'm / ' + km + 'km)';
          }
        }

        // 动态加载当前 GPS 附近的周边推荐 (调用真实 OSRM 计算路网距离与耗时)
        async function loadNearbySuggestions(type) {
          const containerId = type === 'cafe' ? 'cafeSuggestionsContainer' : 'foodSuggestionsContainer';
          const container = document.getElementById(containerId);
          container.innerHTML = '<div style="font-size:11px; color:#64748b; padding:4px;">⏳ Calling OSRM to calculate real road distances & transit times...</div>';

          try {
            const lat = simState ? simState.currentLat : 5.4141;
            const lng = simState ? simState.currentLng : 100.3364;
            const res = await fetch('/api/simulation/nearby?type=' + type + '&lat=' + lat + '&lng=' + lng);
            const result = await res.json();
            if (result.success && result.data && result.data.length > 0) {
              container.innerHTML = result.data.map(function(place, i) {
                const icon = type === 'cafe' ? '☕' : (i === 0 ? '🍜' : '🍲');
                return '<button class="btn btn-outline" style="font-size:11px; padding:6px 8px; text-align:left; justify-content:space-between; display:flex; align-items:center;" onclick="selectNearbyDetour(\\'' + place.name.replace(/'/g, "\\'") + '\\', ' + place.lat + ', ' + place.lng + ')">' +
                  '<span>' + icon + ' <b>' + place.name + '</b> <span style="color:#64748b; font-size:10px;">(' + (place.area || 'Penang') + ')</span></span>' +
                  '<span style="font-weight:700; color:#2563eb; margin-left:8px; white-space:nowrap;">📏 ' + place.distanceMeters + 'm (' + (place.distanceMeters / 1000).toFixed(2) + 'km) · ⏱️ ' + place.durationMinutes + ' min</span>' +
                '</button>';
              }).join('');
            } else {
              container.innerHTML = '<div style="font-size:11px; color:#ef4444;">No nearby candidates found.</div>';
            }
          } catch(err) {
            container.innerHTML = '<div style="font-size:11px; color:#ef4444;">Error: ' + err.message + '</div>';
          }
        }

        async function selectNearbyDetour(name, lat, lng) {
          document.getElementById('detourName').value = name;
          document.getElementById('detourLat').value = lat;
          document.getElementById('detourLng').value = lng;
          await submitDetour();
        }

        async function triggerOverstay(mins) {
          ['btnOverstay15', 'btnOverstay30', 'btnOverstay60'].forEach(id => {
            const btn = document.getElementById(id);
            if (btn) {
              btn.style.background = 'transparent';
              btn.style.color = '#2563eb';
              btn.style.borderColor = '#cbd5e1';
            }
          });
          const activeBtn = document.getElementById('btnOverstay' + mins);
          if (activeBtn) {
            activeBtn.style.background = '#f59e0b';
            activeBtn.style.color = '#1e293b';
            activeBtn.style.borderColor = '#d97706';
            activeBtn.style.fontWeight = '700';
          }
          await triggerIncident('overstay_' + mins);
        }

        // Fetch Telemetry Logs
        async function fetchTelemetry() {
          try {
            const res = await fetch('/api/telemetry');
            const logs = (await res.json()).data;
            const container = document.getElementById('telemetryStream');
            if (logs.length === 0) {
              container.innerHTML = '<div style="color:#64748b; padding:20px; text-align:center;">No logs yet.</div>';
              return;
            }

            container.innerHTML = logs.map(item => {
              return '<div class="telemetry-item">' +
                '<div><span class="telemetry-time">[' + item.time + ']</span> <span class="telemetry-title">' + item.title + '</span> - ' + item.details + '</div>' +
                (item.payload ? '<div class="telemetry-body">' + item.payload + '</div>' : '') +
              '</div>';
            }).join('');
          } catch(e) {}
        }

        async function clearTelemetry() {
          await fetch('/api/telemetry/clear', { method: 'POST' });
          fetchTelemetry();
        }

        // --- Weather Form Logic (Existing) ---
        const weatherTempMap = { 'sunny': 34, 'cloudy': 29, 'rainy': 26, 'thunderstorm': 25 };
        document.getElementById('condition').addEventListener('change', (e) => {
          if (weatherTempMap[e.target.value]) document.getElementById('temperature').value = weatherTempMap[e.target.value];
        });

        async function fetchCurrentJSON() {
          const res = await fetch('/api/weather');
          const data = await res.json();
          document.getElementById('jsonViewer').innerText = JSON.stringify(data, null, 2);
        }

        async function fetchHistory() {
          const res = await fetch('/api/history');
          const list = (await res.json()).data || [];
          document.getElementById('historyCount').innerText = list.length + ' records';
          const container = document.getElementById('historyContainer');
          if (list.length === 0) {
            container.innerHTML = '<div style="text-align:center; color:#a0aec0; padding-top:50px;">No send history</div>';
            return;
          }
          container.innerHTML = list.map(item => {
            const isPending = item.status === 'pending';
            return '<div style="background:#f7fafc; border:1px solid #e2e8f0; border-radius:8px; padding:10px; margin-bottom:8px; font-size:12px;">' +
              '<div style="display:flex; justify-content:space-between; font-weight:bold;"><span>📍 ' + item.location + '</span><span>' + (isPending ? '⏳ 2m timer' : '✅ Received') + '</span></div>' +
              '<div style="color:#64748b; margin-top:4px;">⏱️ ' + item.sendTime + ' | 🌦️ ' + item.condition + ' | 🌡️ ' + item.temperature + '°C | 💧 ' + item.humidity + '%</div>' +
            '</div>';
          }).join('');
        }

        
        function setRainPreset(tier, rate, cond, temp) {
          document.getElementById('rainRate').value = rate;
          document.getElementById('condition').value = cond;
          if (temp) document.getElementById('temperature').value = temp;
          updateRainDisplay(rate);
        }

        function updateRainDisplay(val) {
          const rate = parseFloat(val) || 0;
          let text = rate.toFixed(1) + ' mm/hr';
          if (rate <= 0) text += ' (Clear)';
          else if (rate < 2.5) text += ' (Light Rain)';
          else if (rate <= 7.6) text += ' (Moderate Rain)';
          else text += ' (Heavy Rain - Severe ⚠️)';
          const lbl = document.getElementById('rainRateLabel');
          if (lbl) lbl.innerText = text;
          checkSevereAlert();
        }

        function onConditionChange(val) {
          if (val === 'sunny') setRainPreset('none', 0.0, 'sunny', 34);
          else if (val === 'cloudy') setRainPreset('none', 0.0, 'cloudy', 29);
          else if (val === 'rainy') setRainPreset('moderate', 5.0, 'rainy', 26);
          else if (val === 'thunderstorm') setRainPreset('heavy', 8.5, 'thunderstorm', 25);
        }

        function checkSevereAlert() {
          const rateInput = document.getElementById('rainRate');
          const tempInput = document.getElementById('temperature');
          const badge = document.getElementById('severeAlertBadge');
          if (!rateInput || !tempInput || !badge) return;

          const rate = parseFloat(rateInput.value) || 0;
          const temp = parseFloat(tempInput.value) || 0;

          if (rate > 7.6) {
            badge.style.display = 'block';
            badge.style.background = '#fef2f2';
            badge.style.border = '1px solid #ef4444';
            badge.style.color = '#991b1b';
            badge.innerHTML = '🚨 <b>SEVERE WEATHER EVENT TRIGGERED</b>: Heavy Rain (' + rate.toFixed(1) + ' mm/hr &gt; 7.6 mm/hr). Mobile App will intercept with Full-Screen Shelter Modal!';
          } else if (temp > 37.0) {
            badge.style.display = 'block';
            badge.style.background = '#fff7ed';
            badge.style.border = '1px solid #f97316';
            badge.style.color = '#9a3412';
            badge.innerHTML = '🔥 <b>SEVERE WEATHER EVENT TRIGGERED</b>: Extreme Heatwave (' + temp.toFixed(1) + '°C &gt; 37°C). Mobile App will intercept with Full-Screen Shelter Modal!';
          } else {
            badge.style.display = 'none';
          }
        }

        document.getElementById('weatherForm').addEventListener('submit', async (e) => {
          e.preventDefault();
          const payload = {
            location: document.getElementById('location').value,
            condition: document.getElementById('condition').value,
            temperature: Number(document.getElementById('temperature').value),
            humidity: document.getElementById('humidity').value,
            rain_rate_mm_hr: parseFloat(document.getElementById('rainRate').value) || 0.0
          };
          const res = await fetch('/api/weather', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
          });
          const result = await res.json();
          document.getElementById('jsonViewer').innerText = JSON.stringify(result, null, 2);
          fetchHistory();
          fetchTelemetry();
        });

        // Intervals
        setInterval(refreshSimState, 1000);
        setInterval(fetchTelemetry, 2000);
        setInterval(fetchHistory, 4000);

        // Initial Load
        refreshSimState();
        fetchCurrentJSON();
        fetchHistory();
        fetchTelemetry();
      </script>
    </body>
    </html>
  `);
});

const PORT = process.env.PORT || 4000;
app.listen(PORT, () => {
  console.log(`======================================================================`);
  console.log(`✅ Kia Kia Penang - Unified Simulation Console is Online!`);
  console.log(`👉 Web Dashboard (Bilingual / 多Tab控制台): http://localhost:${PORT}`);
  console.log(`👉 Weather API for Flutter App: http://localhost:${PORT}/api/weather`);
  console.log(`👉 Telemetry Stream: http://localhost:${PORT}/api/telemetry`);
  console.log(`======================================================================`);
});