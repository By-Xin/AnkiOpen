# Progress

Last updated: 2026-06-02

## Done

- Created native iOS SwiftUI project targeting iOS 16+.
- Added local Core Data persistence with notebook, unit, card, review log, and import batch entities.
- Implemented notebook CRUD, unit CRUD, card CRUD, card archive, CSV import, due-card query, and study review flow.
- Added `Notebook -> Unit -> Card` navigation and unit-scoped study entry points.
- Added optional CSV audio import with shared audio or separate front/back audio columns.
- Added optional CSV `unit` column. Blank unit values import into `Default`; numeric values import as `Unit 1`, `Unit 2`, etc.
- Added local audio file storage and Study playback controls for both card sides.
- Added Study mode selection for scheduled due review, all-card custom study, and forced not-yet-due learning.
- Added JSON backup export from Settings, including notebooks, units, cards, audio references, FSRS fields, and review logs.
- Added JSON backup restore from Settings with duplicate handling for notebooks, units, cards, and review logs.
- Upgraded backups to `schemaVersion: 3` so referenced audio files are embedded in JSON and restored into local audio storage.
- Integrated the FSRS Swift package at version 5.0.0 through Swift Package Manager.
- Added an app-local FSRS-6 scheduler with default parameters and retention `0.90`, replacing the earlier simplified fallback in the production review path.
- Added DeepSeek settings with Keychain API key storage, V4 Flash/V4 Pro model selection, and rare glyph replacement suggestions.
- Replaced the static rare glyph image fallback flow with a DeepSeek suggestion flow that caches replacement suggestions and can apply them to affected cards.
- Added a Dictionary tab backed by CZYZD lookup for Chaoshan words, Chaoshan pronunciation, cleaned definitions, and remote audio playback.
- Added optional CSV `czyzd` / `查词` dictionary lookup columns. Rows with a blank back can now be imported when a lookup term is provided, then enriched from CZYZD after import.
- Added Dictionary actions to save a CZYZD result into a new notebook and to build a `CZYZD Dictionary` notebook from a bundled common-character seed list in resumable batches.
- Replaced the bottom tab bar with a hierarchical Chinese home screen: 开始学习, 工具, and 笔记本.
- Localized the main visible workflows into Chinese, including study, import, dictionary, settings, card editing, reports, and rare glyphs.
- Moved Study answer/rating controls into a safe-area bottom inset so they no longer cover card text.
- Added CZYZD audio download when saving dictionary entries or batch-building dictionary notebooks; stored audio is attached to both sides of the generated card.
- Added unit test coverage for CSV import, unit import, audio import, duplicate handling, study mode queries, unit-scoped due queries, FSRS-6 review scheduling, CZYZD dictionary parsing, CZYZD import enrichment, DeepSeek suggestion parsing, backup export, backup restore, media restore, and v2 backup compatibility.
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
- Passed Xcode tests on 2026-06-01:
  `xcodebuild test -project AnkiOpen.xcodeproj -scheme AnkiOpen -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath DerivedData`
- Passed Xcode tests after CZYZD dictionary lookup on 2026-06-01: 52 unit/app tests and 1 UI launch smoke test.
- Passed Xcode tests after CSV CZYZD auto-fill on 2026-06-01: 54 unit/app tests and 1 UI launch smoke test.
- Passed Xcode tests after CZYZD dictionary parsing cleanup on 2026-06-01: 55 unit/app tests and 1 UI launch smoke test.
- Passed Xcode tests after Chinese home/localization and CZYZD dictionary audio card saving on 2026-06-02: 60 unit/app tests and 1 UI launch smoke test.
- Built and installed the app to the connected iPhone on 2026-06-02. Launch was blocked by iOS because the device was locked.
- Manual simulator smoke test passed: create notebook, create card, study due card, reveal answer, rate `Good`, and confirm the due queue clears.

## Current Study Behavior

- `到期` loads unarchived cards with `dueAt <= now`, ordered by due date.
- `全部` loads all unarchived cards in the selected notebook scope.
- `强制` loads unarchived cards with `dueAt > now`, ordered by due date.
- It supports reviewing all notebooks, one selected notebook, or one selected unit.
- All modes write review logs and update the card's FSRS-6 state fields when a rating is selected.
- New cards enter same-day learning steps for `Again`, `Hard`, and `Good`; `Easy` graduates directly to review.

## CSV Import

- Supported CSV shapes:
  - `front,back`
  - `unit,front,back`
  - `unit,front,back,czyzd` or `unit,front,back,查词` for post-import CZYZD dictionary auto-fill
  - `front,back,audio` where one audio file is used on both sides
  - `front,back,frontAudio,backAudio` where each side can use a different file
- If the `unit` column is absent or blank, cards import into `Default`.
- Numeric unit values are normalized to `Unit 1`, `Unit 2`, and so on.
- During import, select the CSV file and any referenced audio files together.
- Supported audio extensions: `mp3`, `m4a`, `aac`, `wav`, `caf`, `aiff`, `aif`.
- Audio files are copied into app-local storage under Application Support.
- CZYZD lookup headers include `czyzd`, `dictionary`, `lookup`, `查词`, `词典`, and `潮语词典`. Existing non-empty back text is preserved.

## Rare Glyph Replacement

- Settings stores the DeepSeek API key in Keychain and keeps the selected model locally.
- Rare Glyphs can ask DeepSeek for a practical replacement character or phrase.
- Suggestions are cached locally and can be applied to all affected cards after review.

## CZYZD Dictionary

- The Dictionary tab searches CZYZD by word or phrase.
- Results display the matched term, CZYZD Chaoshan pronunciation image under `潮拼`, cleaned definition text under `解释`, and a speaker button when CZYZD exposes an audio clip.
- Mandarin pinyin and source labels such as `字义` are filtered out of the main dictionary result.
- Exact phrase matches are preferred; phrase lookups do not fall back to the first character when the phrase itself has no entry.
- Individual results can be saved as cards into a newly created notebook.
- A batch builder downloads a bundled common-character seed list in small batches into `CZYZD Dictionary`, stores progress locally, and skips duplicate cards in that notebook.
- Saved dictionary cards attach available CZYZD audio to both front and back playback buttons.

## Backup Export And Restore

- Settings now offers `Create JSON Backup`.
- Settings now offers `Import JSON Backup`.
- The backup schema is versioned with `schemaVersion: 3`.
- JSON backups include notebooks, units, cards, audio files, scheduling fields, and review logs.
- Restore deduplicates notebooks, units, cards, and review logs.
- Restore still accepts legacy `schemaVersion: 2` backups without embedded media files.

## Next

- Relaunch on the connected iPhone after the device is unlocked.
- Wire dictionary lookup into card editing so pinyin/definition can be auto-filled from CZYZD.
