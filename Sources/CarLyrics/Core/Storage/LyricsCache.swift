import Foundation

/// Caché de letras en dos niveles: memoria (rápida, para el tema actual y
/// los anteriores) y disco (para que un viaje sin señal siga funcionando).
///
/// El disco guarda JSON en `Caches/`, que el sistema puede purgar; es
/// intencional: no queremos ocupar cuota de respaldo del usuario.
actor LyricsCache {
    private struct Entry: Codable {
        let lyrics: Lyrics?
        let storedAt: Date
        let isNegative: Bool
    }

    private let directory: URL
    private let fileManager: FileManager
    private var memory: [String: Entry] = [:]
    private let memoryLimit = 24

    /// Los "no encontrado" también se cachean, pero por menos tiempo: la base
    /// de datos comunitaria crece y conviene reintentar de vez en cuando.
    private let positiveTTL: TimeInterval = 60 * 60 * 24 * 60
    private let negativeTTL: TimeInterval = 60 * 60 * 24 * 3

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        self.directory = caches.appendingPathComponent("Lyrics", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func value(for key: String) -> LyricsResult? {
        guard let entry = memory[key] ?? readFromDisk(key) else { return nil }
        guard !isExpired(entry) else {
            memory[key] = nil
            try? fileManager.removeItem(at: fileURL(key))
            return nil
        }
        memory[key] = entry

        if entry.isNegative { return .notFound }
        guard let lyrics = entry.lyrics else { return .notFound }
        return lyrics.isInstrumental ? .instrumental : .found(lyrics)
    }

    func store(_ result: LyricsResult, for key: String) {
        let entry: Entry
        switch result {
        case .found(let lyrics):
            entry = Entry(lyrics: lyrics, storedAt: Date(), isNegative: false)
        case .instrumental:
            let instrumental = Lyrics(lines: [], isSynced: false, sourceName: "", sourceURL: nil, isInstrumental: true)
            entry = Entry(lyrics: instrumental, storedAt: Date(), isNegative: false)
        case .notFound:
            entry = Entry(lyrics: nil, storedAt: Date(), isNegative: true)
        }

        memory[key] = entry
        trimMemoryIfNeeded()

        if let data = try? JSONEncoder().encode(entry) {
            try? data.write(to: fileURL(key), options: .atomic)
        }
    }

    func clear() {
        memory.removeAll()
        try? fileManager.removeItem(at: directory)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    /// Tamaño aproximado en disco, para mostrarlo en Ajustes.
    func diskSizeInBytes() -> Int {
        let contents = (try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey]
        )) ?? []
        return contents.reduce(0) { total, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return total + size
        }
    }

    // MARK: - Interno

    private func isExpired(_ entry: Entry) -> Bool {
        let ttl = entry.isNegative ? negativeTTL : positiveTTL
        return Date().timeIntervalSince(entry.storedAt) > ttl
    }

    private func fileURL(_ key: String) -> URL {
        directory.appendingPathComponent(key).appendingPathExtension("json")
    }

    private func readFromDisk(_ key: String) -> Entry? {
        guard let data = try? Data(contentsOf: fileURL(key)) else { return nil }
        return try? JSONDecoder().decode(Entry.self, from: data)
    }

    private func trimMemoryIfNeeded() {
        guard memory.count > memoryLimit else { return }
        let sorted = memory.sorted { $0.value.storedAt < $1.value.storedAt }
        for (key, _) in sorted.prefix(memory.count - memoryLimit) {
            memory[key] = nil
        }
    }
}
