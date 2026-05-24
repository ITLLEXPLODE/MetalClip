import Cocoa
import AVKit

class ClipLibraryWindowController: NSObject, ClipLibraryDelegate, NSTableViewDataSource, NSTableViewDelegate {

    private var window: NSWindow?
    private var tableView: NSTableView!
    private var playerView: AVPlayerView!
    private var player: AVPlayer?
    private var infoLabel: NSTextField!
    private var sortPopup: NSPopUpButton!
    private var renameButton: NSButton!
    private var deleteButton: NSButton!
    private var finderButton: NSButton!
    // FUTURE: add Enhance, Share, Compress buttons here
    private var emptyLabel: NSTextField!

    let library: ClipLibrary

    private var currentSort: ClipLibrary.SortOrder = .newestFirst
    private var displayGroups: [ClipLibrary.DateGroup] = []
    private var flatList: [ClipMetadata] = []

    private var selectedClip: ClipMetadata? {
        let row = tableView?.selectedRow ?? -1
        guard row >= 0, row < flatList.count else { return nil }
        return flatList[row]
    }

    init(library: ClipLibrary) {
        self.library = library
        super.init()
        library.delegate = self
    }

    // MARK: - Public

    func showWindow(selectingFilename: String? = nil) {
        print("📚 library showWindow called, window=\(String(describing: window))")
        if window == nil {
            createWindow()
        }
        library.refresh()
        print("📚 clips count=\(library.clips.count)")
        reloadData()

        if let name = selectingFilename, let idx = flatList.firstIndex(where: { $0.filename == name }) {
            tableView.selectRowIndexes(IndexSet(integer: idx), byExtendingSelection: false)
            tableView.scrollRowToVisible(idx)
            loadClip(flatList[idx])
        } else if !flatList.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            loadClip(flatList[0])
        }

        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - ClipLibraryDelegate

    func clipLibraryDidUpdate() {
        reloadData()
    }

    // MARK: - Window

    private func createWindow() {
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 700),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        w.title = "MetalClip Library"
        w.isReleasedWhenClosed = false
        w.minSize = NSSize(width: 800, height: 500)
        w.center()

        let split = NSSplitView()
        split.isVertical = true
        split.dividerStyle = .thin
        split.translatesAutoresizingMaskIntoConstraints = false
        w.contentView?.addSubview(split)

        NSLayoutConstraint.activate([
            split.leadingAnchor.constraint(equalTo: w.contentView!.leadingAnchor),
            split.trailingAnchor.constraint(equalTo: w.contentView!.trailingAnchor),
            split.topAnchor.constraint(equalTo: w.contentView!.topAnchor),
            split.bottomAnchor.constraint(equalTo: w.contentView!.bottomAnchor),
        ])

        let sidebar = createSidebar()
        let rightPane = createRightPane()
        split.addSubview(sidebar)
        split.addSubview(rightPane)
        split.setHoldingPriority(.defaultLow, forSubviewAt: 0)
        split.setHoldingPriority(.defaultHigh, forSubviewAt: 1)

        split.setPosition(300, ofDividerAt: 0)

