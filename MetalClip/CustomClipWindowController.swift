import Cocoa

class CustomClipWindowController: NSObject {

    private var window: NSWindow!
    private var minutesField: NSTextField!
    private var secondsField: NSTextField!
    private var nameField: NSTextField!
    private var folderPathLabel: NSTextField!
    private var qualityPopup: NSPopUpButton!

    private var selectedFolder: URL!
    private let defaultFolder: URL = {
        let movies = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first!
        return movies.appendingPathComponent("MetalClip")
    }()

    var onSave: ((_ totalSeconds: Int, _ clipName: String, _ saveFolder: URL, _ quality: String) -> Void)?
    var availableSecondsProvider: (() -> Int)?

    var snapshotURLs: [URL] = []
    var captureTimestamp: Date?

    var defaultQuality: String = "High"

    func showWindow(snapshotURLs: [URL], captureTimestamp: Date) {
        self.snapshotURLs = snapshotURLs
        self.captureTimestamp = captureTimestamp

        if window == nil {
            createWindow()
        }

        minutesField.stringValue = ""
        secondsField.stringValue = ""

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        nameField.stringValue = fmt.string(from: captureTimestamp)

        selectedFolder = defaultFolder
        folderPathLabel.stringValue = selectedFolder.path

        qualityPopup.selectItem(withTitle: defaultQuality)

        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.makeFirstResponder(minutesField)
    }

