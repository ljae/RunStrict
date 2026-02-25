# CLAUDE.md — RunStrict

> This file points to the main AI coding guide. All guidelines are in AGENTS.md.

## Primary Reference

**→ [AGENTS.md](./AGENTS.md)** — Comprehensive coding guidelines, code style, patterns, do's/don'ts.

## Additional References

| File | Purpose |
|------|---------|
| [riverpod_rule.md](./riverpod_rule.md) | Riverpod 3.0 state management rules (**MUST** follow) |
| [DEVELOPMENT_SPEC.md](./DEVELOPMENT_SPEC.md) | Index → detailed manuals under `docs/` |
| [CLAUDE_INTEGRATION_GUIDE.md](./CLAUDE_INTEGRATION_GUIDE.md) | Claude Code environment setup |

## Quick Reminders

- **Tech Stack**: Flutter 3.10+, Dart, Riverpod 3.0 (manual providers, NO code gen), Mapbox, Supabase, H3
- **State Management**: Riverpod 3.0 only — NO ChangeNotifier, StateNotifier, or legacy provider package
- **Architecture**: Serverless (Flutter → Supabase RLS, no backend API server)
- **Logging**: Use `debugPrint()`, never `print()`
- **Before committing**: Run `flutter analyze`
