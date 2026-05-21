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

// MARK: - Capture Quality Preset

enum CaptureQualityPreset: String, CaseIterable {
    case performance
    case balanced
    case quality
    case maximum

    var displayName: String {
        switch self {
        case .performance: return "Performance 1080p60"
        case .balanced: return "Balanced 1440p60"
        case .quality: return "Quality 4K60"
        case .maximum: return "Maximum 4K120"
        }
    }

    var targetHeight: Int? {
        switch self {
        case .performance: return 1080
        case .balanced: return 1440
        case .quality: return nil
        case .maximum: return nil
        }
    }

    var maxFPS: Int {
        switch self {
        case .performance: return 60
        case .balanced: return 60
        case .quality: return 60
        case .maximum: return 120
        }
    }

    var bitrate: Int {
        switch self {
        case .performance: return 20_000_000
        case .balanced: return 30_000_000
        case .quality: return 45_000_000
        case .maximum: return 60_000_000
        }
    }
}

// MARK: - Custom Preset

struct CustomPreset: Codable, Equatable {
    var name: String
    var height: Int
    var maxFPS: Int
    var bitrate: Int

    var displayName: String {
        let res = height >= 2160 ? "4K" : "\(height)p"
        let fps = maxFPS == 0 ? "Match" : "\(maxFPS)"
        return "\(name) \(res)\(fps)"
    }

    var effectiveBitrate: Int {
        if bitrate > 0 { return bitrate }
        let base: Int
        switch height {
        case ...720: base = 10_000_000
        case ...1080: base = 20_000_000
        case ...1440: base = 30_000_000
        default: base = 45_000_000
        }
        let fps = maxFPS == 0 ? (NSScreen.main?.maximumFramesPerSecond ?? 60) : maxFPS
        return fps > 60 ? Int(Double(base) * 1.5) : base
    }

