# Universal Translation Support Design

## Goal
Enable double tab translation in all applications by removing privacy filtering, while maintaining secure field protection.

## Current State
- `PrivacyFilter` checks bundle IDs against allowlist/denylist
- Translation blocked if app not in allowlist or is in denylist
- Secure fields always blocked (correct behavior)
- Privacy settings stored in `SettingsStore`
- Privacy UI tab in Settings window

## Proposed Changes

### 1. Core Translation Flow
**File:** `TranslationCoordinator.swift`

Simplify `prepareTranslation()` method (line 168-171):
- Remove `privacyFilter.isAllowed()` check
- Keep only secure field check
- Bundle ID still captured for history tracking

```swift
if capture.isSecureField {
    DebugLogger.log("Translation blocked: secure field")
    return nil
}
```

### 2. Remove Privacy Filter
**File:** `PrivacyFilter.swift`

Delete entire file - no longer needed.

### 3. Settings Cleanup
**File:** `SettingsStore.swift`

Remove properties:
- `denylistBundleIds: [String]`
- `allowlistBundleIds: [String]`

**File:** `TranslationCoordinator.swift`

Remove:
- `privacyFilter` property
- `PrivacyFilter` initialization

**File:** `AppDelegate.swift`

No changes needed (doesn't reference PrivacyFilter directly).

### 4. UI Cleanup
**File:** `PrivacySettingsView.swift`

Delete entire file - no longer needed.

**File:** `SettingsView.swift`

Remove Privacy tab from TabView. Remaining tabs:
- General (shortcuts, preview, launch at login)
- History (translation history)

### 5. Test Updates
**Files:** `PrivacyFilterTests.swift`, other affected tests

Delete or update tests that rely on privacy filtering behavior.

## Benefits
- Simpler codebase - removes entire privacy filtering system
- Translation works in all apps by default
- Maintains security by blocking sensitive fields
- No user confusion about app allowlists

## Migration
Existing users with privacy settings will have them ignored. No data migration needed - just removing unused functionality.

## Success Criteria
- Double tab translation works in all applications
- Secure fields (passwords, credit cards) still blocked
- Privacy settings UI removed
- All tests pass
