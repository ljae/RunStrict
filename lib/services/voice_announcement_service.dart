import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';

/// Singleton TTS service for voice announcements during runs.
class VoiceAnnouncementService {
  static final VoiceAnnouncementService _instance =
      VoiceAnnouncementService._internal();
  factory VoiceAnnouncementService() => _instance;
  VoiceAnnouncementService._internal();

  FlutterTts? _tts;
  bool _initialized = false;
  bool _muted = false;

  bool get isMuted => _muted;

  /// Initialize TTS engine with language and rate settings.
  Future<void> initialize() async {
    if (_initialized) return;

    await _loadMuteState();

    _tts = FlutterTts();
    await _tts!.setLanguage('en-US');
    await _tts!.setSpeechRate(0.55);
    await _tts!.setVolume(1.0);

    _initialized = true;
    debugPrint('VoiceAnnouncementService: initialized (muted=$_muted)');
  }

  /// Toggle mute on/off. Returns the new muted state.
  Future<bool> toggleMute() async {
    _muted = !_muted;
    await _saveMuteState();
    if (_muted && _initialized) {
      await _tts!.stop();
    }
    debugPrint('VoiceAnnouncementService: muted=$_muted');
    return _muted;
  }

  Future<File> get _settingsFile async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/voice_settings.json');
  }

  Future<void> _loadMuteState() async {
    try {
      final file = await _settingsFile;
      if (await file.exists()) {
        final data = jsonDecode(await file.readAsString());
        _muted = data['muted'] == true;
      }
    } catch (e) {
      debugPrint('VoiceAnnouncementService: failed to load mute state - $e');
    }
  }

  Future<void> _saveMuteState() async {
    try {
      final file = await _settingsFile;
      await file.writeAsString(jsonEncode({'muted': _muted}));
    } catch (e) {
      debugPrint('VoiceAnnouncementService: failed to save mute state - $e');
    }
  }

  /// Announce a hex capture ("Territory captured").
  Future<void> announceFlip() async {
    if (!_initialized || _muted) return;
    await _tts!.speak('Territory captured');
  }

  /// Announce run start ("Run started. Let's go!").
  Future<void> announceRunStart() async {
    if (!_initialized || _muted) return;
    await _tts!.speak("Run started. Let's go!");
  }

  /// Announce a same-team hex ("Friendly zone").
  Future<void> announceFlipFailed() async {
    if (!_initialized || _muted) return;
    await _tts!.speak('Friendly zone');
  }

  /// Announce a kilometer milestone with pace.
  ///
  /// [km] — lap number (e.g. 3)
  /// [paceSecPerKm] — pace in seconds per km (e.g. 330.0 for 5:30)
  Future<void> announceKilometer(int km, double paceSecPerKm) async {
    if (!_initialized || _muted) return;

    final paceMinutes = (paceSecPerKm / 60).floor();
    final paceSeconds = (paceSecPerKm % 60).round();

    final kmWord = km == 1 ? 'kilometer' : 'kilometers';
    final secWord = paceSeconds == 1 ? 'second' : 'seconds';
    final minWord = paceMinutes == 1 ? 'minute' : 'minutes';

    final phrase =
        '$km $kmWord. Pace, $paceMinutes $minWord $paceSeconds $secWord';
    await _tts!.speak(phrase);
  }

  /// Stop and clean up TTS resources.
  Future<void> dispose() async {
    if (!_initialized) return;
    await _tts!.stop();
    _initialized = false;
    debugPrint('VoiceAnnouncementService: disposed');
  }
}
