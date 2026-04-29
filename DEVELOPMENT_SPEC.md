# RunStrict Development Specification

> Documentation has been reorganized for AI-friendly indexing.
> **This file is now a pointer** — the real index lives at [`docs/INDEX.md`](./docs/INDEX.md).

---

## Where to Go

| You want… | Open |
|---|---|
| AI routing index (terse) | [`CLAUDE.md`](./CLAUDE.md) |
| Full doc index (humans + AI) | [`docs/INDEX.md`](./docs/INDEX.md) |
| Project overview + architecture rules | [`AGENTS.md`](./AGENTS.md) |
| Production invariants (61) | [`error-fix-history.md`](./error-fix-history.md) |
| Game rules · UI · data · sync · changelog | [`docs/01-…`](./docs/01-game-rules.md) through [`docs/05-…`](./docs/05-changelog.md) |
| Coding style & 500-line file ceiling | [`docs/style/code-style.md`](./docs/style/code-style.md) |

**Tech**: Flutter 3.10+ · Dart · Riverpod 3.0 · Mapbox · Supabase · H3 · SQLite v15.
**Architecture**: Serverless (Flutter → Supabase RLS, no backend API server).
