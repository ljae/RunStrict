import 'package:flutter/foundation.dart';
import 'supabase_service.dart';
import '../models/app_config.dart';
import 'remote_config_service.dart';

class BuffBreakdown {
  final int multiplier;
  final int baseBuff;
  final int allRangeBonus;
  final int districtBonus;
  final int provinceBonus;
  final String reason;
  final String team;
  final String? cityHex;
  final String? districtHex;
  final bool isCityLeader;
  final bool hasDistrictWin;
  final bool hasProvinceWin;
  final bool isElite;
  final int eliteThreshold;
  final int yesterdayPoints;

  const BuffBreakdown({
    required this.multiplier,
    required this.baseBuff,
    required this.allRangeBonus,
    this.districtBonus = 0,
    this.provinceBonus = 0,
    required this.reason,
    required this.team,
    this.cityHex,
    this.districtHex,
    this.isCityLeader = false,
    this.hasDistrictWin = false,
    this.hasProvinceWin = false,
    this.isElite = false,
    this.eliteThreshold = 0,
    this.yesterdayPoints = 0,
  });

  factory BuffBreakdown.fromJson(Map<String, dynamic> json) => BuffBreakdown(
    multiplier: (json['multiplier'] as num?)?.toInt() ?? 1,
    baseBuff: (json['base_buff'] as num?)?.toInt() ?? 1,
    allRangeBonus: (json['all_range_bonus'] as num?)?.toInt() ?? 0,
    districtBonus: (json['district_bonus'] as num?)?.toInt() ?? 0,
    provinceBonus: (json['province_bonus'] as num?)?.toInt() ?? 0,
    reason: json['reason'] as String? ?? 'Unknown',
    team: json['team'] as String? ?? '',
    cityHex: json['city_hex'] as String?,
    districtHex: json['district_hex'] as String?,
    isCityLeader: json['is_city_leader'] as bool? ?? false,
    hasDistrictWin: json['has_district_win'] as bool? ?? false,
    hasProvinceWin: json['has_province_win'] as bool? ?? false,
    isElite: json['is_elite'] as bool? ?? false,
    eliteThreshold: (json['elite_threshold'] as num?)?.toInt() ?? 0,
    yesterdayPoints: (json['yesterday_points'] as num?)?.toInt() ?? 0,
  );

  factory BuffBreakdown.defaultBuff() => const BuffBreakdown(
    multiplier: 1,
    baseBuff: 1,
    allRangeBonus: 0,
    reason: 'Default',
    team: '',
  );
}

class BuffService with ChangeNotifier {
  static final BuffService _instance = BuffService._internal();
  factory BuffService() => _instance;
  BuffService._internal();

  final SupabaseService _supabaseService = SupabaseService();

  int _multiplier = 1;
  int? _frozenMultiplier;
  BuffBreakdown _breakdown = BuffBreakdown.defaultBuff();
  bool _isLoading = false;
  bool _isFrozen = false;

  int get multiplier => _frozenMultiplier ?? _multiplier;

  BuffBreakdown get breakdown => _breakdown;

  bool get isLoading => _isLoading;

  bool get isFrozen => _isFrozen;

  BuffConfig get _config => RemoteConfigService().config.buffConfig;

  Future<void> loadBuff(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _supabaseService.getUserBuff(userId);
      _breakdown = BuffBreakdown.fromJson(result);
      _multiplier = _breakdown.multiplier;
    } catch (e) {
      debugPrint('Error loading user buff: $e');
      _multiplier = 1;
      _breakdown = BuffBreakdown.defaultBuff();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setBuffFromLaunchSync(Map<String, dynamic>? userBuff) {
    if (userBuff == null) {
      _multiplier = 1;
      _breakdown = BuffBreakdown.defaultBuff();
    } else {
      _breakdown = BuffBreakdown.fromJson(userBuff);
      _multiplier = _breakdown.multiplier;
    }
    notifyListeners();
  }

  void freezeForRun() {
    _frozenMultiplier = _multiplier;
    _isFrozen = true;
    debugPrint('BuffService: Frozen at ${_frozenMultiplier}x');
  }

  void unfreezeAfterRun() {
    _frozenMultiplier = null;
    _isFrozen = false;
    debugPrint('BuffService: Unfrozen');
    notifyListeners();
  }

  Future<void> refresh(String userId) async {
    await loadBuff(userId);
  }

  void reset() {
    _multiplier = 1;
    _frozenMultiplier = null;
    _breakdown = BuffBreakdown.defaultBuff();
    _isLoading = false;
    _isFrozen = false;
    notifyListeners();
  }

  int getEffectiveMultiplier() {
    return multiplier > 0 ? multiplier : 1;
  }
}
