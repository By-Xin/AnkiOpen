# Progress

Last updated: 2026-05-31

## Done

- Created native iOS SwiftUI project targeting iOS 16+.
- Added local Core Data persistence with notebook, card, review log, and import batch entities.
- Implemented notebook CRUD, card CRUD, card archive, CSV import, due-card query, and study review flow.
- Added optional CSV audio import with shared audio or separate front/back audio columns.
- Added local audio file storage and Study playback controls for both card sides.
- Integrated the FSRS Swift package at version 5.0.0 through Swift Package Manager.
- Added a local scheduler fallback so development type-checking can continue when the package is unavailable.
- Added unit test coverage for CSV import, audio import, duplicate handling, due queries, and review scheduling.
- Added a UI launch smoke test.
- Created the public GitHub repository and pushed `main`: https://github.com/By-Xin/AnkiOpen
- Built and launched the app in the iPhone 17 simulator on iOS 26.5.
- Created initial GitHub Issues for FSRS, CSV import polish, backup/export, visual polish, and CI.

## Verification

- Passed Swift type-checking against the iOS 16 simulator target with:
  `swiftc -typecheck -parse-as-library -module-cache-path DerivedData/ModuleCache -sdk /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator26.5.sdk -target arm64-apple-ios16.0-simulator ...`
- Xcode resolved `open-spaced-repetition/swift-fsrs` 5.0.0 and wrote `Package.resolved`.
- Passed Xcode build:
  `xcodebuild -project AnkiOpen.xcodeproj -scheme AnkiOpen -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -derivedDataPath DerivedData build CODE_SIGNING_ALLOWED=NO`
- Passed Xcode tests:
  `xcodebuild test -project AnkiOpen.xcodeproj -scheme AnkiOpen -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO`
- Manual simulator smoke test passed: create notebook, create card, study due card, reveal answer, rate `Good`, and confirm the due queue clears.

## Current Study Behavior

- The Study tab currently loads unarchived cards with `dueAt <= now`, ordered by due date.
- It supports reviewing all notebooks or one selected notebook.
- It does not yet support custom study sessions or forced learning of cards that are not due.

## CSV Audio Import

- Supported CSV shapes:
  - `front,back`
  - `front,back,audio` where one audio file is used on both sides
  - `front,back,frontAudio,backAudio` where each side can use a different file
- During import, select the CSV file and any referenced audio files together.
- Supported audio extensions: `mp3`, `m4a`, `aac`, `wav`, `caf`, `aiff`, `aif`.
- Audio files are copied into app-local storage under Application Support.

## Blocked

- The upstream `swift-fsrs` 5.0.0 package builds, but its scheduler initializer and `next` method are not public, so the app currently uses the local scheduler fallback.

## Next

- Decide whether to fork/patch `swift-fsrs` or replace it with an FSRS implementation whose scheduler API is public.
- Add custom study and forced learning modes.
- Replace the default app icon and add a basic visual identity.
- Add export/backup support.
