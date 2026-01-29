/// Server-configurable application settings for RunStrict.
///
/// All configuration is immutable and versioned. Use [copyWith] to create
/// modified copies. Deserialization via [fromJson] allows server-driven updates.
class AppConfig {
  final int configVersion;
  final SeasonConfig seasonConfig;
  final CrewConfig crewConfig;
  final GpsConfig gpsConfig;
  final ScoringConfig scoringConfig;
  final HexConfig hexConfig;
  final TimingConfig timingConfig;

  const AppConfig({
    required this.configVersion,
    required this.seasonConfig,
    required this.crewConfig,
    required this.gpsConfig,
    required this.scoringConfig,
    required this.hexConfig,
    required this.timingConfig,
  });

  /// Creates AppConfig with all hardcoded defaults.
  factory AppConfig.defaults() => AppConfig(
    configVersion: 1,
    seasonConfig: SeasonConfig.defaults(),
    crewConfig: CrewConfig.defaults(),
    gpsConfig: GpsConfig.defaults(),
    scoringConfig: ScoringConfig.defaults(),
    hexConfig: HexConfig.defaults(),
    timingConfig: TimingConfig.defaults(),
  );

  /// Deserializes AppConfig from JSON (typically from server).
  factory AppConfig.fromJson(Map<String, dynamic> json) => AppConfig(
    configVersion: (json['configVersion'] as num?)?.toInt() ?? 1,
    seasonConfig: SeasonConfig.fromJson(
      json['seasonConfig'] as Map<String, dynamic>? ?? {},
    ),
    crewConfig: CrewConfig.fromJson(
      json['crewConfig'] as Map<String, dynamic>? ?? {},
    ),
    gpsConfig: GpsConfig.fromJson(
      json['gpsConfig'] as Map<String, dynamic>? ?? {},
    ),
    scoringConfig: ScoringConfig.fromJson(
      json['scoringConfig'] as Map<String, dynamic>? ?? {},
    ),
    hexConfig: HexConfig.fromJson(
      json['hexConfig'] as Map<String, dynamic>? ?? {},
    ),
    timingConfig: TimingConfig.fromJson(
      json['timingConfig'] as Map<String, dynamic>? ?? {},
    ),
  );

  /// Serializes AppConfig to JSON for storage or transmission.
  Map<String, dynamic> toJson() => {
    'configVersion': configVersion,
    'seasonConfig': seasonConfig.toJson(),
    'crewConfig': crewConfig.toJson(),
    'gpsConfig': gpsConfig.toJson(),
    'scoringConfig': scoringConfig.toJson(),
    'hexConfig': hexConfig.toJson(),
    'timingConfig': timingConfig.toJson(),
  };

  /// Creates a copy with optionally updated fields.
  AppConfig copyWith({
    int? configVersion,
    SeasonConfig? seasonConfig,
    CrewConfig? crewConfig,
    GpsConfig? gpsConfig,
    ScoringConfig? scoringConfig,
    HexConfig? hexConfig,
    TimingConfig? timingConfig,
  }) => AppConfig(
    configVersion: configVersion ?? this.configVersion,
    seasonConfig: seasonConfig ?? this.seasonConfig,
    crewConfig: crewConfig ?? this.crewConfig,
    gpsConfig: gpsConfig ?? this.gpsConfig,
    scoringConfig: scoringConfig ?? this.scoringConfig,
    hexConfig: hexConfig ?? this.hexConfig,
    timingConfig: timingConfig ?? this.timingConfig,
  );
}

/// Season-related configuration.
class SeasonConfig {
  final int durationDays;
  final int serverTimezoneOffsetHours;

  const SeasonConfig({
    required this.durationDays,
    required this.serverTimezoneOffsetHours,
  });

  factory SeasonConfig.defaults() =>
      const SeasonConfig(durationDays: 280, serverTimezoneOffsetHours: 2);

  factory SeasonConfig.fromJson(Map<String, dynamic> json) => SeasonConfig(
    durationDays: (json['durationDays'] as num?)?.toInt() ?? 280,
    serverTimezoneOffsetHours:
        (json['serverTimezoneOffsetHours'] as num?)?.toInt() ?? 2,
  );

