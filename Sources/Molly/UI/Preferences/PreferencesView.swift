import SwiftUI

struct PreferencesView: View {
    var body: some View {
        TabView {
            GeneralPrefsView()
                .tabItem { Label("General", systemImage: "gear") }

            WatchersPrefsView()
                .tabItem { Label("Watchers", systemImage: "eye") }

            LogView()
                .tabItem { Label("Logs", systemImage: "text.alignleft") }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minWidth: 520, minHeight: 400)
    }
}
