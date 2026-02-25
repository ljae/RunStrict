# Claude Integration Guide — RunStrict

> Setup guide for Claude Code environment in this Flutter/Dart project.

**FOR CLAUDE CODE:** When working in this repository, follow these instructions to understand the project structure, available skills, hooks, agents, and commands.

---

## Overview

This project is **RunStrict** — a location-based running game that gamifies territory control through hexagonal maps. It is a **Flutter/Dart mobile app** with a Supabase backend.

- **Tech stack:** Flutter 3.10+, Dart, Riverpod 3.0, Mapbox, Supabase (PostgreSQL + RLS), H3 hex grid, SQLite
- **Key reference files:**
  - `AGENTS.md` — Coding guidelines, naming conventions, architecture rules
  - `DEVELOPMENT_SPEC.md` — Index pointing to docs/ manuals
  - `docs/` — Feature-specific architecture manuals
- **State management:** Riverpod 3.0 with `Notifier`/`AsyncNotifier` — **NO code generation** (no build_runner, no freezed, no riverpod_generator)
- **Auth:** Supabase Auth — NOT Firebase, NOT JWT cookies
- **No backend API server** — Supabase RLS + Edge Functions handle everything

**Key Principle:** Always read `AGENTS.md` before making architectural decisions. It contains critical rules about the two data domains (Snapshot vs Live), location domain separation (Home vs GPS), and the hex snapshot system.

---

## Tech Stack Compatibility Check

**CRITICAL:** Before applying any skill or pattern, verify it matches this project's stack.

### Flutter/Dart Skills

**This project requires:**
- Flutter 3.10+ (not React Native, not Expo, not Ionic)
- Dart (not TypeScript, not JavaScript)
- Riverpod 3.0 — `Notifier`/`AsyncNotifier` class-based providers
- `ConsumerWidget` / `ConsumerStatefulWidget` for reactive UI
- `fromRow()` / `toRow()` for Supabase serialization (not Prisma, not TypeORM)

**Key patterns to follow:**
```dart
// Correct: Riverpod 3.0 Notifier pattern
class RunNotifier extends Notifier<RunState> {
  @override
  RunState build() => const RunState();

  Future<void> startRun() async {
    state = state.copyWith(isRunning: true);
  }
}

final runProvider = NotifierProvider<RunNotifier, RunState>(RunNotifier.new);

// Correct: ConsumerWidget
class RunningScreen extends ConsumerWidget {
  const RunningScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runState = ref.watch(runProvider);
    return Text(runState.isRunning ? 'Running' : 'Idle');
  }
}
```

**If a skill references React, Vue, Angular, or any JS framework:** It does not apply here. Adapt the architecture principles (layered design, separation of concerns) but replace all code examples with Dart/Flutter equivalents.

### Supabase Skills

**This project uses:**
- `supabase_flutter` package (not the JS SDK)
- PostgreSQL RLS for authorization (no custom middleware)
- Supabase RPC calls for complex queries
- Edge Functions (Deno/TypeScript) for server-side logic
- **No backend API server** — direct Supabase client calls only

**Key pattern:**
```dart
// Correct: Supabase RPC call
final result = await supabase.rpc('get_user_buff', params: {
  'p_user_id': userId,
});

// Correct: Direct table query with RLS
final hexes = await supabase
    .from('hex_snapshot')
    .select()
    .eq('parent_hex', parentHex);
```

**If a skill references Express, Prisma, Fastify, or any Node.js ORM:** It does not apply here. Use Supabase RPC and direct table queries instead.

### Mapbox Skills

**This project uses:**
- `mapbox_maps_flutter` package (NOT `mapbox_gl`)
- `GeoJsonSource` + `FillLayer` for hex rendering (NOT `PolygonAnnotationManager`)
- Data-driven styling via `setStyleLayerProperty` with expressions
- Navigation camera with `SmoothCameraController` for 60fps interpolation

**If a skill references Mapbox GL JS (web) or `mapbox_gl` (old Flutter package):** The API is different. Refer to `AGENTS.md` → "Mapbox Patterns" section for the correct patterns.

### Skills That Are Project-Agnostic

These work regardless of tech stack:
- `skill-developer` — Meta-skill for creating new skills
- `git-master` — Git operations, atomic commits, history search
- `systematic-debugging` — Debugging methodology, works for any language
- `senior-architect` — Architecture patterns (adapt examples to Dart/Flutter)

---

## General Integration Pattern

When adding a component (skill/hook/agent/command):

