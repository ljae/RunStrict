import 'package:flutter/foundation.dart';
import '../models/app_config.dart';
import 'config_cache_service.dart';
import 'supabase_service.dart';

class RemoteConfigService {
  static final RemoteConfigService _instance = RemoteConfigService._internal();
  factory RemoteConfigService() => _instance;
  RemoteConfigService._internal();

  final ConfigCacheService _cacheService = ConfigCacheService();

  AppConfig? _config;
  AppConfig? _frozenConfig;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  AppConfig get config {
    if (!_isInitialized || _config == null) {
      debugPrint('RemoteConfigService: Not initialized, returning defaults');
      return AppConfig.defaults();
    }
    return _config!;
  }

  AppConfig get configSnapshot {
    if (_frozenConfig != null) {
      return _frozenConfig!;
    }
    return config;
  }

  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('RemoteConfigService: Already initialized');
      return;
    }

    _config = await _loadConfigWithFallback();
    _isInitialized = true;
    debugPrint(
      'RemoteConfigService: Initialized with config version ${_config!.configVersion}',
    );
  }

  Future<AppConfig> _loadConfigWithFallback() async {
    final serverConfig = await _fetchFromServer();
    if (serverConfig != null) {
      await _cacheService.saveConfig(serverConfig);
      debugPrint(
        'RemoteConfigService: Loaded config version ${serverConfig.configVersion} from server',
      );
      return serverConfig;
    }

    final cachedConfig = await _cacheService.loadConfig();
    if (cachedConfig != null) {
      debugPrint(
        'RemoteConfigService: Server unreachable, using cached config version ${cachedConfig.configVersion}',
      );
      return cachedConfig;
    }

    debugPrint('RemoteConfigService: No cache available, using defaults');
    return AppConfig.defaults();
  }

  Future<AppConfig?> _fetchFromServer() async {
    try {
      final supabase = SupabaseService();
      final userId = supabase.client.auth.currentUser?.id;

      if (userId == null) {
        final result = await supabase.client.rpc(
          'app_launch_sync',
          params: {'p_user_id': null},
        );
        return _parseConfigFromResponse(result);
      }

      final result = await supabase.appLaunchSync(userId);
      return _parseConfigFromResponse(result);
    } catch (e) {
      debugPrint('RemoteConfigService: Failed to fetch from server - $e');
      return null;
    }
  }

  AppConfig? _parseConfigFromResponse(dynamic response) {
    if (response == null) return null;

    final appConfigData = response['app_config'];
    if (appConfigData == null) return null;

    final version = appConfigData['version'] as int?;
    final data = appConfigData['data'] as Map<String, dynamic>?;

    if (data == null) return null;

    return AppConfig.fromJson({
      'configVersion': version ?? 1,
      'seasonConfig': data['season'],
      'crewConfig': data['crew'],
      'gpsConfig': data['gps'],
      'scoringConfig': data['scoring'],
      'hexConfig': data['hex'],
      'timingConfig': data['timing'],
    });
  }

  void freezeForRun() {
    _frozenConfig = _config;
    debugPrint(
      'RemoteConfigService: Config frozen for run (version ${_frozenConfig?.configVersion})',
    );
  }

  void unfreezeAfterRun() {
    _frozenConfig = null;
    debugPrint('RemoteConfigService: Config unfrozen');
  }

  Future<void> refresh() async {
    if (_frozenConfig != null) {
      debugPrint(
        'RemoteConfigService: Cannot refresh while config is frozen for run',
      );
      return;
    }

    final newConfig = await _loadConfigWithFallback();
    if (newConfig.configVersion != _config?.configVersion) {
      _config = newConfig;
      debugPrint(
        'RemoteConfigService: Refreshed to config version ${_config!.configVersion}',
      );
    }
  }

  @visibleForTesting
  void reset() {
    _config = null;
    _frozenConfig = null;
    _isInitialized = false;
  }
}
