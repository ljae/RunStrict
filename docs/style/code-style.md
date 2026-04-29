# Code Style & Conventions

## File Size — 500-Line Ceiling

> **Rule**: New or substantially-modified `.dart`, `.kt`, `.swift` source files **must not exceed 500 lines**.

**Why**: AI tooling reads files in full; large files burn context. Bugs cluster in long files because the relationship between the top and bottom is hard to hold in mind. The error-fix-history archive shows recurring offenders.

**How to apply**:
- **New file?** Plan the split before writing. One feature per file.
- **Existing file under 500?** Keep it under 500 — splitting first is cheaper than splitting later.
- **Existing file over 500?** Grandfathered. When you next *substantially modify* it (>20% diff or new responsibility), split it as part of the same PR.
- **Generated/codegen, vendored, or framework-fixture files** (e.g., `*.g.dart`, `Pods/`) are exempt.

**How to split**:
- By **feature** (`run_tracker_pace.dart`, `run_tracker_lap.dart`), not by mechanical chunking (`run_tracker_part1.dart`).
- A widget over 500 lines almost always has 3+ private widgets — extract them to a `widgets/` sibling directory.
- A provider over 500 lines almost always conflates state shape, business rules, and side effects — extract pure helpers to a service.
- A service over 500 lines almost always has independent sub-domains — split per sub-domain.

**Don't**:
- Split a 700-line file into a 600-line file + a 100-line file just to dodge the rule. The split must reduce coupling, not just line count.
- Re-export everything via a barrel file to "make imports look the same." A split is supposed to change the import surface.

Audit current offenders separately (`find lib -name "*.dart" -exec wc -l {} + | awk '$1 > 500'`) — listed as a follow-up task, not a blocker for this rule.

---

## Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Files | `snake_case.dart` | `run_session.dart`, `hex_service.dart` |
| Classes | `UpperCamelCase` | `RunProvider`, `LocationService` |
| Methods/Variables | `lowerCamelCase` | `startRun()`, `distanceMeters` |
| Constants | `lowerCamelCase` | `const defaultZoom = 14.0` |
| Private members | Prefix with `_` | `_isTracking`, `_locationController` |
| Enums | `UpperCamelCase` | `enum Team { red, blue, purple }` |

## Import Order
1. Dart SDK (`dart:async`, `dart:io`)
2. Flutter (`package:flutter/material.dart`)
3. Third-party packages (`package:hooks_riverpod/hooks_riverpod.dart`)
4. Internal imports (relative paths `../models/run_session.dart`)

## Formatting
- Use trailing commas for multi-line parameter lists; `dart format .` before committing
- Max line length: 80 characters (Dart default)

## Widget Construction
```dart
class MyScreen extends StatelessWidget {
  const MyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _HeaderSection(),
        _ContentSection(),
      ],
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection();  // Private widget, no key needed
}
```

## State Management (Riverpod 3.0)
```dart
class RunNotifier extends Notifier<RunState> {
  @override
  RunState build() => const RunState();

  Future<void> startRun() async {
    final locationService = ref.read(locationServiceProvider);
    state = state.copyWith(activeRun: run);
  }
}

final runProvider = NotifierProvider<RunNotifier, RunState>(RunNotifier.new);
```

Full Riverpod patterns → [`riverpod_rule.md`](../../riverpod_rule.md).

## Error Handling
```dart
Future<void> startTracking() async {
  try {
    await _locationService.startTracking();
  } on LocationPermissionException catch (e) {
    _setError(e.message);
    rethrow;
  } catch (e) {
    debugPrint('Unexpected error: $e');
    _setError('Failed to start tracking');
  }
}
```

## Models — fromRow / toRow Pattern
```dart
class UserModel {
  final String id;
  final String name;
  final Team team;
  final int seasonPoints;

  const UserModel({required this.id, required this.name, required this.team, this.seasonPoints = 0});

  UserModel copyWith({String? name, Team? team, int? seasonPoints}) => UserModel(
    id: id, name: name ?? this.name, team: team ?? this.team,
    seasonPoints: seasonPoints ?? this.seasonPoints,
  );

  factory UserModel.fromRow(Map<String, dynamic> row) => UserModel(
    id: row['id'] as String,
    name: row['name'] as String,
    team: Team.values.byName(row['team'] as String),
    seasonPoints: (row['season_points'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toRow() => {'name': name, 'team': team.name, 'season_points': seasonPoints};
}
```

Schema and full model inventory → [`docs/03-data-architecture.md`](../03-data-architecture.md).

## Logging
- `debugPrint()` only — never `print()`.
- Format: `debugPrint('[ServiceName] message: $value')`.

## Testing
Test files mirror `lib/` structure under `test/`.

```dart
void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const RunnerApp());
    expect(find.textContaining('RUN'), findsOneWidget);
  });
}
```
