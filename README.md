# CaretTranslate

CaretTranslate is a macOS background helper that replaces the nearest word to the caret with an offline translation when you double-tap Tab.

## What is included
- Core translation logic with unit tests.
- A menu bar app stub that requests Accessibility permission and registers a global double-tap Tab shortcut (single Tab is delayed briefly to detect the double-tap).
- A Settings window (SwiftUI) for choosing source/target languages.
- Offline dictionary file (`dictionary.json`) for the Slovak -> English example.

## Permissions
The app needs:
- Accessibility (to read and replace text in other apps)
- Input Monitoring (for the global shortcut)

## Run
Open the package in Xcode and run the `CaretTranslateApp` target. Then enable permissions in System Settings > Privacy & Security.

## Tests
Run `swift test` from the package root.