1. Identify component type
2. **Check tech stack compatibility** (Flutter/Dart, not React/Node)
3. Understand the project structure from `AGENTS.md`
4. Copy files to `.claude/` subdirectory
5. Customize path patterns for Flutter project structure
6. Verify integration with `flutter analyze`

---

## Skill Integration

### Available Skills for This Project

#### flutter-dev-guidelines

- **Covers:** Widget construction, Riverpod 3.0 patterns, code style, naming conventions, model serialization
- **Triggers on:** `*.dart` files in `lib/`
- **Key references:** `AGENTS.md` for full style guide, `riverpod_rule.md` for state management details
- **Critical rules from AGENTS.md:**
  - Use `const` constructors wherever possible
  - Use `super.key` for widget keys
  - Use `debugPrint()` not `print()`
  - No business logic in widgets — use services/providers
  - No hardcoded colors — use `AppTheme` constants

#### supabase-patterns

- **Covers:** RPC calls, RLS policies, migration patterns, Edge Functions, model serialization
- **Triggers on:** `*.sql` files, `supabase/` directory, Dart files using `SupabaseService`
- **Key patterns:**
  - `fromRow()` / `toRow()` for Supabase row serialization
  - RPC calls via `supabase.rpc('function_name', params: {...})`
  - Migrations in `supabase/migrations/` with timestamp prefix
  - No backend API server — RLS handles authorization

#### mapbox-hex-patterns

- **Covers:** `GeoJsonSource` + `FillLayer` rendering, scope boundary layers, navigation camera, data-driven styling
- **Triggers on:** Dart files in `lib/features/map/`
- **Key patterns:**
  - Use `GeoJsonSource` + `FillLayer` (NOT `PolygonAnnotationManager`) to avoid visual flash
  - Apply data-driven expressions via `setStyleLayerProperty`
  - Province boundary = merged outer boundary of district hexes (irregular polygon)
  - Navigation camera uses `SmoothCameraController` with 1800ms animation duration

#### skill-developer (meta-skill)

- **Covers:** Creating new skills for any tech stack
- **Tech requirements:** None
- **Copy as-is** — fully generic

### skill-rules.json Configuration

Path patterns for this Flutter project structure:

```json
{
  "flutter-dev-guidelines": {
    "fileTriggers": {
      "pathPatterns": [
        "lib/**/*.dart",
        "test/**/*.dart"
      ]
    }
  },
  "supabase-patterns": {
    "fileTriggers": {
      "pathPatterns": [
        "supabase/**/*.sql",
        "supabase/functions/**/*.ts",
        "lib/core/services/supabase*.dart",
        "lib/data/repositories/**/*.dart"
      ]
    }
  },
  "mapbox-hex-patterns": {
    "fileTriggers": {
      "pathPatterns": [
        "lib/features/map/**/*.dart",
        "lib/core/utils/route_optimizer.dart"
      ]
    }
  }
}
```

**Customization notes:**
- `lib/**/*.dart` covers all Dart source files
- `supabase/**/*.sql` covers all migration files
- `lib/features/map/**/*.dart` scopes Mapbox skill to map feature only
- Adjust if project structure changes (check `AGENTS.md` → "Project Structure")

---

## Hook Integration

### Pre-commit Hook: flutter analyze

**Purpose:** Runs `flutter analyze` on changed Dart files before commit. Blocks commit if analysis errors are found. Warnings are reported but don't block.

**Integration:**

```bash
# Copy hook file
cp showcase/.claude/hooks/flutter-analyze.sh \
   $CLAUDE_PROJECT_DIR/.claude/hooks/

# Make executable
chmod +x $CLAUDE_PROJECT_DIR/.claude/hooks/flutter-analyze.sh
```

**Add to `.claude/settings.json`:**
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/flutter-analyze.sh"
          }
        ]
      }
    ]
  }
}
```

**Note:** `flutter analyze` is the Dart equivalent of `tsc --noEmit`. It catches type errors, lint violations, and unused imports. Always run before committing.

### File Change Tracker (PostToolUse)

**Purpose:** Tracks edited `.dart` files for context management. Fully generic — no customization needed.

**Integration:**

```bash
cp showcase/.claude/hooks/post-tool-use-tracker.sh \
   $CLAUDE_PROJECT_DIR/.claude/hooks/
