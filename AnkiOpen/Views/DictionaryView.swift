import SwiftUI

struct DictionaryView: View {
    @StateObject private var audioPlayer = AudioPlaybackController()
    @State private var query = ""
    @State private var entries: [CZYZDDictionaryEntry] = []
    @State private var isSearching = false
    @State private var errorMessage: String?

    private let lookup = CZYZDDictionaryLookup()

    var body: some View {
        NavigationStack {
            List {
                Section("Search") {
                    HStack {
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

                                    Spacer()

                                    if let audioURL = entry.audioURL {
                                        Button {
                                            audioPlayer.play(remoteURL: audioURL)
                                        } label: {
                                            Image(systemName: "speaker.wave.2")
                                        }
                                        .buttonStyle(.borderless)
                                    }
                                }

                                if !entry.pronunciation.isEmpty {
                                    LabeledContent("Pronunciation", value: entry.pronunciation)
                                }

                                if !entry.definition.isEmpty {
                                    Text(entry.definition)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
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
            .navigationTitle("Dictionary")
            .alert("Dictionary Error", isPresented: .constant(errorMessage != nil), actions: {
                Button("OK") { errorMessage = nil }
            }, message: {
                Text(errorMessage ?? "")
            })
        }
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
