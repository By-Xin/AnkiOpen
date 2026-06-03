# Progress

Last updated: 2026-06-03

## Done

- Created native iOS SwiftUI project targeting iOS 16+.
- Added local Core Data persistence with notebook, unit, card, review log, and import batch entities.
- Implemented notebook CRUD, unit CRUD, card CRUD, card archive/restore, CSV import, due-card query, and study review flow.
- Added `Notebook -> Unit -> Card` navigation and unit-scoped study entry points.
- Added optional CSV audio import with shared audio or separate front/back audio columns.
- Added notebook and unit CSV export for lightweight spreadsheet editing and sharing.
- Added optional CSV `isArchived` / `已归档` import so CSV export/import preserves archived card state.
- Added optional CSV `unit` column. Blank unit values import into `默认单元`; numeric values import as `单元 1`, `单元 2`, etc.
- Added local audio file storage and Study playback controls for both card sides.
- Added Study mode selection for scheduled due review, all-card custom study, and forced not-yet-due learning.
- Added Study card tools for current-side audio status, playback, missing-audio feedback, and direct card editing.
- Added JSON backup export from Settings, including notebooks, units, cards, audio references, FSRS fields, and review logs.
- Added JSON backup restore from Settings with duplicate handling for notebooks, units, cards, and review logs.
- Upgraded backups to `schemaVersion: 3` so referenced audio files are embedded in JSON and restored into local audio storage.
- Upgraded backups to `schemaVersion: 4` so card reports and report-driven correction logs are exported and restored with v2/v3 compatibility.
- Integrated the FSRS Swift package at version 5.0.0 through Swift Package Manager.
- Added an app-local FSRS-6 scheduler with default parameters and retention `0.90`, replacing the earlier simplified fallback in the production review path.
- Added DeepSeek settings with Keychain API key storage, V4 Flash/V4 Pro model selection, and rare glyph replacement suggestions.
- Replaced the static rare glyph image fallback flow with a DeepSeek suggestion flow that caches replacement suggestions and can apply them to affected cards.
- Added a Dictionary tab backed by CZYZD lookup for Chaoshan words, Chaoshan pronunciation, cleaned definitions, and remote audio playback.
- Added optional CSV `czyzd` / `查词` dictionary lookup columns. Rows with a blank back can now be imported when a lookup term is provided, then enriched from CZYZD after import.
- Added import result unit summaries with per-unit card counts and direct navigation into imported units.
- Added persistent import history on the Import screen with recent batches, counts, issue indicators, timestamps, and links back to imported notebooks.
- Added archived card visibility and restore controls inside unit detail so archived cards can be recovered into study queues.
- Added a Chinese home dashboard with due, active, archived, missing-audio, and open-feedback counts plus notebook due subtitles.
- Added a Study completion summary with reviewed-card count, per-rating counts, and quick continuation actions.
- Added home dashboard review activity counts for today and the last 7 days.
- Added Home `待处理` links that appear when there are missing-audio cards or unresolved feedback reports.
- Added a Home `维护中心` with daily health metrics for today/tomorrow due cards, future due cards, new cards, missing audio, rare glyphs, feedback, and review activity.
- Added a searchable Review History screen with recent review logs, rating chips, card details, and card edit access.
- Added CSV export from Review History and Feedback so filtered logs and issue reports can be shared for spreadsheet review.
- Added Dictionary actions to save a CZYZD result into a new notebook and to build a `潮语词典` notebook from a bundled common-character seed list in resumable batches.
- Replaced the bottom tab bar with a hierarchical Chinese home screen: 开始学习, 工具, and 笔记本.
- Localized the main visible workflows into Chinese, including study, import, dictionary, settings, card editing, reports, and rare glyphs.
- Moved Study answer/rating controls into a safe-area bottom inset so they no longer cover card text.
- Added CZYZD audio download when saving dictionary entries or batch-building dictionary notebooks; stored audio is attached to both sides of the generated card.
- Added local Vision OCR for CZYZD chaopin images so romanized readings such as `le2` can be extracted from pronunciation PNGs instead of using CZYZD's Han-character alt text.
- Added optional DeepSeek dictionary result cleanup that turns CZYZD output into structured `潮拼` and `解释` fields when a DeepSeek API key is configured.
- Improved CZYZD parsing to preserve multi-syllable chaopin, accept accented romanization such as `uá2`, and extract local chaopin from current CZYZD definition pairs such as `hǎo||ho2`.
- Added Dictionary save targets so individual CZYZD results can be saved into either a new notebook or an existing notebook/unit.
- Added CZYZD lookup inside the card editor so a card's front text can fill the back side with structured `潮拼` and `解释`.
- Added card-editor CZYZD audio matching; matched audio is stored only when the card is saved and is applied to both sides.
- Added a card-editor audio section that can preview existing front/back audio and newly matched CZYZD audio before saving.
- Added card-editor controls to manually replace or remove front, back, or shared audio before saving.
- Added a report-driven correction workflow: opening a reported card from Feedback, saving edits, recording before/after text and audio references, and automatically marking changed reports as resolved.
- Added a Feedback analytics overview with open/resolved counts, correction-log count, leading open issue category, and category breakdowns.
- Added a Feedback 7-day trend overview with new/resolved report counts, total resolution rate, and daily mini-bars.
- Added Feedback type filtering and search across issue category, note, card front/back text, notebook, and unit.
- Added a global missing-audio queue from Home tools with search, front/back filters, batch CZYZD audio repair, and direct card editing.
- Updated batch CZYZD audio repair so cards missing only one side can reuse the existing audio from the other side before hitting the network.
- Added audio integrity checks so cards with stored audio file names but missing local files are treated as audio issues in Study, card editing, maintenance metrics, and the missing-audio repair queue.
- Localized default and numeric unit names to `默认单元` / `单元 N`, added startup migration from legacy `Default` / `Unit N`, and localized import, backup, audio, DeepSeek, glyph, and CZYZD error messages.
- Added a Settings release and daily acceptance checklist with persistent checkboxes for CSV import, study, audio, backup, dictionary, feedback correction, signing, and phone/TestFlight readiness.
- Added a Settings privacy and data-flow disclosure covering local storage, user-controlled imports/backups, CZYZD requests, DeepSeek requests, Keychain API key storage, and no-tracking first-release behavior.
- Added unit test coverage for CSV import, unit import, audio import, duplicate handling, study mode queries, unit-scoped due queries, FSRS-6 review scheduling, CZYZD dictionary parsing, CZYZD import enrichment, DeepSeek suggestion parsing, backup export, backup restore, media restore, and v2 backup compatibility.
- Added a UI launch smoke test.
- Stabilized GitHub CI by running the deterministic `AnkiOpenTests` suite there; the UI launch smoke test remains part of local simulator acceptance because GitHub runners can fail before app assertions with simulator background-assertion timeouts.
- Created the public GitHub repository and pushed `main`: https://github.com/By-Xin/AnkiOpen
- Built and launched the app in the iPhone 17 simulator on iOS 26.5.
- Created initial GitHub Issues for FSRS, CSV import polish, backup/export, visual polish, and CI.
- Published GitHub Release `v0.1.0` for the first MVP: https://github.com/By-Xin/AnkiOpen/releases/tag/v0.1.0
- Added `docs/RELEASE_RUNBOOK.md` for repeatable local archive export, development device install, GitHub Release checks, and `devicectl unavailable` troubleshooting.

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
- Passed Xcode tests after CZYZD chaopin OCR and DeepSeek dictionary cleanup on 2026-06-02: 63 unit/app tests and 1 UI launch smoke test.
- Passed Xcode tests after card-editor CZYZD auto-fill on 2026-06-02: 63 unit/app tests and 1 UI launch smoke test.
- Passed Xcode tests after card-editor CZYZD audio matching on 2026-06-02: 63 unit/app tests and 1 UI launch smoke test.
- Passed Xcode tests after card-editor audio preview on 2026-06-02: 65 unit/app tests and 1 UI launch smoke test.
- Passed Xcode tests after card-editor audio replace/remove on 2026-06-02: 67 unit/app tests and 1 UI launch smoke test.
- Passed Xcode tests after report-driven correction history on 2026-06-02: 68 unit/app tests and 1 UI launch smoke test.
- Passed Xcode tests after report/correction backup on 2026-06-02: 70 unit/app tests and 1 UI launch smoke test.
- Passed Xcode tests after Feedback analytics overview on 2026-06-02: 71 unit/app tests and 1 UI launch smoke test.
- Passed Xcode tests after Feedback filtering and search on 2026-06-02: 72 unit/app tests and 1 UI launch smoke test.
- Passed Xcode tests after import result unit navigation on 2026-06-02: 72 unit/app tests and 1 UI launch smoke test.
- Passed Xcode tests after persistent import history on 2026-06-02: 73 unit/app tests and 1 UI launch smoke test.
- Passed Xcode tests after archived card restore controls on 2026-06-02: 74 unit/app tests and 1 UI launch smoke test.
- Passed Xcode tests after notebook/unit CSV export on 2026-06-02: 76 unit/app tests and 1 UI launch smoke test.
- Passed Xcode tests after CSV archived-state import on 2026-06-02: 78 unit/app tests and 1 UI launch smoke test.
- Passed Xcode tests after home dashboard overview on 2026-06-02: 79 unit/app tests and 1 UI launch smoke test.
- Passed Xcode tests after Study completion summary on 2026-06-02: 80 unit/app tests and 1 UI launch smoke test.
- Passed Xcode tests after home review activity metrics on 2026-06-02: 81 unit/app tests and 1 UI launch smoke test.
- Passed Xcode tests after Review History browser on 2026-06-02: 82 unit/app tests and 1 UI launch smoke test.
- Passed Xcode tests after Review History and Feedback CSV export on 2026-06-02: 84 unit/app tests and 1 UI launch smoke test.
- Passed Xcode tests after Feedback 7-day trend analytics on 2026-06-02: 85 unit/app tests and 1 UI launch smoke test.
- Passed Xcode tests after release and daily acceptance checklist on 2026-06-02: 86 unit/app tests and 1 UI launch smoke test.
- Passed Xcode tests after global missing-audio queue on 2026-06-02: 87 unit/app tests and 1 UI launch smoke test.
- Passed Xcode tests after Study audio feedback tools on 2026-06-02: 87 unit/app tests and 1 UI launch smoke test.
- Passed Xcode tests after Home pending-work links on 2026-06-02: 88 unit/app tests and 1 UI launch smoke test.
- Passed Xcode tests after CZYZD multi-syllable and definition-pair parsing on 2026-06-02: 94 unit/app tests and 1 UI launch smoke test.
- Passed Xcode tests after Dictionary existing-notebook save targets on 2026-06-02: 96 unit/app tests and 1 UI launch smoke test.
- Passed Xcode tests after Maintenance Center on 2026-06-02: 97 unit/app tests and 1 UI launch smoke test.
- Passed Xcode tests after audio integrity checks on 2026-06-02: 99 unit/app tests and 1 UI launch smoke test.
- Passed Xcode tests after Chinese unit-name migration and localized error messages on 2026-06-02: 100 unit/app tests and 1 UI launch smoke test.
- Passed local first-release validation on 2026-06-02: 100 unit/app tests, 1 UI launch smoke test, Release archive, development IPA export, and GitHub Actions run `26829166120`.
- Passed Xcode tests after adding the privacy and data-flow disclosure on 2026-06-03: 101 unit/app tests.
- Built, installed, and launched the app on the connected iPhone on 2026-06-02.
- Built, installed, and launched the Chinese unit-name migration build on the connected iPhone on 2026-06-02.
- Manual simulator smoke test passed: create notebook, create card, study due card, reveal answer, rate `Good`, and confirm the due queue clears.