chmod +x $CLAUDE_PROJECT_DIR/.claude/hooks/post-tool-use-tracker.sh
```

**Add to `.claude/settings.json`:**
```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|MultiEdit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/post-tool-use-tracker.sh"
          }
        ]
      }
    ]
  }
}
```

### Skill Activation Prompt (UserPromptSubmit)

**Purpose:** Auto-suggests relevant skills based on user prompts. Fully generic — no customization needed.

**Integration:**

```bash
cp showcase/.claude/hooks/skill-activation-prompt.sh \
   $CLAUDE_PROJECT_DIR/.claude/hooks/
chmod +x $CLAUDE_PROJECT_DIR/.claude/hooks/skill-activation-prompt.sh
```

**Add to `.claude/settings.json`:**
```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/skill-activation-prompt.sh"
          }
        ]
      }
    ]
  }
}
```

---

## Agent Integration

### Existing Agents (in `.claude/agents/`)

| Agent | Purpose |
|-------|---------|
| `perf-pipeline-orchestrator.md` | Performance testing pipeline orchestration |
| `tech-project-manager.md` | Project management, sprint planning |

### Standard Agent Integration

```bash
# Copy agent file
cp showcase/.claude/agents/[agent-name].md \
   $CLAUDE_PROJECT_DIR/.claude/agents/
```

Agents are standalone — no configuration needed after copying.

### Check for Hardcoded Paths

Before copying any agent, read it and check for hardcoded paths:

- `~/git/old-project/` → Should be `$CLAUDE_PROJECT_DIR` or `.`
- `/Users/username/...` → Should be relative or `$CLAUDE_PROJECT_DIR`
- Hardcoded simulator device IDs → Should be dynamic

**If found, update them:**
```bash
sed -i 's|~/git/old-project/|.|g' \
    $CLAUDE_PROJECT_DIR/.claude/agents/[agent].md
```

### Agent Notes

- **perf-pipeline-orchestrator:** Runs `flutter test --coverage` and performance benchmarks. No hardcoded paths — project-local references only.
- **tech-project-manager:** Reads `DEVELOPMENT_SPEC.md` and `docs/` for project context. No customization needed.
- **All other agents:** Copy as-is, they're fully generic.

---

## Slash Commands

### Available Commands

| Command | Action |
|---------|--------|
| `/analyze` | Run `flutter analyze` on changed files |
| `/test` | Run `flutter test` (all tests) |
| `/test-file` | Run `flutter test [file]` on a specific test file |
| `/build` | Build for target platform (`ios`, `apk`, `macos`) |
| `/format` | Run `dart format .` on the project |
| `/simulate-run` | Run `./simulate_run.sh` for GPS simulation on iOS Simulator |

### Adding a Command

```bash
# Copy command file
cp showcase/.claude/commands/[command].md \
   $CLAUDE_PROJECT_DIR/.claude/commands/
```

### Command File Template

```markdown
# /analyze

Run flutter analyze on the project.