    var targetHeight: Int? {
        height >= 2160 ? nil : height
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
    var currentPreset: CaptureQualityPreset = .balanced
    var customPresets: [CustomPreset] = []
    var selectedCustomPresetName: String? = nil
    var customPresetWindowController: CustomPresetWindowController!
    var isLowPowerActive = false
    var lowPowerPopupWindow: NSWindow?

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
        setupCustomPresetWindow()
        clipPlayer = ClipPlayerWindowController()
        startScreenCapture()

        isLowPowerActive = ProcessInfo.processInfo.isLowPowerModeEnabled
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(powerStateChanged),
            name: Notification.Name("NSProcessInfoPowerStateDidChangeNotification"),
            object: nil
        )
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
            "captureQuality": CaptureQualityPreset.balanced.rawValue,
            "microphone": "Off"
        ])
        currentClipLength = defaults.integer(forKey: "clipLength")
        currentPreset = CaptureQualityPreset(rawValue: defaults.string(forKey: "captureQuality") ?? "") ?? .balanced
        currentMicrophone = defaults.string(forKey: "microphone") ?? "Off"
        selectedCustomPresetName = defaults.string(forKey: "selectedCustomPreset")
        if let data = defaults.data(forKey: "customPresets"),
           let decoded = try? JSONDecoder().decode([CustomPreset].self, from: data) {
            customPresets = decoded
        }
    }

    func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(currentClipLength, forKey: "clipLength")
        defaults.set(currentPreset.rawValue, forKey: "captureQuality")
        defaults.set(currentMicrophone, forKey: "microphone")
        defaults.set(selectedCustomPresetName, forKey: "selectedCustomPreset")
        if let data = try? JSONEncoder().encode(customPresets) {
            defaults.set(data, forKey: "customPresets")
        }
    }

    // MARK: - Capture

    func availableBufferSeconds() -> Int {
        let elapsed = Int(Date().timeIntervalSince(bufferStartDate))
        return min(elapsed, 1800)
    }

    func activePresetParams() -> (maxFPS: Int, targetHeight: Int?, bitrate: Int) {
        if let name = selectedCustomPresetName,
           let custom = customPresets.first(where: { $0.name == name }) {
            let fps = custom.maxFPS == 0 ? Int.max : custom.maxFPS
            return (fps, custom.targetHeight, custom.effectiveBitrate)
        }
        return (currentPreset.maxFPS, currentPreset.targetHeight, currentPreset.bitrate)
    }

    func startScreenCapture() {
        let params = activePresetParams()
        screenRecorder = ScreenRecorder()
        screenRecorder.maxBufferDuration = 1800
        screenRecorder.captureMaxFPS = params.maxFPS
        screenRecorder.captureTargetHeight = params.targetHeight
        screenRecorder.captureBitrate = params.bitrate

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

        var statusText = isRecording ? "● Recording in Progress..." : "MetalClip — Ready"
        if isLowPowerActive {
            let displayHz = NSScreen.main?.maximumFramesPerSecond ?? 60
            statusText += " · Low Power (\(displayHz)fps)"
        }
        let statusMenuItem = NSMenuItem(
            title: statusText,
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

        // Quality Preset submenu
        let presetMenu = NSMenu()
        for preset in CaptureQualityPreset.allCases {
            let item = NSMenuItem(
                title: preset.displayName,
                action: #selector(setQualityPresetAction(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = preset.rawValue
            if selectedCustomPresetName == nil && preset == currentPreset { item.state = .on }
            presetMenu.addItem(item)
        }

        if !customPresets.isEmpty {
            presetMenu.addItem(NSMenuItem.separator())
            for (index, custom) in customPresets.enumerated() {
                let item = NSMenuItem(
                    title: custom.displayName,
                    action: #selector(setCustomPresetAction(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.tag = index
                if selectedCustomPresetName == custom.name { item.state = .on }
                presetMenu.addItem(item)
            }
        }

        presetMenu.addItem(NSMenuItem.separator())
        let addCustomItem = NSMenuItem(
            title: "Add Custom...",
            action: #selector(addCustomPresetAction),
            keyEquivalent: ""
        )
        addCustomItem.target = self
        presetMenu.addItem(addCustomItem)

        if !customPresets.isEmpty {
            let deleteItem = NSMenuItem(
                title: "Delete Custom Preset...",
                action: #selector(deleteCustomPresetAction),
                keyEquivalent: ""
            )
            deleteItem.target = self
            presetMenu.addItem(deleteItem)
        }

        let presetItem = NSMenuItem(title: "Quality", action: nil, keyEquivalent: "")
        presetItem.submenu = presetMenu
        menu.addItem(presetItem)

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
        customClipWindowController.defaultQuality = "High"
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
                    quality: "High"
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

        customClipWindowController.defaultQuality = "High"
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

    func offerBufferSave(presetName: String) -> Bool {
        let available = availableBufferSeconds()
        guard available > 0 else { return true }

        let alert = NSAlert()
        alert.messageText = "Change Quality?"
        alert.informativeText = "Switching to \(presetName) will clear the current buffer (\(formatDuration(available)) recorded). Save it first?"
        alert.addButton(withTitle: "Save Clip")
        alert.addButton(withTitle: "Discard")
        alert.addButton(withTitle: "Cancel")
        let response = alert.runModal()

        if response == .alertThirdButtonReturn { return false }

        if response == .alertFirstButtonReturn {
            guard let rollingBuffer = screenRecorder.rollingBuffer else { return true }
            let snapshotURLs = rollingBuffer.takeSnapshot()
            let outputURL = clipsDirectory().appendingPathComponent("\(clipFilename()).mp4")
            Task { [weak self] in
                do {
                    try await ClipExporter.export(
                        segmentURLs: snapshotURLs,
                        lastSeconds: TimeInterval(available),
                        to: outputURL,
                        quality: "High"
                    )
                    DispatchQueue.main.async {
                        self?.clipPlayer.show(url: outputURL)
                    }
                } catch {
                    print("❌ Buffer save failed: \(error)")
                }
            }
        }

        return true
    }

    @objc func setQualityPresetAction(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let newPreset = CaptureQualityPreset(rawValue: rawValue),
              newPreset != currentPreset || selectedCustomPresetName != nil else { return }

        guard offerBufferSave(presetName: newPreset.displayName) else { return }

        currentPreset = newPreset
        selectedCustomPresetName = nil
        saveSettings()
        rebuildMenu()
        restartCapture()
    }

    func restartCapture() {
        Task {
            let params = activePresetParams()
            await screenRecorder.stopCapture()
            screenRecorder = ScreenRecorder()
            screenRecorder.maxBufferDuration = 1800
            screenRecorder.captureMaxFPS = params.maxFPS
            screenRecorder.captureTargetHeight = params.targetHeight
            screenRecorder.captureBitrate = params.bitrate
            bufferStartDate = Date()
            do {
                try await screenRecorder.startCapture()
            } catch {
                print("❌ Restart failed: \(error)")
            }
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

    // MARK: - Custom Presets

    func setupCustomPresetWindow() {
        customPresetWindowController = CustomPresetWindowController()
        customPresetWindowController.onAdd = { [weak self] preset in
            guard let self else { return }
            if self.customPresets.contains(where: { $0.name == preset.name }) {
                let alert = NSAlert()
                alert.messageText = "Duplicate Name"
                alert.informativeText = "A preset named '\(preset.name)' already exists."
                alert.runModal()
                return
            }
            self.customPresets.append(preset)
            self.saveSettings()
            self.rebuildMenu()
        }
    }

    @objc func addCustomPresetAction() {
        customPresetWindowController.showWindow()
    }

    @objc func setCustomPresetAction(_ sender: NSMenuItem) {
        let index = sender.tag
        guard index >= 0, index < customPresets.count else { return }
        let custom = customPresets[index]

        guard selectedCustomPresetName != custom.name else { return }
        guard offerBufferSave(presetName: custom.displayName) else { return }

        selectedCustomPresetName = custom.name
        saveSettings()
        rebuildMenu()
        restartCapture()
    }

    @objc func deleteCustomPresetAction() {
        guard !customPresets.isEmpty else { return }

        let alert = NSAlert()
        alert.messageText = "Delete Custom Preset"
        alert.informativeText = "Choose a preset to delete:"
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")

        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 200, height: 28))
        for custom in customPresets {
            popup.addItem(withTitle: custom.displayName)
        }
        alert.accessoryView = popup

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let index = popup.indexOfSelectedItem
        guard index >= 0, index < customPresets.count else { return }

        let deleted = customPresets.remove(at: index)
        let wasActive = selectedCustomPresetName == deleted.name
        if wasActive {
            selectedCustomPresetName = nil
            currentPreset = .balanced
        }
        saveSettings()
        rebuildMenu()
        if wasActive {
            restartCapture()
        }
    }

    // MARK: - Low Power Mode

    @objc func powerStateChanged() {
        let wasLowPower = isLowPowerActive
        isLowPowerActive = ProcessInfo.processInfo.isLowPowerModeEnabled

        DispatchQueue.main.async { [weak self] in
            self?.rebuildMenu()
            if !wasLowPower && self?.isLowPowerActive == true {
                self?.showLowPowerPopup()
            }
        }
    }

    func showLowPowerPopup() {
        let displayHz = NSScreen.main?.maximumFramesPerSecond ?? 60

        let width: CGFloat = 340
        let height: CGFloat = 50
        let screen = NSScreen.main
        let origin = NSPoint(
            x: (screen?.frame.midX ?? 500) - width / 2,
            y: (screen?.frame.maxY ?? 500) - height - 60
        )

        let popup = NSWindow(
            contentRect: NSRect(origin: origin, size: NSSize(width: width, height: height)),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        popup.isOpaque = false
        popup.backgroundColor = NSColor.black.withAlphaComponent(0.85)
        popup.level = .floating
        popup.sharingType = .none
        popup.collectionBehavior = [.canJoinAllSpaces, .stationary]
        popup.ignoresMouseEvents = true
        popup.hasShadow = true

        let content = NSView()
        content.wantsLayer = true
        content.layer?.cornerRadius = 10
        popup.contentView = content

        let label = NSTextField(labelWithString: "Low Power Mode — capture limited to \(displayHz)fps")
        label.textColor = .white
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: content.centerYAnchor),
        ])

        popup.orderFront(nil)
        lowPowerPopupWindow = popup

        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            self?.lowPowerPopupWindow?.orderOut(nil)
            self?.lowPowerPopupWindow = nil
        }
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
