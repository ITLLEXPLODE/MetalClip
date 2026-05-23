import Cocoa
import Carbon

// MARK: - Capture Quality Preset

enum CaptureQualityPreset: String, CaseIterable {
    case performance
    case balanced
    case quality
    case maximum

    var displayName: String {
        let mbps = bitrate / 1_000_000
        switch self {
        case .performance: return "Performance 1080p60 \(mbps)Mbps"
        case .balanced: return "Balanced 1440p60 \(mbps)Mbps"
        case .quality: return "Quality 4K60 \(mbps)Mbps"
        case .maximum: return "Maximum 4K120 \(mbps)Mbps"
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
        let fpsStr = maxFPS == 0 ? "Match" : "\(maxFPS)"
        let mbps = effectiveBitrate / 1_000_000
        return "\(name) \(res)\(fpsStr) \(mbps)Mbps"
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
    var currentBufferMinutes: Int = 30
    var skipShrinkWarning: Bool = false

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
    let bufferSizePresets = [3, 5, 10, 15, 30]

    // MARK: - App Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        loadSettings()
        bufferStartDate = Date()

        isLowPowerActive = ProcessInfo.processInfo.isLowPowerModeEnabled
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(powerStateChanged),
            name: Notification.Name("NSProcessInfoPowerStateDidChangeNotification"),
            object: nil
        )

        setupMenuBar()
        setupHotKeys()
        setupCustomClipWindow()
        setupCustomPresetWindow()
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
            "captureQuality": CaptureQualityPreset.balanced.rawValue,
            "microphone": "Off",
            "bufferMinutes": 30,
            "skipShrinkWarning": false
        ])
        currentClipLength = defaults.integer(forKey: "clipLength")
        currentPreset = CaptureQualityPreset(rawValue: defaults.string(forKey: "captureQuality") ?? "") ?? .balanced
        currentMicrophone = defaults.string(forKey: "microphone") ?? "Off"
        selectedCustomPresetName = defaults.string(forKey: "selectedCustomPreset")
        currentBufferMinutes = defaults.integer(forKey: "bufferMinutes")
        if currentBufferMinutes <= 0 { currentBufferMinutes = 30 }
        skipShrinkWarning = defaults.bool(forKey: "skipShrinkWarning")
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
        defaults.set(currentBufferMinutes, forKey: "bufferMinutes")
        defaults.set(skipShrinkWarning, forKey: "skipShrinkWarning")
        if let data = try? JSONEncoder().encode(customPresets) {
            defaults.set(data, forKey: "customPresets")
        }
    }

    // MARK: - Capture

    func availableBufferSeconds() -> Int {
        let elapsed = Int(Date().timeIntervalSince(bufferStartDate))
        return min(elapsed, currentBufferMinutes * 60)
    }

    func activePresetParams() -> (maxFPS: Int, targetHeight: Int?, bitrate: Int) {
        let cap = isLowPowerActive ? 60 : Int.max
        if let name = selectedCustomPresetName,
           let custom = customPresets.first(where: { $0.name == name }) {
            let fps = custom.maxFPS == 0 ? cap : min(custom.maxFPS, cap)
            return (fps, custom.targetHeight, custom.effectiveBitrate)
        }
        return (min(currentPreset.maxFPS, cap), currentPreset.targetHeight, currentPreset.bitrate)
    }

    func startScreenCapture() {
        let params = activePresetParams()
        screenRecorder = ScreenRecorder()
        screenRecorder.maxBufferDuration = TimeInterval(currentBufferMinutes * 60)
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
            statusText += " · Low Power (Max 60fps)"
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
            keyEquivalent: "1"
        )
        saveClipItem.keyEquivalentModifierMask = [.command, .shift]
        saveClipItem.target = self
        menu.addItem(saveClipItem)

        let customItem = NSMenuItem(
            title: "Save Custom Clip...",
            action: #selector(saveCustomClipAction),
            keyEquivalent: "2"
        )
        customItem.keyEquivalentModifierMask = [.command, .shift]
        customItem.target = self
        menu.addItem(customItem)

        menu.addItem(NSMenuItem.separator())

        let recordingItem = NSMenuItem(
            title: isRecording ? "■ Stop Recording" : "● Start Recording",
            action: #selector(toggleRecordingAction),
            keyEquivalent: "r"
        )
        recordingItem.keyEquivalentModifierMask = [.command, .shift]
        recordingItem.target = self
        menu.addItem(recordingItem)

        menu.addItem(NSMenuItem.separator())

        // Clip Length submenu
        let bufferSeconds = currentBufferMinutes * 60
        let clipLengthMenu = NSMenu()
        clipLengthMenu.autoenablesItems = false
        for seconds in clipLengthPresets {
            let item = NSMenuItem(
                title: formatDuration(seconds),
                action: #selector(setClipLengthAction(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.tag = seconds
            if seconds == currentClipLength { item.state = .on }
            if seconds > bufferSeconds { item.isEnabled = false }
            clipLengthMenu.addItem(item)
        }
        let clipLengthItem = NSMenuItem(title: "Clip Length", action: nil, keyEquivalent: "")
        clipLengthItem.submenu = clipLengthMenu
        menu.addItem(clipLengthItem)

        // Buffer Size submenu
        let bufferMenu = NSMenu()
        let isCustomValue = !bufferSizePresets.contains(currentBufferMinutes)
        for minutes in bufferSizePresets {
            let item = NSMenuItem(
                title: "\(minutes) minutes",
                action: #selector(setBufferSizeAction(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.tag = minutes
            if minutes == currentBufferMinutes { item.state = .on }
            bufferMenu.addItem(item)
        }
        if isCustomValue {
            let customCurrent = NSMenuItem(
                title: "\(currentBufferMinutes) minutes",
                action: nil,
                keyEquivalent: ""
            )
            customCurrent.state = .on
            customCurrent.isEnabled = false
            bufferMenu.addItem(customCurrent)
        }
        bufferMenu.addItem(NSMenuItem.separator())
        let customBufferItem = NSMenuItem(
            title: "Custom...",
            action: #selector(customBufferSizeAction),
            keyEquivalent: ""
        )
        customBufferItem.target = self
        bufferMenu.addItem(customBufferItem)
        let bufferItem = NSMenuItem(title: "Buffer Size", action: nil, keyEquivalent: "")
        bufferItem.submenu = bufferMenu
        menu.addItem(bufferItem)

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

        let micItem = NSMenuItem(title: "Microphone (coming soon)", action: nil, keyEquivalent: "")
        micItem.isEnabled = false
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
            } catch {
                print("❌ Recording failed: \(error)")
            }
            rebuildMenu()
        }
    }

    // MARK: - Settings Actions

    @objc func setClipLengthAction(_ sender: NSMenuItem) {
        currentClipLength = sender.tag
        saveSettings()
        rebuildMenu()
    }

    @objc func setBufferSizeAction(_ sender: NSMenuItem) {
        let newMinutes = sender.tag
        guard newMinutes != currentBufferMinutes else { return }
        applyBufferSize(newMinutes)
    }

    @objc func customBufferSizeAction() {
        let alert = NSAlert()
        alert.messageText = "Custom Buffer Size"
        alert.informativeText = "Enter buffer size in minutes (3–30):"
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 80, height: 24))
        field.stringValue = "\(currentBufferMinutes)"
        alert.accessoryView = field

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        guard let value = Int(field.stringValue), value >= 3, value <= 30 else {
            let err = NSAlert()
            err.messageText = "Invalid Value"
            err.informativeText = "Enter a number between 3 and 30."
            err.runModal()
            return
        }
        guard value != currentBufferMinutes else { return }
        applyBufferSize(value)
    }

    func applyBufferSize(_ newMinutes: Int) {
        let isShrinking = newMinutes < currentBufferMinutes
        let available = availableBufferSeconds()

        if isShrinking && available > 0 && !skipShrinkWarning {
            let alert = NSAlert()
            alert.messageText = "Shrink Buffer?"
            alert.informativeText = "Reducing buffer to \(newMinutes) min will delete older recorded content (currently \(formatDuration(available)) buffered). Save it first?"
            alert.addButton(withTitle: "Save & Shrink")
            alert.addButton(withTitle: "Discard")
            alert.addButton(withTitle: "Cancel")
            alert.showsSuppressionButton = true
            alert.suppressionButton?.title = "Don't ask again"

            let response = alert.runModal()

            if alert.suppressionButton?.state == .on {
                skipShrinkWarning = true
            }

            if response == .alertThirdButtonReturn { return }

            if response == .alertFirstButtonReturn {
                guard let rollingBuffer = screenRecorder.rollingBuffer else { return }
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
        }

        currentBufferMinutes = newMinutes

        let newBufferSeconds = newMinutes * 60
        if currentClipLength > newBufferSeconds {
            let validPresets = clipLengthPresets.filter { $0 <= newBufferSeconds }
            currentClipLength = validPresets.last ?? newBufferSeconds
        }

        saveSettings()
        rebuildMenu()
        restartCapture()
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
            screenRecorder.maxBufferDuration = TimeInterval(currentBufferMinutes * 60)
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

    @objc func openClipsFolderAction() {
        NSWorkspace.shared.open(clipsDirectory())
    }

    // MARK: - Custom Presets

    func setupCustomPresetWindow() {
        customPresetWindowController = CustomPresetWindowController()
        customPresetWindowController.onAdd = { [weak self] preset in
            guard let self else { return }

            let displayHz = NSScreen.main?.maximumFramesPerSecond ?? 60
            let newFPS = preset.maxFPS == 0 ? displayHz : preset.maxFPS
            let newBitrate = preset.effectiveBitrate

            for builtin in CaptureQualityPreset.allCases {
                let builtinHeight = builtin.targetHeight ?? 2160
                if builtinHeight == preset.height && builtin.maxFPS == newFPS && builtin.bitrate == newBitrate {
                    let alert = NSAlert()
                    alert.messageText = "Duplicate Settings"
                    alert.informativeText = "A preset with these settings already exists (\(builtin.displayName))."
                    alert.runModal()
                    return
                }
            }

            for existing in self.customPresets {
                let existFPS = existing.maxFPS == 0 ? displayHz : existing.maxFPS
                let existBitrate = existing.effectiveBitrate
                if existing.height == preset.height && existFPS == newFPS && existBitrate == newBitrate {
                    let alert = NSAlert()
                    alert.messageText = "Duplicate Settings"
                    alert.informativeText = "A preset with these settings already exists (\(existing.displayName))."
                    alert.runModal()
                    return
                }
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

        let label = NSTextField(labelWithString: "Low Power Mode — capture limited to Max 60fps")
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