## Steps
1. Run: `flutter analyze`
2. Report any errors (block) or warnings (report only)
3. If clean: "✅ No analysis issues found"
```

### Customize Paths

Commands may reference docs paths. Check and update:

- `docs/` references → Verify against actual `docs/` directory structure
- `DEVELOPMENT_SPEC.md` → Confirm file exists at project root
- Platform-specific paths → Update for iOS/Android/macOS as needed

---

## Adapting Skills for This Stack

When a skill from another project doesn't match Flutter/Dart, you have options:

### Option 1: Adapt Existing Skill (Recommended)

**When to use:** Skill has good architecture patterns but wrong tech stack.

**Process:**
1. Copy the skill as a starting point
2. Replace framework-specific code:
   - React hooks → Riverpod `Notifier` / `ref.watch()`
   - Express routes → Supabase RPC calls
   - Prisma queries → `fromRow()` / `toRow()` + Supabase client
   - TypeScript interfaces → Dart classes with `final` fields
3. Keep what transfers:
   - Layered architecture (Screens → Providers → Repositories → Services)
   - Separation of concerns
   - Error handling philosophy
   - Testing strategies

**Example — Adapting a backend skill for Supabase:**
```
I'll adapt this for Supabase + Dart:
- Replace Express routes → Supabase RPC functions (SQL)
- Replace Prisma models → Dart models with fromRow/toRow
- Replace JWT middleware → Supabase RLS policies
- Keep: Layered architecture, error handling, validation patterns
```

### Option 2: Extract Framework-Agnostic Patterns

**When to use:** Stacks are very different, but core principles apply.

**What transfers across stacks:**
- ✅ Layered architecture (Screens → Providers → Repositories)
- ✅ Repository pattern for data access
- ✅ Separation of concerns
- ✅ Error handling philosophy
- ✅ Testing strategies
- ✅ File organization (features/ pattern)

**What does NOT transfer:**
- ❌ React hooks → Different from Riverpod
- ❌ MUI components → Different from Flutter widgets
- ❌ Prisma queries → Different from Supabase client
- ❌ Express middleware → No equivalent (use RLS)
- ❌ npm/package.json → Use pubspec.yaml

### Option 3: Create From Scratch

**When to use:** Too different to adapt, or user wants Flutter-native patterns.

Follow `AGENTS.md` code style and use the modular pattern (main skill file + resource files).

---

## Common Integration Patterns

### Pattern: Adding a New Feature

1. Read `DEVELOPMENT_SPEC.md` (index) to find the relevant manual
2. Read the relevant `docs/*.md` manual for architecture context
3. Follow `AGENTS.md` code style (naming, imports, formatting)
4. Follow `riverpod_rule.md` for state management
5. Create files in the correct `lib/features/[feature]/` subdirectory:
   - `screens/` — UI screens (`ConsumerWidget`)
   - `providers/` — State (`Notifier`/`AsyncNotifier`)
   - `services/` — Business logic
   - `widgets/` — Reusable UI components
6. Run `flutter analyze` before committing

**Example — Adding a new screen:**
```dart
// lib/features/my_feature/screens/my_screen.dart
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class MyScreen extends ConsumerWidget {
  const MyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(myProvider);
    return Scaffold(
      body: Text(state.toString()),
    );
  }
}
```

### Pattern: Database Changes

1. Read `docs/03-data-architecture.md` for schema context
2. Create migration in `supabase/migrations/` with timestamp prefix:
   ```
   supabase/migrations/20260224_add_my_table.sql
   ```
3. Apply migration via Supabase MCP or CLI:
   ```bash
   supabase db push
   ```
4. Update Dart model with `fromRow()` / `toRow()`:
   ```dart
   factory MyModel.fromRow(Map<String, dynamic> row) => MyModel(
     id: row['id'] as String,
     name: row['name'] as String,
   );

   Map<String, dynamic> toRow() => {
     'name': name,
   };
   ```
5. Update provider if needed
6. Run `flutter test` to verify

### Pattern: Map/Hex Changes

1. Read `docs/02-ui-screens.md` for Mapbox patterns
2. Use `GeoJsonSource` + `FillLayer` pattern (NOT `PolygonAnnotationManager`)
3. Apply data-driven styling via `setStyleLayerProperty` with expressions:
   ```dart
   await mapboxMap.style.setStyleLayerProperty(
     _hexLayerId, 'fill-color', ['to-color', ['get', 'fill-color']],
   );
   ```
4. GeoJSON feature properties drive per-hex colors:
   ```json
   {
     "properties": {
       "fill-color": "#FF003C",
       "fill-opacity": 0.3,
       "fill-outline-color": "#FF003C"
     }
   }
   ```
5. Test on device (GPS simulation: `./simulate_run.sh`)

### Pattern: State Management Change

1. Read `riverpod_rule.md` for Riverpod 3.0 rules
2. Use `Notifier<T>` for synchronous state, `AsyncNotifier<T>` for async
3. Always check `ref.mounted` after async ops:
   ```dart
   Future<void> fetchData() async {
     final data = await someService.fetch();
     if (!ref.mounted) return;  // Critical: check before state update
     state = state.copyWith(data: data);
   }
   ```
4. Use `ref.watch()` for reactive state, `ref.read()` for one-off actions
5. Run `flutter analyze` — Riverpod lint rules catch common mistakes

### Pattern: Supabase RPC Call

1. Define the PostgreSQL function in a migration
2. Call via Dart:
   ```dart
   final result = await supabase.rpc('my_function', params: {
     'p_user_id': userId,
     'p_date': date.toIso8601String(),
   });
   ```
3. Handle errors with targeted try-catch:
   ```dart
   try {
     final result = await supabase.rpc('my_function', params: {...});
     return MyModel.fromRow(result as Map<String, dynamic>);
   } on PostgrestException catch (e) {
     debugPrint('RPC error: ${e.message}');
     rethrow;
   }
   ```

---

## Verification Checklist

After any integration, verify:

```bash
# 1. Hooks are executable
ls -la $CLAUDE_PROJECT_DIR/.claude/hooks/*.sh
# Should show: -rwxr-xr-x

# 2. skill-rules.json is valid JSON
cat $CLAUDE_PROJECT_DIR/.claude/skills/skill-rules.json | python3 -m json.tool
# Should parse without errors

# 3. Flutter analysis is clean
flutter analyze
# Should show: No issues found!

# 4. Tests pass
flutter test
# Should show: All tests passed!

# 5. Settings JSON is valid
cat $CLAUDE_PROJECT_DIR/.claude/settings.local.json | python3 -m json.tool
# Should parse without errors
```

**Checklist:**
- [ ] `.claude/skills/` directory has skill files
- [ ] `.claude/skills/skill-rules.json` is valid JSON with correct `pathPatterns`
- [ ] `.claude/hooks/` has hook scripts with execute permission (`chmod +x`)
- [ ] `.claude/commands/` has command markdown files
- [ ] `.claude/agents/` has agent markdown files
- [ ] `AGENTS.md` is readable and referenced by skills
- [ ] `riverpod_rule.md` is present and referenced by flutter-dev-guidelines skill
- [ ] `flutter analyze` returns no errors
- [ ] `flutter test` passes

---

## Common Mistakes to Avoid

### ❌ DON'T: Use npm/node_modules for hooks
**Why:** This is a Flutter/Dart project — no Node.js runtime
**DO:** Write hooks as shell scripts or Dart scripts

### ❌ DON'T: Reference TypeScript patterns in skills
**Why:** This project uses Dart, not TypeScript
**DO:** Use Dart equivalents (classes, `final`, `const`, `async/await`)

### ❌ DON'T: Use `print()` for logging
**Why:** Dart lint rules flag `print()` as a warning
**DO:** Use `debugPrint()` instead

### ❌ DON'T: Skip `flutter analyze` before committing
**Why:** Analysis catches type errors, unused imports, and lint violations
**DO:** Always run `flutter analyze` — treat errors as blockers

### ❌ DON'T: Mix Snapshot and Live data domains
**Why:** Critical architecture rule — see AGENTS.md "Two Data Domains"
**DO:** Snapshot domain = server data (read-only). Live domain = local runs (write). Never mix.

### ❌ DON'T: Use GPS hex for server data requests
**Why:** Server data is always anchored to home hex, not GPS position
**DO:** Use `PrefetchService.homeHex` for server calls, `PrefetchService.gpsHex` for map display only

### ❌ DON'T: Add code generation dependencies
**Why:** This project explicitly avoids build_runner, freezed, riverpod_generator
**DO:** Write models and providers manually following the patterns in AGENTS.md

### ❌ DON'T: Copy settings.json as-is from another project
**Why:** Hook paths and permissions are project-specific
**DO:** Extract only the sections needed and merge carefully

### ❌ DON'T: Skip making hooks executable
**Why:** Hooks won't run without execute permission
**DO:** Always `chmod +x` after copying hook scripts

---

## Example Integration Conversations

### Example 1: Adding a Flutter Skill

**User:** "Add a skill for Flutter widget development"

**Claude should:**
1. Check if `flutter-dev-guidelines` skill exists in `.claude/skills/`
2. If not, create it referencing `AGENTS.md` patterns
3. Update `skill-rules.json` with `"lib/**/*.dart"` path pattern
4. Respond:
```
✅ Added flutter-dev-guidelines skill!

Configuration:
- Triggers when editing files in lib/
- References AGENTS.md for code style
- References riverpod_rule.md for state management

Try it: Edit any .dart file in lib/ and the skill should activate.
```

