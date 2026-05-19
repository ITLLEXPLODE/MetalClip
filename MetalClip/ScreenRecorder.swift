import ScreenCaptureKit
@preconcurrency import AVFoundation

enum RecorderError: LocalizedError {
    case noDisplay
    case notCapturing
    case permissionNeeded

    var errorDescription: String? {
        switch self {
        case .noDisplay: return "No display found"
        case .notCapturing: return "Screen capture is not running"
        case .permissionNeeded: return "Screen recording permission needed. Grant access then relaunch the app."
        }
    }
}

class ScreenRecorder: NSObject, SCStreamOutput, SCStreamDelegate {

    private var stream: SCStream?
    nonisolated(unsafe) private(set) var rollingBuffer: RollingBuffer?

    nonisolated(unsafe) private var continuousWriter: AVAssetWriter?
    nonisolated(unsafe) private var continuousVideoInput: AVAssetWriterInput?
    nonisolated(unsafe) private var continuousAudioInput: AVAssetWriterInput?
    nonisolated(unsafe) private var continuousSessionStarted = false
    private let continuousQueue = DispatchQueue(label: "com.metalclip.continuous")

    nonisolated(unsafe) private(set) var isCapturing = false
    nonisolated(unsafe) private(set) var isContinuousRecording = false

    var maxBufferDuration: TimeInterval = 1800
    var requestedFPS: Int = 30
    var qualityScale: Double = 1.0

    nonisolated(unsafe) private var captureWidth: Int = 1920
    nonisolated(unsafe) private var captureHeight: Int = 1080

    // MARK: - Capture Lifecycle

    func startCapture() async throws {
        if !CGPreflightScreenCaptureAccess() {
            CGRequestScreenCaptureAccess()
            throw RecorderError.permissionNeeded
        }

        let content = try await SCShareableContent.excludingDesktopWindows(
            false, onScreenWindowsOnly: true
        )
        guard let display = content.displays.first else {
            throw RecorderError.noDisplay
        }

        let scaleFactor = NSScreen.main?.backingScaleFactor ?? 2.0
        captureWidth = Int(Double(display.width) * scaleFactor * qualityScale)
        captureHeight = Int(Double(display.height) * scaleFactor * qualityScale)
        // H.264 requires even dimensions
        captureWidth = captureWidth & ~1
        captureHeight = captureHeight & ~1

        let filter = SCContentFilter(display: display, excludingWindows: [])

        let config = SCStreamConfiguration()
        config.width = captureWidth
        config.height = captureHeight
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(requestedFPS))
        config.capturesAudio = true
        config.queueDepth = 8
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.colorSpaceName = CGColorSpace.displayP3

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MetalClipBuffer", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        rollingBuffer = RollingBuffer(
            directory: tempDir,
            maxDuration: maxBufferDuration,
            width: captureWidth,
            height: captureHeight
        )

        stream = SCStream(filter: filter, configuration: config, delegate: self)
        try stream?.addStreamOutput(self, type: .screen, sampleHandlerQueue: .global(qos: .userInitiated))
        try stream?.addStreamOutput(self, type: .audio, sampleHandlerQueue: .global(qos: .userInitiated))

        try await stream?.startCapture()
        isCapturing = true
        print("✅ Screen capture started (\(captureWidth)x\(captureHeight) @ \(requestedFPS)fps)")
    }

    func stopCapture() async {
        try? await stream?.stopCapture()
        stream = nil
        rollingBuffer?.finalize()
        rollingBuffer = nil
        isCapturing = false
    }

    // MARK: - SCStreamOutput

    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard sampleBuffer.isValid, CMSampleBufferDataIsReady(sampleBuffer) else { return }

        autoreleasepool {
            switch type {
            case .screen:
                guard sampleBuffer.imageBuffer != nil else { return }
                rollingBuffer?.appendVideoSample(sampleBuffer)
                if isContinuousRecording {
                    appendToContinuous(sampleBuffer, isVideo: true)
                }
            case .audio:
                rollingBuffer?.appendAudioSample(sampleBuffer)
                if isContinuousRecording {
                    appendToContinuous(sampleBuffer, isVideo: false)
                }
            default:
                break
            }
        }
    }

    // MARK: - SCStreamDelegate

    nonisolated func stream(_ stream: SCStream, didStopWithError error: any Error) {
        print("❌ Stream error: \(error.localizedDescription)")
    }

    // MARK: - Save Clip (from rolling buffer)

    func saveClip(lastSeconds: Int, to outputURL: URL, completion: @escaping (Bool) -> Void) {
        guard let rollingBuffer else {
            completion(false)
            return
        }
        rollingBuffer.exportClip(lastSeconds: lastSeconds, to: outputURL, completion: completion)
    }

    // MARK: - Continuous Recording

    func startContinuousRecording(to url: URL) throws {
        let writer = try AVAssetWriter(url: url, fileType: .mp4)

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.hevc,
            AVVideoWidthKey: captureWidth,
            AVVideoHeightKey: captureHeight,
            AVVideoColorPropertiesKey: [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_P3_D65,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
            ],
            AVVideoCompressionPropertiesKey: [
                AVVideoAllowFrameReorderingKey: false,
            ],
        ]
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = true
        writer.add(videoInput)

        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 48000,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: 128_000,
        ]
        let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        audioInput.expectsMediaDataInRealTime = true
        writer.add(audioInput)

        writer.startWriting()

        continuousWriter = writer
        continuousVideoInput = videoInput
        continuousAudioInput = audioInput
        continuousSessionStarted = false
        isContinuousRecording = true
        print("⏺ Recording started → \(url.lastPathComponent)")
    }

    func stopContinuousRecording(completion: @escaping (URL?) -> Void) {
        isContinuousRecording = false
        continuousQueue.async { [weak self] in
            guard let self, let writer = self.continuousWriter else {
                completion(nil)
                return
            }
            let outputURL = writer.outputURL
            self.continuousVideoInput?.markAsFinished()
            self.continuousAudioInput?.markAsFinished()
            writer.finishWriting {
                self.continuousWriter = nil
                self.continuousVideoInput = nil
                self.continuousAudioInput = nil
                print("⏹ Recording saved → \(outputURL.lastPathComponent)")
                completion(outputURL)
            }
        }
    }

    nonisolated private func appendToContinuous(_ sampleBuffer: CMSampleBuffer, isVideo: Bool) {
        continuousQueue.async { [weak self] in
            guard let self,
                  let writer = self.continuousWriter,
                  writer.status == .writing else { return }

            if !self.continuousSessionStarted {
                writer.startSession(atSourceTime: sampleBuffer.presentationTimeStamp)
                self.continuousSessionStarted = true
            }

            if isVideo {
                if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                    CVBufferSetAttachment(pixelBuffer, kCVImageBufferColorPrimariesKey, kCVImageBufferColorPrimaries_P3_D65, .shouldPropagate)
                    CVBufferSetAttachment(pixelBuffer, kCVImageBufferTransferFunctionKey, kCVImageBufferTransferFunction_ITU_R_709_2, .shouldPropagate)
                    CVBufferSetAttachment(pixelBuffer, kCVImageBufferYCbCrMatrixKey, kCVImageBufferYCbCrMatrix_ITU_R_709_2, .shouldPropagate)
                }
                if let input = self.continuousVideoInput, input.isReadyForMoreMediaData {
                    input.append(sampleBuffer)
                }
            } else {
                if let input = self.continuousAudioInput, input.isReadyForMoreMediaData {
                    input.append(sampleBuffer)
                }
            }
        }
    }
}
