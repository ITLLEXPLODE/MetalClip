@preconcurrency import AVFoundation

final class RollingBuffer: @unchecked Sendable {

    struct Segment {
        let url: URL
        let startTime: Date
        var endTime: Date
        var isFinalized: Bool
    }

    private let directory: URL
    private let maxDuration: TimeInterval
    private let segmentDuration: TimeInterval = 15

    private var segments: [Segment] = []
    private var currentWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var sessionStarted = false
    private var currentSegmentStart: Date?
    private var videoFrameCount = 0
    private var audioFrameCount = 0
    private var droppedFrameCount = 0

    private let queue = DispatchQueue(label: "com.metalclip.rollingbuffer")
    private let rotationGroup = DispatchGroup()
    private let pendingLock = NSLock()
    private var pendingSegments: [Segment] = []

    private let width: Int
    private let height: Int
    private let bitrate: Int

    init(directory: URL, maxDuration: TimeInterval, width: Int, height: Int, bitrate: Int = 30_000_000) {
        self.directory = directory
        self.maxDuration = maxDuration
        self.width = width
        self.height = height
        self.bitrate = bitrate
    }

    // MARK: - Append Samples

    func appendVideoSample(_ sampleBuffer: CMSampleBuffer) {
        queue.async { [weak self] in
            guard let self else { return }
            self.ensureWriterReady()
            self.rotateIfNeeded()

            guard let writer = self.currentWriter,
                  writer.status == .writing,
                  let input = self.videoInput else { return }

            guard input.isReadyForMoreMediaData else {
                self.droppedFrameCount += 1
                if self.droppedFrameCount % 30 == 1 {
                    print("⚠️ Dropped \(self.droppedFrameCount) video frames (input not ready)")
                }
                return
            }

            if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                CVBufferSetAttachment(pixelBuffer, kCVImageBufferColorPrimariesKey, kCVImageBufferColorPrimaries_P3_D65, .shouldPropagate)
                CVBufferSetAttachment(pixelBuffer, kCVImageBufferTransferFunctionKey, kCVImageBufferTransferFunction_ITU_R_709_2, .shouldPropagate)
                CVBufferSetAttachment(pixelBuffer, kCVImageBufferYCbCrMatrixKey, kCVImageBufferYCbCrMatrix_ITU_R_709_2, .shouldPropagate)
            }

            if !self.sessionStarted {
                writer.startSession(atSourceTime: sampleBuffer.presentationTimeStamp)
                self.sessionStarted = true
            }

            input.append(sampleBuffer)
            self.videoFrameCount += 1
        }
    }

    func appendAudioSample(_ sampleBuffer: CMSampleBuffer) {
        queue.async { [weak self] in
            guard let self,
                  let writer = self.currentWriter,
                  writer.status == .writing,
                  self.sessionStarted,
                  let input = self.audioInput,
                  input.isReadyForMoreMediaData else { return }

            input.append(sampleBuffer)
            self.audioFrameCount += 1
        }
    }

    // MARK: - Segment Management

    private func ensureWriterReady() {
        if currentWriter == nil {
            startNewSegment()
        }
    }

    private func collectPendingSegments() {
        pendingLock.lock()
        let pending = pendingSegments
        pendingSegments.removeAll()
        pendingLock.unlock()
        segments.append(contentsOf: pending)
    }

    private func rotateIfNeeded() {
        collectPendingSegments()
        guard let start = currentSegmentStart else { return }
        if Date().timeIntervalSince(start) >= segmentDuration {
            finalizeCurrentSegmentAsync()
            startNewSegment()
            cleanupOldSegments()
        }
    }

    private func startNewSegment() {
        let timestamp = String(format: "%.0f", Date().timeIntervalSince1970 * 1000)
        let url = directory.appendingPathComponent("seg_\(timestamp).mov")

        do {
            let writer = try AVAssetWriter(url: url, fileType: .mov)

            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.hevc,
                AVVideoWidthKey: width,
                AVVideoHeightKey: height,
                AVVideoColorPropertiesKey: [
                    AVVideoColorPrimariesKey: AVVideoColorPrimaries_P3_D65,
                    AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                    AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
                ],
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: bitrate,
                    AVVideoAllowFrameReorderingKey: false,
                ],
            ]
            let vInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            vInput.expectsMediaDataInRealTime = true
            writer.add(vInput)

            let audioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 48000,
                AVNumberOfChannelsKey: 2,
                AVEncoderBitRateKey: 128_000,
            ]
            let aInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            aInput.expectsMediaDataInRealTime = true
            writer.add(aInput)

            writer.startWriting()

            currentWriter = writer
            videoInput = vInput
            audioInput = aInput
            sessionStarted = false
            currentSegmentStart = Date()
            print("📝 New segment: \(url.lastPathComponent)")
        } catch {
            print("❌ Segment writer failed: \(error)")
        }
    }

    private func finalizeCurrentSegment() {
        guard let writer = currentWriter else { return }

        videoInput?.markAsFinished()
        audioInput?.markAsFinished()

        let url = writer.outputURL
        let startTime = currentSegmentStart ?? Date()
        let endTime = Date()

        let semaphore = DispatchSemaphore(value: 0)
        writer.finishWriting { semaphore.signal() }
        semaphore.wait()

        let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        print("📼 Segment done: v=\(videoFrameCount) a=\(audioFrameCount) size=\(fileSize/1024)KB status=\(writer.status.rawValue)")

        if writer.status == .failed {
            print("❌ Segment write failed: \(writer.error?.localizedDescription ?? "unknown")")
        }

        videoFrameCount = 0
        audioFrameCount = 0
        droppedFrameCount = 0

        guard writer.status == .completed, fileSize > 0 else { return }

        segments.append(Segment(
            url: url,
            startTime: startTime,
            endTime: endTime,
            isFinalized: true
        ))

        currentWriter = nil
        videoInput = nil
        audioInput = nil
        sessionStarted = false
        currentSegmentStart = nil
    }

    private func finalizeCurrentSegmentAsync() {
        guard let writer = currentWriter else { return }

        videoInput?.markAsFinished()
        audioInput?.markAsFinished()

        let url = writer.outputURL
        let startTime = currentSegmentStart ?? Date()
        let endTime = Date()
        let vCount = videoFrameCount
        let aCount = audioFrameCount

        currentWriter = nil
        videoInput = nil
        audioInput = nil
        sessionStarted = false
        currentSegmentStart = nil
        videoFrameCount = 0
        audioFrameCount = 0
        droppedFrameCount = 0

        rotationGroup.enter()
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let semaphore = DispatchSemaphore(value: 0)
            writer.finishWriting { semaphore.signal() }
            semaphore.wait()

            let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
            print("📼 Segment done: v=\(vCount) a=\(aCount) size=\(fileSize/1024)KB status=\(writer.status.rawValue)")

            if writer.status == .failed {
                print("❌ Segment write failed: \(writer.error?.localizedDescription ?? "unknown")")
            }

            if writer.status == .completed, fileSize > 0 {
                self?.pendingLock.lock()
                self?.pendingSegments.append(Segment(
                    url: url,
                    startTime: startTime,
                    endTime: endTime,
                    isFinalized: true
                ))
                self?.pendingLock.unlock()
            }

            self?.rotationGroup.leave()
        }
    }

    private func cleanupOldSegments() {
        let cutoff = Date().addingTimeInterval(-maxDuration)
        let old = segments.filter { $0.endTime < cutoff }
        segments.removeAll { $0.endTime < cutoff }
        for seg in old {
            try? FileManager.default.removeItem(at: seg.url)
        }
    }

    // MARK: - Export

    func exportClip(lastSeconds: Int, to outputURL: URL, completion: @escaping (Bool) -> Void) {
        queue.async { [weak self] in
            guard let self else {
                completion(false)
                return
            }

            self.rotationGroup.wait()
            self.collectPendingSegments()
            self.finalizeCurrentSegment()
            self.startNewSegment()

            let cutoff = Date().addingTimeInterval(-Double(lastSeconds))
            let relevant = self.segments.filter { $0.isFinalized && $0.endTime > cutoff }
            let urls = relevant.map(\.url)

            guard !urls.isEmpty else {
                print("⚠️ No segments available")
                completion(false)
                return
            }

            print("📦 Exporting \(urls.count) segments → \(outputURL.lastPathComponent)")

            Task {
                do {
                    try await ClipExporter.export(
                        segmentURLs: urls,
                        lastSeconds: TimeInterval(lastSeconds),
                        to: outputURL
                    )
                    print("✅ Clip saved → \(outputURL.lastPathComponent)")
                    completion(true)
                } catch {
                    print("❌ Export failed: \(error)")
                    completion(false)
                }
            }
        }
    }

    // MARK: - Snapshot

    func takeSnapshot() -> [URL] {
        var result: [URL] = []
        queue.sync {
            rotationGroup.wait()
            collectPendingSegments()
            finalizeCurrentSegment()
            startNewSegment()
            result = segments.filter(\.isFinalized).map(\.url)
        }
        return result
    }

    // MARK: - Cleanup

    func finalize() {
        queue.sync {
            rotationGroup.wait()
            collectPendingSegments()
            finalizeCurrentSegment()
            for seg in segments {
                try? FileManager.default.removeItem(at: seg.url)
            }
            segments.removeAll()
        }
    }
}
