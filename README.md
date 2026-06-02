# AnkiOpen

AnkiOpen is an open-source, offline-first iOS flashcard app built with SwiftUI and Core Data. The first MVP focuses on notebook/unit-based flashcards, CSV import, local editing, and FSRS-style spaced repetition scheduling.

## Current Scope

- iOS 16+ native app
- Local Core Data persistence
- Notebook and unit CRUD
- Flashcard CRUD and archive
- CSV import with `front,back`, optional `unit`, optional `audio`, or optional `frontAudio,backAudio` columns
- Optional CSV `czyzd` / `查词` column for CZYZD dictionary auto-fill
- Study flow with `Due`, `All`, and `Forced` modes, using `Again`, `Hard`, `Good`, `Easy`
- Audio playback on the front and back side of a card
- Review logs and due-card querying
- JSON backup export and restore from Settings
- FSRS-6 spaced repetition scheduling with default retention `0.90`
- DeepSeek-powered rare glyph replacement suggestions from Settings and Rare Glyphs
- CZYZD dictionary lookup for Chaoshan words, chaopin OCR, meanings, and available audio
- Optional DeepSeek cleanup for CZYZD dictionary results
- Card editor CZYZD auto-fill from the card front text
- Chinese-first interface with a hierarchical home screen instead of a bottom tab bar

## Development

Open `AnkiOpen.xcodeproj` in Xcode, select the `AnkiOpen` scheme, and run on an iOS simulator.

The project references [`open-spaced-repetition/swift-fsrs`](https://github.com/open-spaced-repetition/swift-fsrs). Xcode will resolve the package automatically when network access is available. The production review path currently uses the app-local FSRS-6 scheduler because `swift-fsrs` 5.0.0 does not expose the needed scheduling API publicly.

DeepSeek integration uses the OpenAI-compatible `https://api.deepseek.com/chat/completions` endpoint. Add an API key in Settings, then use it for rare glyph replacement suggestions and optional CZYZD dictionary result cleanup.

## CSV Import

The smallest supported CSV is:

```csv
front,back
Question,Answer
```

Cards are organized as `Notebook -> Unit -> Card`. If the CSV does not include a `unit` column, cards are imported into a `Default` unit. Numeric unit values are displayed as `Unit 1`, `Unit 2`, and so on.

Use a unit column:

```csv
unit,front,back
1,Question,Answer
2,Another question,Another answer
```

Use a CZYZD lookup column to auto-fill a blank back side from the Chaoshan dictionary after import:

```csv
unit,front,back,czyzd
1,你好,,你好
```

Supported lookup headers include `czyzd`, `dictionary`, `lookup`, `查词`, `词典`, and `潮语词典`. Existing non-empty back text is preserved.

Audio can be attached by selecting the CSV and referenced audio files in the same import picker. Supported audio extensions are `mp3`, `m4a`, `aac`, `wav`, `caf`, `aiff`, and `aif`.

Use one shared audio file for both sides:

```csv
front,back,audio
Question,Answer,clip.mp3
```

Or use different files for each side:

```csv
front,back,frontAudio,backAudio
Question,Answer,front.mp3,back.mp3
```

The app copies selected audio into its local sandbox, so the original files are not needed after import.

## Backup Export And Restore

Settings includes `Create JSON Backup` and `Import JSON Backup` actions. The generated backup contains notebooks, units, cards, audio files, FSRS state fields, and review logs. Restore deduplicates existing notebooks, units, cards, and review logs.

## Study Modes

- `到期`: scheduled review only. Shows unarchived cards whose `dueAt` is earlier than or equal to now.
- `全部`: custom study over all unarchived cards in the selected notebook scope.
- `强制`: forced learning for unarchived cards that are not due yet.

All modes still write review logs and update the card's next due date when a rating is selected.

## Dictionary

The 潮语词典 page searches CZYZD directly. It returns exact phrase matches when possible, shows the CZYZD Chaoshan pronunciation image under `潮拼`, attempts local Vision OCR to extract romanized chaopin text, shows cleaned definition text under `解释`, and plays remote dictionary audio when CZYZD provides a clip. Mandarin pinyin, Han-character chaopin placeholders, and source labels such as `字义` are filtered out of the main result. Phrase lookups avoid falling back to the first character when no exact phrase entry is found.

When a DeepSeek API key is configured and dictionary cleanup is enabled in Settings, lookup results are also sent through DeepSeek to normalize the `潮拼` and `解释` fields. AI cleanup failure does not block local dictionary results.

Dictionary results can be saved into a new notebook as flashcards. When CZYZD provides audio, the app downloads the clip into local storage and attaches it to both card sides. The Dictionary page also includes a resumable common-character builder that downloads a small bundled seed list from CZYZD in batches and adds results to a `CZYZD Dictionary` notebook, skipping duplicate cards in that notebook.

The card editor can also query CZYZD using the current front text and fill the back side with structured `潮拼` and `解释`. If the back side already has content, the app asks before overwriting it.

## Progress

- [x] Xcode iOS project scaffold
- [x] SwiftUI app shell
- [x] Programmatic Core Data model
- [x] Notebook, unit, and card management
- [x] CSV import
- [x] CSV audio import and playback
- [x] Study modes and review logs
- [x] Unit and UI test scaffolding
- [x] JSON backup export
- [x] JSON backup restore
- [x] Audio-bundled JSON backup
- [x] FSRS-6 scheduling defaults
- [x] DeepSeek rare glyph replacement workflow
- [x] CZYZD dictionary lookup tab
- [x] CSV CZYZD dictionary auto-fill column
- [x] Save CZYZD dictionary entries into notebooks
- [x] Batch CZYZD common-character notebook builder
- [x] App icon and polished visual identity
- [x] Hierarchical Chinese home screen and localized core workflows
- [x] Attach CZYZD audio when saving dictionary cards
- [x] CZYZD chaopin OCR and DeepSeek dictionary cleanup
- [x] Card editor CZYZD auto-fill
- [ ] TestFlight/App Store setup

## License

MIT
