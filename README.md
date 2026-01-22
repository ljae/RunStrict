# 🏃 달리기로 하나되는 (United Through Running)

**"우리는 같은 길을 달린다"**

A revolutionary running app that gamifies territory control through hexagonal maps, combining competitive team dynamics with electoral broadcast aesthetics. Run to claim territories, compete with rival crews, and discover unity through competition.

## 🎯 Core Concept

Transform real running distances into territorial control on a hexagonal map grid. Users choose between Red Team (🔴) or Blue Team (🔵) and compete for district domination, with results presented in an exciting electoral broadcast style.

### Hidden Truth
While users compete fiercely on the surface, the app's deeper design reveals how competition naturally leads to connection and mutual respect through the Twin Crew system.

## ✨ Key Features

### 1. **Team-Based Competition**
- Choose between Red Team or Blue Team
- Real-time territory balance visualization
- Electoral district mapping overlaid on real locations

### 2. **Hexagonal Territory System**
- Interactive hex grid representing real-world locations
- Territory states: Neutral → Light Control → Strong Control → Contested
- Visual feedback with glowing effects and animations
- Scale structure:
  - Neighborhood (500m radius)
  - District (2km radius)
  - City/Province (grouped areas)
  - National (entire map)

### 3. **Crew System**
- **My Crew**: 12-member teams competing for territory
- **Twin Crew**: Rival matching system for 1v1 crew battles
- Weekly "Derby Matches" with persistent records
- Crew chat and leaderboards

### 4. **GPS Running Tracker**
- Real-time distance, pace, and time tracking
- Territory contribution calculation
- Offline support with sync
- Anti-spoofing measures (speed filter: 25 km/h max)

### 5. **Electoral-Style Results**
- Breaking news announcements
- District-by-district result breakdowns
- Animated percentage bars
- MVP highlights and dramatic moments
- Time-based vote counting animations

### 6. **Season System**
- Quarterly "election" events:
  - New Year Presidential Election (Jan-Feb)
  - Spring Local Elections (April)
  - Summer By-Elections (July)
  - Fall General Elections (October)

## 🎨 Design Philosophy

### Broadcast Aesthetic
The entire app is designed to feel like watching election night coverage:
- **Dark theme** resembling a broadcast control room
- **Bold red/blue colors** with electric purple for contested areas
- **Monospace fonts** for data (Space Mono)
- **Display fonts** for headers (Bebas Neue)
- **Korean support** (Noto Sans KR)
- **Real-time animations** mimicking vote tallies

### Color System
- **Red Team**: `#DC2626` → `#EF4444` gradient
- **Blue Team**: `#2563EB` → `#3B82F6` gradient
- **Contested**: `#8B5CF6` with glow effects
- **Background**: Dark `#0A0E1A` → `#111827`
- **Accents**: Gold `#F59E0B` for highlights

## 📱 App Screens

### 1. Team Selection
Beautiful onboarding with animated team cards, gradient text, and bouncing emoji.

### 2. Map View
- Hexagonal grid overlay on territory map
- Real-time hex state updates
- Legend showing territory types
- Interactive hex cells with hover effects

### 3. Running Tracker
- Large distance display
- Secondary stats (time, pace, calories)
- Start/Pause/Stop controls
- Territory impact preview

### 4. Crew Management
- My Crew tab with member grid
- Twin Crew rivalry display with VS screen
- Weekly match progress bars
- Crew messaging system

### 5. Results Screen
- Breaking news banner
- Side-by-side team scoreboards
- District result bars with animations
- Highlights section (MVP, comebacks, close races)

### 6. Leaderboard
- Filter by All/My Team/Other Team
- Top 3 highlighted with medals
- Real-time ranking updates

## 🛠 Technical Stack

### Frontend
- **Framework**: React 18 (via CDN for simplicity)
- **Language**: JavaScript (ES6+)
- **Styling**: Pure CSS with CSS Variables
- **Fonts**: Google Fonts (Bebas Neue, Noto Sans KR, Space Mono)

### Planned Backend (Future)
- **Database**: Firebase Firestore
- **Authentication**: Firebase Auth (Email/Google/Apple)
- **Maps**: Mapbox SDK
- **Spatial Indexing**: S2 Geometry for hex grid
- **Location Data**: Korean Electoral Commission GeoJSON

### GPS Tracking
- GPS displacement-based distance calculation
- Accelerometer verification
- Speed filter (25 km/h cap)
- Offline SQLite storage with sync

## 🚀 Getting Started

### Quick Start
1. Open `index.html` in a modern web browser
2. Select your team (Red or Blue)
3. Start exploring the interface!

### File Structure
```
runner/
├── index.html          # Main HTML structure
├── styles.css          # Complete styling system
├── app.js              # React application logic
├── Runner.pdf          # Original specification document
└── README.md           # This file
```

