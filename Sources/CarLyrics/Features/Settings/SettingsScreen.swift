import SwiftUI
import UIKit

struct SettingsScreen: View {
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var settings: UserSettings
    @EnvironmentObject private var auth: SpotifyAuthManager
    @EnvironmentObject private var lyrics: LyricsController

    @State private var cacheSize: String = "—"
    @State private var showingPrivacy = false

    var body: some View {
        NavigationStack {
            Form {
                accountSection
                syncSection
                displaySection
                carPlaySection
                dataSection
                aboutSection
            }
            .navigationTitle(L10n.settingsTitle)
            .task { await refreshCacheSize() }
            .sheet(isPresented: $showingPrivacy) { PrivacyScreen() }
        }
    }

    private var accountSection: some View {
        Section(L10n.settingsAccount) {
            if auth.isAuthorized {
                Label(L10n.settingsConnected, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Theme.accent)
                Button(L10n.settingsDisconnect, role: .destructive) {
                    environment.signOut()
                }
            } else {
                Button(L10n.settingsConnect) {
                    Task { await environment.signIn() }
                }
                .disabled(!auth.isConfigured)

                if !auth.isConfigured {
                    Text(L10n.errorNotConfigured)
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private var syncSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(L10n.settingsOffset)
                    Spacer()
                    Text(offsetLabel)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(
                    value: Binding(
                        get: { Double(settings.lyricsOffsetMilliseconds) },
                        set: {
                            settings.lyricsOffsetMilliseconds = Int($0.rounded())
                            lyrics.offsetDidChange()
                        }
                    ),
                    in: -3000...3000,
                    step: 50
                )
                Text(L10n.settingsOffsetDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text(L10n.settingsSync)
        }
    }

    private var displaySection: some View {
        Section(L10n.settingsDisplay) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(L10n.settingsFontSize)
                    Spacer()
                    Text("\(Int(settings.fontScale * 100))%")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(
                    value: Binding(get: { settings.fontScale }, set: { settings.fontScale = $0 }),
                    in: 0.8...1.8,
                    step: 0.1
                )
            }

            Toggle(L10n.settingsKeepAwake, isOn: Binding(
                get: { settings.keepScreenAwake },
                set: {
                    settings.keepScreenAwake = $0
                    UIApplication.shared.isIdleTimerDisabled = $0
                }
            ))
        }
    }

    private var carPlaySection: some View {
        Section {
            Picker(L10n.settingsCarPlayLines, selection: Binding(
                get: { settings.carPlayLinesVisible },
                set: { settings.carPlayLinesVisible = $0 }
            )) {
                Text("1").tag(1)
                Text("3").tag(3)
                Text("5").tag(5)
            }
            .pickerStyle(.segmented)

            Text(L10n.settingsCarPlayLinesDetail)
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Text(L10n.settingsCarPlay)
        }
    }

    private var dataSection: some View {
        Section(L10n.settingsData) {
            Button(L10n.settingsClearCache, role: .destructive) {
                Task {
                    await environment.repository.clearCache()
                    await refreshCacheSize()
                }
            }
            LabeledContent(L10n.settingsCacheSize(cacheSize), value: "")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var aboutSection: some View {
        Section(L10n.settingsAbout) {
            LabeledContent(L10n.settingsVersion, value: Bundle.main.versionDescription)
            Button(L10n.settingsPrivacy) { showingPrivacy = true }
            LabeledContent(L10n.lyricsSource("LRCLIB"), value: "lrclib.net")
                .font(.caption)
        }
    }

    private var offsetLabel: String {
        let value = Double(settings.lyricsOffsetMilliseconds) / 1000
        return String(format: "%+.2f s", value)
    }

    private func refreshCacheSize() async {
        let bytes = await environment.repository.cacheSizeInBytes()
        cacheSize = ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}

extension Bundle {
    var versionDescription: String {
        let short = object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(short) (\(build))"
    }
}
