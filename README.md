# AnkiOpen

AnkiOpen is an open-source, offline-first iOS flashcard app built with SwiftUI and Core Data. The first MVP focuses on notebook-based flashcards, CSV import, local editing, and FSRS-style spaced repetition scheduling.

## Current Scope

- iOS 16+ native app
- Local Core Data persistence
- Notebook CRUD
- Flashcard CRUD and archive
- CSV import with `front,back` columns
- Study flow with `Again`, `Hard`, `Good`, `Easy`
- Review logs and due-card querying
- FSRS Swift package integration, with a local scheduler fallback for development builds

## Development

Open `AnkiOpen.xcodeproj` in Xcode, select the `AnkiOpen` scheme, and run on an iOS simulator.

The project references [`open-spaced-repetition/swift-fsrs`](https://github.com/open-spaced-repetition/swift-fsrs). Xcode will resolve the package automatically when network access is available.

## Progress

- [x] Xcode iOS project scaffold
- [x] SwiftUI app shell
- [x] Programmatic Core Data model
- [x] Notebook and card management
- [x] CSV import
- [x] Study flow and review logs
- [x] Unit and UI test scaffolding
- [ ] App icon and polished visual identity
- [ ] Export/backup
- [ ] TestFlight/App Store setup

## License

MIT
