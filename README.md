# AnkiOpen

AnkiOpen is an open-source, offline-first iOS flashcard app built with SwiftUI and Core Data. The first MVP focuses on notebook/unit-based flashcards, CSV import, local editing, and FSRS-style spaced repetition scheduling.

## Current Scope

- iOS 16+ native app
- Local Core Data persistence
- Notebook and unit CRUD
- Flashcard CRUD and archive
- CSV import with `front,back`, optional `unit`, optional `audio`, or optional `frontAudio,backAudio` columns
- Study flow with `Due`, `All`, and `Forced` modes, using `Again`, `Hard`, `Good`, `Easy`
- Audio playback on the front and back side of a card
- Review logs and due-card querying
- JSON backup export and restore from Settings
- FSRS-6 spaced repetition scheduling with default retention `0.90`
- DeepSeek-powered rare glyph replacement suggestions from Settings and Rare Glyphs

## Development

Open `AnkiOpen.xcodeproj` in Xcode, select the `AnkiOpen` scheme, and run on an iOS simulator.

The project references [`open-spaced-repetition/swift-fsrs`](https://github.com/open-spaced-repetition/swift-fsrs). Xcode will resolve the package automatically when network access is available. The production review path currently uses the app-local FSRS-6 scheduler because `swift-fsrs` 5.0.0 does not expose the needed scheduling API publicly.

DeepSeek integration uses the OpenAI-compatible `https://api.deepseek.com/chat/completions` endpoint. Add an API key in Settings, then open Settings -> Rare Glyphs to ask for replacement suggestions and apply them to affected cards.

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

- `Due`: scheduled review only. Shows unarchived cards whose `dueAt` is earlier than or equal to now.
- `All`: custom study over all unarchived cards in the selected notebook scope.
- `Forced`: forced learning for unarchived cards that are not due yet.

All modes still write review logs and update the card's next due date when a rating is selected.

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
- [ ] App icon and polished visual identity
- [ ] TestFlight/App Store setup

## License

MIT
