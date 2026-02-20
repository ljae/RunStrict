# Riverpod 3.0.0 Best Practices (Without Code Generation)

## Core Principles

### 1. Manual Provider Definitions (Non-Code Generation)
- Use explicit provider constructors for full control
- Define providers using traditional Riverpod syntax
- No build runner or code generation required

```dart
// ✅ Manual provider definition
class TodoListNotifier extends Notifier<List<Todo>> {
  @override
  List<Todo> build() => [];

  void addTodo(Todo todo) {
    state = [...state, todo];
  }
}

final todoListProvider = NotifierProvider<TodoListNotifier, List<Todo>>(
  TodoListNotifier.new,
);
```

### 2. Notifier Class Structure
- **Must** extend `Notifier<T>` or `AsyncNotifier<T>`
- **Must** override `build()` method
- **Never** place logic in constructor — `ref` is not available yet

```dart
class MyNotifier extends Notifier<int> {
  // ❌ Don't do this - constructor logic
  MyNotifier() {
    // This will throw an exception - ref not available yet
    // state = 42;
  }

  // ✅ Do this - logic in build method
  @override
  int build() {
    // Your business logic here
    return 0;
  }

  void increment() => state++;
}

final myNotifierProvider = NotifierProvider<MyNotifier, int>(MyNotifier.new);
```

---

## State Management Patterns

### 3. Async Operations with AsyncNotifier
- Use `AsyncNotifier<T>` for asynchronous state management
- Riverpod automatically handles loading/error states via `AsyncValue`
- Use `ref.mounted` to check if provider is still active after async operations

```dart
class UserNotifier extends AsyncNotifier<User> {
  @override
  Future<User> build() async {
    // Riverpod automatically handles loading/error states
    return await fetchUser();
  }

  Future<void> updateUser(User user) async {
    state = const AsyncLoading();

    try {
      final updatedUser = await api.updateUser(user);

      // Check if provider is still mounted after async operation
      if (!ref.mounted) return;

      state = AsyncData(updatedUser);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }
}

final userProvider = AsyncNotifierProvider<UserNotifier, User>(UserNotifier.new);
```

### 4. Progress Tracking
- Use `AsyncLoading` with `progress` for granular progress updates (Riverpod 3.0 feature)

```dart
class DownloadNotifier extends AsyncNotifier<File> {
  @override
  Future<File> build() async {
    state = const AsyncLoading(progress: 0.0);
    await downloadStep1();

    state = const AsyncLoading(progress: 0.5);
    await downloadStep2();

    state = const AsyncLoading(progress: 1.0);
    return await finalizeDownload();
  }
}

final downloadProvider = AsyncNotifierProvider<DownloadNotifier, File>(
  DownloadNotifier.new,
);
```

---

## Ref Usage and Lifecycle

### 5. Unified Ref (Riverpod 3.0 Breaking Change)
- Riverpod 3.0 unifies `Ref` — no more type parameters or subclasses (`FutureProviderRef`, `StreamProviderRef`, etc.)
- Properties like `listenSelf`, `future` are now accessed directly on the Notifier instance
- `WidgetRef` remains separate and unchanged

```dart
class ExampleNotifier extends AsyncNotifier<int> {
  @override
  Future<int> build() async {
    // Direct access on notifier (NOT ref.listenSelf)
    listenSelf((previous, next) {
      debugPrint('State changed: $previous -> $next');
    });

    // Direct access on notifier (NOT ref.future)
    future.then((value) {
      debugPrint('Future completed: $value');
    });

    // ref.listen still works for watching other providers
    ref.listen(anotherProvider, (previous, next) {
      debugPrint('Another provider changed');
    });

    return 0;
  }
}

final exampleProvider = AsyncNotifierProvider<ExampleNotifier, int>(
  ExampleNotifier.new,
);
```

### 6. Provider Interaction
- **Never** directly access other notifier's protected properties (`.state`, `.ref`)
- **Always** use exposed methods for cross-notifier communication

```dart
class CounterNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void increment() => state++;
}

final counterProvider = NotifierProvider<CounterNotifier, int>(CounterNotifier.new);

class ControllerNotifier extends Notifier<void> {
  @override
  void build() {}

  void triggerIncrement() {
    // ✅ Good - use exposed methods
    ref.read(counterProvider.notifier).increment();

    // ❌ Bad - direct state access on another notifier
    // ref.read(counterProvider.notifier).state++;
  }
}

final controllerProvider = NotifierProvider<ControllerNotifier, void>(
  ControllerNotifier.new,
);
```

