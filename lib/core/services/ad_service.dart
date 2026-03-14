import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';

/// Singleton service for managing Google AdMob ads.
///
/// Initialization order (mandatory for iOS 14+ App Store compliance):
///   1. [_requestTrackingAuthorization] — shows ATT prompt if needed.
///   2. [MobileAds.instance.initialize] — initializes AdMob SDK.
///
/// ATT authorization is requested once per install. AdMob serves personalized
/// ads when authorized and non-personalized ads otherwise. The app works
/// correctly either way.
class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  bool _initialized = false;

  /// Production banner ad unit IDs.
  /// iOS: ca-app-pub-5211646950805880 (production)
  /// Android: ca-app-pub-5211646950805880 (production)
  static String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-5211646950805880/4698345485'; // Android production banner
    } else if (Platform.isIOS) {
      return 'ca-app-pub-5211646950805880/8533648712'; // iOS production banner
    }
    throw UnsupportedError('Unsupported platform');
  }

  /// Initialize the Mobile Ads SDK.
  ///
  /// On iOS 14+: requests App Tracking Transparency authorization first, then
  /// initializes AdMob. AdMob serves non-personalized ads if the user declines
  /// or if the system has not yet shown the prompt.
  ///
  /// Call once at app startup (before any ad is loaded).
  Future<void> initialize() async {
    if (_initialized) return;

    if (Platform.isIOS) {
      await _requestTrackingAuthorization();
    }

    await MobileAds.instance.initialize();
    _initialized = true;
    debugPrint('AdService: MobileAds SDK initialized');
  }

  /// Requests App Tracking Transparency authorization on iOS 14+.
  ///
  /// - If status is [TrackingStatus.notDetermined], shows the system ATT dialog.
  /// - If already determined (authorized / denied / restricted), returns immediately.
  /// - On failure, continues silently — AdMob serves non-personalized ads.
  Future<void> _requestTrackingAuthorization() async {
    try {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;

      if (status == TrackingStatus.notDetermined) {
        // Brief delay so the ATT dialog appears after the app's UI is ready
        // (avoids the dialog appearing before the root widget is rendered).
        await Future<void>.delayed(const Duration(milliseconds: 300));
        final result =
            await AppTrackingTransparency.requestTrackingAuthorization();
        debugPrint('AdService: ATT authorization result — $result');
      } else {
        debugPrint('AdService: ATT status already determined — $status');
      }
    } catch (e) {
      // ATT is unavailable (e.g., iOS Simulator, older OS). Continue without it.
      debugPrint('AdService: ATT request skipped — $e');
    }
  }
}
