# Kia-Kia Penang Admin Web Panel (Administrative Operations Control Center)

A centralized web operations console designed in **English** for managing platform metrics, MongoDB attractions, stickers, events calendar, feature ads, gamification stamps, and issue resolution for **Kia-Kia Penang**.

---

## 🚀 Quick Start

### 1. Launch Admin Server
```bash
cd admin_web
npm install
node server.js
```

### 2. Access Web Panel
Open your browser and navigate to:
```
http://localhost:5050
```

---

## 🛠️ Complete Feature Modules (All 7 Suites)

### 1. 📊 Dashboard, UCM & Broadcasts
- **KPI Metrics**: Real-time display of total users (Travelers vs Companions), monthly generated trips, open bug count, and active MongoDB connection status.
- **Rank Tier Distribution**: Live Chart.js interactive bar chart categorizing users across *Tourist*, *Traveler*, *Explorer*, *Adventurer*, and *Legend*.
- **UCM (User & Companion Management)**: Instant search/filter by role and status, 1-click companion verification (`verified`), and account ban/unban capabilities (`banned`).
- **FCM Push Broadcasts**: Multi-target notifications selector (*All Users*, *Travelers Only*, *Companions Only*) with instant dispatch logs.

### 2. 🗺️ Attraction CMS (MongoDB `places_new` Collection)
- **Direct MongoDB Integration**: Connected to MongoDB Atlas cluster `places_new` collection with 100+ live attractions and spots.
- **Search & Filter**: Search by title, summary, or category (*Heritage & Culture*, *Cafes*, *Food & Dining*, *Religious Sites*, *Nature & Parks*, etc.).
- **Field Editing**: Update attraction name, coordinates, address, operating hours, search keywords, and LLM AI description summary.
- **Thumbnail Upload & Sync**: Drag-and-drop or file selector uploads local images to `/uploads/thumbnails/` and binds the URL directly to `place_media.thumbnail` in MongoDB with live preview.

### 3. 🎨 Studio Sticker Manager
- **Sticker Asset Upload**: Upload transparent PNG/SVG graphics for camera decoration in the Studio Tab.
- **Metadata Management**: Set sticker title and tag categories (*George Town Landmarks*, *Authentic Delicacies*, *Handdrawn Typography*).
- **Popularity & Visibility**: Live usage statistics counter and toggle between *Active* and *Hidden*.

### 4. 📅 George Town Calendar (Cultural & Events)
- **Happenings & Road Advisories**: Log festivals, religious ceremonies, night markets, and road closures with start/end dates and GPS pins.
- **LLM AI Planner Injection**: 1-click toggle (`includeInAIPlanner`) to feed dynamic context into the Ollama/Gemini itinerary planner.

### 5. 📢 Feature Ads & Banners
- **Banner Deployment**: Input campaign titles, target URLs/Deeplinks (`kiakia://...`), and upload banner artwork.
- **Timestamp Scheduling**: Auto calculates start/end Unix timestamps; dynamically sets campaign status to *Active*, *Scheduled*, or *Expired*.

### 6. 🏆 Gamifications & Stamps
- **Geofence Hotspots**: Set GPS coordinates, unlock radius (e.g. 30m), category, and XP points for digital stamp acquisition.
- **Digital Badges**: Manage criteria for unlocking explorer milestones.
- **Rank Tier Thresholds**: Configure XP and route thresholds for tier upgrades.

### 7. 💬 Issue & Bug Reports
- **Ticket Tracking**: Centralized inbox for user feedback categorizing map offset issues, pricing discrepancies, and crash reports.
- **Workflow State Management**: Transition tickets between *Open*, *In Progress*, and *Resolved* with one click, or delete spam entries.

---

## 🎨 Design System Compliance
- **Typography**: SF Pro / System font for all titles, labels, normal text, and descriptions.
- **Button System**: Styled with **26px `Roboto Mono`**:
  - **Discover, Studio & Profile actions**: Background `Colors.indigoAccent[700]` (`#304FFE`) with White text.
  - **Story, Map & Calendar actions**: Background `Colors.yellowAccent[400]` (`#FFEA00`) with Black text.