### 7. Resource Cleanup with ref.onDispose
- Always clean up subscriptions, timers, and controllers

```dart
class ResourceNotifier extends Notifier<Resource> {
  late StreamSubscription _subscription;

  @override
  Resource build() {
    _subscription = someStream.listen((data) {
      state = Resource(data: data);
    });

    // Auto-dispose when provider is disposed
    ref.onDispose(() {
      _subscription.cancel();
    });

    return Resource();
  }
}

final resourceProvider = NotifierProvider<ResourceNotifier, Resource>(
  ResourceNotifier.new,
);
```

### 8. CancelToken Pattern for Safe Async
- Use `CancelToken` + `ref.onDispose` to cancel in-flight requests when provider is disposed

```dart
class SafeAsyncNotifier extends AsyncNotifier<Data> {
  @override
  Future<Data> build() async {
    final cancelToken = CancelToken();
    ref.onDispose(cancelToken.cancel);

    return await repository.fetchData(cancelToken: cancelToken);
  }

  Future<void> refresh() async {
    final cancelToken = CancelToken();
    ref.onDispose(cancelToken.cancel);

    state = const AsyncLoading();
    try {
      final data = await repository.fetchData(cancelToken: cancelToken);
      state = AsyncData(data);
    } catch (e, st) {
      if (e is! CancelException) {
        state = AsyncError(e, st);
      }
    }
  }
}

final safeAsyncProvider = AsyncNotifierProvider<SafeAsyncNotifier, Data>(
  SafeAsyncNotifier.new,
);
```

---

## Widget Integration

### 9. ConsumerWidget and ConsumerStatefulWidget
- Use `ConsumerWidget` instead of `StatelessWidget`
- Use `ConsumerStatefulWidget` + `ConsumerState` instead of `StatefulWidget`

```dart
// Stateless
class MyWidget extends ConsumerWidget {
  const MyWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(counterProvider);
    return Text('$count');
  }
}

// Stateful
class MyStatefulWidget extends ConsumerStatefulWidget {
  const MyStatefulWidget({super.key});

  @override
  ConsumerState<MyStatefulWidget> createState() => _MyStatefulWidgetState();
}

class _MyStatefulWidgetState extends ConsumerState<MyStatefulWidget> {
  @override
  Widget build(BuildContext context) {
    final count = ref.watch(counterProvider);
    return Text('$count');
  }
}
```

### 10. Pattern Matching with AsyncValue
- Use exhaustive pattern matching for AsyncValue states (Dart 3.0+)

```dart
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncValue = ref.watch(userProvider);

    return switch (asyncValue) {
      AsyncData(:final value) => Text('User: ${value.name}'),
      AsyncError(:final error) => Text('Error: $error'),
      AsyncLoading(:final progress) => progress != null
        ? CircularProgressIndicator(value: progress)
        : const CircularProgressIndicator(),
    };
  }
}
```

### 11. Safe Async Operations in Widgets
- Always check `context.mounted` after async operations in widgets

```dart
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ElevatedButton(
      onPressed: () async {
        try {
          await someAsyncOperation();

          // Check if widget is still mounted
          if (context.mounted) {
            ref.read(someProvider.notifier).updateState();
          }
        } catch (e) {
          debugPrint('Error: $e');
        }
      },
      child: const Text('Action'),
    );
  }
}
```

### 12. Notifier Method Invocation
- Use `ref.watch(provider)` to reactively listen to state
- Use `ref.read(provider.notifier).method()` for one-off actions (e.g., button press)

```dart
// In widget build method — reactive
final count = ref.watch(counterProvider);

// In callbacks — one-off read
onPressed: () => ref.read(counterProvider.notifier).increment(),
```

---

## State Encapsulation

### 13. State Access Rules
- **Never** expose public properties/getters on notifiers
- All state accessed through `.state` property
- Private and `@protected` properties are acceptable

```dart
class MyNotifier extends Notifier<MyState> {
  // ❌ Bad - public property
  // int publicValue = 0;

  // ✅ Good - private property
  int _privateValue = 0;

  // ✅ Good - protected property
  @protected
  int protectedValue = 0;

  @override
  MyState build() => MyState(value: _privateValue);

  void updateValue(int newValue) {
    _privateValue = newValue;
    state = MyState(value: _privateValue);
  }
}

final myProvider = NotifierProvider<MyNotifier, MyState>(MyNotifier.new);
```

