# Universal Translation Support Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Enable double tab translation in all applications by removing privacy filtering while maintaining secure field protection.

**Architecture:** Remove the entire PrivacyFilter system from TranslationCoordinator, delete privacy settings from SettingsStore, and remove Privacy UI tab. Translation will work universally except in secure fields (passwords, credit cards).

**Tech Stack:** Swift, SwiftUI, AppKit, Xcode

---

## Task 1: Simplify Translation Coordinator Privacy Check

**Files:**
- Modify: `CaretTranslate/App/TranslationCoordinator.swift:168-171`
- Modify: `CaretTranslate/App/TranslationCoordinator.swift:20-24` (init)
- Modify: `CaretTranslate/App/TranslationCoordinator.swift:9` (property)

**Step 1: Remove PrivacyFilter property and initialization**

In `TranslationCoordinator.swift`, remove the `privacyFilter` property (line ~9) and its initialization (line ~23).

Remove:
```swift
private let privacyFilter: PrivacyFilter
```

Remove from init:
```swift
self.privacyFilter = PrivacyFilter(settings: settings)
```

**Step 2: Simplify prepareTranslation privacy check**

Replace the privacy filter check at lines 168-171 with a secure field-only check:

Replace:
```swift
if !privacyFilter.isAllowed(bundleId: bundleId, isSecureField: capture.isSecureField) {
    DebugLogger.log("Translation blocked by privacy rules")
    return nil
}
```

With:
```swift
if capture.isSecureField {
    DebugLogger.log("Translation blocked: secure field")
    return nil
}
```

**Step 3: Build to verify no compilation errors**

Run: `xcodebuild build -scheme CaretTranslate -destination 'platform=macOS'`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add CaretTranslate/App/TranslationCoordinator.swift
git commit -m "Remove privacy filter from translation coordinator

Translation now works in all apps, blocked only by secure fields.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 2: Delete PrivacyFilter File

**Files:**
- Delete: `CaretTranslate/App/PrivacyFilter.swift`

**Step 1: Remove PrivacyFilter.swift from project**

Run: `rm CaretTranslate/App/PrivacyFilter.swift`

**Step 2: Build to verify no compilation errors**

Run: `xcodebuild build -scheme CaretTranslate -destination 'platform=macOS'`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add CaretTranslate/App/PrivacyFilter.swift
git commit -m "Delete PrivacyFilter class

No longer needed for universal translation support.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 3: Remove Privacy Settings from SettingsStore

**Files:**
- Modify: `CaretTranslate/Core/SettingsStore.swift`

**Step 1: Read SettingsStore to identify privacy properties**

Read `CaretTranslate/Core/SettingsStore.swift` and locate:
- `denylistBundleIds` property
- `allowlistBundleIds` property

**Step 2: Remove privacy properties**

Remove both properties and their @AppStorage wrappers from SettingsStore.

**Step 3: Build to verify no compilation errors**

Run: `xcodebuild build -scheme CaretTranslate -destination 'platform=macOS'`
Expected: BUILD SUCCEEDED (or compilation errors in Settings UI - we'll fix next)

**Step 4: Commit**

```bash
git add CaretTranslate/Core/SettingsStore.swift
git commit -m "Remove privacy settings from SettingsStore

Denylist and allowlist no longer needed for universal translation.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 4: Delete PrivacySettingsView

**Files:**
- Delete: `CaretTranslate/App/PrivacySettingsView.swift`

**Step 1: Remove PrivacySettingsView.swift**

Run: `rm CaretTranslate/App/PrivacySettingsView.swift`

**Step 2: Build (may fail, fixed in next task)**

Run: `xcodebuild build -scheme CaretTranslate -destination 'platform=macOS'`
Expected: May fail if SettingsView still references it

**Step 3: Commit**

```bash
git add CaretTranslate/App/PrivacySettingsView.swift
git commit -m "Delete PrivacySettingsView

Privacy tab no longer needed in Settings window.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 5: Remove Privacy Tab from SettingsView

**Files:**
- Modify: `CaretTranslate/App/SettingsView.swift`

**Step 1: Read SettingsView to locate Privacy tab**

Read `CaretTranslate/App/SettingsView.swift` and identify the Privacy tab in the TabView.

**Step 2: Remove Privacy tab**

Remove the TabView entry that includes `PrivacySettingsView()`. Keep only:
- General tab
- History tab

**Step 3: Build to verify compilation**

Run: `xcodebuild build -scheme CaretTranslate -destination 'platform=macOS'`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add CaretTranslate/App/SettingsView.swift
git commit -m "Remove Privacy tab from Settings window

Settings now shows only General and History tabs.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 6: Delete or Update Privacy Filter Tests

**Files:**
- Check: `CaretTranslateTests/PrivacyFilterTests.swift`
- Modify or Delete based on existence

**Step 1: Check if PrivacyFilterTests exists**

Run: `ls CaretTranslateTests/PrivacyFilterTests.swift 2>/dev/null || echo "not found"`

**Step 2: Delete test file if it exists**

If found: `rm CaretTranslateTests/PrivacyFilterTests.swift`

**Step 3: Build and run tests**

Run: `xcodebuild test -scheme CaretTranslate -destination 'platform=macOS'`
Expected: All tests pass (or identify failures to fix)

**Step 4: Commit**

```bash
git add CaretTranslateTests/PrivacyFilterTests.swift
git commit -m "Delete PrivacyFilterTests

Tests no longer relevant after removing privacy filtering.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 7: Run Full Test Suite and Verify

**Files:**
- All test files

**Step 1: Run complete test suite**

Run: `xcodebuild test -scheme CaretTranslate -destination 'platform=macOS'`

**Step 2: Review test results**

Expected: All tests pass. If failures:
- Review failed tests
- Determine if they rely on removed privacy functionality
- Update or remove tests as needed

**Step 3: Manual verification**

1. Build and run app
2. Test double tab translation in multiple apps
3. Verify secure fields still block translation
4. Check Settings window shows only General and History tabs

**Step 4: Document verification**

Add to TASKS.md:
```
- CTD-020 | Enable universal translation by removing privacy filtering | Status: done | Owner: @codex | Dependency: none | Review: n/a
```

And outcomes:
```
- 2026-02-04: Removed privacy filtering system; translation now works in all apps except secure fields. (Owner: @codex)
```

**Step 5: Final commit if changes needed**

If any test fixes were required:
```bash
git add -A
git commit -m "Fix tests after privacy filter removal

All tests now pass with universal translation support.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Success Criteria

- [ ] Build succeeds without errors
- [ ] All tests pass
- [ ] Double tab translation works in all applications
- [ ] Secure fields still block translation
- [ ] Settings window shows only General and History tabs
- [ ] PrivacyFilter.swift deleted
- [ ] PrivacySettingsView.swift deleted
- [ ] PrivacyFilterTests.swift deleted (if existed)
- [ ] Privacy properties removed from SettingsStore
- [ ] Clean git history with atomic commits

---

## Risk Assessment

**Low risk changes:**
- Removing UI elements (Settings tab)
- Deleting unused test files
- Simplifying boolean checks

**Medium risk:**
- Modifying TranslationCoordinator (core translation logic)
- Removing settings properties (could break user defaults)

**Mitigation:**
- Frequent builds after each change
- Test suite run before final verification
- Manual testing in multiple apps

**Rollback plan:**
If issues arise, revert commits in reverse order using `git revert`.
