import 'package:flutter/foundation.dart';

class RevenueCatConfig {
  // Production: set via --dart-define=REVENUECAT_API_KEY=...
  // Development: falls back to sandbox key below.
  static const String apiKey = String.fromEnvironment(
    'REVENUECAT_API_KEY',
    defaultValue: 'test_wuQqIhVMWueLVWVtXQZYYRmQCnX',
  );
  static const String proEntitlementId = 'RunStrict Pro';

  /// Call once at startup (debug builds only) to catch accidental submission
  /// with the sandbox test key instead of a real production API key.
  static void assertProductionKey() {
    assert(
      !kDebugMode || apiKey != 'test_wuQqIhVMWueLVWVtXQZYYRmQCnX',
      'RevenueCat is using the hardcoded test key. '
      'Pass --dart-define=REVENUECAT_API_KEY=<your_key> for production builds.',
    );
  }
}