  Map<String, dynamic> toJson() => {
    'durationDays': durationDays,
    'serverTimezoneOffsetHours': serverTimezoneOffsetHours,
  };

  SeasonConfig copyWith({int? durationDays, int? serverTimezoneOffsetHours}) =>
      SeasonConfig(
        durationDays: durationDays ?? this.durationDays,
        serverTimezoneOffsetHours:
            serverTimezoneOffsetHours ?? this.serverTimezoneOffsetHours,
      );
}

/// Crew-related configuration.
class CrewConfig {
  final int maxMembersRegular;
  final int maxMembersPurple;

  const CrewConfig({
    required this.maxMembersRegular,
    required this.maxMembersPurple,
  });

  factory CrewConfig.defaults() =>
      const CrewConfig(maxMembersRegular: 12, maxMembersPurple: 24);

  factory CrewConfig.fromJson(Map<String, dynamic> json) => CrewConfig(
    maxMembersRegular: (json['maxMembersRegular'] as num?)?.toInt() ?? 12,
    maxMembersPurple: (json['maxMembersPurple'] as num?)?.toInt() ?? 24,
  );

  Map<String, dynamic> toJson() => {
    'maxMembersRegular': maxMembersRegular,
    'maxMembersPurple': maxMembersPurple,
  };

  CrewConfig copyWith({int? maxMembersRegular, int? maxMembersPurple}) =>
      CrewConfig(
        maxMembersRegular: maxMembersRegular ?? this.maxMembersRegular,
        maxMembersPurple: maxMembersPurple ?? this.maxMembersPurple,
      );
}

/// GPS tracking and validation configuration.
class GpsConfig {
  final double maxSpeedMps;
  final double minSpeedMps;
  final double maxAccuracyMeters;
  final double maxAltitudeChangeMps;
  final double maxJumpDistanceMeters;
  final int movingAvgWindowSeconds;
  final double maxCapturePaceMinPerKm;
  final double pollingRateHz;
  final int minTimeBetweenPointsMs;

  const GpsConfig({
    required this.maxSpeedMps,
    required this.minSpeedMps,
    required this.maxAccuracyMeters,
    required this.maxAltitudeChangeMps,
    required this.maxJumpDistanceMeters,
    required this.movingAvgWindowSeconds,
    required this.maxCapturePaceMinPerKm,
    required this.pollingRateHz,
    required this.minTimeBetweenPointsMs,
  });

  factory GpsConfig.defaults() => const GpsConfig(
    maxSpeedMps: 6.94,
    minSpeedMps: 0.3,
    maxAccuracyMeters: 50.0,
    maxAltitudeChangeMps: 5.0,
    maxJumpDistanceMeters: 100.0,
    movingAvgWindowSeconds: 20,
    maxCapturePaceMinPerKm: 8.0,
    pollingRateHz: 0.5,
    minTimeBetweenPointsMs: 1500,
  );

  factory GpsConfig.fromJson(Map<String, dynamic> json) => GpsConfig(
    maxSpeedMps: (json['maxSpeedMps'] as num?)?.toDouble() ?? 6.94,
    minSpeedMps: (json['minSpeedMps'] as num?)?.toDouble() ?? 0.3,
    maxAccuracyMeters: (json['maxAccuracyMeters'] as num?)?.toDouble() ?? 50.0,
    maxAltitudeChangeMps:
        (json['maxAltitudeChangeMps'] as num?)?.toDouble() ?? 5.0,
    maxJumpDistanceMeters:
        (json['maxJumpDistanceMeters'] as num?)?.toDouble() ?? 100.0,
    movingAvgWindowSeconds:
        (json['movingAvgWindowSeconds'] as num?)?.toInt() ?? 20,
    maxCapturePaceMinPerKm:
        (json['maxCapturePaceMinPerKm'] as num?)?.toDouble() ?? 8.0,
    pollingRateHz: (json['pollingRateHz'] as num?)?.toDouble() ?? 0.5,
    minTimeBetweenPointsMs:
        (json['minTimeBetweenPointsMs'] as num?)?.toInt() ?? 1500,
  );

