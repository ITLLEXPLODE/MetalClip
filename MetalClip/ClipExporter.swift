import AVFoundation

enum ExporterError: LocalizedError {
    case noSegments
    case noTracks
    case exportFailed(String)

    var errorDescription: String? {
        switch self {
        case .noSegments: return "No segments to export"
        case .noTracks: return "Segments contain no video tracks"
        case .exportFailed(let msg): return "Export failed: \(msg)"
        }
    }
}

class ClipExporter {

    static func export(
        segmentURLs: [URL],
        lastSeconds: TimeInterval,
        to outputURL: URL,
        quality: String = "High"
    ) async throws {
        guard !segmentURLs.isEmpty else { throw ExporterError.noSegments }

        let neededCount = Int(ceil(lastSeconds / 15.0)) + 2
        let startIdx = max(0, segmentURLs.count - neededCount)
        let urls = Array(segmentURLs[startIdx...])

        let outputDir = outputURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        try? FileManager.default.removeItem(at: outputURL)

        let composition = AVMutableComposition()

        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ), let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw ExporterError.exportFailed("Cannot create composition tracks")
        }

        var insertTime = CMTime.zero
        var tracksFound = 0

        for url in urls {
            let asset = AVURLAsset(url: url)

            guard let sourceVideo = try? await asset.loadTracks(withMediaType: .video).first else { continue }
            let videoRange = try await sourceVideo.load(.timeRange)
            guard videoRange.duration.seconds > 0.1 else { continue }

            try videoTrack.insertTimeRange(videoRange, of: sourceVideo, at: insertTime)
            tracksFound += 1

            if let sourceAudio = try? await asset.loadTracks(withMediaType: .audio).first {
                try? audioTrack.insertTimeRange(videoRange, of: sourceAudio, at: insertTime)
            }

            insertTime = CMTimeAdd(insertTime, videoRange.duration)
        }

        guard tracksFound > 0 else { throw ExporterError.noTracks }

        let totalDuration = composition.duration
        let requestedDuration = CMTime(seconds: lastSeconds, preferredTimescale: 600)

        if totalDuration > requestedDuration {
            let excess = CMTimeSubtract(totalDuration, requestedDuration)
            composition.removeTimeRange(CMTimeRange(start: .zero, duration: excess))
        }

        // Preset-based export — no video composition, preserves original timing/FPS
        let presetName: String
        switch quality {
        case "Low":
            presetName = AVAssetExportPreset1280x720
        case "Medium":
            presetName = AVAssetExportPresetHEVC1920x1080
        default:
            presetName = AVAssetExportPresetHEVCHighestQuality
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".mp4")

        guard let session = AVAssetExportSession(
            asset: composition,
            presetName: presetName
        ) else {
            throw ExporterError.exportFailed("Cannot create export session")
        }

        session.outputURL = tempURL
        session.outputFileType = .mp4

        await session.export()

        if session.status != .completed {
            throw ExporterError.exportFailed(
                session.error?.localizedDescription ?? "Unknown error"
            )
        }

        try? FileManager.default.removeItem(at: outputURL)
        try FileManager.default.moveItem(at: tempURL, to: outputURL)
    }
}