## Current Study Behavior

- `到期` loads unarchived cards with `dueAt <= now`, ordered by due date.
- `全部` loads all unarchived cards in the selected notebook scope.
- `强制` loads unarchived cards with `dueAt > now`, ordered by due date.
- Archived cards are excluded from all study queues until they are restored from the unit detail screen.
- It supports reviewing all notebooks, one selected notebook, or one selected unit.
- All modes write review logs and update the card's FSRS-6 state fields when a rating is selected.
- New cards enter same-day learning steps for `Again`, `Hard`, and `Good`; `Easy` graduates directly to review.
- Completed study queues show a session summary with reviewed-card count and rating breakdowns, plus actions to recheck due cards, force-study future cards, or shuffle all cards.
- Each study card shows the current side's audio status and location.
- If the current side has audio, Study can play it inline.
- If the current side is missing audio, Study can open a prefilled audio feedback sheet.
- Study can open the existing card editor so CZYZD matching, manual audio replacement, and card text edits are available without leaving the learning flow.

## CSV Import

- Supported CSV shapes:
  - `front,back`
  - `unit,front,back`
  - `unit,front,back,czyzd` or `unit,front,back,查词` for post-import CZYZD dictionary auto-fill
  - `unit,front,back,isArchived` for restoring archived cards from exported CSV
  - `front,back,audio` where one audio file is used on both sides
  - `front,back,frontAudio,backAudio` where each side can use a different file
