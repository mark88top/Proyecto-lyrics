import SwiftUI

/// Pantalla principal del teléfono: cabecera con el tema y la letra que
/// avanza sola.
struct NowPlayingScreen: View {
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var playback: PlaybackCoordinator
    @EnvironmentObject private var lyrics: LyricsController
    @EnvironmentObject private var auth: SpotifyAuthManager

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                if !auth.isAuthorized && !environment.isSimulated {
                    ConnectPrompt()
                } else {
                    NowPlayingHeader(state: playback.state, position: lyrics.position)
                    Divider().overlay(Color.white.opacity(0.08))
                    content
                }
            }
        }
        .task { environment.startIfNeeded() }
    }

    @ViewBuilder
    private var content: some View {
        switch lyrics.state {
        case .idle:
            EmptyStateView(
                icon: "music.note",
                title: L10n.nowPlayingNothing,
                message: L10n.nowPlayingNothingDetail,
                actionTitle: L10n.nowPlayingOpenSpotify,
                action: { environment.openSpotify() }
            )
        case .loading:
            VStack(spacing: 16) {
                ProgressView().controlSize(.large)
                Text(L10n.lyricsSearching)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .ready(let snapshot):
            LyricsListView(snapshot: snapshot)
        case .notFound:
            EmptyStateView(
                icon: "text.magnifyingglass",
                title: L10n.lyricsNotFound,
                message: L10n.lyricsNotFoundDetail,
                actionTitle: L10n.retry,
                action: { lyrics.retry() }
            )
        case .instrumental:
            EmptyStateView(
                icon: "guitars",
                title: L10n.lyricsInstrumental,
                message: L10n.lyricsInstrumentalDetail,
                actionTitle: nil,
                action: nil
            )
        case .failed(let message):
            EmptyStateView(
                icon: "exclamationmark.triangle",
                title: message,
                message: "",
                actionTitle: L10n.retry,
                action: { lyrics.retry() }
            )
        }
    }
}

/// Cabecera compacta: carátula, título, artista y barra de progreso.
private struct NowPlayingHeader: View {
    let state: PlaybackState
    let position: TimeInterval

    var body: some View {
        HStack(spacing: 14) {
            Artwork(url: state.track?.artworkURL)

            VStack(alignment: .leading, spacing: 3) {
                Text(state.track?.title ?? L10n.nowPlayingNothing)
                    .font(.headline)
                    .lineLimit(1)
                Text(state.track?.artist ?? "")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let duration = state.track?.duration, duration > 0 {
                    Text("\(TimeFormatting.clock(position)) / \(TimeFormatting.clock(duration))")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 0)

            if state.isPlaying {
                // `symbolEffect` es iOS 17+; en iOS 16 mostramos el icono fijo.
                if #available(iOS 17.0, *) {
                    Image(systemName: "waveform")
                        .foregroundStyle(Theme.accent)
                        .symbolEffect(.variableColor.iterative, options: .repeating)
                } else {
                    Image(systemName: "waveform")
                        .foregroundStyle(Theme.accent)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

private struct Artwork: View {
    let url: URL?

    var body: some View {
        AsyncImage(url: url) { image in
            image.resizable().aspectRatio(contentMode: .fill)
        } placeholder: {
            RoundedRectangle(cornerRadius: 8)
                .fill(Theme.surface)
                .overlay(Image(systemName: "music.note").foregroundStyle(.secondary))
        }
        .frame(width: 48, height: 48)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 42))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)
            if !message.isEmpty {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 4)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Se muestra cuando todavía no hay cuenta conectada.
private struct ConnectPrompt: View {
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var auth: SpotifyAuthManager
    @State private var isWorking = false

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "music.note.list")
                .font(.system(size: 52))
                .foregroundStyle(Theme.accent)
            Text(L10n.errorNeedsLogin)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)

            if !auth.isConfigured {
                Text(L10n.errorNotConfigured)
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button {
                Task {
                    isWorking = true
                    await environment.signIn()
                    isWorking = false
                }
            } label: {
                if isWorking {
                    ProgressView()
                } else {
                    Text(L10n.settingsConnect)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isWorking || !auth.isConfigured)
            Spacer()
        }
        .padding(28)
    }
}
