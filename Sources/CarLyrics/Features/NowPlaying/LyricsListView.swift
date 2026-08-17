import SwiftUI

/// Lista de la letra con auto-scroll a la línea activa.
///
/// Detalle importante de UX: si el usuario hace scroll a mano, dejamos de
/// seguir la canción durante unos segundos. Nada más molesto que la lista
/// te arrastre de vuelta mientras estás leyendo otra parte.
struct LyricsListView: View {
    let snapshot: LyricsSnapshot

    @EnvironmentObject private var settings: UserSettings
    @State private var userIsScrolling = false
    @State private var resumeWorkItem: DispatchWorkItem?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    ForEach(snapshot.lines) { line in
                        LyricLineView(
                            line: line,
                            state: state(for: line),
                            scale: settings.fontScale
                        )
                        .id(line.index)
                    }

                    attribution
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 28)
            }
            .simultaneousGesture(
                DragGesture().onChanged { _ in pauseAutoScroll() }
            )
            .onChange(of: snapshot.activeIndex) { newValue in
                guard let newValue, !userIsScrolling, snapshot.isSynced else { return }
                withAnimation(.easeInOut(duration: 0.35)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }

    private var attribution: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !snapshot.isSynced {
                Label(L10n.lyricsUnsynced, systemImage: "text.alignleft")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            // La atribución al proveedor no es decorativa: es requisito de
            // uso de la fuente de letras.
            Text(L10n.lyricsSource(snapshot.sourceName))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.top, 24)
    }

    private func state(for line: LyricLine) -> LyricLineView.State {
        guard snapshot.isSynced, let active = snapshot.activeIndex else { return .neutral }
        if line.index == active { return .active }
        return line.index < active ? .past : .upcoming
    }

    private func pauseAutoScroll() {
        userIsScrolling = true
        resumeWorkItem?.cancel()

        let item = DispatchWorkItem { userIsScrolling = false }
        resumeWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 6, execute: item)
    }
}

struct LyricLineView: View {
    enum State { case past, active, upcoming, neutral }

    let line: LyricLine
    let state: State
    let scale: Double

    var body: some View {
        Text(line.isBlank ? " " : line.text)
            .font(Theme.lyricFont(scale: scale, isActive: state == .active))
            .foregroundStyle(color)
            .scaleEffect(state == .active ? 1.0 : 0.97, anchor: .leading)
            .animation(.easeOut(duration: 0.25), value: state == .active)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(state == .active ? .isSelected : [])
    }

    private var color: Color {
        switch state {
        case .active: return Theme.activeLine
        case .past: return Theme.pastLine
        case .upcoming: return Theme.inactiveLine
        case .neutral: return Theme.activeLine.opacity(0.85)
        }
    }
}
