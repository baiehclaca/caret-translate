# CaretTranslate (Documents) - Shared Task File

## Purpose
Track the project's actionable tasks, owners, dependencies, and outcomes for CaretTranslate in Documents.

## Usage
- Update statuses as work progresses.
- Add outcomes and timestamps when tasks complete.
- Keep dependencies explicit and avoid ambiguous tasks.

## Parameters
- **Status:** one of `pending`, `in_progress`, `blocked`, `done`.
- **Owner:** responsible agent tag (e.g., `@codex`).
- **Dependency:** upstream task IDs required before start.
- **Review:** mandatory reviewer for security-sensitive tasks.

## Examples
- Task format: `CTD-001 | Add language ID and mixed-language routing | Status: in_progress | Owner: @codex | Dependency: none | Review: n/a`

## Tasks
- CTD-001 | Add Apple NaturalLanguage word-level language identification in core decision logic | Status: done | Owner: @codex | Dependency: none | Review: n/a
- CTD-002 | Wire NaturalLanguage identifier into the app translation coordinator with decision logging | Status: done | Owner: @codex | Dependency: CTD-001 | Review: n/a
- CTD-003 | Add unit and integration tests for mixed-language decision behavior | Status: done | Owner: @codex | Dependency: CTD-001 | Review: n/a
- CTD-004 | Run tests and record results | Status: done | Owner: @codex | Dependency: CTD-003 | Review: n/a
- CTD-005 | Fix CoreML Float16 logits conversion crash | Status: done | Owner: @codex | Dependency: none | Review: n/a
- CTD-006 | Add local-only mode and language pack management UI with pack-backed dictionary translation | Status: done | Owner: @codex | Dependency: none | Review: n/a
- CTD-007 | Add language pack tests, documentation, and test logs | Status: done | Owner: @codex | Dependency: CTD-006 | Review: n/a
- CTD-008 | Remove DeepL and language packs; switch to Apple Translation and slim settings tabs | Status: done | Owner: @codex | Dependency: none | Review: n/a
- CTD-009 | Add mixed-language word replacement pass before sentence translation | Status: done | Owner: @codex | Dependency: none | Review: n/a
- CTD-010 | Add FreeDict hybrid packs with auto-download and dynamic language catalog | Status: done | Owner: @codex | Dependency: none | Review: n/a
- CTD-011 | Remove FreeDict integration and revert to Apple Translation-only language catalog | Status: done | Owner: @codex | Dependency: none | Review: n/a
- CTD-012 | Route auto-detected NLLB-only languages to NLLB and add Tagalog alias mapping | Status: done | Owner: @codex | Dependency: none | Review: n/a
- CTD-013 | Tighten mixed-language detection to avoid false positives on non-target sentences | Status: done | Owner: @codex | Dependency: none | Review: n/a
- CTD-014 | Add launch-at-login setting and ServiceManagement sync | Status: done | Owner: @codex | Dependency: none | Review: n/a
- CTD-015 | Add Accessibility text replacement fallback for Discord-style fields | Status: done | Owner: @codex | Dependency: none | Review: n/a
- CTD-016 | Add first-run launch-at-login onboarding screen | Status: done | Owner: @codex | Dependency: CTD-014 | Review: n/a
- CTD-017 | Add silent warm-up translation on app launch to reduce first-translation latency | Status: done | Owner: @codex | Dependency: none | Review: n/a
- CTD-018 | Normalize invalid language selections on launch and add tests | Status: done | Owner: @codex | Dependency: none | Review: n/a
- CTD-019 | Add diacritic restoration pass for common Slovak/Czech phrases | Status: done | Owner: @codex | Dependency: none | Review: n/a
- CTD-020 | Enable universal translation by removing privacy filtering | Status: done | Owner: @codex | Dependency: none | Review: n/a

## Outcomes Log
- 2026-02-02: Added Apple NaturalLanguage-based word language identification, updated translation routing, and added tests. (Owner: @codex)
- 2026-02-02: Test run blocked by SwiftPM manifest cache conflict in Xcode build; resolved by removing manifest cache file. (Owner: @codex)
- 2026-02-02: `xcodebuild test` passed (scheme: CaretTranslate). (Owner: @codex)
- 2026-02-02: Fixed CoreML Float16 logits conversion to prevent MLShapedArray crash; `xcodebuild test` passed. (Owner: @codex)
- 2026-02-02: Added local-only translation mode, language pack manager UI, and pack-backed dictionary translation with tests and docs; `xcodebuild test` passed. (Owner: @codex)
- 2026-02-03: Removed DeepL and language pack surfaces, integrated Apple Translation, and reduced Settings to General/Privacy/History. (Owner: @codex)
- 2026-02-03: Added mixed-language word translation pass with sentence fallback; updated tests. (Owner: @codex)
- 2026-02-03: Added FreeDict catalog integration, auto-download pack manager, dictd lookup, and hybrid word translation routing. (Owner: @codex)
- 2026-02-03: Removed FreeDict integration and returned to Apple Translation-only language list and routing. (Owner: @codex)
- 2026-02-03: Routed auto-detected NLLB-only sources to NLLB, added Tagalog alias mapping, and updated tests. (Owner: @codex)
- 2026-02-03: Tightened mixed-language detection to avoid false positives and added tests. (Owner: @codex)
- 2026-02-03: Added launch-at-login setting with ServiceManagement sync and fallback text replacement for Discord-style fields. (Owner: @codex)
- 2026-02-03: Added first-run onboarding window to request launch-at-login permission. (Owner: @codex)
- 2026-02-04: Added silent warm-up translation on app launch with cancellation and tests. (Owner: @codex)
- 2026-02-04: Normalized invalid language selections on launch, fixed language code casing, and added tests. (Owner: @codex)
- 2026-02-04: Added diacritic restoration pass for Slovak/Czech phrase input and tests. (Owner: @codex)
- 2026-02-04: Removed privacy filtering system; translation now works in all apps except secure fields. (Owner: @codex)
