import Foundation

enum TimeFormatting {
    /// Convierte segundos a `m:ss`, tolerando negativos y NaN.
    static func clock(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite else { return "0:00" }
        let total = Int(max(0, seconds.rounded()))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
