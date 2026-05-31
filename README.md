# AnkiOpen

AnkiOpen is an open-source, offline-first iOS flashcard app built with SwiftUI and Core Data. The first MVP focuses on notebook-based flashcards, CSV import, local editing, and FSRS-style spaced repetition scheduling.

## Current Scope

- iOS 16+ native app
- Local Core Data persistence
- Notebook CRUD
- Flashcard CRUD and archive
- CSV import with `front,back`, optional `audio`, or optional `frontAudio,backAudio` columns
- Study flow with `Again`, `Hard`, `Good`, `Easy`
- Audio playback on the front and back side of a card
- Review logs and due-card querying
- FSRS Swift package integration, with a local scheduler fallback for development builds

## Development

Open `AnkiOpen.xcodeproj` in Xcode, select the `AnkiOpen` scheme, and run on an iOS simulator.

The project references [`open-spaced-repetition/swift-fsrs`](https://github.com/open-spaced-repetition/swift-fsrs). Xcode will resolve the package automatically when network access is available.

## CSV Import

The smallest supported CSV is:

```csv
front,back
Question,Answer
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

## Study Mode

The current Study tab is scheduled review only: it shows unarchived cards whose `dueAt` is earlier than or equal to now, sorted by due date. Custom study and forced learning of not-yet-due cards are not part of the current MVP yet.

## Progress

- [x] Xcode iOS project scaffold
- [x] SwiftUI app shell
- [x] Programmatic Core Data model
- [x] Notebook and card management
- [x] CSV import
- [x] CSV audio import and playback
- [x] Study flow and review logs
- [x] Unit and UI test scaffolding
- [ ] App icon and polished visual identity
- [ ] Export/backup
- [ ] TestFlight/App Store setup

## License

MIT