### Running Locally
Simply open `index.html` in your browser. No build process required!

```bash
# Optional: Use a local server
python -m http.server 8000
# Then visit http://localhost:8000
```

## 🎮 User Flow

### Phase 1: Competition (Months 1-3)
- Select team
- Join or create crew
- Start running to claim territories
- Watch hex map change in real-time

### Phase 2: Rivalry (Months 3-6)
- Get matched with Twin Crew
- See ghost runners from rival crew
- Compete in weekly derbies
- Notice similar running patterns

### Phase 3: Recognition (Months 6-9)
- Rival recognition system unlocks
- See repeated matchups with specific runners
- Acknowledge worthy opponents

### Phase 4: Unity (Months 12+)
- Season ends with revelation
- Hidden stats revealed (same times, same locations, mutual respect)
- Message exchange with rival crew
- "We fought together" moment

## 🎯 Core Mechanics

### Territory Control
- Each hex requires minimum cumulative distance
- States: Neutral (0km) → Light (5km) → Strong (15km+)
- Contested if within 5% difference
- Weekly resets for active competition

### Twin Crew Matching
Automatic algorithm scores based on:
- Activity time similarity (40%)
- Weekly distance similarity (30%)
- Geographic overlap (30%)

### Rewards
- **Solo Crew**: Base XP, basic badges, global ranking
- **Twin Crew**: 2x XP, limited edition badges, rivalry rankings, exclusive events

## 📊 Data Model

### User
```javascript
{
  id: string,
  team: 'red' | 'blue',
  name: string,
  avatar: emoji,
  crewId: string,
  totalDistance: number,
  currentSeasonDistance: number
}
```

### Hex
```javascript
{
  id: string,
  coordinates: [lat, lng],
  redDistance: number,
  blueDistance: number,
  state: 'neutral' | 'red-light' | 'red-strong' | 'blue-light' | 'blue-strong' | 'contested',
  lastUpdate: timestamp
}
```

### Crew
```javascript
{
  id: string,
  name: string,
  team: 'red' | 'blue',
  members: userId[],
  twinCrewId: string | null,
  weeklyDistance: number,
  hexesClaimed: number,
  twinRecord: { wins: number, losses: number }
}
```

## 🎨 Animation System

### Key Animations
- **Team Selection**: Fade in, bounce, gradient text
- **Hex States**: Pulse, glow, scale on hover
- **Results**: Slide in with stagger delay
- **Breaking News**: Slide from left
- **Grid Background**: Infinite subtle movement
- **Progress Bars**: Smooth 1s transitions

### Performance
- CSS-only animations where possible
- GPU-accelerated transforms
- Smooth 60fps on mobile devices

## 🌏 Viral Features

### Shareable Moments
1. **Comeback Victory**: "My 3km at 5am flipped our neighborhood!"
2. **Electoral Parody**: News anchor-style result cards
3. **Unity Map**: First-time purple (both teams) overlay
4. **Season Recap**: Annual highlight video

### Slogans
- "같은 땀, 다른 색" (Same sweat, different colors)
- "우리는 반대로 달려 만났다" (We ran apart, met together)
- "Run Apart, Meet Together"

## 🔮 Future Roadmap

### Short-term
- Local business integration (runner discounts)
- Photo check-in at hexes
- Real marathon event partnerships

### Mid-term
- Expand to all major Korean cities
- Seasonal team themes
- Crew tournaments

### Long-term
- National coverage
- Regional community managers
- DAO-style governance for rules

## 🏆 Success Metrics

### Phase 1 (MVP - 3 months)
- ✅ 1,000 active users
- ✅ 100 crews formed
- ✅ 500 territories claimed
- ✅ 80% weekly retention

### Phase 2 (Social - 6 months)
- ✅ 50 twin crew pairs
- ✅ 5,000 weekly active users
- ✅ 15+ min average session time

### Phase 3 (Seasons - 9 months)
- ✅ 60% season completion rate
- ✅ 70% season-to-season return rate
- ✅ 10,000 monthly active users

## 🤝 Contributing

This is a conceptual prototype. For production implementation:
1. Set up Firebase project
2. Integrate Mapbox for real maps
3. Implement actual GPS tracking
4. Add real-time database synchronization
5. Deploy backend infrastructure

## 📄 License

Conceptual prototype based on Runner.pdf specifications.

## 🙏 Credits

- **Concept**: Runner.pdf specification
- **Design & Development**: Claude Code with /frontend-design
- **Typography**: Google Fonts
- **Icons**: Emoji (universal support)

---

**Remember**: "화합은 선언되지 않습니다. 경쟁 속에서 자연스럽게 쌓입니다."
*(Unity is not declared. It naturally accumulates through competition.)*
