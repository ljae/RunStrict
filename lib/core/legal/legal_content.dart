/// Legal content for RunStrict — Terms of Service and Privacy Policy.
///
/// Version: 1.0
/// Effective date: 2026-03-01
/// Last updated: 2026-03-01

const String kLegalVersion = '1.0';
const String kLegalEffectiveDate = 'March 1, 2026';
const String kLegalContactEmail = 'esther.runstrict@gmail.com';
const String kLegalCompany = 'RunStrict';

// ---------------------------------------------------------------------------
// TERMS OF SERVICE
// ---------------------------------------------------------------------------

const String kTermsOfService =
    '''
TERMS OF SERVICE
Effective Date: $kLegalEffectiveDate
Version: $kLegalVersion

PLEASE READ THESE TERMS CAREFULLY BEFORE USING RUNSTRICT. BY CREATING AN ACCOUNT OR USING THE APP, YOU AGREE TO BE BOUND BY THESE TERMS.

────────────────────────────────────
1. ACCEPTANCE OF TERMS
────────────────────────────────────
These Terms of Service ("Terms") constitute a legally binding agreement between you ("User", "you") and $kLegalCompany ("Company", "we", "us") governing your use of the RunStrict mobile application and any related services (collectively, the "Service").

By tapping "I agree" and proceeding to create an account, you confirm that you have read, understood, and agree to these Terms and our Privacy Policy. If you do not agree, you may not use the Service.

────────────────────────────────────
2. ELIGIBILITY
────────────────────────────────────
You must be at least 13 years of age to use RunStrict. If you are between 13 and 18 years old, you must have the consent of a parent or legal guardian. By using the Service, you represent and warrant that you meet these requirements.

────────────────────────────────────
3. THE SERVICE
────────────────────────────────────
RunStrict is a location-based running game that gamifies territory control through hexagonal maps. The Service includes:

• Real-time GPS tracking during active running sessions
• Hexagonal territory ("hex") capture and team competition
• 40-day competitive seasons ("The Season")
• Team-based buff multipliers and scoring systems
• Leaderboards and community competition features

────────────────────────────────────
4. USER ACCOUNTS
────────────────────────────────────
4.1 Account Creation. You may create an account using Apple Sign-In or Google Sign-In. You are responsible for maintaining the confidentiality of your account credentials.

4.2 Runner Identity. Your chosen username, team affiliation, and public statistics (distance, pace, flip points, stability score) are visible to other users on leaderboards and within the app.

4.3 Team Selection. At the start of each season, you must choose a team: FLAME (Red) or WAVE (Blue). You may defect to CHAOS (Purple) at any time during the season. Defection to Purple is irreversible for the remainder of that season. Season points are preserved upon defection.

4.4 Guest Mode. You may use the Service as a guest for a single session without creating an account. Guest sessions are not preserved across app restarts. Guests may not appear on leaderboards.

4.5 Account Accuracy. You agree to provide accurate information including your sex and date of birth. This information is used for community statistics only and is not publicly displayed in identifiable form.

────────────────────────────────────
5. LOCATION SERVICES AND GPS
────────────────────────────────────
5.1 Required Permission. RunStrict requires access to your device's precise location (GPS) to function. The app tracks your location continuously during active running sessions to:
    • Record your route and calculate distance
    • Determine which hexagonal territories you pass through
    • Calculate flip points based on territories captured
    • Validate running pace and detect anti-spoofing

5.2 Scope of Tracking. Location tracking occurs ONLY during active runs that you explicitly start. The app does not track your location in the background when no run is active.

5.3 GPS Accuracy Requirements. For a territory flip to be counted, your GPS accuracy must be 50 meters or better. Inaccurate readings may result in missed territory captures.

5.4 Anti-Spoofing. Automated movement, GPS spoofing, emulator use, or any other method of faking physical activity is strictly prohibited and may result in account termination.

────────────────────────────────────
6. SEASONAL GAMEPLAY AND THE VOID
────────────────────────────────────
6.1 Season Duration. Each competitive season lasts exactly 40 days.

6.2 The Void (Season Reset). On Day 40 (the final day), ALL territory data, team hex counts, and season scores are permanently deleted. This is a core game mechanic. The following data is reset at season end:
    • All hex territory assignments
    • Season points for all users
    • Team rankings
    • Team assignments (users must re-select teams)

6.3 Data Preserved After Reset. Your personal running history (distance, runs, pace records) is permanently stored locally on your device and is never deleted by season resets.

6.4 Server-Verified Scoring. Flip points are calculated on your device and validated server-side. The server caps points at: hex_count × buff_multiplier. This validation exists to maintain fairness. Accepted risk: client-authoritative scoring; cap validation bounds maximum damage.

────────────────────────────────────
7. BUFF SYSTEM AND SCORING
────────────────────────────────────
7.1 Daily Buff Multipliers. Buff multipliers are calculated at midnight GMT+2 daily and apply to runs completed the following day. Multipliers depend on your team and competitive performance.

7.2 Flip Points. Points are calculated as: territories flipped × buff multiplier. A "flip" occurs when you enter a hex territory that previously belonged to a different team or was neutral.

7.3 No Guarantee of Points. Network failures, sync errors, or exceptional circumstances may result in points not being credited. We make no guarantee that all runs will be successfully synced.

────────────────────────────────────
8. ACCEPTABLE USE
────────────────────────────────────
You agree NOT to:
• Use GPS spoofing, emulators, or any device to simulate physical movement
• Exploit bugs or vulnerabilities to gain unfair advantage
• Create multiple accounts to manipulate leaderboards
• Harass, threaten, or abuse other users
• Reverse-engineer or decompile the application
• Use automated scripts or bots to interact with the Service
• Interfere with the integrity of the competitive systems

────────────────────────────────────
9. INTELLECTUAL PROPERTY
────────────────────────────────────
All content, features, and functionality of RunStrict — including game mechanics, visuals, trademarks, text, and code — are owned by $kLegalCompany and are protected by applicable intellectual property laws. You are granted a limited, non-exclusive, non-transferable license to use the Service for personal, non-commercial purposes.

────────────────────────────────────
10. THIRD-PARTY SERVICES
────────────────────────────────────
RunStrict uses the following third-party services:
• Supabase (database and authentication infrastructure)
• Mapbox (map rendering and geographic data)
• Apple Sign-In / Google Sign-In (authentication)
• H3 (Uber's hexagonal grid system)

Your use of these services is subject to their respective terms of service and privacy policies.

────────────────────────────────────
11. DISCLAIMERS AND LIABILITY
────────────────────────────────────
11.1 Physical Activity Risk. RunStrict encourages outdoor physical activity. You acknowledge that running and outdoor activities carry inherent risks including personal injury. You assume all risk associated with your physical activity.

11.2 "As Is" Service. The Service is provided "as is" and "as available" without warranty of any kind. We do not guarantee uninterrupted service, accuracy of GPS data, or preservation of any in-game progress.

11.3 Limitation of Liability. To the maximum extent permitted by applicable law, $kLegalCompany shall not be liable for any indirect, incidental, special, consequential, or punitive damages, or any loss of profits, data, or goodwill.

────────────────────────────────────
12. TERMINATION
────────────────────────────────────
We reserve the right to suspend or terminate your account at any time for violation of these Terms, without notice. You may delete your account at any time from within the app. Upon account deletion, your profile data is removed from our servers; locally stored run history on your device is not affected.

────────────────────────────────────
13. CHANGES TO TERMS
────────────────────────────────────
We may update these Terms from time to time. We will notify you of material changes via the app. Continued use of the Service after the effective date of revised Terms constitutes acceptance of the new Terms.

────────────────────────────────────
14. GOVERNING LAW
────────────────────────────────────
These Terms shall be governed by and construed in accordance with applicable laws. Any disputes shall be resolved through binding arbitration, except where prohibited by law.

────────────────────────────────────
15. CONTACT
────────────────────────────────────
For questions about these Terms, contact us at:
$kLegalContactEmail

$kLegalCompany
"Run. Conquer. Reset."
''';

