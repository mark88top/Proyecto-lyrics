import SwiftUI

/// Tres pantallas: qué hace la app, cómo se usa en el auto y la advertencia
/// de seguridad. La última no es opcional ni cosmética: App Review espera
/// que una app que se usa manejando diga explícitamente que no hay que
/// leerla al volante.
struct OnboardingScreen: View {
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var settings: UserSettings
    @EnvironmentObject private var auth: SpotifyAuthManager

    @State private var page = 0
    @State private var isConnecting = false

    private let pages: [Page] = [
        Page(icon: "quote.bubble.fill", title: L10n.onboardingStepSpotify, detail: L10n.onboardingStepSpotifyDetail),
        Page(icon: "car.fill", title: L10n.onboardingStepCarPlay, detail: L10n.onboardingStepCarPlayDetail),
        Page(icon: "exclamationmark.shield.fill", title: L10n.onboardingStepSafety, detail: L10n.onboardingStepSafetyDetail)
    ]

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                VStack(spacing: 10) {
                    Text(L10n.onboardingTitle)
                        .font(.largeTitle.weight(.bold))
                        .multilineTextAlignment(.center)
                    Text(L10n.onboardingSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 28)

                TabView(selection: $page) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, item in
                        PageView(page: item).tag(index)
                    }
                }
                .tabViewStyle(.page)
                .frame(height: 260)

                Spacer()

                actions
                    .padding(.horizontal, 28)
                    .padding(.bottom, 32)
            }
        }
    }

    @ViewBuilder
    private var actions: some View {
        if page < pages.count - 1 {
            Button(L10n.onboardingContinue) {
                withAnimation { page += 1 }
            }
            .buttonStyle(PrimaryButtonStyle())
        } else {
            VStack(spacing: 12) {
                Button {
                    Task {
                        isConnecting = true
                        await environment.signIn()
                        isConnecting = false
                        if auth.isAuthorized { settings.hasSeenOnboarding = true }
                    }
                } label: {
                    if isConnecting {
                        ProgressView().tint(.black)
                    } else {
                        Text(L10n.onboardingConnect)
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isConnecting || !auth.isConfigured)

                // Salida sin conectar: la app no debe ser un callejón sin
                // salida si Spotify falla o el usuario quiere mirar primero.
                Button(L10n.close) { settings.hasSeenOnboarding = true }
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if !auth.isConfigured {
                    Text(L10n.errorNotConfigured)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }

    private struct Page {
        let icon: String
        let title: String
        let detail: String
    }

    private struct PageView: View {
        let page: Page

        var body: some View {
            VStack(spacing: 16) {
                Image(systemName: page.icon)
                    .font(.system(size: 46))
                    .foregroundStyle(Theme.accent)
                Text(page.title)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                Text(page.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 14))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}
