import CarPlay
import Foundation

/// Arma las secciones de CarPlay a partir del estado de la app.
///
/// Es un `struct` sin dependencias de UIKit vivas justamente para poder
/// testearlo: la lógica de "qué se ve en el auto" es la más difícil de
/// probar a mano (hace falta un auto) y la más cara de equivocar.
struct CarPlayLyricsBoard {
    let lyricsState: LyricsViewState
    let playback: PlaybackState
    let connection: PlaybackConnectionState
    let isAuthorized: Bool
    let visibleLines: Int

    /// Radio de la ventana alrededor de la línea activa. Con `visibleLines`
    /// = 3 mostramos anterior + actual + siguiente.
    private var radius: Int { max(0, (visibleLines - 1) / 2) }

    /// Huella del contenido. Si no cambia, no hace falta repintar.
    var identity: String {
        var parts: [String] = [
            isAuthorized ? "auth" : "noauth",
            playback.track?.id ?? "notrack",
            String(describing: connection)
        ]
        switch lyricsState {
        case .idle: parts.append("idle")
        case .loading: parts.append("loading")
        case .notFound: parts.append("notfound")
        case .instrumental: parts.append("instrumental")
        case .failed(let message): parts.append("failed:\(message)")
        case .ready(let snapshot):
            parts.append("ready:\(snapshot.activeIndex.map(String.init) ?? "-")")
        }
        parts.append("lines:\(visibleLines)")
        return parts.joined(separator: "|")
    }

    // MARK: - Construcción

    func makeSections() -> [CPListSection] {
        guard isAuthorized else {
            return [message(L10n.carPlayConnect)]
        }

        switch lyricsState {
        case .idle:
            return [message(L10n.nowPlayingNothing, detail: L10n.nowPlayingNothingDetail)]
        case .loading:
            return [header, message(L10n.lyricsSearching)]
        case .notFound:
            return [header, message(L10n.lyricsNotFound)]
        case .instrumental:
            return [header, message(L10n.lyricsInstrumental)]
        case .failed(let text):
            return [header, message(text)]
        case .ready(let snapshot):
            return [header, lyricsSection(snapshot)]
        }
    }

    /// Cabecera: qué está sonando. En CarPlay no hay carátula grande en una
    /// lista, así que el título es la referencia visual.
    private var header: CPListSection {
        let title = playback.track?.title ?? L10n.appName
        let subtitle = playback.track?.artist ?? ""

        let item = CPListItem(text: title, detailText: subtitle)
        item.isEnabled = false
        return CPListSection(items: [item])
    }

    private func lyricsSection(_ snapshot: LyricsSnapshot) -> CPListSection {
        guard !snapshot.lines.isEmpty else {
            return message(L10n.carPlayNoLyrics)
        }

        // Sin sincronía no podemos seguir la canción: mostramos el arranque
        // de la letra y nada más. Hacer scroll manual al volante no es algo
        // que queramos incentivar.
        guard snapshot.isSynced, let active = snapshot.activeIndex else {
            let preview = snapshot.lines.prefix(visibleLines).map { line -> CPListItem in
                let item = CPListItem(text: line.text, detailText: nil)
                item.isEnabled = false
                return item
            }
            return CPListSection(items: Array(preview), header: L10n.lyricsUnsynced, sectionIndexTitle: nil)
        }

        let lower = max(0, active - radius)
        let upper = min(snapshot.lines.count - 1, active + radius)

        var items: [CPListItem] = []
        for index in lower...upper {
            let line = snapshot.lines[index]
            let text = line.isBlank ? "…" : line.text

            let item: CPListItem
            if index == active {
                // La línea activa se marca con un indicador textual: CarPlay
                // no expone control tipográfico, así que el contraste tiene
                // que venir del contenido.
                item = CPListItem(text: "▸ " + text, detailText: nil)
            } else {
                item = CPListItem(text: text, detailText: nil)
            }
            // Nada de esta lista es accionable: tocar la pantalla manejando
            // es exactamente lo que queremos evitar.
            item.isEnabled = false
            items.append(item)
        }

        return CPListSection(items: items, header: snapshot.sourceName, sectionIndexTitle: nil)
    }

    private func message(_ text: String, detail: String? = nil) -> CPListSection {
        let item = CPListItem(text: text, detailText: detail)
        item.isEnabled = false
        return CPListSection(items: [item])
    }
}
