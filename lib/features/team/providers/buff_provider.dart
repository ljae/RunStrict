import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/app_config.dart';
import '../../../core/services/buff_service.dart';
import '../../../core/services/remote_config_service.dart';
import '../../../core/services/supabase_service.dart';

class BuffState {
  final int multiplier;
  final int? frozenMultiplier;
  final BuffBreakdown breakdown;
  final bool isLoading;
  final bool isFrozen;

  const BuffState({
    this.multiplier = 1,
    this.frozenMultiplier,
    this.breakdown = const BuffBreakdown(
      multiplier: 1,
      baseBuff: 1,
      allRangeBonus: 0,
      reason: 'Default',
      team: '',
    ),
    this.isLoading = false,
    this.isFrozen = false,
  });

  int get effectiveMultiplier {
    final m = frozenMultiplier ?? multiplier;
    return m > 0 ? m : 1;
  }

  BuffState copyWith({
    int? multiplier,
    int? Function()? frozenMultiplier,
    BuffBreakdown? breakdown,
    bool? isLoading,
    bool? isFrozen,
  }) {
    return BuffState(
      multiplier: multiplier ?? this.multiplier,
      frozenMultiplier: frozenMultiplier != null ? frozenMultiplier() : this.frozenMultiplier,
      breakdown: breakdown ?? this.breakdown,
      isLoading: isLoading ?? this.isLoading,
      isFrozen: isFrozen ?? this.isFrozen,
    );
  }
}

class BuffNotifier extends Notifier<BuffState> {
  @override
  BuffState build() => const BuffState();

  BuffConfig get _config => RemoteConfigService().config.buffConfig;

  Future<void> loadBuff(String userId, {String? districtHex}) async {
    state = state.copyWith(isLoading: true);

    try {
      final result = await SupabaseService().getUserBuff(
        userId,
        districtHex: districtHex,
      );
      final breakdown = BuffBreakdown.fromJson(result);
      state = state.copyWith(
        multiplier: breakdown.multiplier,
        breakdown: breakdown,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('Error loading user buff: $e');
      state = state.copyWith(
        multiplier: 1,
        breakdown: BuffBreakdown.defaultBuff(),
        isLoading: false,
      );
    }
  }

  void setBuffFromLaunchSync(Map<String, dynamic>? userBuff) {
    if (userBuff == null) {
      state = state.copyWith(
        multiplier: 1,
        breakdown: BuffBreakdown.defaultBuff(),
      );
    } else {
      final breakdown = BuffBreakdown.fromJson(userBuff);
      state = state.copyWith(
        multiplier: breakdown.multiplier,
        breakdown: breakdown,
      );
    }
  }

  void freezeForRun() {
    state = state.copyWith(
      frozenMultiplier: () => state.multiplier,
      isFrozen: true,
    );
    debugPrint('BuffNotifier: Frozen at ${state.effectiveMultiplier}x');
  }

  void unfreezeAfterRun() {
    state = state.copyWith(
      frozenMultiplier: () => null,
      isFrozen: false,
    );
    debugPrint('BuffNotifier: Unfrozen');
  }

  Future<void> refresh(String userId, {String? districtHex}) async {
    await loadBuff(userId, districtHex: districtHex);
  }

  void reset() {
    state = const BuffState();
  }
}

final buffProvider = NotifierProvider<BuffNotifier, BuffState>(
  BuffNotifier.new,
);