- If the `unit` column is absent or blank, cards import into `默认单元`.
- Numeric unit values are normalized to `单元 1`, `单元 2`, and so on.
- Legacy English unit names `Default` and `Unit N` are migrated to `默认单元` and `单元 N` on app launch; duplicate migrated units are merged.
- During import, select the CSV file and any referenced audio files together.
- Supported audio extensions: `mp3`, `m4a`, `aac`, `wav`, `caf`, `aiff`, `aif`.
- Audio files are copied into app-local storage under Application Support.
- CZYZD lookup headers include `czyzd`, `dictionary`, `lookup`, `查词`, `词典`, and `潮语词典`. Existing non-empty back text is preserved.
- Archived headers include `isArchived`, `archived`, `归档`, and `已归档`; true values include `true`, `yes`, `1`, `archived`, `归档`, `已归档`, and `是`.
- After import, the result summary shows each imported unit, the number of cards added to it, and a direct link into that unit.
- The Import screen keeps a recent import history after app relaunch, with direct links back to imported notebooks.
- Notebook and unit detail screens can generate shareable CSV files with `unit`, `front`, `back`, front/back audio file names, and archived state.

## Rare Glyph Replacement

- Settings stores the DeepSeek API key in Keychain and keeps the selected model locally.
- Rare Glyphs can ask DeepSeek for a practical replacement character or phrase.
- Suggestions are cached locally and can be applied to all affected cards after review.
- DeepSeek can also clean dictionary lookup results into structured `潮拼` and `解释` fields when enabled in Settings.