  Map<String, dynamic> toJson() => {
    'maxSpeedMps': maxSpeedMps,
    'minSpeedMps': minSpeedMps,
    'maxAccuracyMeters': maxAccuracyMeters,
    'maxAltitudeChangeMps': maxAltitudeChangeMps,
    'maxJumpDistanceMeters': maxJumpDistanceMeters,
    'movingAvgWindowSeconds': movingAvgWindowSeconds,
    'maxCapturePaceMinPerKm': maxCapturePaceMinPerKm,
    'pollingRateHz': pollingRateHz,
    'minTimeBetweenPointsMs': minTimeBetweenPointsMs,
  };

  GpsConfig copyWith({
    double? maxSpeedMps,
    double? minSpeedMps,
    double? maxAccuracyMeters,
    double? maxAltitudeChangeMps,
    double? maxJumpDistanceMeters,
    int? movingAvgWindowSeconds,
    double? maxCapturePaceMinPerKm,
    double? pollingRateHz,
    int? minTimeBetweenPointsMs,
  }) => GpsConfig(
    maxSpeedMps: maxSpeedMps ?? this.maxSpeedMps,
    minSpeedMps: minSpeedMps ?? this.minSpeedMps,
    maxAccuracyMeters: maxAccuracyMeters ?? this.maxAccuracyMeters,
    maxAltitudeChangeMps: maxAltitudeChangeMps ?? this.maxAltitudeChangeMps,
    maxJumpDistanceMeters: maxJumpDistanceMeters ?? this.maxJumpDistanceMeters,
    movingAvgWindowSeconds:
        movingAvgWindowSeconds ?? this.movingAvgWindowSeconds,
    maxCapturePaceMinPerKm:
        maxCapturePaceMinPerKm ?? this.maxCapturePaceMinPerKm,
    pollingRateHz: pollingRateHz ?? this.pollingRateHz,
    minTimeBetweenPointsMs:
        minTimeBetweenPointsMs ?? this.minTimeBetweenPointsMs,
  );
}

/// Scoring and points configuration.
class ScoringConfig {
  final List<int> tierThresholdsKm;
  final List<int> tierPoints;
  final Map<String, double> paceMultipliers;
  final Map<String, double> crewMultipliers;

  const ScoringConfig({
    required this.tierThresholdsKm,
    required this.tierPoints,
    required this.paceMultipliers,
    required this.crewMultipliers,
  });

  factory ScoringConfig.defaults() => ScoringConfig(
    tierThresholdsKm: const [0, 3, 6, 9, 12, 15],
    tierPoints: const [10, 25, 50, 100, 150, 200],
    paceMultipliers: const {'slow': 0.8, 'normal': 1.0, 'fast': 1.2},
    crewMultipliers: const {
      'solo': 1.0,
      'small': 1.5,
      'medium': 2.0,
      'large': 3.0,
    },
  );

  factory ScoringConfig.fromJson(Map<String, dynamic> json) => ScoringConfig(
    tierThresholdsKm:
        (json['tierThresholdsKm'] as List<dynamic>?)
            ?.map((e) => (e as num).toInt())
            .toList() ??
        [0, 3, 6, 9, 12, 15],
    tierPoints:
        (json['tierPoints'] as List<dynamic>?)
            ?.map((e) => (e as num).toInt())
            .toList() ??
        [10, 25, 50, 100, 150, 200],
    paceMultipliers:
        (json['paceMultipliers'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, (v as num).toDouble()),
        ) ??
        {'slow': 0.8, 'normal': 1.0, 'fast': 1.2},
    crewMultipliers:
        (json['crewMultipliers'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, (v as num).toDouble()),
        ) ??
        {'solo': 1.0, 'small': 1.5, 'medium': 2.0, 'large': 3.0},
  );

  Map<String, dynamic> toJson() => {
    'tierThresholdsKm': tierThresholdsKm,
    'tierPoints': tierPoints,
    'paceMultipliers': paceMultipliers,
    'crewMultipliers': crewMultipliers,
  };