        window = w
    }

    // MARK: - Sidebar

    private func createSidebar() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        sortPopup = NSPopUpButton()
        sortPopup.translatesAutoresizingMaskIntoConstraints = false
        for order in ClipLibrary.SortOrder.allCases {
            sortPopup.addItem(withTitle: order.title)
        }
        sortPopup.target = self
        sortPopup.action = #selector(sortChanged)
        container.addSubview(sortPopup)

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        tableView = NSTableView()
        tableView.style = .plain
        tableView.headerView = nil
        tableView.rowHeight = 80
        tableView.intercellSpacing = NSSize(width: 0, height: 1)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.target = self
        tableView.action = #selector(clipSelected)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("clip"))
        column.width = 280
        tableView.addTableColumn(column)

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Rename", action: #selector(contextRename), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Delete", action: #selector(contextDelete), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Show in Finder", action: #selector(contextShowInFinder), keyEquivalent: ""))
        for item in menu.items { item.target = self }
        tableView.menu = menu

        scrollView.documentView = tableView

        container.addSubview(scrollView)

        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(greaterThanOrEqualToConstant: 250),

            sortPopup.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            sortPopup.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            sortPopup.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),

            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: sortPopup.bottomAnchor, constant: 6),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        return container
    }

    // MARK: - Right Pane

    private func createRightPane() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        playerView = AVPlayerView()
        playerView.translatesAutoresizingMaskIntoConstraints = false
        playerView.controlsStyle = .floating
        container.addSubview(playerView)

        infoLabel = NSTextField(labelWithString: "")
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        infoLabel.font = .systemFont(ofSize: 12)
        infoLabel.textColor = .secondaryLabelColor
        infoLabel.lineBreakMode = .byTruncatingTail
        infoLabel.maximumNumberOfLines = 2
        container.addSubview(infoLabel)

        let buttonStack = NSStackView()
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 8

        renameButton = NSButton(title: "Rename", target: self, action: #selector(renameAction))
        renameButton.bezelStyle = .rounded
        deleteButton = NSButton(title: "Delete", target: self, action: #selector(deleteAction))
        deleteButton.bezelStyle = .rounded
        finderButton = NSButton(title: "Show in Finder", target: self, action: #selector(showInFinderAction))
        finderButton.bezelStyle = .rounded

        buttonStack.addArrangedSubview(renameButton)
        buttonStack.addArrangedSubview(deleteButton)
        buttonStack.addArrangedSubview(finderButton)
        // FUTURE: add Enhance, Share, Compress buttons to buttonStack
        container.addSubview(buttonStack)

        emptyLabel = NSTextField(labelWithString: "No clip selected")
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.font = .systemFont(ofSize: 16, weight: .medium)
        emptyLabel.textColor = .tertiaryLabelColor
        emptyLabel.alignment = .center
        container.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(greaterThanOrEqualToConstant: 400),

            playerView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            playerView.topAnchor.constraint(equalTo: container.topAnchor),
            playerView.bottomAnchor.constraint(equalTo: infoLabel.topAnchor, constant: -8),

            infoLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            infoLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            infoLabel.bottomAnchor.constraint(equalTo: buttonStack.topAnchor, constant: -6),

            buttonStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            buttonStack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10),

            emptyLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])

        return container
    }

    // MARK: - Data

    private func reloadData() {
        displayGroups = library.grouped(by: currentSort)

        flatList = []
        for group in displayGroups {
            for clip in group.clips {
                flatList.append(clip)
            }
        }

        tableView?.reloadData()
        updateRightPane()
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        flatList.count
    }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < flatList.count else { return nil }
        let clip = flatList[row]

        let cell = NSView()

        // Placeholder thumbnail (grey 16:9 rounded rect)
        let thumb = NSView()
        thumb.translatesAutoresizingMaskIntoConstraints = false
        thumb.wantsLayer = true
        thumb.layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
        thumb.layer?.cornerRadius = 4
        // FUTURE: replace placeholder with actual thumbnail from clip.thumbnailPath
        cell.addSubview(thumb)

        let nameLabel = NSTextField(labelWithString: clip.filename)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = .systemFont(ofSize: 12, weight: .medium)
        nameLabel.lineBreakMode = .byTruncatingTail
        cell.addSubview(nameLabel)

        let detailLabel = NSTextField(labelWithString: "\(clip.durationFormatted) · \(clip.resolution) · \(clip.fileSizeFormatted)")
        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        detailLabel.font = .systemFont(ofSize: 10)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.lineBreakMode = .byTruncatingTail
        cell.addSubview(detailLabel)

        NSLayoutConstraint.activate([
            thumb.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
            thumb.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            thumb.widthAnchor.constraint(equalToConstant: 96),
            thumb.heightAnchor.constraint(equalToConstant: 54),

            nameLabel.leadingAnchor.constraint(equalTo: thumb.trailingAnchor, constant: 8),
            nameLabel.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
            nameLabel.topAnchor.constraint(equalTo: thumb.topAnchor, constant: 4),

            detailLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            detailLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            detailLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
        ])

        return cell
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let isGroupStart = groupTitleForRow(row) != nil
        if isGroupStart {
            return nil
        }
        return nil
    }

    func tableView(_ tableView: NSTableView, isGroupRow row: Int) -> Bool {
        false
    }

    // MARK: - Group Headers

    private func groupTitleForRow(_ row: Int) -> String? {
        guard currentSort == .newestFirst || currentSort == .oldestFirst else { return nil }
        var offset = 0
        for group in displayGroups {
            if row == offset && !group.title.isEmpty {
                return group.title
            }
            offset += group.clips.count
        }
        return nil
    }

    // MARK: - Selection & Playback

    @objc private func clipSelected() {
        guard let clip = selectedClip else { return }
        loadClip(clip)
    }

    private func loadClip(_ clip: ClipMetadata) {
        let url = library.directory.appendingPathComponent(clip.filename)
        player?.pause()
        player = AVPlayer(url: url)
        playerView.player = player
        player?.play()
        updateRightPane()
    }

    private func updateRightPane() {
        guard let clip = selectedClip else {
            infoLabel.stringValue = ""
            renameButton.isEnabled = false
            deleteButton.isEnabled = false
            finderButton.isEnabled = false
            emptyLabel.isHidden = false
            playerView.isHidden = true
            return
        }

        emptyLabel.isHidden = true
        playerView.isHidden = false
        renameButton.isEnabled = true
        deleteButton.isEnabled = true
        finderButton.isEnabled = true

        infoLabel.stringValue = "\(clip.filename)\n\(clip.durationFormatted) · \(clip.resolution) · \(clip.fileSizeFormatted) · \(clip.relativeDateFormatted)"
    }

    // MARK: - Actions

    @objc private func sortChanged() {
        currentSort = ClipLibrary.SortOrder(rawValue: sortPopup.indexOfSelectedItem) ?? .newestFirst
        reloadData()
    }

    @objc private func renameAction() {
        guard let clip = selectedClip else { return }
        performRename(clip)
    }

    @objc private func deleteAction() {
        guard let clip = selectedClip else { return }
        performDelete(clip)
    }

    @objc private func showInFinderAction() {
        guard let clip = selectedClip else { return }
        let url = library.directory.appendingPathComponent(clip.filename)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    // MARK: - Context Menu

    @objc private func contextRename() {
        let row = tableView.clickedRow
        guard row >= 0, row < flatList.count else { return }
        performRename(flatList[row])
    }

    @objc private func contextDelete() {
        let row = tableView.clickedRow
        guard row >= 0, row < flatList.count else { return }
        performDelete(flatList[row])
    }

    @objc private func contextShowInFinder() {
        let row = tableView.clickedRow
        guard row >= 0, row < flatList.count else { return }
        let url = library.directory.appendingPathComponent(flatList[row].filename)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    // MARK: - Rename / Delete

    private func performRename(_ clip: ClipMetadata) {
        let alert = NSAlert()
        alert.messageText = "Rename Clip"
        alert.informativeText = "Enter a new name:"
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 250, height: 24))
        let baseName = (clip.filename as NSString).deletingPathExtension
        field.stringValue = baseName
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let newName = field.stringValue.trimmingCharacters(in: .whitespaces)
        guard !newName.isEmpty else { return }

        if !library.rename(clip: clip, to: newName) {
            let err = NSAlert()
            err.messageText = "Rename Failed"
            err.informativeText = "A file with that name may already exist."
            err.runModal()
        }
    }

    private func performDelete(_ clip: ClipMetadata) {
        let alert = NSAlert()
        alert.messageText = "Delete Clip?"
        alert.informativeText = "Are you sure you want to delete \"\(clip.filename)\"? This cannot be undone."
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        player?.pause()
        player = nil
        playerView.player = nil

        library.delete(clip: clip)

        if !flatList.isEmpty {
            let newRow = min(tableView.selectedRow, flatList.count - 1)
            if newRow >= 0 {
                tableView.selectRowIndexes(IndexSet(integer: newRow), byExtendingSelection: false)
                loadClip(flatList[newRow])
            }
        }
    }
}
