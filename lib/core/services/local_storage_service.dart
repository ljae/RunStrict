import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class LocalStorageService {
  static const String _fileName = 'user_location.json';

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/$_fileName');
  }

  Future<void> saveLastLocation(double lat, double lng) async {
    try {
      final file = await _localFile;
      final data = jsonEncode({
        'latitude': lat,
        'longitude': lng,
        'timestamp': DateTime.now().toIso8601String(),
      });
      await file.writeAsString(data);
    } catch (e) {
      debugPrint('Error saving location: $e');
    }
  }

  Future<Map<String, double>?> getLastLocation() async {
    try {
      final file = await _localFile;
      if (!await file.exists()) return null;

      final contents = await file.readAsString();
      if (contents.isEmpty) return null;

      final data = jsonDecode(contents);

      return {
        'latitude': data['latitude'] as double,
        'longitude': data['longitude'] as double,
      };
    } catch (e) {
      debugPrint('Error reading location: $e');
      return null;
    }
  }
}
