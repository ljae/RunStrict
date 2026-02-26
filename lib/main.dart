import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'app/app.dart';
import 'theme/app_theme.dart';
import 'core/config/mapbox_config.dart';
import 'core/services/hex_service.dart';
import 'core/services/supabase_service.dart';
import 'core/services/remote_config_service.dart';
import 'core/services/ad_service.dart';
import 'core/services/purchases_service.dart';
import 'core/storage/local_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global error handlers
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exception}');
    debugPrint('Stack trace: ${details.stack}');
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('PlatformDispatcher error: $error');
    debugPrint('Stack trace: $stack');
    return true;
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundStart,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'Something went wrong',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  };

  // Initialize Supabase
  await SupabaseService.initialize();

  // Initialize RemoteConfig (fallback chain: server → cache → defaults)
  await RemoteConfigService().initialize();

  // Initialize HexService
  await HexService().initialize();

  // Initialize LocalStorage for run history persistence
  final localStorage = LocalStorage();
  await localStorage.initialize();

  // Initialize AdMob SDK
  await AdService().initialize();

  // Initialize RevenueCat SDK
  await PurchasesService().initialize();

  // Set Mapbox access token
  MapboxOptions.setAccessToken(MapboxConfig.accessToken);

  // Set system UI overlay style for premium dark theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.backgroundStart,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const ProviderScope(child: RunStrictApp()));
}
