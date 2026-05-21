import Cocoa

class CustomPresetWindowController: NSObject, NSTextFieldDelegate {

    private var window: NSWindow!
    private var nameField: NSTextField!
    private var resolutionPopup: NSPopUpButton!
    private var fpsPopup: NSPopUpButton!
    private var bitratePopup: NSPopUpButton!

    var onAdd: ((CustomPreset) -> Void)?

    func showWindow() {
        if window == nil {
            createWindow()
        }
        nameField.stringValue = ""
        resolutionPopup.selectItem(at: 1)
        fpsPopup.selectItem(at: 0)
        bitratePopup.selectItem(at: 0)
        updateAutoBitrateLabel()

        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.makeFirstResponder(nameField)
    }

    private func createWindow() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 260),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Add Custom Quality"
        window.isReleasedWhenClosed = false
        window.level = .floating

        let content = NSView()
        window.contentView = content

        let nameLabel = NSTextField(labelWithString: "Name:")
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(nameLabel)

        nameField = NSTextField()
        nameField.translatesAutoresizingMaskIntoConstraints = false
        nameField.placeholderString = "My Preset"
        nameField.delegate = self
        content.addSubview(nameField)

        let resLabel = NSTextField(labelWithString: "Resolution:")
        resLabel.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(resLabel)

        resolutionPopup = NSPopUpButton()
        resolutionPopup.translatesAutoresizingMaskIntoConstraints = false
        resolutionPopup.addItems(withTitles: ["720p", "1080p", "1440p", "4K (native)"])
        resolutionPopup.target = self
        resolutionPopup.action = #selector(settingChanged)
        content.addSubview(resolutionPopup)

        let fpsLabel = NSTextField(labelWithString: "Frame Rate:")
        fpsLabel.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(fpsLabel)

        fpsPopup = NSPopUpButton()
        fpsPopup.translatesAutoresizingMaskIntoConstraints = false
        fpsPopup.addItems(withTitles: ["Match Display", "120", "60", "50", "48", "30"])
        fpsPopup.target = self
        fpsPopup.action = #selector(settingChanged)
        content.addSubview(fpsPopup)

        let brLabel = NSTextField(labelWithString: "Bitrate:")
        brLabel.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(brLabel)

        bitratePopup = NSPopUpButton()
        bitratePopup.translatesAutoresizingMaskIntoConstraints = false
        bitratePopup.addItems(withTitles: ["Auto", "10 Mbps", "20 Mbps", "30 Mbps", "40 Mbps", "50 Mbps", "60 Mbps"])
        content.addSubview(bitratePopup)

        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancelAction))
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}"
        content.addSubview(cancelButton)

        let addButton = NSButton(title: "Add", target: self, action: #selector(addAction))
        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.bezelStyle = .rounded
        addButton.keyEquivalent = "\r"
        content.addSubview(addButton)

        NSLayoutConstraint.activate([
            nameLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            nameLabel.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            nameLabel.widthAnchor.constraint(equalToConstant: 80),

            nameField.leadingAnchor.constraint(equalTo: nameLabel.trailingAnchor, constant: 8),
            nameField.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),
            nameField.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),

            resLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            resLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 16),
            resLabel.widthAnchor.constraint(equalToConstant: 80),

            resolutionPopup.leadingAnchor.constraint(equalTo: resLabel.trailingAnchor, constant: 8),
            resolutionPopup.centerYAnchor.constraint(equalTo: resLabel.centerYAnchor),
            resolutionPopup.widthAnchor.constraint(equalToConstant: 150),

            fpsLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            fpsLabel.topAnchor.constraint(equalTo: resLabel.bottomAnchor, constant: 16),
            fpsLabel.widthAnchor.constraint(equalToConstant: 80),

            fpsPopup.leadingAnchor.constraint(equalTo: fpsLabel.trailingAnchor, constant: 8),
            fpsPopup.centerYAnchor.constraint(equalTo: fpsLabel.centerYAnchor),
            fpsPopup.widthAnchor.constraint(equalToConstant: 150),

            brLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            brLabel.topAnchor.constraint(equalTo: fpsLabel.bottomAnchor, constant: 16),
            brLabel.widthAnchor.constraint(equalToConstant: 80),

            bitratePopup.leadingAnchor.constraint(equalTo: brLabel.trailingAnchor, constant: 8),
            bitratePopup.centerYAnchor.constraint(equalTo: brLabel.centerYAnchor),
            bitratePopup.widthAnchor.constraint(equalToConstant: 150),

            addButton.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            addButton.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -16),

            cancelButton.trailingAnchor.constraint(equalTo: addButton.leadingAnchor, constant: -8),
            cancelButton.centerYAnchor.constraint(equalTo: addButton.centerYAnchor),
        ])
    }

    private func selectedHeight() -> Int {
        switch resolutionPopup.indexOfSelectedItem {
        case 0: return 720
        case 1: return 1080
        case 2: return 1440
        default: return 2160
        }
    }

    private func selectedFPS() -> Int {
        switch fpsPopup.indexOfSelectedItem {
        case 0: return 0
        case 1: return 120
        case 2: return 60
        case 3: return 50
        case 4: return 48
        case 5: return 30
        default: return 60
        }
    }

    private func selectedBitrate() -> Int {
        switch bitratePopup.indexOfSelectedItem {
        case 0: return 0
        case 1: return 10_000_000
        case 2: return 20_000_000
        case 3: return 30_000_000
        case 4: return 40_000_000
        case 5: return 50_000_000
        case 6: return 60_000_000
        default: return 0
        }
    }

    private func autoBitrate(height: Int, fps: Int) -> Int {
        let base: Int
        switch height {
        case ...720: base = 10_000_000
        case ...1080: base = 20_000_000
        case ...1440: base = 30_000_000
        default: base = 45_000_000
        }
        let effectiveFPS = fps == 0 ? (NSScreen.main?.maximumFramesPerSecond ?? 60) : fps
        return effectiveFPS > 60 ? Int(Double(base) * 1.5) : base
    }

    private func updateAutoBitrateLabel() {
        let computed = autoBitrate(height: selectedHeight(), fps: selectedFPS())
        let mbps = computed / 1_000_000
        bitratePopup.itemArray.first?.title = "Auto (\(mbps) Mbps)"
    }

    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSTextField, field === nameField else { return }
        if field.stringValue.count > 15 {
            field.stringValue = String(field.stringValue.prefix(15))
        }
    }

    @objc private func settingChanged() {
        updateAutoBitrateLabel()
    }

    @objc private func cancelAction() {
        window.close()
    }

    @objc private func addAction() {
        var name = nameField.stringValue.trimmingCharacters(in: .whitespaces)
        if name.isEmpty {
            let res = selectedHeight() >= 2160 ? "4K" : "\(selectedHeight())p"
            let fps = selectedFPS() == 0 ? "Match" : "\(selectedFPS())fps"
            name = "\(res) \(fps)"
        }

        let preset = CustomPreset(
            name: name,
            height: selectedHeight(),
            maxFPS: selectedFPS(),
            bitrate: selectedBitrate()
        )

        onAdd?(preset)
        window.close()
    }
}
