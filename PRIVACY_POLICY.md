# Privacy Policy

**Effective Date:** March 1, 2026
**Version:** 1.0

RunStrict ("we", "us", "our") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use RunStrict.

---

## 1. Information We Collect

### 1.1 Account Information
- Display name (username)
- Biological sex (used for community statistics)
- Date of birth (for age verification and statistics)
- Nationality (ISO country code, optional)
- Team affiliation (FLAME, WAVE, or CHAOS)
- Personal manifesto (up to 30 characters, optional, publicly visible)
- OAuth identity from Apple or Google (email, profile photo)

### 1.2 Location Data
- **GPS coordinates:** Collected continuously ONLY during active running sessions
- **Route path:** The sequence of H3 hexagonal coordinates you traverse during a run
- Accuracy readings and heading data (for anti-spoofing validation)
- **Home hex:** The general neighborhood area from which you typically run (city-level precision, H3 resolution 6, ~3.2km diameter)

### 1.3 Running Performance Data
- Distance, duration, and pace of each run
- Hex territories captured (flip count)
- Coefficient of Variation (CV) for pace consistency
- Buff multiplier applied to each run
- Flip points earned per run

### 1.4 Device Data
- Accelerometer readings (for anti-spoofing validation only; **not stored**)
- Device locale and timezone
- App version and platform

---

## 2. How We Use Your Information

We use your information to:

- Provide and operate the RunStrict game service
- Calculate your running performance, flip points, and leaderboard ranking
- Determine territory capture (hex flips) during runs
- Calculate team buff multipliers based on community performance
- Prevent cheating and maintain competitive fairness
- Improve the Service and develop new features
- Send in-app notifications about game events

---

## 3. Hex Territory Privacy

RunStrict is designed with privacy in mind regarding territory data:

- Hex records store **only** the last team color (e.g., "red", "blue") and a conflict-resolution timestamp
- Your personal runner ID is **never** stored in hex records
- Individual timestamps per hex are **not** attributed to specific users
- Other players can see which team controls a territory but **not** who specifically captured it or when
- Your home hex is stored at city-district level precision (H3 resolution 6, ~3.2km diameter) — not your exact address

---

## 4. Data Sharing and Disclosure

### 4.1 Public Information
The following is visible to other RunStrict users:
- Username, team, and manifesto
- Season flip points and ranking
- Total distance and pace statistics (aggregated)
- General neighborhood (home hex end location)

### 4.2 Third-Party Service Providers
We share data with:
- **Supabase:** Hosts our database. Your profile and run data is stored on Supabase infrastructure.
- **Mapbox:** Renders maps. Anonymized location data may be sent to Mapbox for tile rendering during map interactions.
- **Apple / Google:** Provide authentication. We receive only the minimum necessary identity information.

### 4.3 Legal Requirements
We may disclose your information if required by law or in response to valid legal process.

### 4.4 No Sale of Data
We do not sell, rent, or trade your personal information to third parties for their marketing purposes.

---

## 5. Data Retention

**5.1 Season Data.** Territory data (hexes) and season scores are permanently deleted at the end of each 40-day season ("The Void"). This is a core game mechanic.

**5.2 Run History.** Your personal running history (distance, pace, runs completed) is preserved across seasons — it is stored locally on your device and is never deleted by season resets. Server-side aggregate statistics are retained for the life of your account.

**5.3 Account Data.** Profile information is retained until you delete your account. Upon deletion, your personal data is removed from our servers within 30 days.

**5.4 Legal Holds.** We may retain certain data longer if required by applicable law.

---

## 6. Local Storage

RunStrict stores data locally on your device:
- **SQLite database:** Run history, lap records, route data, crash recovery checkpoints
- **JSON file:** Your cached user profile
- **App preferences:** Mute settings, app configuration

This data remains on your device and is not accessible to us unless you explicitly sync it. Uninstalling the app will delete this local data.

---

## 7. Children's Privacy

RunStrict is not directed to children under 13. We do not knowingly collect personal information from children under 13. If you are a parent or guardian and believe your child has provided us with personal information, please contact us at esther.runstrict@gmail.com. If we become aware that a child under 13 has provided personal information, we will delete it promptly.

---

## 8. Security

We implement industry-standard security measures including:

- Row-Level Security (RLS) on all database tables
- Authentication via established OAuth providers (Apple, Google)
- Encrypted data transmission (HTTPS/TLS)
- Server-side validation of all scoring data

No method of transmission or storage is 100% secure. We cannot guarantee absolute security of your information.

---

## 9. Your Rights

Depending on your jurisdiction, you may have rights to:

- **Access:** Request a copy of your personal data
- **Correction:** Request correction of inaccurate data
- **Deletion:** Request deletion of your account and associated data
- **Portability:** Request your data in a machine-readable format
- **Objection:** Object to certain processing of your data

To exercise these rights, contact us at esther.runstrict@gmail.com.

---

## 10. International Data Transfers

Your data may be processed and stored in countries other than your own. We use Supabase infrastructure which may store data in multiple regions. By using RunStrict, you consent to such transfers.

---

## 11. Changes to This Policy

We may update this Privacy Policy periodically. We will notify you of significant changes via the app. The "Effective Date" at the top of this document reflects the most recent revision.

---

## 12. Contact Us

If you have questions or concerns about this Privacy Policy or our data practices:

**Email:** esther.runstrict@gmail.com

RunStrict — *"Run. Conquer. Reset."*