### Example 2: Database Schema Change

**User:** "Add a new table for user achievements"

**Claude should:**
1. Read `docs/03-data-architecture.md` for schema context
2. Create migration: `supabase/migrations/20260224_add_achievements.sql`
3. Apply via Supabase MCP (`apply_migration`)
4. Create Dart model: `lib/data/models/achievement.dart` with `fromRow`/`toRow`
5. Create repository if needed: `lib/data/repositories/achievement_repository.dart`
6. Run `flutter analyze` to verify
7. Respond:
```
✅ Added achievements table!

What I did:
- Created migration: supabase/migrations/20260224_add_achievements.sql
- Created Dart model: lib/data/models/achievement.dart
- Added fromRow/toRow serialization
- flutter analyze: No issues found

Next: Create a provider in lib/features/profile/providers/ to expose achievements.
```

### Example 3: Tech Stack Mismatch

**User:** "Add the React frontend skill to this project"

**Claude should respond:**
```
This project uses Flutter/Dart, not React. The React frontend skill won't
apply directly. I can:

Option 1 (Recommended): Create a flutter-dev-guidelines skill using the
React skill's structure as a template. I'll adapt:
- React components → Flutter ConsumerWidget
- useState/useEffect → Riverpod Notifier
- MUI components → Flutter Material widgets
- Keep: File organization, performance principles, error handling

Option 2: Extract only the framework-agnostic patterns (file organization,
separation of concerns, testing strategies) without React-specific code.

Option 3: Skip it — AGENTS.md already covers Flutter-specific guidelines.

Which would you prefer?
```

