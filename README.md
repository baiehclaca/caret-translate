# CaretTranslate

CaretTranslate is a macOS menu bar helper that replaces whichever word is closest to the caret with a translation. It blends DeepL sentence-level quality, a local dictionary fallback, contextual fixes, and a configurable user experience so you can translate words without leaving your keyboard.

## Highlights
- **Instant trigger**: double-tap Tab or a custom hotkey prefetches the translation and caches it for snappy replacements.
- **DeepL power**: automatic language detection, formality control, and performance modes backed by DeepL plus optional Qwen contextual fixing.
- **Privacy-first design**: secure-field filtering, per-app allow/deny lists, encrypted history/cache storage, and explicit Clear buttons.
- **Preview & history**: confirm replacements before applying them and review the encrypted history with retention controls and a confirmation dialog.
- **System health + debug**: a Status tab reports Accessibility/Input Monitoring permissions and API key status, while the Debug Log shows runtime events.
- **Experimental tools**: custom dictionary entries for specific language pairs and a drawer to stage replacements before committing.

## Controls
- **Menu bar**: click the caret icon (or “Translate” word) for “Translate Now”, Languages, Settings, Debug Log, and Quit.
- **Shortcut modes**: choose double-tap Tab (default) or configure a custom hotkey in Settings > General > Shortcut.
- **Quick languages**: swap source/target directly inside the Languages submenu in the menu bar item.
- **Preview**: a modal shows the original word and replacement before it is committed.

## Settings overview

### General
- Save your DeepL API key, load supported languages, and pick Auto Detect when needed.
- Pick source/target languages, toggle preview, and fine-tune formality/performance.
- Configure shortcut mode or hotkey (with modifiers and key capture).
- Clear Translation Cache (encrypted on disk) with a single tap.

### Privacy
- Manage allowlist/denylist plus secure-field detection.
- Translation attempts to secure fields are always blocked.

### History
- Enable/disable history, limit retention count/days, and Clear History with confirmation.
- All entries are encrypted locally and can be purged on demand.

### Status
- Health indicators for Accessibility, Input Monitoring, and the DeepL API key.
- Refresh button re-checks permissions and API availability.

### Experimental
- Custom dictionary editor pairs incoming words with preferred replacements per language pair.
- Clear All removes every custom entry.

## Security & data use
- Text is read only after the hotkey is triggered.
- Translations are sent to DeepL when an API key is configured.
- API key, history, and cache are encrypted with a Keychain-backed store.
- No analytics, crash reporting, or tracking is included by default.

## Permissions
CaretTranslate requests:
- **Accessibility** to read and replace text in the focused app.
- **Input Monitoring** to detect the shortcut/tap.

## Running locally
```bash
swift run CaretTranslateApp
```
After launching, grant the requested permissions in System Settings > Privacy & Security so the shortcuts work.

## Tests
```bash
swift test
```

## Screenshots
Drop the provided artwork into the docs folder and update the paths if needed:
- `docs/screenshots/history.png` (History tab + log)
- `docs/screenshots/status.png` (Status health indicators)
- `docs/screenshots/experimental.png` (Custom dictionary editor)
- `docs/screenshots/debug-log.png` (Debug log window)
- `docs/screenshots/preview-dialog.png` (Preview translation modal)
- `docs/screenshots/menu-bar.png` (Menu bar caret + menu)
- `docs/screenshots/caret-icon.png` (Status item icon)

## Roadmap
- Per-app presets for privacy allowlists.
- Improved preview automation.
- Optional offline/LLM translation fallback for very low-connectivity scenarios.
