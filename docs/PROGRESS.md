# Progress

Last updated: 2026-05-31

## Done

- Created native iOS SwiftUI project targeting iOS 16+.
- Added local Core Data persistence with notebook, card, review log, and import batch entities.
- Implemented notebook CRUD, card CRUD, card archive, CSV import, due-card query, and study review flow.
- Integrated the FSRS Swift package at version 5.0.0 through Swift Package Manager.
- Added a local scheduler fallback so development type-checking can continue when the package is unavailable.
- Added unit test coverage for CSV import, duplicate handling, due queries, and review scheduling.
- Added a UI launch smoke test.

## Verification

- Passed Swift type-checking against the iOS 16 simulator target with:
  `swiftc -typecheck -parse-as-library -module-cache-path DerivedData/ModuleCache -sdk /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator26.5.sdk -target arm64-apple-ios16.0-simulator ...`
- Xcode resolved `open-spaced-repetition/swift-fsrs` 5.0.0 and wrote `Package.resolved`.

## Blocked

- Full `xcodebuild build/test` is blocked on this machine because no usable iOS Simulator destination is available from the current Xcode installation.
- GitHub repository creation is blocked because `gh` is not authenticated and the available GitHub connector tools do not expose repository creation.

## Next

- Authenticate GitHub CLI with `gh auth login`, then create and push the public repository.
- Open the project in Xcode, install any missing iOS simulator runtime if prompted, and run the `AnkiOpen` scheme.
- Replace the default app icon and add a basic visual identity.
- Add export/backup support after the MVP is usable on device.
