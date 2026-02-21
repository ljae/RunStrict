import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/purchases_service.dart';

/// Reactive provider for RunStrict Pro (ad-free) status.
class ProNotifier extends Notifier<bool> {
  @override
  bool build() => PurchasesService().isPro;

  void setProStatus(bool isPro) {
    state = isPro;
    debugPrint('ProNotifier: Pro status set to $isPro');
  }

  /// Refresh pro status from RevenueCat server.
  Future<void> refresh() async {
    final isPro = await PurchasesService().refreshProStatus();
    state = isPro;
  }
}

final proProvider = NotifierProvider<ProNotifier, bool>(
  ProNotifier.new,
);
