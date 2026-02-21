import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../config/revenuecat_config.dart';

/// Singleton service wrapping the RevenueCat SDK.
///
/// Handles initialization, identity sync, entitlement checks, and purchases.
/// Falls back to debug mode when no real store app is configured in RevenueCat.
class PurchasesService {
  static final PurchasesService _instance = PurchasesService._internal();
  factory PurchasesService() => _instance;
  PurchasesService._internal();

  bool _initialized = false;

  /// Whether the user has the "RunStrict Pro" entitlement.
  bool _isPro = false;
  bool get isPro => _isPro;

  /// Whether real store products are available.
  /// False when only a RevenueCat Test Store app exists (no iOS/Android app registered).
  bool _hasStoreProducts = false;
  bool get hasStoreProducts => _hasStoreProducts;

  /// Initialize the RevenueCat SDK. Call once at app startup.
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      await Purchases.configure(
        PurchasesConfiguration(RevenueCatConfig.apiKey),
      );
      _initialized = true;
      debugPrint('PurchasesService: RevenueCat SDK initialized');
    } catch (e) {
      debugPrint('PurchasesService: SDK init failed - $e');
      // Continue without SDK — debug mode will handle purchases
    }
  }

  /// Sync RevenueCat identity with an authenticated user.
  Future<void> login(String userId) async {
    if (!_initialized) return;

    try {
      final result = await Purchases.logIn(userId);
      _isPro = result.customerInfo.entitlements.active
          .containsKey(RevenueCatConfig.proEntitlementId);
      debugPrint('PurchasesService: Logged in as $userId (pro=$_isPro)');
    } catch (e) {
      debugPrint('PurchasesService: Login failed - $e');
    }
  }

  /// Clear RevenueCat identity on sign-out.
  Future<void> logout() async {
    if (!_initialized) {
      _isPro = false;
      return;
    }

    try {
      await Purchases.logOut();
      _isPro = false;
      debugPrint('PurchasesService: Logged out');
    } catch (e) {
      debugPrint('PurchasesService: Logout failed - $e');
      _isPro = false;
    }
  }

  /// Refresh pro status from the server.
  Future<bool> refreshProStatus() async {
    if (!_initialized) return _isPro;

    try {
      final customerInfo = await Purchases.getCustomerInfo();
      _isPro = customerInfo.entitlements.active
          .containsKey(RevenueCatConfig.proEntitlementId);
      debugPrint('PurchasesService: Pro status refreshed (pro=$_isPro)');
      return _isPro;
    } catch (e) {
      debugPrint('PurchasesService: Failed to refresh pro status - $e');
      return _isPro;
    }
  }

  /// Fetch available offerings (packages for purchase UI).
  /// Returns null if SDK not initialized or fetch fails.
  Future<Offerings?> getOfferings() async {
    if (!_initialized) return null;

    try {
      final offerings = await Purchases.getOfferings();
      final current = offerings.current;
      _hasStoreProducts = current != null && current.availablePackages.isNotEmpty;
      if (!_hasStoreProducts) {
        debugPrint(
          'PurchasesService: No store products available. '
          'Register an iOS/Android app in RevenueCat dashboard '
          'and configure store products.',
        );
      }
      return offerings;
    } catch (e) {
      debugPrint('PurchasesService: Failed to get offerings - $e');
      return null;
    }
  }

  /// Execute a purchase for a given package.
  /// Returns true if the user now has pro entitlement.
  Future<bool> purchasePackage(Package package) async {
    if (!_initialized) return false;

    try {
      final result = await Purchases.purchasePackage(package);
      _isPro = result.entitlements.active
          .containsKey(RevenueCatConfig.proEntitlementId);
      debugPrint('PurchasesService: Purchase complete (pro=$_isPro)');
      return _isPro;
    } catch (e) {
      debugPrint('PurchasesService: Purchase failed - $e');
      return false;
    }
  }

  /// Restore purchases for reinstalls or cross-device.
  /// Returns true if the user now has pro entitlement.
  Future<bool> restorePurchases() async {
    if (!_initialized) return false;

    try {
      final customerInfo = await Purchases.restorePurchases();
      _isPro = customerInfo.entitlements.active
          .containsKey(RevenueCatConfig.proEntitlementId);
      debugPrint('PurchasesService: Restore complete (pro=$_isPro)');
      return _isPro;
    } catch (e) {
      debugPrint('PurchasesService: Restore failed - $e');
      return false;
    }
  }

  /// Debug-only: Toggle pro status without a real purchase.
  /// Only available in debug builds.
  void debugTogglePro() {
    assert(() {
      _isPro = !_isPro;
      debugPrint('PurchasesService: [DEBUG] Pro toggled to $_isPro');
      return true;
    }());
  }
}