  ScoringConfig copyWith({
    List<int>? tierThresholdsKm,
    List<int>? tierPoints,
    Map<String, double>? paceMultipliers,
    Map<String, double>? crewMultipliers,
  }) => ScoringConfig(
    tierThresholdsKm: tierThresholdsKm ?? this.tierThresholdsKm,
    tierPoints: tierPoints ?? this.tierPoints,
    paceMultipliers: paceMultipliers ?? this.paceMultipliers,
    crewMultipliers: crewMultipliers ?? this.crewMultipliers,
  );
}

/// Hexagonal grid configuration.
class HexConfig {
  final int baseResolution;
  final int zoneResolution;
  final int cityResolution;
  final int allResolution;
  final double captureCheckDistanceMeters;
  final int maxCacheSize;

  const HexConfig({
    required this.baseResolution,
    required this.zoneResolution,
    required this.cityResolution,
    required this.allResolution,
    required this.captureCheckDistanceMeters,
    required this.maxCacheSize,
  });

  factory HexConfig.defaults() => const HexConfig(
    baseResolution: 9,
    zoneResolution: 8,
    cityResolution: 6,
    allResolution: 4,
    captureCheckDistanceMeters: 20.0,
    maxCacheSize: 4000,
  );

  factory HexConfig.fromJson(Map<String, dynamic> json) => HexConfig(
    baseResolution: (json['baseResolution'] as num?)?.toInt() ?? 9,
    zoneResolution: (json['zoneResolution'] as num?)?.toInt() ?? 8,
    cityResolution: (json['cityResolution'] as num?)?.toInt() ?? 6,
    allResolution: (json['allResolution'] as num?)?.toInt() ?? 4,
    captureCheckDistanceMeters:
        (json['captureCheckDistanceMeters'] as num?)?.toDouble() ?? 20.0,
    maxCacheSize: (json['maxCacheSize'] as num?)?.toInt() ?? 4000,
  );

  Map<String, dynamic> toJson() => {
    'baseResolution': baseResolution,
    'zoneResolution': zoneResolution,
    'cityResolution': cityResolution,
    'allResolution': allResolution,
    'captureCheckDistanceMeters': captureCheckDistanceMeters,
    'maxCacheSize': maxCacheSize,
  };

  HexConfig copyWith({
    int? baseResolution,
    int? zoneResolution,
    int? cityResolution,
    int? allResolution,
    double? captureCheckDistanceMeters,
    int? maxCacheSize,
  }) => HexConfig(
    baseResolution: baseResolution ?? this.baseResolution,
    zoneResolution: zoneResolution ?? this.zoneResolution,
    cityResolution: cityResolution ?? this.cityResolution,
    allResolution: allResolution ?? this.allResolution,
    captureCheckDistanceMeters:
        captureCheckDistanceMeters ?? this.captureCheckDistanceMeters,
    maxCacheSize: maxCacheSize ?? this.maxCacheSize,
  );
}

/// Timing and sampling configuration.
class TimingConfig {
  final int accelerometerSamplingPeriodMs;
  final int refreshThrottleSeconds;

  const TimingConfig({
    required this.accelerometerSamplingPeriodMs,
    required this.refreshThrottleSeconds,
  });

  factory TimingConfig.defaults() => const TimingConfig(
    accelerometerSamplingPeriodMs: 200,
    refreshThrottleSeconds: 30,
  );

  factory TimingConfig.fromJson(Map<String, dynamic> json) => TimingConfig(
    accelerometerSamplingPeriodMs:
        (json['accelerometerSamplingPeriodMs'] as num?)?.toInt() ?? 200,
    refreshThrottleSeconds:
        (json['refreshThrottleSeconds'] as num?)?.toInt() ?? 30,
  );

  Map<String, dynamic> toJson() => {
    'accelerometerSamplingPeriodMs': accelerometerSamplingPeriodMs,
    'refreshThrottleSeconds': refreshThrottleSeconds,
  };

  TimingConfig copyWith({
    int? accelerometerSamplingPeriodMs,
    int? refreshThrottleSeconds,
  }) => TimingConfig(
    accelerometerSamplingPeriodMs:
        accelerometerSamplingPeriodMs ?? this.accelerometerSamplingPeriodMs,
    refreshThrottleSeconds:
        refreshThrottleSeconds ?? this.refreshThrottleSeconds,
  );
}
