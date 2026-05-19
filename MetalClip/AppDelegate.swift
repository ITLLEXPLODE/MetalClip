import Cocoa
import Carbon

// MARK: - Recording Indicator

class RecordingIndicatorWindow: NSWindow {
    init() {
        let size: CGFloat = 12
        let screen = NSScreen.main
        let origin = NSPoint(
            x: (screen?.frame.maxX ?? 200) - size - 20,
            y: (screen?.frame.maxY ?? 200) - size - 8
        )
        super.init(
            contentRect: NSRect(origin: origin, size: NSSize(width: size, height: size)),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        level = .floating
        sharingType = .none
        collectionBehavior = [.canJoinAllSpaces, .stationary]
        ignoresMouseEvents = true
        hasShadow = false

        let dot = NSView(frame: NSRect(x: 0, y: 0, width: size, height: size))
        dot.wantsLayer = true
        dot.layer?.backgroundColor = NSColor.red.cgColor
        dot.layer?.cornerRadius = size / 2
        contentView = dot
    }
}

// MARK: - AppDelegate

class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Properties

    var statusItem: NSStatusItem!
    var hotKeyManager: HotKeyManager!
    var customClipWindowController: CustomClipWindowController!
    var screenRecorder: ScreenRecorder!
    var recordingIndicator: RecordingIndicatorWindow?
    var clipPlayer: ClipPlayerWindowController!

    var bufferStartDate: Date!

    var currentClipLength: Int = 120
    var currentMicrophone: String = "Off"
    var isRecording: Bool = false
    var currentFPS: Int = 60
    var currentQuality: String = "High"
    var forceApply: Bool = false

    let fpsOptions = [15, 30, 60, 120]
    let qualityOptions = ["High", "Medium", "Low"]

    let saveClipHotKey = HotKey(
        keyCode: 18,
        modifiers: UInt32(cmdKey | shiftKey)
    )
    let customClipHotKey = HotKey(
        keyCode: 19,
        modifiers: UInt32(cmdKey | shiftKey)
    )
    let recordingHotKey = HotKey(
        keyCode: 15,
        modifiers: UInt32(cmdKey | shiftKey)
    )

    let clipLengthPresets = [30, 60, 120, 300, 600, 1800]

