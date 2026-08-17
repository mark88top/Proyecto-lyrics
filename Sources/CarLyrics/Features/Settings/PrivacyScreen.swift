import SwiftUI

/// Política de privacidad embebida. La misma versión se publica como página
/// web, porque App Store Connect exige una URL pública (ver docs/PRIVACY.md).
struct PrivacyScreen: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    section(
                        "Qué datos recogemos",
                        "Ninguno. CarLyrics no tiene servidores propios, no tiene cuentas y no registra tu actividad."
                    )
                    section(
                        "Tu cuenta de Spotify",
                        "El token de acceso se guarda cifrado en el Llavero de tu iPhone y nunca sale del dispositivo. Sólo pedimos permisos de lectura: qué canción está sonando y en qué segundo va. No podemos modificar tu música ni acceder a tus playlists privadas."
                    )
                    section(
                        "Búsqueda de letras",
                        "Para encontrar la letra enviamos el título, el artista y la duración de la canción a LRCLIB (lrclib.net), una base comunitaria gratuita. No enviamos ningún dato que te identifique."
                    )
                    section(
                        "Almacenamiento",
                        "Las letras encontradas quedan en la caché del dispositivo para que funcionen sin señal. Podés borrarlas cuando quieras desde Ajustes."
                    )
                    section(
                        "Donaciones",
                        "Las propinas se procesan íntegramente por Apple mediante compras in-app. No vemos ni almacenamos ningún dato de pago."
                    )
                    section(
                        "Terceros",
                        "No hay analítica, no hay publicidad, no hay SDK de seguimiento."
                    )
                }
                .padding(24)
            }
            .navigationTitle(L10n.settingsPrivacy)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.done) { dismiss() }
                }
            }
        }
    }

    private func section(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            Text(body).font(.subheadline).foregroundStyle(.secondary)
        }
    }
}
