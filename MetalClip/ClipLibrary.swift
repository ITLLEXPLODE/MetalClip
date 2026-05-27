import Foundation
import AVFoundation
import ImageIO

protocol ClipLibraryDelegate: AnyObject {
    func clipLibraryDidUpdate()
}

class ClipLibrary {

    weak var delegate: ClipLibraryDelegate?

    private(set) var clips: [ClipMetadata] = []
    private(set) var playlists: [Playlist] = []
    let directory: URL
    private let metadataURL: URL
    private let playlistsURL: URL
    private var isGeneratingThumbnails = false

    struct Playlist: Codable, Identifiable {
        let id: UUID
        var name: String
        var clipIDs: [UUID]
        var coverClipID: UUID? = nil
    }

    var thumbnailsDirectory: URL {
        directory.appendingPathComponent(".thumbnails")
    }

    init(directory: URL) {
        self.directory = directory
        self.metadataURL = directory.appendingPathComponent(".metadata.json")
        self.playlistsURL = directory.appendingPathComponent(".playlists.json")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: directory.appendingPathComponent(".thumbnails"), withIntermediateDirectories: true)
        loadPlaylists()
    }

    // MARK: - Load & Scan

    func refresh() {
        let existing = loadMetadataFile()
        let fm = FileManager.default
        let mp4s = (try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey]))?.filter { $0.pathExtension == "mp4" } ?? []

        let existingByFilename = Dictionary(uniqueKeysWithValues: existing.map { ($0.filename, $0) })
        let currentFilenames = Set(mp4s.map(\.lastPathComponent))

        var merged: [ClipMetadata] = []

        for url in mp4s {
            let name = url.lastPathComponent
            if var meta = existingByFilename[name] {
                meta.fileSize = fileSize(url)
                merged.append(meta)
            } else {
                let meta = buildMetadata(for: url)
                merged.append(meta)
            }
        }

        clips = merged.sorted { $0.dateCreated > $1.dateCreated }
        saveMetadataFile()
        delegate?.clipLibraryDidUpdate()
    }

    // MARK: - CRUD

    func rename(clip: ClipMetadata, to newName: String) -> Bool {
        guard let index = clips.firstIndex(where: { $0.id == clip.id }) else { return false }
        let oldURL = directory.appendingPathComponent(clip.filename)
        let sanitized = newName.trimmingCharacters(in: .whitespaces)
        guard !sanitized.isEmpty else { return false }
        let newFilename = sanitized.hasSuffix(".mp4") ? sanitized : "\(sanitized).mp4"
        let newURL = directory.appendingPathComponent(newFilename)
        guard !FileManager.default.fileExists(atPath: newURL.path) else { return false }

        do {
            try FileManager.default.moveItem(at: oldURL, to: newURL)
            clips[index].filename = newFilename
            saveMetadataFile()
            delegate?.clipLibraryDidUpdate()
            return true
        } catch {
            print("❌ Rename failed: \(error)")
            return false
        }
    }

    func delete(clip: ClipMetadata) {
        let url = directory.appendingPathComponent(clip.filename)
        try? FileManager.default.removeItem(at: url)
        if let thumbPath = clip.thumbnailPath {
            try? FileManager.default.removeItem(atPath: thumbPath)
        }
        clips.removeAll { $0.id == clip.id }
        for i in playlists.indices {
            playlists[i].clipIDs.removeAll { $0 == clip.id }
            if playlists[i].coverClipID == clip.id {
                playlists[i].coverClipID = nil
            }
        }
        saveMetadataFile()
        savePlaylists()
        delegate?.clipLibraryDidUpdate()
    }

    func clip(forFilename filename: String) -> ClipMetadata? {
        clips.first { $0.filename == filename }
    }

    func setFavorite(_ clip: ClipMetadata, _ value: Bool) {
        guard let idx = clips.firstIndex(where: { $0.id == clip.id }) else { return }
        clips[idx].isFavorite = value
        saveMetadataFile()
    }

    // MARK: - Playlists

    @discardableResult
    func createPlaylist(name: String) -> Playlist {
        let p = Playlist(id: UUID(), name: name, clipIDs: [])
        playlists.append(p)
        savePlaylists()
        return p
    }

    func deletePlaylist(_ playlist: Playlist) {
        playlists.removeAll { $0.id == playlist.id }
        savePlaylists()
    }

    func renamePlaylist(_ playlist: Playlist, to newName: String) {
        guard let idx = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        playlists[idx].name = newName
        savePlaylists()
    }

    func addClip(_ clip: ClipMetadata, toPlaylist playlist: Playlist) {
        guard let idx = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        guard !playlists[idx].clipIDs.contains(clip.id) else { return }
        playlists[idx].clipIDs.append(clip.id)
        savePlaylists()
    }

    func removeClip(_ clip: ClipMetadata, fromPlaylist playlist: Playlist) {
        guard let idx = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        playlists[idx].clipIDs.removeAll { $0 == clip.id }
        if playlists[idx].coverClipID == clip.id {
            playlists[idx].coverClipID = nil
        }
        savePlaylists()
    }

    func setPlaylistCover(_ playlist: Playlist, clipID: UUID?) {
        guard let idx = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        playlists[idx].coverClipID = clipID
        savePlaylists()
    }

    func coverThumbnailPath(for playlist: Playlist) -> String? {
        if let coverID = playlist.coverClipID,
           let clip = clips.first(where: { $0.id == coverID }) {
            return clip.thumbnailPath
        }
        return clips(in: playlist).first?.thumbnailPath
    }

    func clips(in playlist: Playlist) -> [ClipMetadata] {
        // FUTURE: drag-reorder clips within a playlist
        playlist.clipIDs.compactMap { clipID in
            clips.first { $0.id == clipID }
        }
    }

    private func loadPlaylists() {
        guard let data = try? Data(contentsOf: playlistsURL),
              let decoded = try? JSONDecoder().decode([Playlist].self, from: data) else {
            playlists = []
            return
        }
        playlists = decoded
    }

    private func savePlaylists() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(playlists) else { return }
        try? data.write(to: playlistsURL, options: .atomic)
    }

    // FUTURE: compress(clip:) -> ClipMetadata

    // MARK: - Search & Filtering

    enum DateFilter: Int, CaseIterable {
        case today, thisWeek, thisMonth, all

        var title: String {
            switch self {
            case .today: return "Today"
            case .thisWeek: return "This Week"
            case .thisMonth: return "This Month"
            case .all: return "All"
            }
        }
    }

    enum LengthFilter: Int, CaseIterable {
        case upTo30s, thirtyTo60s, oneToFive, fiveToTen, tenToTwenty, twentyPlus

        var title: String {
            switch self {
            case .upTo30s: return "~30s"
            case .thirtyTo60s: return "30s~1min"
            case .oneToFive: return "1~5min"
            case .fiveToTen: return "5~10min"
            case .tenToTwenty: return "10~20min"
            case .twentyPlus: return "20min+"
            }
        }

        func matches(duration: TimeInterval) -> Bool {
            switch self {
            case .upTo30s: return duration < 30
            case .thirtyTo60s: return duration >= 30 && duration < 60
            case .oneToFive: return duration >= 60 && duration < 300
            case .fiveToTen: return duration >= 300 && duration < 600
            case .tenToTwenty: return duration >= 600 && duration < 1200
            case .twentyPlus: return duration >= 1200
            }
        }
    }

    var distinctGameLabels: [String] {
        Array(Set(clips.compactMap(\.gameLabel))).sorted()
    }

    func search(text: String, dateFilters: Set<DateFilter>, lengthFilters: Set<LengthFilter>, gameFilters: Set<String>, favoritesOnly: Bool = false, customDateRange: (start: Date, end: Date)? = nil) -> [ClipMetadata] {
        // FUTURE: add quality/tag filters here
        var results = clips

        if favoritesOnly {
            results = results.filter { $0.isFavorite }
        }

        if !text.isEmpty {
            results = results.filter { $0.filename.localizedCaseInsensitiveContains(text) }
        }

        if let range = customDateRange {
            let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: range.end) ?? range.end
            results = results.filter { $0.dateCreated >= range.start && $0.dateCreated < endOfDay }
        } else if !dateFilters.isEmpty && !dateFilters.contains(.all) {
            let calendar = Calendar.current
            let now = Date()
            results = results.filter { clip in
                dateFilters.contains { filter in
                    switch filter {
                    case .today: return calendar.isDateInToday(clip.dateCreated)
                    case .thisWeek: return clip.dateCreated >= calendar.date(byAdding: .day, value: -7, to: now)!
                    case .thisMonth: return clip.dateCreated >= calendar.date(byAdding: .day, value: -30, to: now)!
                    case .all: return true
                    }
                }
            }
        }

        if !lengthFilters.isEmpty {
            results = results.filter { clip in
                lengthFilters.contains { $0.matches(duration: clip.duration) }
            }
        }

        if !gameFilters.isEmpty {
            results = results.filter { clip in
                guard let game = clip.gameLabel else { return false }
                return gameFilters.contains(game)
            }
        }

        return results.sorted { $0.dateCreated > $1.dateCreated }
    }

    // MARK: - Thumbnail Generation

    func generateMissingThumbnails(progress: @escaping (UUID) -> Void) {
        guard !isGeneratingThumbnails else { return }

        let clipsNeedingThumbs = clips.filter { clip in
            guard let path = clip.thumbnailPath else { return true }
            return !FileManager.default.fileExists(atPath: path)
        }
        guard !clipsNeedingThumbs.isEmpty else { return }

        isGeneratingThumbnails = true
        let dir = self.directory
        let thumbsDir = self.thumbnailsDirectory

        Task.detached { [weak self] in
            for clip in clipsNeedingThumbs {
                let videoURL = dir.appendingPathComponent(clip.filename)
                let thumbURL = thumbsDir.appendingPathComponent("\(clip.id.uuidString).jpg")

                do {
                    let asset = AVURLAsset(url: videoURL)
                    let generator = AVAssetImageGenerator(asset: asset)
                    generator.appliesPreferredTrackTransform = true
                    generator.maximumSize = CGSize(width: 480, height: 0)

                    let midTime = CMTime(seconds: clip.duration * 0.5, preferredTimescale: 600)
                    let (cgImage, _) = try await generator.image(at: midTime)

                    guard let dest = CGImageDestinationCreateWithURL(thumbURL as CFURL, "public.jpeg" as CFString, 1, nil) else { continue }
                    CGImageDestinationAddImage(dest, cgImage, [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary)
                    CGImageDestinationFinalize(dest)

                    let path = thumbURL.path
                    await MainActor.run {
                        guard let self else { return }
                        if let idx = self.clips.firstIndex(where: { $0.id == clip.id }) {
                            self.clips[idx].thumbnailPath = path
                            self.saveMetadataFile()
                            progress(clip.id)
                        }
                    }
                } catch {
                    continue
                }
            }

            await MainActor.run {
                self?.isGeneratingThumbnails = false
            }
        }
    }

    // MARK: - Sorting & Grouping

    enum SortOrder: Int, CaseIterable {
        case newestFirst, oldestFirst, longestFirst, shortestFirst

        var title: String {
            switch self {
            case .newestFirst: return "Newest First"
            case .oldestFirst: return "Oldest First"
            case .longestFirst: return "Longest First"
            case .shortestFirst: return "Shortest First"
            }
        }
    }

    func sorted(by order: SortOrder) -> [ClipMetadata] {
        switch order {
        case .newestFirst: return clips.sorted { $0.dateCreated > $1.dateCreated }
        case .oldestFirst: return clips.sorted { $0.dateCreated < $1.dateCreated }
        case .longestFirst: return clips.sorted { $0.duration > $1.duration }
        case .shortestFirst: return clips.sorted { $0.duration < $1.duration }
        }
    }

    struct DateGroup {
        let title: String
        var clips: [ClipMetadata]
    }

    func grouped(by order: SortOrder) -> [DateGroup] {
        let sorted = sorted(by: order)
        guard order == .newestFirst || order == .oldestFirst else {
            return [DateGroup(title: "", clips: sorted)]
        }

        let calendar = Calendar.current
        var today: [ClipMetadata] = []
        var yesterday: [ClipMetadata] = []
        var earlier: [ClipMetadata] = []

        for clip in sorted {
            if calendar.isDateInToday(clip.dateCreated) {
                today.append(clip)
            } else if calendar.isDateInYesterday(clip.dateCreated) {
                yesterday.append(clip)
            } else {
                earlier.append(clip)
            }
        }

        var groups: [DateGroup] = []
        if !today.isEmpty { groups.append(DateGroup(title: "Today", clips: today)) }
        if !yesterday.isEmpty { groups.append(DateGroup(title: "Yesterday", clips: yesterday)) }
        if !earlier.isEmpty { groups.append(DateGroup(title: "Earlier", clips: earlier)) }
        return groups
    }

    // MARK: - Metadata Persistence

    private func loadMetadataFile() -> [ClipMetadata] {
        guard let data = try? Data(contentsOf: metadataURL),
              let decoded = try? JSONDecoder().decode([ClipMetadata].self, from: data) else { return [] }
        return decoded
    }

    private func saveMetadataFile() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(clips) else { return }
        try? data.write(to: metadataURL, options: .atomic)
    }

    // MARK: - Helpers

    private func buildMetadata(for url: URL) -> ClipMetadata {
        let fm = FileManager.default
        let attrs = try? fm.attributesOfItem(atPath: url.path)
        let created = attrs?[.creationDate] as? Date ?? Date()
        let size = (attrs?[.size] as? Int64) ?? 0

        var duration: TimeInterval = 0
        var resolution = ""

        let asset = AVURLAsset(url: url)
        let semaphore = DispatchSemaphore(value: 0)

        Task.detached {
            duration = (try? await asset.load(.duration).seconds) ?? 0
            if let track = try? await asset.loadTracks(withMediaType: .video).first {
                let sz = try? await track.load(.naturalSize)
                let fps = try? await track.load(.nominalFrameRate)
                if let sz, let fps {
                    let h = Int(sz.height)
                    let f = Int(round(fps))
                    resolution = "\(h)p\(f)"
                }
            }
            semaphore.signal()
        }
        semaphore.wait()

        return ClipMetadata(
            id: UUID(),
            filename: url.lastPathComponent,
            dateCreated: created,
            duration: duration,
            fileSize: size,
            resolution: resolution
        )
    }

    private func fileSize(_ url: URL) -> Int64 {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
    }
}
