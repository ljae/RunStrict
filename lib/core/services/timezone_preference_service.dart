import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

enum DisplayTimezone { local, gmt2 }

/// Singleton service for persisting timezone display preference.
/// Follows VoiceAnnouncementService pattern (file-based JSON with path_provider).
class TimezonePreferenceService {
  static final TimezonePreferenceService _instance =
      TimezonePreferenceService._internal();
  factory TimezonePreferenceService() => _instance;
  TimezonePreferenceService._internal();

  DisplayTimezone _timezone = DisplayTimezone.local;
  bool _loaded = false;

  DisplayTimezone get timezone => _timezone;
  bool get isGmt2 => _timezone == DisplayTimezone.gmt2;

  Future<File> get _settingsFile async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/timezone_preference.json');
  }

  /// Load persisted preference. Safe to call multiple times.
  Future<DisplayTimezone> load() async {
    if (_loaded) return _timezone;
    try {
      final file = await _settingsFile;
      if (await file.exists()) {
        final data = jsonDecode(await file.readAsString());
        if (data['timezone'] == 'gmt2') {
          _timezone = DisplayTimezone.gmt2;
        }
      }
    } catch (e) {
      debugPrint('TimezonePreferenceService: failed to load - $e');
    }
    _loaded = true;
    return _timezone;
  }

  /// Toggle between local and GMT+2. Returns the new value.
  Future<DisplayTimezone> toggle() async {
    _timezone = _timezone == DisplayTimezone.local
        ? DisplayTimezone.gmt2
        : DisplayTimezone.local;
    try {
      final file = await _settingsFile;
      await file.writeAsString(jsonEncode({
        'timezone': _timezone == DisplayTimezone.gmt2 ? 'gmt2' : 'local',
      }));
    } catch (e) {
      debugPrint('TimezonePreferenceService: failed to save - $e');
    }
    return _timezone;
  }
}
