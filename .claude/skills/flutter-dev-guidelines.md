# Flutter Development Guidelines — RunStrict

> Activated when editing Dart files in `lib/`. Provides project-specific Flutter/Dart coding standards.

## State Management: Riverpod 3.0 (MANDATORY)

**Full rules → [riverpod_rule.md](../../riverpod_rule.md)**

### Quick Reference
- Use `Notifier<T>` / `AsyncNotifier<T>` class-based providers
- Use `NotifierProvider` / `AsyncNotifierProvider` declarations
- Use `ConsumerWidget` / `ConsumerStatefulWidget` for widgets
- Use `ref.watch()` for reactive state, `ref.read()` for one-off actions
- Always check `ref.mounted` after async ops in notifiers
- Use `ref.onDispose()` for cleanup (subscriptions, timers)
- NO code generation (no build_runner, no freezed, no riverpod_generator)
- NO ChangeNotifier, StateNotifier, or legacy provider package

### Provider Pattern
```dart
class ExampleNotifier extends Notifier<ExampleState> {
  @override
  ExampleState build() => const ExampleState();

  Future<void> doAction() async {
    state = state.copyWith(loading: true);
    try {
      final result = await ref.read(serviceProvider).fetch();
      if (!ref.mounted) return; // CRITICAL: check after async
      state = state.copyWith(data: result, loading: false);
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(error: e.toString(), loading: false);
    }
  }
}

final exampleProvider = NotifierProvider<ExampleNotifier, ExampleState>(
  ExampleNotifier.new,
);
```

### Widget Pattern
```dart
class ExampleScreen extends ConsumerWidget {
  const ExampleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(exampleProvider);
    return // ... UI using state
  }
}
```

## Code Style

### Naming
| Type | Convention | Example |
|------|------------|---------|
| Files | `snake_case.dart` | `run_tracker.dart` |
| Classes | `UpperCamelCase` | `RunProvider` |
| Methods/Vars | `lowerCamelCase` | `startRun()` |
| Constants | `lowerCamelCase` | `const defaultZoom = 14.0` |
| Private | Prefix `_` | `_isTracking` |
| Enums | `UpperCamelCase` | `enum Team { red, blue, purple }` |

### Import Order
1. `dart:` SDK imports
2. `package:flutter/` imports
3. Third-party packages
4. Internal relative imports

### Widget Construction
- Use `const` constructors wherever possible
- Use `super.key` for widget keys
- Break large widgets into private helper widgets (`class _Section extends StatelessWidget`)
- Trailing commas for multi-line parameter lists

### Error Handling
```dart
// DO: Targeted try-catch with specific exceptions
try {
  await service.doThing();
} on SpecificException catch (e) {
  _handleError(e.message);
} catch (e) {
  debugPrint('Unexpected: $e');
}

// DON'T: Empty catch, print(), as any
```

### Model Pattern (fromRow/toRow)
```dart
class MyModel {
  final String id;
  final String name;

  const MyModel({required this.id, required this.name});

  MyModel copyWith({String? name}) => MyModel(
    id: id,
    name: name ?? this.name,
  );

  factory MyModel.fromRow(Map<String, dynamic> row) => MyModel(
    id: row['id'] as String,
    name: row['name'] as String,
  );

  Map<String, dynamic> toRow() => {'name': name};
}
```

## Architecture Rules

### Two Data Domains (NEVER mix)
- **Snapshot Domain**: Server → Local, read-only. Downloaded on launch/OnResume.
- **Live Domain**: Local creation → Upload via Final Sync.
- See [docs/03-data-architecture.md](../../docs/03-data-architecture.md) for full rules.

### Repository Pattern
- `UserRepository()`, `HexRepository()`, `LeaderboardRepository()` — singletons
- Providers delegate storage to repositories
- `HexRepository` is the SINGLE source of truth for hex data

### Do's
- Use `debugPrint()` for logging
- Use `AppTheme` constants for colors
- Use Supabase RPC for complex queries
- Use derived getters instead of stored fields
- Run `flutter analyze` before committing

### Don'ts
- Don't use `print()`
- Don't suppress lint rules without reason
- Don't put business logic in widgets
- Don't hardcode colors
- Don't store derived/calculated data in database
- Don't create backend API endpoints — use RLS + Edge Functions
