import Foundation

struct ClipMetadata: Codable, Identifiable, Equatable {
    let id: UUID
    var filename: String
    var dateCreated: Date
    var duration: TimeInterval
    var fileSize: Int64
    var resolution: String

    // FUTURE: game detection
    var gameLabel: String?
    // FUTURE: auto-generated thumbnail
    var thumbnailPath: String?
    // FUTURE: user tags
    var tags: [String] = []
    // FUTURE: zip compression
    var isCompressed: Bool = false
    // FUTURE: playlists
    var playlists: [String] = []
    // FUTURE: user notes
    var notes: String?

    var fileSizeFormatted: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }

    var durationFormatted: String {
        let total = Int(duration)
        let m = total / 60
        let s = total % 60
        return m > 0 ? String(format: "%d:%02d", m, s) : "\(s)s"
    }

    var relativeDateFormatted: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: dateCreated, relativeTo: Date())
    }
}
