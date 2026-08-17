import SwiftUI

/// Pantalla de donaciones. El texto es deliberadamente explícito en que
/// nada se desbloquea: es lo que separa un "tip jar" legítimo de un muro de
/// pago encubierto a ojos de App Review.
struct TipJarScreen: View {
    @EnvironmentObject private var tipJar: TipJar
    @EnvironmentObject private var settings: UserSettings

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        header
                        products
                        if settings.hasEverTipped {
                            Label(L10n.tipsAlreadyTipped, systemImage: "checkmark.seal.fill")
                                .font(.footnote)
                                .foregroundStyle(Theme.accent)
                        }
                    }
                    .padding(24)
                }
            }
            .navigationTitle(L10n.tabSupport)
            .task { await tipJar.load() }
            .alert(
                tipJar.lastThankYou ?? "",
                isPresented: Binding(
                    get: { tipJar.lastThankYou != nil },
                    set: { if !$0 { tipJar.lastThankYou = nil } }
                )
            ) {
                Button(L10n.done, role: .cancel) { tipJar.lastThankYou = nil }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart.fill")
                .font(.system(size: 44))
                .foregroundStyle(Theme.accent)
            Text(L10n.tipsHeadline)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
            Text(L10n.tipsBody)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 12)
    }

    @ViewBuilder
    private var products: some View {
        switch tipJar.state {
        case .idle, .loading:
            ProgressView().padding(.vertical, 32)
        case .unavailable(let message):
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.vertical, 24)
        case .ready(let tips):
            VStack(spacing: 12) {
                ForEach(tips) { tip in
                    Button {
                        Task { await tipJar.purchase(tip) }
                    } label: {
                        HStack {
                            Text(tip.emoji).font(.title2)
                            Text(tip.displayName).font(.headline)
                            Spacer()
                            Text(tip.displayPrice)
                                .font(.headline.monospacedDigit())
                                .foregroundStyle(Theme.accent)
                        }
                        .padding(16)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .disabled(tipJar.isPurchasing)
                }
            }
        }
    }
}
