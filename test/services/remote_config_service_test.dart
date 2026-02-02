import 'package:flutter_test/flutter_test.dart';
import 'package:runner/models/app_config.dart';
import 'package:runner/services/remote_config_service.dart';

void main() {
  group('RemoteConfigService', () {
    late RemoteConfigService service;

    setUp(() {
      service = RemoteConfigService();
      service.reset();
    });

    test('returns defaults when not initialized', () {
      final config = service.config;
      expect(config.configVersion, equals(1));
      expect(config.seasonConfig.durationDays, equals(40));
      expect(config.gpsConfig.maxSpeedMps, equals(6.94));
    });

    test('isInitialized is false before initialize()', () {
      expect(service.isInitialized, isFalse);
    });

    test('configSnapshot returns frozen config when frozen', () {
      service.reset();

      final defaultConfig = AppConfig.defaults();
      expect(
        service.configSnapshot.configVersion,
        equals(defaultConfig.configVersion),
      );

      service.freezeForRun();
      expect(service.configSnapshot, isNotNull);

      service.unfreezeAfterRun();
    });

    test('freezeForRun and unfreezeAfterRun work correctly', () {
      service.freezeForRun();
      final frozenSnapshot = service.configSnapshot;
      expect(frozenSnapshot, isNotNull);

      service.unfreezeAfterRun();
      final unfrozenSnapshot = service.configSnapshot;
      expect(unfrozenSnapshot, isNotNull);
    });

    test('AppConfig.defaults() has all expected values', () {
      final defaults = AppConfig.defaults();

      expect(defaults.seasonConfig.durationDays, equals(40));
      expect(defaults.seasonConfig.serverTimezoneOffsetHours, equals(2));

      expect(defaults.gpsConfig.maxSpeedMps, equals(6.94));
      expect(defaults.gpsConfig.maxAccuracyMeters, equals(50.0));
      expect(defaults.gpsConfig.maxCapturePaceMinPerKm, equals(8.0));
      expect(defaults.gpsConfig.pollingRateHz, equals(0.5));

      expect(defaults.hexConfig.baseResolution, equals(9));
      expect(defaults.hexConfig.maxCacheSize, equals(4000));

      expect(defaults.timingConfig.accelerometerSamplingPeriodMs, equals(200));
      expect(defaults.timingConfig.refreshThrottleSeconds, equals(30));
    });

    test('AppConfig.fromJson handles partial data gracefully', () {
      final partialJson = {
        'configVersion': 2,
        'seasonConfig': {'durationDays': 365},
      };

      final config = AppConfig.fromJson(partialJson);

      expect(config.configVersion, equals(2));
      expect(config.seasonConfig.durationDays, equals(365));
      expect(config.seasonConfig.serverTimezoneOffsetHours, equals(2));
      expect(config.gpsConfig.maxSpeedMps, equals(6.94));
    });

    test('AppConfig.toJson and fromJson round-trip correctly', () {
      final original = AppConfig.defaults();
      final json = original.toJson();
      final restored = AppConfig.fromJson(json);

      expect(restored.configVersion, equals(original.configVersion));
      expect(
        restored.seasonConfig.durationDays,
        equals(original.seasonConfig.durationDays),
      );
      expect(
        restored.gpsConfig.maxSpeedMps,
        equals(original.gpsConfig.maxSpeedMps),
      );
      expect(
        restored.hexConfig.baseResolution,
        equals(original.hexConfig.baseResolution),
      );
    });
  });
}
