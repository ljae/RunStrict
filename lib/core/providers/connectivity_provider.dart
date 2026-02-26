import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Streams device connectivity state.
///
/// Returns `true` when connected, `false` when offline.
final connectivityProvider = StreamProvider<bool>((ref) {
  return Connectivity().onConnectivityChanged.map(
    (results) => !results.contains(ConnectivityResult.none),
  );
});
