import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Singleton service for managing Google AdMob ads.
///
/// Handles initialization and provides ad unit IDs.
/// Uses test ad unit IDs by default — replace with real IDs for production.
class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  bool _initialized = false;

  /// Test banner ad unit IDs from Google (safe for development).
  /// Replace these with your real ad unit IDs before releasing.
  static String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/6300978111'; // Android test banner
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/2934735716'; // iOS test banner
    }
    throw UnsupportedError('Unsupported platform');
  }

  /// Initialize the Mobile Ads SDK. Call once at app startup.
  Future<void> initialize() async {
    if (_initialized) return;
    await MobileAds.instance.initialize();
    _initialized = true;
    debugPrint('AdService: MobileAds SDK initialized');
  }
}
