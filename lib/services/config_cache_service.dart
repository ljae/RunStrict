import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import '../models/app_config.dart';

class ConfigCacheService {
  static const String _fileName = 'config_cache.json';

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/$_fileName');
  }

  Future<void> saveConfig(AppConfig config) async {
    try {
      final file = await _localFile;
      final data = jsonEncode({
        'config': config.toJson(),
        'cachedAt': DateTime.now().toIso8601String(),
      });
      await file.writeAsString(data);
      debugPrint(
        'ConfigCacheService: Saved config version ${config.configVersion}',
      );
    } catch (e) {
      debugPrint('ConfigCacheService: Error saving config - $e');
    }
  }

  Future<AppConfig?> loadConfig() async {
    try {
      final file = await _localFile;
      if (!await file.exists()) {
        debugPrint('ConfigCacheService: No cache file found');
        return null;
      }

      final contents = await file.readAsString();
      final data = jsonDecode(contents) as Map<String, dynamic>;
      final configJson = data['config'] as Map<String, dynamic>?;

      if (configJson == null) {
        debugPrint('ConfigCacheService: Cache file corrupt - no config key');
        return null;
      }

      final config = AppConfig.fromJson(configJson);
      debugPrint(
        'ConfigCacheService: Loaded cached config version ${config.configVersion}',
      );
      return config;
    } catch (e) {
      debugPrint('ConfigCacheService: Error loading config - $e');
      return null;
    }
  }

  Future<void> clearCache() async {
    try {
      final file = await _localFile;
      if (await file.exists()) {
        await file.delete();
        debugPrint('ConfigCacheService: Cache cleared');
      }
    } catch (e) {
      debugPrint('ConfigCacheService: Error clearing cache - $e');
    }
  }

  Future<Duration?> getCacheAge() async {
    try {
      final file = await _localFile;
      if (!await file.exists()) return null;

      final contents = await file.readAsString();
      final data = jsonDecode(contents) as Map<String, dynamic>;
      final cachedAtStr = data['cachedAt'] as String?;

      if (cachedAtStr == null) return null;

      final cachedAt = DateTime.parse(cachedAtStr);
      return DateTime.now().difference(cachedAt);
    } catch (e) {
      debugPrint('ConfigCacheService: Error getting cache age - $e');
      return null;
    }
  }
}