    // MARK: - App Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        loadSettings()
        bufferStartDate = Date()
        setupMenuBar()
        setupHotKeys()
        setupCustomClipWindow()
        clipPlayer = ClipPlayerWindowController()
        startScreenCapture()
    }

    func applicationWillTerminate(_ notification: Notification) {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MetalClipBuffer")
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - UserDefaults

    func loadSettings() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [
            "clipLength": 120,
            "fps": 60,
            "quality": "High",
            "forceApply": false,
            "microphone": "Off"
        ])
        currentClipLength = defaults.integer(forKey: "clipLength")
        currentFPS = defaults.integer(forKey: "fps")
        currentQuality = defaults.string(forKey: "quality") ?? "High"
        forceApply = defaults.bool(forKey: "forceApply")
        currentMicrophone = defaults.string(forKey: "microphone") ?? "Off"
    }

    func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(currentClipLength, forKey: "clipLength")
        defaults.set(currentFPS, forKey: "fps")
        defaults.set(currentQuality, forKey: "quality")
        defaults.set(forceApply, forKey: "forceApply")
        defaults.set(currentMicrophone, forKey: "microphone")
    }

    // MARK: - Capture

    func availableBufferSeconds() -> Int {
        let elapsed = Int(Date().timeIntervalSince(bufferStartDate))
        return min(elapsed, 1800)
    }

    func startScreenCapture() {
        screenRecorder = ScreenRecorder()
        screenRecorder.maxBufferDuration = 1800

        if forceApply {
            screenRecorder.requestedFPS = currentFPS
            screenRecorder.qualityScale = qualityScaleValue()
        } else {
            screenRecorder.requestedFPS = 120
            screenRecorder.qualityScale = 1.0
        }

        Task {
            do {
                try await screenRecorder.startCapture()
            } catch {
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "Screen Capture Failed"
                    alert.informativeText = "\(error.localizedDescription)\n\nIf you already granted permission, quit and relaunch the app."
                    alert.alertStyle = .warning
                    alert.runModal()
                }
            }
        }
    }

    // MARK: - Menu Bar

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "record.circle",
                accessibilityDescription: "MetalClip"
            )
        }

        rebuildMenu()
    }

    func rebuildMenu() {
        let menu = NSMenu()

        let statusMenuItem = NSMenuItem(
            title: isRecording ? "● Recording in Progress..." : "MetalClip — Ready",
            action: nil,
            keyEquivalent: ""
        )
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        menu.addItem(NSMenuItem.separator())

        let saveClipItem = NSMenuItem(
            title: "Save Clip (Last \(formatDuration(currentClipLength)))",
            action: #selector(saveClipAction),
            keyEquivalent: ""
        )
        saveClipItem.target = self
        menu.addItem(saveClipItem)

        let customItem = NSMenuItem(
            title: "Save Custom Clip...",
            action: #selector(saveCustomClipAction),
            keyEquivalent: ""
        )
        customItem.target = self
        menu.addItem(customItem)

        menu.addItem(NSMenuItem.separator())

        let recordingItem = NSMenuItem(
            title: isRecording ? "■ Stop Recording" : "● Start Recording",
            action: #selector(toggleRecordingAction),
            keyEquivalent: ""
        )
        recordingItem.target = self
        menu.addItem(recordingItem)

        menu.addItem(NSMenuItem.separator())

        // Clip Length submenu
        let clipLengthMenu = NSMenu()
        for seconds in clipLengthPresets {
            let item = NSMenuItem(
                title: formatDuration(seconds),
                action: #selector(setClipLengthAction(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.tag = seconds
            if seconds == currentClipLength { item.state = .on }
            clipLengthMenu.addItem(item)
        }
        let clipLengthItem = NSMenuItem(title: "Clip Length", action: nil, keyEquivalent: "")
        clipLengthItem.submenu = clipLengthMenu
        menu.addItem(clipLengthItem)

        // FPS submenu
        let fpsMenu = NSMenu()
        for fps in fpsOptions {
            let item = NSMenuItem(
                title: "\(fps) fps",
                action: #selector(setFPSAction(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.tag = fps
            if fps == currentFPS { item.state = .on }
            fpsMenu.addItem(item)
        }
        let fpsItem = NSMenuItem(title: "Frame Rate", action: nil, keyEquivalent: "")
        fpsItem.submenu = fpsMenu
        menu.addItem(fpsItem)

        // Quality submenu
        let qualityMenu = NSMenu()
        for quality in qualityOptions {
            let item = NSMenuItem(
                title: quality,
                action: #selector(setQualityAction(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = quality
            if quality == currentQuality { item.state = .on }
            qualityMenu.addItem(item)
        }
        let qualityItem = NSMenuItem(title: "Quality", action: nil, keyEquivalent: "")
        qualityItem.submenu = qualityMenu
        menu.addItem(qualityItem)

        // Force Apply toggle
        let forceApplyItem = NSMenuItem(
            title: "Force Apply Settings",
            action: #selector(toggleForceApplyAction),
            keyEquivalent: ""
        )
        forceApplyItem.target = self
        forceApplyItem.state = forceApply ? .on : .off
        menu.addItem(forceApplyItem)

        // Microphone submenu
        let micMenu = NSMenu()
        let micOptions = ["Off", "MacBook Pro Microphone"]
        for micName in micOptions {
            let item = NSMenuItem(
                title: micName,
                action: #selector(setMicrophoneAction(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = micName
            if micName == currentMicrophone { item.state = .on }
            micMenu.addItem(item)
        }
        let micItem = NSMenuItem(title: "Microphone", action: nil, keyEquivalent: "")
        micItem.submenu = micMenu
        menu.addItem(micItem)

        menu.addItem(NSMenuItem.separator())

        let openFolderItem = NSMenuItem(
            title: "Open Clips Folder",
            action: #selector(openClipsFolderAction),
            keyEquivalent: ""
        )
        openFolderItem.target = self
        menu.addItem(openFolderItem)

        menu.addItem(NSMenuItem(
            title: "Quit MetalClip",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))

        statusItem.menu = menu
    }

    // MARK: - HotKeys

    func setupHotKeys() {
        hotKeyManager = HotKeyManager()

        hotKeyManager.register(saveClipHotKey) { [weak self] in
            self?.saveClipAction()
        }
        hotKeyManager.register(customClipHotKey) { [weak self] in
            self?.saveCustomClipAction()
        }
        hotKeyManager.register(recordingHotKey) { [weak self] in
            self?.toggleRecordingAction()
        }
    }

    // MARK: - Custom Clip Window

    func setupCustomClipWindow() {
        customClipWindowController = CustomClipWindowController()
        customClipWindowController.availableSecondsProvider = { [weak self] in
            self?.availableBufferSeconds() ?? 0
        }
        customClipWindowController.defaultQuality = currentQuality
        customClipWindowController.onSave = { [weak self] totalSeconds, clipName, saveFolder, quality in
            guard let self else { return }
            let snapshotURLs = self.customClipWindowController.snapshotURLs
            guard !snapshotURLs.isEmpty else {
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "Save Failed"
                    alert.informativeText = "No recorded content available."
                    alert.runModal()
                }
                return
            }
            let available = self.availableBufferSeconds()
            let actual = min(totalSeconds, available)
            let name = clipName.isEmpty ? self.clipFilename() : clipName
            let outputURL = saveFolder.appendingPathComponent("\(name).mp4")

            Task {
                do {
                    try await ClipExporter.export(
                        segmentURLs: snapshotURLs,
                        lastSeconds: TimeInterval(actual),
                        to: outputURL,
                        quality: quality
                    )
                    DispatchQueue.main.async { [weak self] in
                        self?.clipPlayer.show(url: outputURL)
                    }
                } catch {
                    DispatchQueue.main.async {
                        let alert = NSAlert()
                        alert.messageText = "Save Failed"
                        alert.informativeText = error.localizedDescription
                        alert.runModal()
                    }
                }
            }
        }
    }

    // MARK: - Actions

    @objc func saveClipAction() {
        let available = availableBufferSeconds()
        guard available > 0 else { return }
        let actual = min(currentClipLength, available)

        guard let rollingBuffer = screenRecorder.rollingBuffer else { return }
        let snapshotURLs = rollingBuffer.takeSnapshot()
        let outputURL = clipsDirectory().appendingPathComponent("\(clipFilename()).mp4")

        Task {
            do {
                try await ClipExporter.export(
                    segmentURLs: snapshotURLs,
                    lastSeconds: TimeInterval(actual),
                    to: outputURL,
                    quality: currentQuality
                )
                DispatchQueue.main.async { [weak self] in
                    self?.clipPlayer.show(url: outputURL)
                }
            } catch {
                print("❌ Clip save failed: \(error)")
            }
        }
    }

    @objc func saveCustomClipAction() {
        guard let rollingBuffer = screenRecorder.rollingBuffer else { return }
        let timestamp = Date()
        let snapshotURLs = rollingBuffer.takeSnapshot()

        customClipWindowController.defaultQuality = currentQuality
        customClipWindowController.showWindow(snapshotURLs: snapshotURLs, captureTimestamp: timestamp)
    }

    @objc func toggleRecordingAction() {
        if isRecording {
            isRecording = false
            hideRecordingIndicator()
            rebuildMenu()
            screenRecorder.stopContinuousRecording { [weak self] url in
                if let url {
                    DispatchQueue.main.async {
                        self?.clipPlayer.show(url: url)
                    }
                }
            }
        } else {
            let outputURL = clipsDirectory().appendingPathComponent("Recording_\(clipFilename()).mp4")
            do {
                try screenRecorder.startContinuousRecording(to: outputURL)
                isRecording = true
                showRecordingIndicator()
            } catch {
                print("❌ Recording failed: \(error)")
            }
            rebuildMenu()
        }
    }

    // MARK: - Recording Indicator

    func showRecordingIndicator() {
        if recordingIndicator == nil {
            recordingIndicator = RecordingIndicatorWindow()
        }
        recordingIndicator?.orderFront(nil)
    }

    func hideRecordingIndicator() {
        recordingIndicator?.orderOut(nil)
    }

    // MARK: - Settings Actions

    @objc func setClipLengthAction(_ sender: NSMenuItem) {
        currentClipLength = sender.tag
        saveSettings()
        rebuildMenu()
    }

    @objc func setFPSAction(_ sender: NSMenuItem) {
        currentFPS = sender.tag
        saveSettings()
        rebuildMenu()
        if forceApply { restartCapture() }
    }

    @objc func setQualityAction(_ sender: NSMenuItem) {
        if let quality = sender.representedObject as? String {
            currentQuality = quality
            saveSettings()
            rebuildMenu()
            if forceApply { restartCapture() }
        }
    }

    @objc func toggleForceApplyAction() {
        forceApply = !forceApply
        saveSettings()
        rebuildMenu()
        restartCapture()
    }

    func restartCapture() {
        Task {
            await screenRecorder.stopCapture()
            screenRecorder = ScreenRecorder()
            screenRecorder.maxBufferDuration = 1800
            if forceApply {
                screenRecorder.requestedFPS = currentFPS
                screenRecorder.qualityScale = qualityScaleValue()
            } else {
                screenRecorder.requestedFPS = 120
                screenRecorder.qualityScale = 1.0
            }
            bufferStartDate = Date()
            do {
                try await screenRecorder.startCapture()
            } catch {
                print("❌ Restart failed: \(error)")
            }
        }
    }

    func qualityScaleValue() -> Double {
        switch currentQuality {
        case "Medium": return 0.85
        case "Low": return 0.7
        default: return 1.0
        }
    }

    @objc func setMicrophoneAction(_ sender: NSMenuItem) {
        if let micName = sender.representedObject as? String {
            currentMicrophone = micName
            saveSettings()
            rebuildMenu()
        }
    }

    @objc func openClipsFolderAction() {
        NSWorkspace.shared.open(clipsDirectory())
    }

    // MARK: - Utilities

    func clipFilename() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return fmt.string(from: Date())
    }

    func clipsDirectory() -> URL {
        let movies = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first!
        let metalClipDir = movies.appendingPathComponent("MetalClip")
        try? FileManager.default.createDirectory(at: metalClipDir, withIntermediateDirectories: true)
        return metalClipDir
    }

    func formatDuration(_ seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds)s"
        } else if seconds < 3600 {
            let mins = seconds / 60
            let secs = seconds % 60
            return secs == 0 ? "\(mins)m" : "\(mins)m \(secs)s"
        } else {
            let hours = seconds / 3600
            return "\(hours)h"
        }
    }
}
