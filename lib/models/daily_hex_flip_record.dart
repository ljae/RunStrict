class DailyHexFlipRecord {
  final String userId;
  final String dateKey;
  final Set<String> flippedHexIds;

  DailyHexFlipRecord({
    required this.userId,
    required this.dateKey,
    Set<String>? flippedHexIds,
  }) : flippedHexIds = flippedHexIds ?? {};

  bool hasFlippedToday(String hexId) => flippedHexIds.contains(hexId);

  DailyHexFlipRecord recordFlip(String hexId) {
    return DailyHexFlipRecord(
      userId: userId,
      dateKey: dateKey,
      flippedHexIds: {...flippedHexIds, hexId},
    );
  }
}
