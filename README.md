# CaretTranslate

CaretTranslate is a macOS menu bar app that replaces the nearest word to the caret with a translation. It uses DeepL for sentence translation, an offline dictionary for word fallback, and an optional local contextual fixer to keep grammar correct.

## Features
- Global shortcut: double-tap Tab or custom hotkey.
- Sentence-aware replacement around the caret.
- Auto-detect source language (DeepL) or choose a specific source.
- Preview and confirm before replacing text.
- Privacy controls: allowlist/denylist and secure-field blocking.
- Translation history with retention controls.
- Translation cache for faster repeat translations (clearable).
- Quick language switcher in the menu bar.
- Quality knobs: formality and performance (fast/balanced/quality).
- Debug log window and status health checks.
- Experimental custom dictionary editor.

## Controls
- Translate now: menu bar item "Translate Now".
- Shortcut mode: double-tap Tab or custom hotkey (Settings > General).
- Quick language switcher: menu bar > Languages.

## Settings
### General
- DeepL API key
- Source and target languages (includes Auto Detect)
- Shortcut mode and hotkey
- Preview before replacing
- Formality and performance
- Clear translation cache

### Privacy
- Allowlist/denylist apps
- Secure-field blocking (automatic)

### History
- Enable/disable history
- Retention count and days
- Clear history

### Status
- Accessibility permission
- Input Monitoring permission
- API key configured

### Experimental
- Custom dictionary editor (per language pair)

## Permissions
The app needs:
- Accessibility (to read and replace text in other apps)
- Input Monitoring (for global shortcuts)

## Run
Open the package in Xcode and run the `CaretTranslateApp` target. Then enable permissions in System Settings > Privacy & Security.

## Tests
Run `swift test` from the package root.

## Screenshots
Add screenshots here (drag-drop or replace placeholders):
- `docs/screenshots/menu-bar.png`
- `docs/screenshots/preview.png`
- `docs/screenshots/settings-general.png`
- `docs/screenshots/settings-privacy.png`
- `docs/screenshots/settings-history.png`
- `docs/screenshots/status.png`

## Privacy & Data Use (App Store Draft)
- Text is read from the focused app only when you trigger a translation.
- Translations are sent to DeepL when enabled.
- API key is stored encrypted locally (Keychain-backed).
- Translation history and cache are stored locally, encrypted at rest, and can be cleared anytime.
- No analytics or tracking is included by default.

## Roadmap
- Preview UI polish and keyboard shortcuts.
- Allowlist presets for popular apps.
- Open-source offline translation option.
- Per-app language rules.