// ---------------------------------------------------------------------------
// PRIVACY POLICY
// ---------------------------------------------------------------------------

const String kPrivacyPolicy =
    '''
PRIVACY POLICY
Effective Date: $kLegalEffectiveDate
Version: $kLegalVersion

$kLegalCompany ("we", "us", "our") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use RunStrict.

────────────────────────────────────
1. INFORMATION WE COLLECT
────────────────────────────────────
1.1 Account Information
    • Display name (username)
    • Biological sex (used for community statistics)
    • Date of birth (for age verification and statistics)
    • Nationality (ISO country code, optional)
    • Team affiliation (FLAME, WAVE, or CHAOS)
    • Personal manifesto (up to 30 characters, optional, publicly visible)
    • OAuth identity from Apple or Google (email, profile photo)

1.2 Location Data
    • GPS coordinates: Collected continuously ONLY during active running sessions
    • Route path: The sequence of H3 hexagonal coordinates you traverse during a run
    • Accuracy readings and heading data (for anti-spoofing validation)
    • Home hex: The general neighborhood area from which you typically run (city-level precision, H3 resolution 6)

1.3 Running Performance Data
    • Distance, duration, and pace of each run
    • Hex territories captured (flip count)
    • Coefficient of Variation (CV) for pace consistency
    • Buff multiplier applied to each run
    • Flip points earned per run

1.4 Device Data
    • Accelerometer readings (for anti-spoofing validation only; not stored)
    • Device locale and timezone
    • App version and platform

────────────────────────────────────
2. HOW WE USE YOUR INFORMATION
────────────────────────────────────
We use your information to:
    • Provide and operate the RunStrict game service
    • Calculate your running performance, flip points, and leaderboard ranking
    • Determine territory capture (hex flips) during runs
    • Calculate team buff multipliers based on community performance
    • Prevent cheating and maintain competitive fairness
    • Improve the Service and develop new features
    • Send in-app notifications about game events

────────────────────────────────────
3. HEX TERRITORY PRIVACY
────────────────────────────────────
RunStrict is designed with privacy in mind regarding territory data:

    • Hex records store ONLY the last team color (e.g., "red", "blue") and a conflict-resolution timestamp
    • Your personal runner ID is NEVER stored in hex records
    • Individual timestamps per hex are NOT attributed to specific users
    • Other players can see which team controls a territory but NOT who specifically captured it or when
    • Your home hex is stored at city-district level precision (H3 resolution 6, ~3.2km diameter) — not your exact address

────────────────────────────────────
4. DATA SHARING AND DISCLOSURE
────────────────────────────────────
4.1 Public Information. The following is visible to other RunStrict users:
    • Username, team, and manifesto
    • Season flip points and ranking
    • Total distance and pace statistics (aggregated)
    • General neighborhood (home hex end location)

4.2 Third-Party Service Providers. We share data with:
    • Supabase: Hosts our database. Your profile and run data is stored on Supabase infrastructure.
    • Mapbox: Renders maps. Anonymized location data may be sent to Mapbox for tile rendering during map interactions.
    • Apple / Google: Provide authentication. We receive only the minimum necessary identity information.

4.3 Legal Requirements. We may disclose your information if required by law or in response to valid legal process.

4.4 No Sale of Data. We do not sell, rent, or trade your personal information to third parties for their marketing purposes.

────────────────────────────────────
5. DATA RETENTION
────────────────────────────────────
5.1 Season Data. Territory data (hexes) and season scores are permanently deleted at the end of each 40-day season ("The Void"). This is a core game mechanic.

5.2 Run History. Your personal running history (distance, pace, runs completed) is preserved across seasons — it is stored locally on your device and is never deleted by season resets. Server-side aggregate statistics are retained for the life of your account.

5.3 Account Data. Profile information is retained until you delete your account. Upon deletion, your personal data is removed from our servers within 30 days.

5.4 Legal Holds. We may retain certain data longer if required by applicable law.

────────────────────────────────────
6. LOCAL STORAGE
────────────────────────────────────
RunStrict stores data locally on your device:
    • SQLite database: Run history, lap records, route data, crash recovery checkpoints
    • JSON file: Your cached user profile
    • App preferences: Mute settings, app configuration

This data remains on your device and is not accessible to us unless you explicitly sync it. Uninstalling the app will delete this local data.

────────────────────────────────────
7. CHILDREN'S PRIVACY
────────────────────────────────────
RunStrict is not directed to children under 13. We do not knowingly collect personal information from children under 13. If you are a parent or guardian and believe your child has provided us with personal information, please contact us at $kLegalContactEmail. If we become aware that a child under 13 has provided personal information, we will delete it promptly.

────────────────────────────────────
8. SECURITY
────────────────────────────────────
We implement industry-standard security measures including:
    • Row-Level Security (RLS) on all database tables
    • Authentication via established OAuth providers (Apple, Google)
    • Encrypted data transmission (HTTPS/TLS)
    • Server-side validation of all scoring data

No method of transmission or storage is 100% secure. We cannot guarantee absolute security of your information.

────────────────────────────────────
9. YOUR RIGHTS
────────────────────────────────────
Depending on your jurisdiction, you may have rights to:
    • Access: Request a copy of your personal data
    • Correction: Request correction of inaccurate data
    • Deletion: Request deletion of your account and associated data
    • Portability: Request your data in a machine-readable format
    • Objection: Object to certain processing of your data

To exercise these rights, contact us at $kLegalContactEmail.

────────────────────────────────────
10. INTERNATIONAL DATA TRANSFERS
────────────────────────────────────
Your data may be processed and stored in countries other than your own. We use Supabase infrastructure which may store data in multiple regions. By using RunStrict, you consent to such transfers.

────────────────────────────────────
11. CHANGES TO THIS POLICY
────────────────────────────────────
We may update this Privacy Policy periodically. We will notify you of significant changes via the app. The "Last Updated" date at the top of this document reflects the most recent revision.

────────────────────────────────────
12. CONTACT US
────────────────────────────────────
If you have questions or concerns about this Privacy Policy or our data practices:

Email: $kLegalContactEmail

$kLegalCompany
"Run. Conquer. Reset."
''';
