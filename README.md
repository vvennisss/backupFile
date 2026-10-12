# Kia Kia Penang - Travel Companion Web App (同行者 Web App)

A lightweight, mobile-first Web Application enabling travel companions to instantly sync with group itineraries, view live GPS location radar, receive lead traveler directives, and send 1-tap emergency/status alerts without creating an account or installing native apps.

---

## 📱 The 4 Core Screens (All in English)

### 1. Join Screen (`#screen-join`)
- **Digit Code Verification**: 6-digit access code input box with auto-focus shifting, backspace navigation, and paste support.
- **Companion Nickname Input**: Custom nickname for instant identification on group radar.
- **Action & Validation**: Primary `"Join Trip"` button styled in Indigo (`#304FFE`) with inline feedback for expired or invalid codes.
- **Built-in Demo Codes**:
  - `888888` (Penang Heritage Explorer Trail)
  - `666666` (Penang Foodie & Hawker Paradise)

### 2. Dashboard / Map Screen (`#screen-dashboard`)
- **Real-Time Interactive Map**: Powered by **Mapbox GL JS** (using the exact same Mapbox public token and style as the Flutter mobile app).
  - Uses `mapbox://styles/mapbox/streets-v12` by default and supports 1-tap switching to `mapbox://styles/mapbox/outdoors-v12` (terrain view).
  - Shows Lead Traveler position with a Crown pin icon and live subtle simulation movements.
  - Shows Companion's real-time position with radar pulse animation and GPS watcher sync.
  - Destination stops pinned with sequential numbering and dashed GeoJSON route polylines.
- **Top Status Bar**: Displays current Trip ID, Itinerary Title, and countdown timer pill to the next scheduled stop.
- **Quick Next-Stop Banner**: Floating badge showing distance, departure time, and a 1-tap Google Maps Navigation shortcut.
- **Itinerary Drawer (Collapsible Bottom Sheet)**:
  - Collapsible timeline list showing each stop's schedule, recommended duration, category, and local tips.
  - Tapping any stop immediately pans and zooms the map to that destination pin.

### 3. Action & SOS Panel (`#screen-action`)
- **Lead Traveler Directive Broadcast Box**:
  - Highlights real-time instructions sent by the group organizer (e.g., *"Regroup at the main entrance in 10 minutes"*).
- **1-Tap Quick Status & Safety Triggers**:
  - **"I'm Left Behind" (Red)**: Broadcasts immediate lost alert and pulses companion GPS coordinates to leader.
  - **"I'm Safe" (Green)**: Clears alerts and confirms regroup status.
  - **"Need Assistance" (Amber)**: Requests quick group support without typing.
  - **"At Meeting Point" (Blue)**: Signals arrival at assembly location.
- **Live Activity Feed**: Timestamped log of team updates.

### 4. Settings & Privacy Screen (`#screen-settings`)
- **Live GPS Sharing Toggle**: Autonomously pause or resume sharing real-time location with teammates.
- **Offline Cache Status**: PWA Service Worker caching (`sw.js`) guarantees itinerary stops and map cache function even with weak connectivity.
- **Session & Profile Management**: Edit nickname or leave the current trip session with one tap.

---

## 🎨 Design System Compliance
- **Typography**: SF Pro / Inter font for standard text; **Roboto Mono** for digit codes and action buttons.
- **Button Styling**: Strict palette mapping:
  - Join & Primary Actions: `Colors.indigoAccent[700]` (`#304FFE`) with white text.
  - Highlights & Accents: `Colors.yellowAccent[400]` (`#FFEA00`) with black text.
- **Mobile First**: Optimized touch targets and responsive layouts tailored for mobile viewports.

---

## 🚀 How to Run Locally

### Option 1: Using Node.js `npx serve`
```bash
cd companion_web
npx serve -l 5000
```
Then visit: `http://localhost:5000`

### Option 2: Using Python HTTP Server
```bash
cd companion_web
python -m http.server 8080
```
Then visit: `http://localhost:8080`
