import '../services/remote_config_service.dart';

class Gmt2DateUtils {
  static int get _offsetHours =>
      RemoteConfigService().config.seasonConfig.serverTimezoneOffsetHours;

  static DateTime get todayGmt2 {
    final utcNow = DateTime.now().toUtc();
    final gmt2Now = utcNow.add(Duration(hours: _offsetHours));
    return DateTime(gmt2Now.year, gmt2Now.month, gmt2Now.day);
  }

  static String get todayGmt2String {
    final today = todayGmt2;
    return '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
  }

  static bool isTodayGmt2(DateTime utcDateTime) {
    final gmt2Time = utcDateTime.toUtc().add(Duration(hours: _offsetHours));
    final gmt2Date = DateTime(gmt2Time.year, gmt2Time.month, gmt2Time.day);
    return gmt2Date == todayGmt2;
  }

  static DateTime toGmt2Date(DateTime utcDateTime) {
    final gmt2Time = utcDateTime.toUtc().add(Duration(hours: _offsetHours));
    return DateTime(gmt2Time.year, gmt2Time.month, gmt2Time.day);
  }

  static String toGmt2DateString(DateTime utcDateTime) {
    final gmt2Date = toGmt2Date(utcDateTime);
    return '${gmt2Date.year}-${gmt2Date.month.toString().padLeft(2, '0')}-${gmt2Date.day.toString().padLeft(2, '0')}';
  }
}
