import SwiftUI

struct RootView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var settings: UserSettings
    @EnvironmentObject private var auth: SpotifyAuthManager

    @State private var selection = Tab.lyrics

    enum Tab: Hashable { case lyrics, settings, support }

    var body: some View {
        Group {
            if !settings.hasSeenOnboarding {
                OnboardingScreen()
                    .transition(.opacity)
            } else {
                tabs
            }
        }
        .animation(.easeInOut(duration: 0.25), value: settings.hasSeenOnboarding)
        .preferredColorScheme(.dark)
        .tint(Theme.accent)
    }

    private var tabs: some View {
        TabView(selection: $selection) {
            NowPlayingScreen()
                .tabItem { Label(L10n.tabLyrics, systemImage: "quote.bubble") }
                .tag(Tab.lyrics)

            SettingsScreen()
                .tabItem { Label(L10n.tabSettings, systemImage: "gearshape") }
                .tag(Tab.settings)

            TipJarScreen()
                .tabItem { Label(L10n.tabSupport, systemImage: "heart") }
                .tag(Tab.support)
        }
    }
}