    private func createWindow() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 270),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Save Custom Clip"
        window.isReleasedWhenClosed = false
        window.level = .floating

        let content = NSView()
        window.contentView = content

        // --- Minutes ---
        let minutesLabel = NSTextField(labelWithString: "Minutes:")
        minutesLabel.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(minutesLabel)

        minutesField = NSTextField()
        minutesField.translatesAutoresizingMaskIntoConstraints = false
        minutesField.placeholderString = "0"
        let minutesFormatter = NumberFormatter()
        minutesFormatter.minimum = 0
        minutesFormatter.maximum = 30
        minutesFormatter.allowsFloats = false
        minutesField.formatter = minutesFormatter
        content.addSubview(minutesField)

        let minUnit = NSTextField(labelWithString: "min")
        minUnit.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(minUnit)

        // --- Seconds ---
        let secondsLabel = NSTextField(labelWithString: "Seconds:")
        secondsLabel.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(secondsLabel)

        secondsField = NSTextField()
        secondsField.translatesAutoresizingMaskIntoConstraints = false
        secondsField.placeholderString = "0"
        let secondsFormatter = NumberFormatter()
        secondsFormatter.minimum = 0
        secondsFormatter.maximum = 59
        secondsFormatter.allowsFloats = false
        secondsField.formatter = secondsFormatter
        content.addSubview(secondsField)

        let secUnit = NSTextField(labelWithString: "sec")
        secUnit.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(secUnit)

        // --- Clip Name ---
        let nameLabel = NSTextField(labelWithString: "Clip Name:")
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(nameLabel)

        nameField = NSTextField()
        nameField.translatesAutoresizingMaskIntoConstraints = false
        nameField.placeholderString = "Auto-generated"
        content.addSubview(nameField)

        // --- Save To ---
        let folderLabel = NSTextField(labelWithString: "Save to:")
        folderLabel.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(folderLabel)

        folderPathLabel = NSTextField(labelWithString: defaultFolder.path)
        folderPathLabel.translatesAutoresizingMaskIntoConstraints = false
        folderPathLabel.lineBreakMode = .byTruncatingMiddle
        folderPathLabel.textColor = .secondaryLabelColor
        folderPathLabel.font = .systemFont(ofSize: 11)
        content.addSubview(folderPathLabel)

        let browseButton = NSButton(title: "Browse…", target: self, action: #selector(browseAction))
        browseButton.translatesAutoresizingMaskIntoConstraints = false
        browseButton.bezelStyle = .rounded
        browseButton.controlSize = .small
        browseButton.font = .systemFont(ofSize: 11)
        content.addSubview(browseButton)

        // --- Quality ---
        let qualityLabel = NSTextField(labelWithString: "Quality:")
        qualityLabel.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(qualityLabel)

        qualityPopup = NSPopUpButton()
        qualityPopup.translatesAutoresizingMaskIntoConstraints = false
        qualityPopup.addItems(withTitles: ["High", "Medium", "Low"])
        qualityPopup.selectItem(withTitle: defaultQuality)
        content.addSubview(qualityPopup)

        // --- Buttons ---
        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancelAction))
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}"
        content.addSubview(cancelButton)

        let saveButton = NSButton(title: "Save Clip", target: self, action: #selector(saveAction))
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        content.addSubview(saveButton)

        // --- Layout ---
        NSLayoutConstraint.activate([
            minutesLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            minutesLabel.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            minutesLabel.widthAnchor.constraint(equalToConstant: 80),

            minutesField.leadingAnchor.constraint(equalTo: minutesLabel.trailingAnchor, constant: 8),
            minutesField.centerYAnchor.constraint(equalTo: minutesLabel.centerYAnchor),
            minutesField.widthAnchor.constraint(equalToConstant: 60),

            minUnit.leadingAnchor.constraint(equalTo: minutesField.trailingAnchor, constant: 4),
            minUnit.centerYAnchor.constraint(equalTo: minutesLabel.centerYAnchor),

            secondsLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            secondsLabel.topAnchor.constraint(equalTo: minutesLabel.bottomAnchor, constant: 12),
            secondsLabel.widthAnchor.constraint(equalToConstant: 80),

            secondsField.leadingAnchor.constraint(equalTo: secondsLabel.trailingAnchor, constant: 8),
            secondsField.centerYAnchor.constraint(equalTo: secondsLabel.centerYAnchor),
            secondsField.widthAnchor.constraint(equalToConstant: 60),

            secUnit.leadingAnchor.constraint(equalTo: secondsField.trailingAnchor, constant: 4),
            secUnit.centerYAnchor.constraint(equalTo: secondsLabel.centerYAnchor),

            nameLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            nameLabel.topAnchor.constraint(equalTo: secondsLabel.bottomAnchor, constant: 12),
            nameLabel.widthAnchor.constraint(equalToConstant: 80),

            nameField.leadingAnchor.constraint(equalTo: nameLabel.trailingAnchor, constant: 8),
            nameField.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),
            nameField.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),

            folderLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            folderLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 12),
            folderLabel.widthAnchor.constraint(equalToConstant: 80),

            folderPathLabel.leadingAnchor.constraint(equalTo: folderLabel.trailingAnchor, constant: 8),
            folderPathLabel.centerYAnchor.constraint(equalTo: folderLabel.centerYAnchor),
            folderPathLabel.trailingAnchor.constraint(equalTo: browseButton.leadingAnchor, constant: -6),

            browseButton.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            browseButton.centerYAnchor.constraint(equalTo: folderLabel.centerYAnchor),
            browseButton.widthAnchor.constraint(equalToConstant: 70),

            qualityLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            qualityLabel.topAnchor.constraint(equalTo: folderLabel.bottomAnchor, constant: 12),
            qualityLabel.widthAnchor.constraint(equalToConstant: 80),

            qualityPopup.leadingAnchor.constraint(equalTo: qualityLabel.trailingAnchor, constant: 8),
            qualityPopup.centerYAnchor.constraint(equalTo: qualityLabel.centerYAnchor),
            qualityPopup.widthAnchor.constraint(equalToConstant: 120),

            saveButton.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            saveButton.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -16),

            cancelButton.trailingAnchor.constraint(equalTo: saveButton.leadingAnchor, constant: -8),
            cancelButton.centerYAnchor.constraint(equalTo: saveButton.centerYAnchor),
        ])
    }

    @objc private func browseAction() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Select"
        panel.directoryURL = selectedFolder

        if panel.runModal() == .OK, let url = panel.url {
            selectedFolder = url
            folderPathLabel.stringValue = url.path
        }
    }

    @objc private func cancelAction() {
        window.close()
    }

    @objc private func saveAction() {
        let minutes = minutesField.integerValue
        let seconds = secondsField.integerValue
        let name = nameField.stringValue.trimmingCharacters(in: .whitespaces)
        let quality = qualityPopup.titleOfSelectedItem ?? "High"

        let totalSeconds = minutes * 60 + seconds

        if totalSeconds <= 0 {
            showAlert("Invalid Duration", "Please enter a clip length greater than 0 seconds.")
            return
        }

        if totalSeconds > 1800 {
            showAlert("Duration Too Long", "Maximum clip length is 30 minutes.")
            return
        }

        let available = availableSecondsProvider?() ?? totalSeconds
        if totalSeconds > available {
            let availMin = available / 60
            let availSec = available % 60
            let timeStr = availMin > 0 ? "\(availMin)m \(availSec)s" : "\(availSec)s"
            let alert = NSAlert()
            alert.messageText = "Clip will be shorter"
            alert.informativeText = "The app has only been running for \(timeStr). Only \(timeStr) will be saved."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Save Anyway")
            alert.addButton(withTitle: "Cancel")
            if alert.runModal() == .alertSecondButtonReturn {
                return
            }
        }

        try? FileManager.default.createDirectory(at: selectedFolder, withIntermediateDirectories: true)
        onSave?(totalSeconds, name, selectedFolder, quality)
        window.close()
    }

    private func showAlert(_ title: String, _ message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}
