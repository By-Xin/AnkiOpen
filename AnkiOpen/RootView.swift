import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            NotebooksView()
                .tabItem {
                    Label("Notebooks", systemImage: "books.vertical")
                }

            StudyView()
                .tabItem {
                    Label("Study", systemImage: "rectangle.stack.badge.play")
                }

            ImportView()
                .tabItem {
                    Label("Import", systemImage: "square.and.arrow.down")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}