---

## Provider Types Reference

### 14. All Provider Types (Manual Declaration)

```dart
// Simple value provider (read-only, computed)
final stringProvider = Provider<String>((ref) => 'Hello');

// Notifier for synchronous mutable state
final counterProvider = NotifierProvider<CounterNotifier, int>(
  CounterNotifier.new,
);

// AsyncNotifier for async mutable state
final userProvider = AsyncNotifierProvider<UserNotifier, User>(
  UserNotifier.new,
);

// StreamNotifier for stream-based state
final streamProvider = StreamNotifierProvider<MyStreamNotifier, List<Data>>(
  MyStreamNotifier.new,
);

// Family providers for parameterized providers
final itemProvider = Provider.family<Item, String>((ref, id) {
  return getItem(id);
});

// AutoDispose variants
final autoDisposeProvider = NotifierProvider.autoDispose<MyNotifier, int>(
  MyNotifier.new,
);
```

### 15. StreamNotifier

```dart
class MyStreamNotifier extends StreamNotifier<List<Data>> {
  @override
  Stream<List<Data>> build() {
    return repository.watchAll();
  }

  // Override updateShouldNotify for custom notification logic (3.0 feature)
  @override
  bool updateShouldNotify(
    AsyncValue<List<Data>> previous,
    AsyncValue<List<Data>> next,
  ) {
    // Default in 3.0: uses == operator
    return previous != next;
  }
}

final myStreamProvider = StreamNotifierProvider<MyStreamNotifier, List<Data>>(
  MyStreamNotifier.new,
);
```

---

## Performance Considerations

### 16. Selective Rebuilds with select
- Use `select` to rebuild only when specific parts of state change

```dart
// Only rebuild when user name changes
final userName = ref.watch(userProvider.select((user) => user?.name));

// Multiple selectors for fine-grained control
final isAdmin = ref.watch(
  userProvider.select((user) => user?.role == 'admin'),
);
```

### 17. updateShouldNotify (Riverpod 3.0)
- All providers now use `==` operator by default for notification
- Override `updateShouldNotify` for custom comparison logic

```dart
class LargeStateNotifier extends Notifier<LargeState> {
  @override
  LargeState build() => LargeState.initial();

  @override
  bool updateShouldNotify(LargeState previous, LargeState next) {
    // Custom: only notify on meaningful changes
    return previous.importantField != next.importantField;
  }
}
```

### 18. Invalidation
- Use `ref.invalidate()` to force a provider to rebuild
- Supports both full invalidation and family-specific invalidation

```dart
// Invalidate all parameter combinations
ref.invalidate(labelProvider);

// Invalidate specific family parameter
ref.invalidate(labelProvider('John'));
```

---

## Code Organization

### 19. File Structure
- Keep related providers and notifiers in the same file
- No need for `part` files or generated code
- Group by feature, not by type

```
lib/
├── features/
│   ├── auth/
│   │   ├── auth_provider.dart      # AuthNotifier + authProvider
│   │   └── auth_screen.dart
│   ├── todos/
│   │   ├── todo_provider.dart      # TodoNotifier + todoProvider
│   │   └── todo_screen.dart
│   └── settings/
│       ├── settings_provider.dart
│       └── settings_screen.dart
└── main.dart                       # ProviderScope wraps MaterialApp
```

### 20. ProviderScope Setup

```dart
void main() {
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}
```

---

## Migration Notes (Riverpod 3.0 Breaking Changes)

### Key Changes from 2.x to 3.0
1. **Unified Ref**: No more `FutureProviderRef`, `StreamProviderRef`, etc. — just `Ref`
2. **Notifier properties**: `listenSelf`, `future`, `state` are now direct Notifier properties (not on `ref`)
3. **`==` comparison**: All providers use `==` for `updateShouldNotify` by default (was `identical` for some)
4. **AsyncLoading.progress**: New `progress` field on `AsyncLoading` for granular progress tracking
5. **Function providers deprecated**: Prefer class-based Notifiers over function-based providers for new code

### Quick Reference: Before → After
```dart
// Ref type (function providers)
// Before: int example(ExampleRef ref) { ... }
// After:  int example(Ref ref) { ... }

// listenSelf (in Notifier)
// Before: ref.listenSelf(...)
// After:  listenSelf(...)

// future (in AsyncNotifier)
// Before: ref.future
// After:  future
```
