import SwiftUI

struct DictionaryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var audioPlayer = AudioPlaybackController()
    @AppStorage("czyzdDictionaryBuilderNextIndex") private var builderNextIndex = 0
    @State private var query = ""
    @State private var entries: [CZYZDDictionaryEntry] = []
    @State private var isSearching = false
    @State private var isBuildingNotebook = false
    @State private var entryToSave: CZYZDDictionaryEntry?
    @State private var saveNotebookName = CZYZDDictionaryNotebookBuilder.defaultNotebookName
    @State private var builderNotebookName = CZYZDDictionaryNotebookBuilder.defaultNotebookName
    @State private var builderBatchSize = 10
    @State private var notebookSummary: CZYZDDictionaryNotebookImportSummary?
    @State private var errorMessage: String?

    private let lookup = CZYZDDictionaryLookup()

    var body: some View {
        NavigationStack {
            List {
                Section("Search") {
                    HStack {
                        LeadingSymbol(systemImage: "magnifyingglass")
                        TextField("Word or phrase", text: $query)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.search)
                            .onSubmit {
                                search()
                            }

                        Button {
                            search()
                        } label: {
                            Image(systemName: "magnifyingglass")
                        }
                        .disabled(query.trimmed.isEmpty || isSearching)
                    }
                    .appListRow()
                }

                Section("Dictionary Notebook") {
                    TextField("Notebook name", text: $builderNotebookName)
                        .disabled(isBuildingNotebook)

                    Stepper("Batch size: \(builderBatchSize)", value: $builderBatchSize, in: 5...50, step: 5)
                        .disabled(isBuildingNotebook)

                    LabeledContent("Progress", value: "\(min(builderNextIndex, CZYZDDictionaryNotebookBuilder.commonCharacterTerms.count)) / \(CZYZDDictionaryNotebookBuilder.commonCharacterTerms.count)")

                    Button {
                        Task {
                            await buildDictionaryNotebook()
                        }
                    } label: {
                        Label(isBuildingNotebook ? "Downloading..." : "Download Next Batch", systemImage: "square.and.arrow.down")
                    }
                    .disabled(isBuildingNotebook || builderNextIndex >= CZYZDDictionaryNotebookBuilder.commonCharacterTerms.count)

                    Button(role: .destructive) {
                        builderNextIndex = 0
                        notebookSummary = nil
                    } label: {
                        Label("Reset Batch Progress", systemImage: "arrow.counterclockwise")
                    }
                    .disabled(isBuildingNotebook || builderNextIndex == 0)

                    Text("This uses a bundled common-character seed list and downloads in small batches so progress can be resumed later.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if isBuildingNotebook {
                    Section {
                        ProgressView("Building dictionary notebook...")
                            .frame(maxWidth: .infinity)
                    }
                }

                if let notebookSummary {
                    Section("Last Notebook Update") {
                        LabeledContent("Checked", value: "\(notebookSummary.checkedTerms)")
                        LabeledContent("Added", value: "\(notebookSummary.addedCards)")
                        LabeledContent("Skipped", value: "\(notebookSummary.skippedCards)")
                        LabeledContent("Failed", value: "\(notebookSummary.failedTerms)")
                        if let messages = notebookSummary.messageSummary {
                            Text(messages)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if isSearching {
                    Section {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    }
                }

                if !entries.isEmpty {
                    Section("Results") {
                        ForEach(entries) { entry in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(entry.term)
                                        .flashcardCJKFont(size: 22, relativeTo: .title3, weight: .semibold)
                                        .foregroundStyle(AppPalette.ink)

                                    Spacer()

                                    Button {
                                        saveNotebookName = "\(entry.term) Dictionary"
                                        entryToSave = entry
                                    } label: {
                                        Image(systemName: "plus.rectangle.on.rectangle")
                                    }
                                    .buttonStyle(.borderless)

                                    if let audioURL = entry.audioURL {
                                        Button {
                                            audioPlayer.play(remoteURL: audioURL)
                                        } label: {
                                            Image(systemName: "speaker.wave.2")
                                        }
                                        .buttonStyle(.borderless)
                                    }
                                }

                                if entry.chaopinImageURL != nil || !entry.chaopin.isEmpty || !entry.pronunciation.isEmpty {
                                    LabeledContent {
                                        HStack(spacing: 8) {
                                            if let imageURL = entry.chaopinImageURL {
                                                AsyncImage(url: imageURL) { phase in
                                                    switch phase {
                                                    case .success(let image):
                                                        image
                                                            .resizable()
                                                            .scaledToFit()
                                                    default:
                                                        Text(entry.chaopin.isEmpty ? entry.pronunciation : entry.chaopin)
                                                            .font(.body)
                                                    }
                                                }
                                                .frame(width: 92, height: 28, alignment: .leading)
                                            } else {
                                                Text(entry.chaopin.isEmpty ? entry.pronunciation : entry.chaopin)
                                            }
                                        }
                                    } label: {
                                        Text("潮拼")
                                    }
                                }

                                if !entry.definition.isEmpty {
                                    LabeledContent {
                                        Text(entry.definition)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .multilineTextAlignment(.leading)
                                    } label: {
                                        Text("解释")
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                            .appListRow()
                        }
                    }
                } else if !query.trimmed.isEmpty, !isSearching {
                    Section {
                        EmptyStateView(
                            title: "No Results",
                            systemImage: "book.closed",
                            message: "Try a single character or an exact phrase."
                        )
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.insetGrouped)
            .appScreenBackground()
            .navigationTitle("Dictionary")
            .sheet(item: $entryToSave) { entry in
                NavigationStack {
                    Form {
                        Section("Card") {
                            LabeledContent("Front", value: entry.term)
                            Text(CZYZDDictionaryNotebookBuilder.cardBackText(from: entry))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Section("New Notebook") {
                            TextField("Notebook name", text: $saveNotebookName)
                        }
                    }
                    .navigationTitle("Save Entry")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                entryToSave = nil
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                saveEntry(entry)
                            }
                            .disabled(saveNotebookName.trimmed.isEmpty)
                        }
                    }
                }
            }
            .alert("Dictionary Error", isPresented: .constant(errorMessage != nil), actions: {
                Button("OK") { errorMessage = nil }
            }, message: {
                Text(errorMessage ?? "")
            })
        }
    }

    @MainActor
    private func saveEntry(_ entry: CZYZDDictionaryEntry) {
        do {
            notebookSummary = try CZYZDDictionaryNotebookBuilder().addEntry(
                entry,
                toNewNotebookNamed: saveNotebookName,
                context: viewContext
            )
            builderNotebookName = saveNotebookName
            entryToSave = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func buildDictionaryNotebook() async {
        isBuildingNotebook = true
        defer {
            isBuildingNotebook = false
        }

        let summary = await CZYZDDictionaryNotebookBuilder().importCommonTerms(
            intoNotebookNamed: builderNotebookName,
            startingAt: builderNextIndex,
            limit: builderBatchSize,
            context: viewContext
        )
        notebookSummary = summary
        builderNextIndex = summary.nextIndex
    }

    private func search() {
        let cleanQuery = query.trimmed
        guard !cleanQuery.isEmpty else {
            return
        }

        isSearching = true
        errorMessage = nil
        entries = []

        Task {
            do {
                let results = try await lookup.lookup(term: cleanQuery)
                await MainActor.run {
                    entries = results
                    isSearching = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSearching = false
                }
            }
        }
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