### Example 4: Adding an Agent

**User:** "Add the code-architecture-reviewer agent"

**Claude should:**
1. Copy agent file to `.claude/agents/`
2. Check for hardcoded paths (update if found)
3. Respond:
```
✅ Added code-architecture-reviewer agent!

Use it by running the Task tool with:
- subagent_type: "code-architecture-reviewer"
- prompt: Description of code to review

The agent will review your Flutter/Dart code for architectural issues,
checking against the patterns in AGENTS.md.
```

---

## Quick Reference Tables

### What Needs Customization?

| Component | Tech Requirements | Customization | What to Ask |
|-----------|------------------|--------------|-------------|
| **flutter-dev-guidelines** | Flutter/Dart | ⚠️ Path patterns | "Where is lib/ located?" |
| **supabase-patterns** | supabase_flutter | ⚠️ Path patterns | "Where are migrations?" |
| **mapbox-hex-patterns** | mapbox_maps_flutter | ⚠️ Path patterns | "Where is map feature?" |
| **skill-developer** | None | ✅ None | Copy as-is |
| **git-master** | None | ✅ None | Copy as-is |
| **systematic-debugging** | None | ✅ None | Copy as-is |
| **post-tool-use-tracker** | None | ✅ None | Copy as-is |
| **skill-activation-prompt** | None | ✅ None | Copy as-is |
| **All agents** | Minimal | ⚠️ Check paths | Read file first |
| **All commands** | None | ⚠️ Verify paths | Check docs/ references |

### When to Recommend Skipping

| Component | Skip If... |
|-----------|-----------|
| **React/Vue/Angular skills** | Always — this is Flutter/Dart |
| **Node.js/Express skills** | Always — no backend server |
| **Prisma/TypeORM skills** | Always — use Supabase client |
| **JWT cookie auth skills** | Always — use Supabase Auth |
| **tsc-check hooks** | Always — use `flutter analyze` instead |
| **npm-based hooks** | Always — no Node.js runtime |

### Flutter-Specific Commands Reference

```bash
flutter pub get          # Install dependencies (≈ npm install)
flutter analyze          # Static analysis (≈ tsc --noEmit + eslint)
dart format .            # Format code (≈ prettier)
flutter test             # Run tests (≈ jest)
flutter test --coverage  # Run with coverage
flutter run -d ios       # Run on iOS Simulator
flutter run -d android   # Run on Android Emulator
flutter build ios        # Build iOS release
flutter build apk        # Build Android release
./simulate_run.sh        # GPS simulation for testing
```

---

## Final Tips for Claude

**When user says "add everything":**
- Start with essentials: skill-activation hook + flutter-dev-guidelines
- Don't add skills for tech stacks not used (no React, no Node.js skills)
- Ask what they actually need

**When something doesn't work:**
- Run `flutter analyze` — catches most Dart/Flutter issues
- Check `skill-rules.json` path patterns match actual project structure
- Verify hooks have execute permission (`chmod +x`)
- Check for JSON syntax errors in settings files

**When user is unsure:**
- Recommend starting with `flutter analyze` hook + flutter-dev-guidelines skill
- Add supabase-patterns if working on database features
- Add mapbox-hex-patterns if working on map features

**Always explain what you're doing:**
- Show the commands you're running
- Explain why you're asking questions
- Provide clear next steps after integration
- Reference `AGENTS.md` sections when explaining architecture decisions

**Critical architecture rules to always remember:**
- Two data domains: Snapshot (server, read-only) vs Live (local runs, write)
- Location separation: Home hex for server data, GPS hex for map display
- No realtime/WebSocket — sync on launch, OnResume, and run completion
- Config frozen during active runs (`RemoteConfigService().freezeForRun()`)
- Hex snapshot = daily freeze at midnight GMT+2, not live `hexes` table

---

**Remember:** This is a Flutter/Dart mobile app with a Supabase backend. Every pattern, skill, and hook must be compatible with this stack. When in doubt, read `AGENTS.md` — it is the authoritative source for all coding decisions in this project.