## 潮语词典

- The Dictionary tab searches CZYZD by word or phrase.
- Results display the matched term, CZYZD Chaoshan pronunciation image under `潮拼`, cleaned definition text under `解释`, and a speaker button when CZYZD exposes an audio clip.
- The app attempts local OCR on the CZYZD chaopin image and only stores romanized chaopin text when it can extract a Latin-reading value.
- Multi-syllable chaopin is preserved, accented romanization such as `uá2` is accepted, and CZYZD definition pairs such as `hǎo||ho2` can provide local chaopin when image titles are Han-character placeholders.
- Mandarin pinyin, CZYZD `pinyin||chaopin` prefixes, and source labels such as `字义` are filtered out of the main dictionary result.
- Exact phrase matches are preferred; phrase lookups do not fall back to the first character when the phrase itself has no entry.
- Card editing can use the card front text to fetch CZYZD and fill the back side; non-empty back text asks for confirmation before overwriting.
- Card editing can match CZYZD audio from the front text; the audio is saved only when the card is saved and is applied to both front/back playback.
- Card editing can preview current front/back audio and pending matched audio before saving.
- Card editing can replace or remove front, back, or shared audio before saving.
- Individual results can be saved as cards into a newly created notebook or an existing notebook/unit; duplicate cards are skipped within the target notebook before creating empty units.
- A batch builder downloads a bundled common-character seed list in small batches into `潮语词典`, stores progress locally, and skips duplicate cards in that notebook.
- Saved dictionary cards attach available CZYZD audio to both front and back playback buttons.

## Backup Export And Restore

- Settings now offers `Create JSON Backup`.
- Settings now offers `Import JSON Backup`.
- The backup schema is versioned with `schemaVersion: 4`.
- JSON backups include notebooks, units, cards, audio files, scheduling fields, review logs, feedback reports, and correction logs.
- Restore deduplicates notebooks, units, cards, review logs, feedback reports, and correction logs.
- Restore still accepts legacy `schemaVersion: 2` backups without embedded media files and `schemaVersion: 3` backups without report history.

## Reports

- Reported cards can be opened directly from Feedback.
- Saving a changed reported card records a before/after correction log for text and audio references.
- Changed reports are automatically marked as resolved; unchanged saves leave the report in its current state.
- Feedback shows open/resolved counts, correction-log count, the leading unresolved issue category, and category breakdowns.
- Feedback shows near-term trend analytics for the last 7 days, including new reports, resolved reports, total resolution rate, and daily mini-bars.
- Feedback can be filtered by issue type and searched by category, note, card text, notebook, or unit.
- Feedback can export the current filtered report list to CSV, including status, category, note, card location, audio references, and correction count.

## Review History

- Review History can export the current filtered review log list to CSV, including reviewed time, rating, card location, front/back text, and due-date changes.

## Missing Audio

- Home tools includes `缺音频卡片`.
- Home tools includes `维护中心`, which links to the missing-audio queue, feedback, rare glyphs, study, and review history from one repair-focused dashboard.
- The queue shows unarchived cards missing front audio, back audio, both, or referencing local audio files that no longer exist.
- It supports search across card text, notebook, unit, and missing-audio status.
- It can filter by all missing cards, missing front audio, missing back audio, or both sides missing.
- Batch repair first clears broken local audio references, then reuses existing audio from the other side of the card when the file still exists, then uses CZYZD matching for cards still missing local audio.
- Tapping a row opens the existing card editor, so manual audio replacement, CZYZD matching, and feedback reporting stay in one workflow.

## Release Checklist

- Settings includes `发布与验收清单`.
- The checklist covers daily CSV import, study completion, audio playback, JSON backup, dictionary lookup, DeepSeek cleanup, feedback correction, CSV feedback export, local/CI tests, signing, privacy notes, and phone/TestFlight readiness.
- Checklist progress is stored locally, so checked items persist after relaunch and can be reset.

## Next

- Add App Store Connect/TestFlight account steps once a paid Apple Developer account is ready.
- Re-run final phone install once `xcrun devicectl list devices` shows the iPhone as `available` instead of `unavailable`.
