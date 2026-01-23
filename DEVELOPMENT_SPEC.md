# Runner App Development Specification: "The 280-Day Journey"

## Quick Reference for Development

**Last Updated**: 2026-01-23 (FlipPoints moved to header, GPS timeout fix, doc sync)  
**App Name**: RunStrict (Project Code: 280-Journey)  
**Current Season Status**: D-280 (Pre-season)

---

## Table of Contents

1. [Project Overview & Philosophy](#1-project-overview--philosophy)
2. [Tech Stack & Architecture](#2-tech-stack--architecture)
3. [Core Gameplay Mechanics](#3-core-gameplay-mechanics)
4. [The Economy & Ranking Logic](#4-the-economy--ranking-logic)
5. [Purple Crew: The Protocol of Chaos](#5-purple-crew-the-protocol-of-chaos)
6. [Season Cycle & D-Day Protocol](#6-season-cycle--d-day-protocol)
7. [Screen Specifications](#7-screen-specifications)
8. [Data Models Reference](#8-data-models-reference)
9. [Hex Map System](#9-hex-map-system)
10. [Development Roadmap](#10-development-roadmap)
11. [Success Metrics](#11-success-metrics)
12. [Exit Strategy Considerations](#12-exit-strategy-considerations)

---

## 1. Project Overview & Philosophy

### Concept
A location-based running game that gamifies territory control through hexagonal maps.
- **Season**: Fixed **280 days** (Gestation period).
- **Reset**: On D-Day, all territories and scores are deleted (The Void). Only personal history remains.

### Core Philosophy
| Surface Layer | Hidden Layer |
|--------------|--------------|
| Red vs Blue competition | Connection through rivalry |
| Territory capture | Mutual respect growth |
| Weekly battles | Long-term relationships |
| "Win at all costs" | "We ran together" |

### Key Differentiators
- **Natural unity discovery** through competition phases
- **Purple Crew**: Mid-season chaos mechanic for comeback opportunities (Max 24 members)

---

## 2. Tech Stack & Architecture

### Core Strategy: "Hot vs Cold Data"
- **Hot Data**: Current Season Map, Live Leaderboard, Daily Stats (Firestore/Redis).
- **Cold Data**: Past Personal Records, Raw GPS Paths (AWS S3/Glacier).

### 12:00 PM Settlement (The Thundering Herd Solution)
1.  **11:59:59**: Freezing of `daily_flip_counts`.
2.  **12:00:00**: **Ranking Calculation** starts (Background Worker).
3.  **Update**: Leaderboard & Crew Rewards distributed.

### Current Implementation

| Layer | Technology | Status |
|-------|------------|--------|
| **Frontend** | Flutter | ✅ Active |
| **State Management** | Provider | ✅ Implemented |
| **Database** | Firebase Firestore | ✅ Configured (not fully integrated) |
| **Auth** | Firebase Auth | ✅ Configured |
| **Maps** | Mapbox | ✅ Integrated |
| **Hex Grid** | H3 (h3_flutter) | ✅ Implemented |
| **Spatial** | latlong2 | ✅ Implemented |
| **Local Storage** | SQLite (sqflite) | ✅ Configured |

### Package Dependencies (pubspec.yaml)

```yaml
# Core
flutter: sdk
provider: ^6.1.2

# Location & Maps
geolocator: ^13.0.2
mapbox_maps_flutter: ^2.3.0
latlong2: ^0.9.0
h3_flutter: ^0.7.1

# Firebase
firebase_core: ^3.8.1
cloud_firestore: ^5.5.1
firebase_auth: ^5.3.3

# Storage
sqflite: ^2.3.3+2
path_provider: ^2.1.4

# UI
google_fonts: ^6.2.1
animated_text_kit: ^4.2.2
shimmer: ^3.0.0
```

### Directory Structure

```
lib/
├── main.dart                    # App entry point, Provider setup
├── config/
│   └── mapbox_config.dart       # Mapbox API configuration
├── models/
│   ├── team.dart                # Team enum (red/blue/purple)
│   ├── user_model.dart          # User data model
│   ├── hex_model.dart           # Hex tile model (lastRunnerTeam only)
│   ├── crew_model.dart          # Crew with isPurple/multiplier/maxMembers
│   ├── district_model.dart      # Electoral district model
│   ├── run_session.dart         # Active run session data
│   ├── run_summary.dart         # Lightweight run summary for history
│   ├── daily_running_stat.dart  # Daily stats (Cold/Warm data)
│   ├── location_point.dart      # GPS point model (active run)
│   └── route_point.dart         # Compact route point (cold storage)
├── providers/
│   ├── app_state_provider.dart  # Global app state (team, user)
│   ├── run_provider.dart        # Run lifecycle & hex capture
│   ├── crew_provider.dart       # Crew management state
│   └── hex_data_provider.dart   # Hex data cache & state
├── screens/
│   ├── team_selection_screen.dart
│   ├── home_screen.dart         # Main navigation hub + AppBar
│   ├── map_screen.dart          # Hex map exploration view
│   ├── running_screen.dart      # Run screen (pre-run & active tracking)
│   ├── results_screen.dart      # Election-style results
│   ├── crew_screen.dart         # Crew management
│   ├── leaderboard_screen.dart  # Rankings
│   └── run_history_screen.dart  # Past runs (Calendar)
├── services/
│   ├── hex_service.dart         # H3 hex grid operations
│   ├── location_service.dart    # GPS tracking
│   ├── run_tracker.dart         # Run session management & hex capture
│   ├── gps_validator.dart       # Anti-spoofing validation
│   ├── storage_service.dart     # Storage interface (abstract)
│   ├── in_memory_storage_service.dart # In-memory storage (MVP/testing)
│   ├── local_storage_service.dart # SharedPreferences (last location, etc.)
│   ├── points_service.dart      # Flip points tracking & settlement
│   ├── season_service.dart      # 280-day season countdown
│   ├── running_score_service.dart # Pace validation for hex capture
│   └── data_manager.dart        # Hot/Cold data separation manager
├── storage/
│   └── local_storage.dart       # SQLite implementation (runs, routes)
├── theme/
│   ├── app_theme.dart           # Main theme configuration
│   ├── broadcast_theme.dart     # Election broadcast styling
│   ├── cyberpunk_theme.dart     # Alternative theme
│   └── neon_theme.dart          # Neon accent theme
├── utils/
│   ├── image_utils.dart         # Location marker generation
│   ├── route_optimizer.dart     # Ring buffer + Douglas-Peucker for routes
│   └── lru_cache.dart           # LRU cache for hex data
└── widgets/
    ├── hexagon_map.dart         # Hex grid overlay widget
    ├── route_map.dart           # Running route display + navigation mode
    ├── smooth_camera_controller.dart # 60fps camera interpolation
    ├── glowing_location_marker.dart  # Team-colored pulsing marker
    ├── flip_points_widget.dart  # Animated flip counter (header)
    ├── season_countdown_widget.dart  # D-day countdown badge
    ├── energy_hold_button.dart  # Hold-to-trigger action button
    ├── stat_card.dart           # Statistics card
    └── neon_stat_card.dart      # Neon-styled stat card
```

---

## 3. Core Gameplay Mechanics

### 3.1 Personal Stats (The Calendar)
- **Metrics**: Distance (km), Pace (min/km), Time (duration).
- **View**: Calendar UI (Day / Week / Month / Year).
- **Aggregation**: Raw daily sums vs. period averages.

### 3.2 (Removed)
*Section intentionally left blank. Pack Running Bonus has been removed to simplify the economy.*

---

## 4. The Economy & Ranking Logic

### 4.1 Crew Economy: Winner-Takes-All
Inside a Crew:
- **Red/Blue Crew**: Max **12 members**
- **Purple Crew**: Max **24 members** (larger to accommodate defectors)
- **Pool**: Sum of all members' flip points.
- **Winner**: Only **Top 4** members split the pool.
- **Loser**: Remaining members get **0 Points** (only personal mileage).

### 4.2 Tie-Breaking Protocol
1.  **Primary Filter**: Flip Count (Quantity).
2.  **Secondary Filter**: Achievement Timestamp (Time Priority).
3.  **Tertiary Filter**: The Blood Split (Equal Division of Rewards).

---

## 5. Purple Crew: The Protocol of Chaos

### 5.1 Concept & Role
The Purple Crew is not a starting team. It is a **mid-season mechanic** designed to break the stalemate between Red and Blue.
- **Role**: The "Joker" or "Virus".
- **Target Audience**: Low-ranking users (Ranks 5-12) in Red/Blue crews who are earning 0 rewards.
- **Crew Size**: Max **24 members** (double the Red/Blue limit to accommodate mass defection).

### 5.2 The "Traitor's Gate" (Mechanics)
- **Unlock Condition**: Opens strictly at **D-140** (Halfway point).
- **Entry Cost**: 
    1.  **Total Season Score Reset**: The user's accumulated Season Points become **0**.
    2.  **Irreversible**: Once a user joins Purple, they **cannot** return to Red or Blue for the rest of the season.
- **UI UX**: When joining, a warning modal appears: *"You are about to abandon your history. This path has no return. Do you accept the Chaos?"*

### 5.3 The "High Risk, High Return" Economy
Purple Crews operate under a different economic law to incentivize betrayal.

| Feature | Red / Blue Crew | Purple Crew |
| :--- | :--- | :--- |
| **Point Multiplier** | **1.0x** (1 Flip = 1 Point) | **2.0x** (1 Flip = 2 Points) |
| **Internal Economy** | Top 4 Take All | **Top 4 Take All** (Same cruelty) |

* **Logic**: A Purple runner is twice as efficient. This allows late-starters or defectors to catch up to the Global Leaderboard rapidly, provided they can survive the internal competition.

---

## 6. Season Cycle & D-Day Protocol

### Season Structure
- **Duration**: 280 days (Gestation period metaphor)
- **D-140**: Purple Crew unlocks (Halfway point)
- **D-Day**: Season reset

### D-Day Reset Protocol
- **Hard Delete**: All Map & Score data is wiped (The Void).
- **Archive**: Personal Calendar data (km, pace) is preserved in Cold Storage.
- **New Beginning**: All users start fresh with team selection.

---

## 7. Screen Specifications

### 1. Map Screen (The Void)
- Default: Grey/Transparent. Painted by running.
- **Purple Effect**: Purple tiles pulse slowly to indicate "Instability".

### 2. Running Screen (Pre-Run & Active Run)
- **Pre-run state**: Shows map with hex grid, pulsing hold-to-start button, "READY" indicator
- **Active run state**: 
  - Glowing ball (user location) moving forward
  - Map rotates based on direction of movement (navigation mode)
  - Car navigation style (60fps smooth camera interpolation via SmoothCameraController)
  - Tracing line draws the running path
  - Stats overlay: distance, time, pace
  - Top bar shows "RUNNING" + team-colored pulsing dot
  - **Flip points shown in header AppBar** (not in running screen) with team-colored glow animation on each flip
  - Hold-to-stop button (1.5s hold, no confirmation dialog)

### 3. Leaderboard Screen
- **Filters**: Tabs for [ALL] / [RED] / [BLUE] / [PURPLE].
- **List View Structure**:
    1.  **Top 1 ~ 20**: Fixed display.
    2.  **Divider**: Visual break.
    3.  **Sticky Footer**: My Rank (if > 20).
- **Purple Highlighting**: In the [ALL] tab, Purple users have a distinct glowing border to signify their "Traitor/Joker" status.

### 4. Personal History (Calendar)
- **UI**: Month view calendar grid with daily dot indicators.
- **Stats**: Total km, Avg Pace, Total Time.

### 5. Results Screen
- Real-time territory flip animations
- District-by-district breakdown

---

## 8. Data Models Reference

### Team Enum

```dart
enum Team {
  red,    // Display: "FLAME" 🔥 - "Passion & Energy"
  blue,   // Display: "WAVE" 🌊 - "Trust & Harmony"
  purple; // Display: "CHAOS" 💜 - "The Betrayer's Path"
}
```

### User Model

```dart
class UserModel {
  String id;
  String name;
  Team team;              // 'red' | 'blue' | 'purple' (team == purple means defected)
  String avatar;          // Emoji avatar
  String? crewId;
  int seasonPoints;       // Reset to 0 when joining Purple
}
```

**Note**: `totalDistance` and `currentSeasonDistance` are calculated from `dailyStats/` collection on-demand.

### UserHistory (Cold/Warm Data)

```dart
class DailyRunningStat {
  String userId;
  String dateKey; 
  double totalDistanceKm;
  int totalDurationSeconds;
  double avgPaceSeconds; 
}
```

### Hex Model (Last Runner Color System)

```dart
/// Hex color based on last runner - NO ownership
class HexModel {
  String id;              // H3 hex index as hex string
  LatLng center;
  Team? lastRunnerTeam;   // null = neutral, else Red/Blue/Purple
  
  /// Color is purely based on who ran last
  Color get hexColor {
    if (lastRunnerTeam == null) return neutralGray;
    return lastRunnerTeam!.color;
  }
}
```

**Important**: No timestamps, no runner IDs - just the team color. This minimizes storage cost and protects user privacy.

### Crew Model (Updated for Purple)

```dart
class CrewModel {
  String id;
  String name;
  Team team;              // Red, Blue, Purple
  List<String> memberIds; // Max 12 (Red/Blue) or 24 (Purple)

  // Purple Specific Logic (derived, not stored)
  bool get isPurple => team == Team.purple;
  int get multiplier => isPurple ? 2 : 1;
  int get maxMembers => isPurple ? 24 : 12;
}
```

**Note**: `weeklyDistance`, `hexesClaimed`, `wins`, `losses` are calculated from `runs/` and `dailyStats/` on-demand.

### Color Display Rules

| Hex State | Condition | Display |
|-----------|-----------|---------|
| Neutral | lastRunnerTeam == null | Gray, subtle fill |
| Blue | lastRunnerTeam == blue | Blue subtle fill |
| Red | lastRunnerTeam == red | Red subtle fill |
| Purple | lastRunnerTeam == purple | Purple subtle fill (pulsing) |

**Important**: No scores, no ownership percentages - just the last runner's color.

---

## 9. Hex Map System

### H3 Resolution Reference

| Resolution | Avg Edge (m) | Avg Area (km²) | Use Case |
|------------|--------------|----------------|----------|
| 5 | 8,544 | 252.9 | Province level |
| 6 | 3,229 | 36.1 | City level |
| 7 | 1,220 | 5.2 | District level |
| 8 | 461 | 0.74 | Neighborhood |
| 9 | 174 | 0.11 | Block level |

**Recommended**: Resolution 8 for 동네 (500m radius target)

### Hex Color Change Logic

```dart
/// Update hex when a runner passes through
void updateHexColor({
  required HexModel hex,
  required Team runnerTeam,
  required bool isPurpleRunner,
}) {
  // Simply set the hex to the runner's color
  if (isPurpleRunner) {
    hex.lastRunnerTeam = Team.purple;
  } else {
    hex.lastRunnerTeam = runnerTeam;
  }
  hex.lastRunTime = DateTime.now();
}

/// Check if runner can change this hex's color
bool canCaptureHex({required double paceMinPerKm}) {
  // Must be running at valid pace (faster than 8:00 min/km)
  return paceMinPerKm < 8.0;
}
```

### Hex Visual Feedback

| State | Fill Color | Opacity | Border |
|-------|-----------|---------|--------|
| Neutral | Dark gray (#2A3550) | 0.15 | Gray (#6B7280), 1px |
| Blue last | Blue light | 0.3 | Blue, 1.5px |
| Red last | Red light | 0.3 | Red, 1.5px |
| Purple last | Purple light | 0.3 (pulsing) | Purple, 1.5px |
| Current (runner here) | Team color | 0.5 | Team color, 2.5px |

---

## 10. Development Roadmap

### Phase 1: Core Gameplay (Target: 1-3 months)

| Feature | Sub-feature | Status | Notes |
|---------|-------------|--------|-------|
| **Distance Tracking** | GPS integration | ✅ Done | geolocator package |
| | Accelerometer validation | ⬜ TODO | Requires sensor_plus |
| | Offline storage | ✅ Done | SQLite ready |
| | Speed filter (25 km/h) | ⬜ TODO | In gps_validator.dart |
| **User Auth** | Firebase Auth setup | ✅ Done | Email/Google/Apple |
| | Team selection UI | ✅ Done | team_selection_screen.dart |
| | User profile | ✅ Done | Basic implementation |
| | Personal stats dashboard | ⬜ TODO | Calendar view |
| **Crew System** | Crew creation | ✅ Done | crew_model.dart |
| | Crew join (2-12 members) | ⬜ TODO | UI exists, backend missing |
| | Crew stats page | ⬜ TODO | |
| | In-app chat | ⬜ TODO | |
| **Hex Map** | H3 grid overlay | ✅ Done | hex_service.dart |
| | Territory visualization | ✅ Done | hexagon_map.dart |
| | State transitions | ✅ Done | HexState enum |
| | Interactive cells | ⬜ TODO | Tap handling |

### Phase 2: Social & Economy (Target: 4-6 months)

| Feature | Sub-feature | Status | Notes |
|---------|-------------|--------|-------|
| **Crew Economy** | Top 4 winner system | ⬜ TODO | Winner-Takes-All |
| | Flip point tracking | ✅ Done | points_service.dart |
| | 12:00 PM settlement | ⬜ TODO | Background worker |
| **Advanced Hex** | Contested zones | ✅ Done | In HexState |
| | District aggregation | ⬜ TODO | |
| | Time-based animations | ⬜ TODO | |

### Phase 3: Purple Crew & Season (Target: 7-9 months)

| Feature | Sub-feature | Status | Notes |
|---------|-------------|--------|-------|
| **Purple Crew** | D-140 unlock gate | ⬜ TODO | Traitor's Gate |
| | Score reset mechanic | ⬜ TODO | |
| | 2x multiplier logic | ⬜ TODO | |
| | Purple pulsing effect | ⬜ TODO | Map visual |
| **Season System** | 280-day cycle | ⬜ TODO | |
| | D-Day reset protocol | ⬜ TODO | |
| | Cold storage archive | ⬜ TODO | AWS S3/Glacier |
| **Analytics** | Global/regional rankings | ⬜ TODO | |
| | Achievement badges | ⬜ TODO | |

---

## 11. Success Metrics

### Key Performance Indicators

| Category | Metric | Phase 1 Target | Phase 2 Target | Phase 3 Target |
|----------|--------|----------------|----------------|----------------|
| **Users** | DAU | 300 | 1,500 | 5,000 |
| | WAU | 1,000 | 5,000 | 15,000 |
| | MAU | 2,000 | 10,000 | 30,000 |
| **Engagement** | D1 Retention | 50% | 55% | 60% |
| | D7 Retention | 30% | 35% | 40% |
| | D30 Retention | 15% | 20% | 25% |
| | Avg Session | 8 min | 12 min | 15 min |
| **Social** | Crews Formed | 100 | 500 | 2,000 |
| | Avg Crew Size | 4 | 6 | 8 |
| **Activity** | Runs/Day | 500 | 2,000 | 6,000 |
| | Avg Distance/Run | 3 km | 4 km | 5 km |
| | Hexes Claimed | 500 | 5,000 | 20,000 |
| **Purple (Phase 3)** | Defection Rate | - | - | 15% |
| | Purple Crew Count | - | - | 50+ |

### Revenue Metrics (Post-Launch)

| Metric | Description | Target |
|--------|-------------|--------|
| LTV | Lifetime Value per user | $15+ |
| CAC | Customer Acquisition Cost | <$5 |
| LTV:CAC | Ratio | >3:1 |
| MRR | Monthly Recurring Revenue | Growth-focused |
| Churn | Monthly churn rate | <5% |

---

## 12. Exit Strategy Considerations

### Built-to-Sell Checklist

#### Technical Foundation
- [x] Popular tech stack (Flutter - cross-platform)
- [ ] Clean architecture documentation
- [ ] API documentation (Swagger)
- [ ] System architecture diagrams
- [ ] Third-party license audit
- [ ] No hardcoded secrets

#### Business Metrics
- [ ] Analytics integration (Firebase + custom)
- [ ] Retention tracking (D1/D7/D30)
- [ ] LTV/CAC calculations
- [ ] MRR/Churn tracking (if subscription)
- [ ] Third-party verification tools

#### Financial Readiness
- [ ] SDE-based P&L preparation
- [ ] Add-backs documentation
- [ ] Revenue source breakdown
- [ ] Cost structure analysis

#### Legal Compliance
- [ ] IP ownership documentation
- [ ] Privacy policy (PIPA compliant)
- [ ] Terms of service
- [ ] Open source license compliance

### Valuation Factors

| Factor | Impact | Current Status |
|--------|--------|----------------|
| Tech Stack | High | ✅ Flutter (favorable) |
| User Base | Critical | ⬜ Pre-launch |
| Retention | Critical | ⬜ Pre-launch |
| Revenue | Critical | ⬜ Pre-launch |
| Documentation | Medium | ⬜ Partial |
| Clean Code | Medium | ✅ Decent |
| Scalability | High | ✅ Firebase scales |
| Market Size | High | ✅ Korean running market growing |

---

## Appendix A: API Reference (Planned)

### Firestore Collections

```
users/
  {userId}/
    - name: string
    - team: 'red' | 'blue' | 'purple'
    - crewId: string?
    - seasonPoints: number

crews/
  {crewId}/
    - name: string
    - team: 'red' | 'blue' | 'purple'
    - memberIds: string[]              # Max 12 (Red/Blue) or 24 (Purple)

hexes/
  {hexId}/
    - lastRunnerTeam: 'red' | 'blue' | 'purple' | null

runs/
  {runId}/
    - userId: string
    - teamAtRun: 'red' | 'blue' | 'purple'
    - startTime: timestamp
    - endTime: timestamp
    - distance: number
    - avgPace: number
    - hexesColored: number             # Flip count for this run

dailyStats/
  {dateKey}/
    {userId}/
      - totalDistanceKm: number
      - totalDurationSeconds: number
      - avgPaceSeconds: number
      - flipCount: number
```

**Design Notes**:
- `hexes/`: Only stores `lastRunnerTeam`. No timestamps or runner IDs (privacy + cost savings).
- `users/`: Distance stats are calculated from `dailyStats/` on-demand.
- `runs/`: GPS `route[]` and `hexesPassed[]` moved to Cold Storage (AWS S3).
- `crews/`: `multiplier` is derived from `team == 'purple'` (no need to store).

---

## Appendix B: Slogan Options

Korean:
- "같은 땀, 다른 색" (Same sweat, different colors)
- "우리는 반대로 달려 만났다" (We ran apart, met together)
- "배신은 새로운 시작이다" (Betrayal is a new beginning)

English:
- "Run Apart, Meet Together"
- "United Through Running"
- "Same Path, Different Colors"
- "Embrace the Chaos"

---

## 주요 변경 사항 요약 (Summary of Changes from Previous Version)

1.  **팩 러닝 보너스 삭제**:
    * 3.2 섹션을 삭제하고, 로직을 단순화하여 4명 독식 구조에 집중하도록 했습니다. 이제 "같이 뛰는 것"에 대한 시스템적 보너스는 없으며, 오직 순수 실력(Flip 수)으로만 경쟁합니다.

2.  **보라색 크루(Purple Crew) 상세화 (Section 5)**:
    * **정체성 확립**: 레드/블루의 하위권(보상을 못 받는 5~12위)을 유혹하여 시스템을 전복시키는 "바이러스/조커" 역할로 정의했습니다.
    * **진입 장벽(The Cost)**: 시즌 점수 **0점 리셋**이라는 페널티를 명시하여, "잃을 게 없는 자들"만 진입하도록 유도했습니다.
    * **경제적 이점**: **2배(2.0x) 멀티플라이어**를 부여하여, 늦게 시작해도 압도적인 속도로 랭킹을 역전할 수 있는 가능성을 열어두었습니다.

3.  **280일 시즌 구조 명시**:
    * 시즌이 280일(임신 기간 메타포)로 고정되었으며, D-Day에 모든 맵과 점수가 리셋되는 "The Void" 프로토콜이 추가되었습니다.
    * 개인 기록(Calendar data)만 Cold Storage에 보존됩니다.

4.  **데이터 최적화 (2026-01-20)**:
    * `hexes/`: `lastRunTime`, `lastRunnerId` 삭제 (프라이버시 보호 + 비용 절감)
    * `users/`: `totalDistance`, `currentSeasonDistance`, `isPurple`, `purpleJoinDate` 삭제 (중복 데이터 제거)
    * `crews/`: `weeklyDistance`, `hexesClaimed`, `wins`, `losses`, `multiplier` 삭제 (계산 가능한 값)
    * `runs/`: `route[]`, `hexesPassed[]`, `pointsEarned` 삭제 (Cold Storage로 이동 또는 계산 가능)

5.  **기존 유지 항목**:
    * Tech Stack & Package Dependencies
    * Directory Structure
    * Success Metrics
    * Exit Strategy Considerations
    * H3 Resolution Reference

6.  **Purple Crew 인원 확대 및 Twin Crew 삭제 (2026-01-20)**:
    * Purple Crew 최대 인원: 12명 → **24명** (대규모 이탈을 수용하기 위해)
    * Twin Crew 시스템 완전 삭제 (Key Differentiators, Phase 2 Roadmap, Success Metrics, Firestore Schema에서 제거)
    * Crew Model에 `maxMembers` getter 추가 (팀별 최대 인원 차등 적용)

7.  **Running Screen 통합 (2026-01-22)**:
    * `active_run_screen.dart` 삭제
    * `running_screen.dart`가 Pre-run 및 Active run 상태를 모두 처리
    * 단일 화면에서 시작 전/러닝 중 UI 전환
    * Navigation mode (베어링 추적) 기능 포함

8.  **FlipPoints 헤더 이동 & 카메라 수정 (2026-01-23)**:
    * `FlipPointsWidget`을 Running Screen에서 제거, AppBar 헤더에서만 표시
    * 플립 포인트 획득 시 팀 컬러 글로우 + 스케일 바운스 애니메이션 추가 (peripheral vision에 눈에 띄게)
    * Running Screen 상단 바: "RUNNING" + pulsing dot (러닝 중), "READY" (대기 중)
    * 러닝 종료 확인 다이얼로그 제거 (hold-to-stop 버튼이 확인 역할)
    * MapScreen GPS TimeoutException 처리 개선 (캐시 위치 폴백)
    * `easeTo` 카메라 애니메이션을 fire-and-forget으로 변경 (타임아웃 방지)
    * RunHistoryScreen stat card overflow 수정 (`FittedBox` 적용)
    * Directory structure에 새 서비스/위젯 반영 (points_service, season_service, smooth_camera_controller 등)

---

*This document should be updated as development progresses. Mark checkboxes as features are completed.*
