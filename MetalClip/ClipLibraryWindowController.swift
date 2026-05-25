import Cocoa
import AVKit

class ClipLibraryWindowController: NSObject, ClipLibraryDelegate, NSTableViewDataSource, NSTableViewDelegate, NSWindowDelegate {

    // MARK: - Nav

    private enum NavItem: Int, CaseIterable {
        case allClips, search, playlists, settings

        var title: String {
            switch self {
            case .allClips: return "All Clips"
            case .search: return "Search"
            case .playlists: return "Playlists"
            case .settings: return "Settings"
            }
        }

        var symbolName: String {
            switch self {
            case .allClips: return "folder"
            case .search: return "magnifyingglass"
            case .playlists: return "list.bullet.rectangle"
            case .settings: return "gearshape"
            }
        }
    }

    // MARK: - Properties

    private var window: NSWindow?
    private var splitView: NSSplitView!
    private var navSidebarView: NSView!
    private var navTableView: NSTableView!
    private var mainContainer: NSView!

    private var clipListView: NSView!
    private var clipTableView: NSTableView!
    private var sortPopup: NSPopUpButton!

    private var playerContainerView: NSView!
    private var playerView: AVPlayerView!
    private var player: AVPlayer?
    private var playerBackButton: NSButton!
    private var playerFullscreenButton: NSButton!
    private var playerInfoLabel: NSTextField!
    private var playerRenameButton: NSButton!
    private var playerDeleteButton: NSButton!
    private var playerFinderButton: NSButton!
    // FUTURE: add Enhance, Share, Compress buttons to player action row

    private var placeholderViews: [NavItem: NSView] = [:]
    private var playerNormalConstraints: [NSLayoutConstraint] = []
    private var fullscreenOverlayConstraints: [NSLayoutConstraint] = []
    private var buttonStack: NSStackView!

    let library: ClipLibrary

    private var currentNav: NavItem = .allClips
    private var currentSort: ClipLibrary.SortOrder = .newestFirst
    private var displayGroups: [ClipLibrary.DateGroup] = []
    private var flatList: [ClipMetadata] = []
    private var activeClip: ClipMetadata?
    private var isShowingPlayer = false
    private var pendingSelectFilename: String?

    // MARK: - Init

    init(library: ClipLibrary) {
        self.library = library
        super.init()
        library.delegate = self
    }

    // MARK: - Public

    func showWindow(selectingFilename: String? = nil) {
        if window == nil {
            createWindow()
        }

        pendingSelectFilename = selectingFilename
        selectNav(.allClips)

        library.refresh()
        reloadClipList()

        if let name = selectingFilename, let idx = flatList.firstIndex(where: { $0.filename == name }) {
            clipTableView.selectRowIndexes(IndexSet(integer: idx), byExtendingSelection: false)
            clipTableView.scrollRowToVisible(idx)
            openClipInPlayer(flatList[idx])
        }

        pendingSelectFilename = nil

        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - ClipLibraryDelegate

    func clipLibraryDidUpdate() {
        reloadClipList()
    }

    // MARK: - Window

    private func createWindow() {
        let w = LibraryWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 700),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        w.title = "MetalClip Library"
        w.isReleasedWhenClosed = false
        w.minSize = NSSize(width: 800, height: 500)
        w.collectionBehavior = [.fullScreenPrimary]
        w.center()
        w.keyHandler = { [weak self] event in
            self?.handleKeyDown(event)
        }

        w.delegate = self

        let contentView = w.contentView!

        splitView = NSSplitView()
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(splitView)

        NSLayoutConstraint.activate([
            splitView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            splitView.topAnchor.constraint(equalTo: contentView.topAnchor),
            splitView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])

        navSidebarView = createNavSidebar()
        mainContainer = NSView()
        mainContainer.translatesAutoresizingMaskIntoConstraints = false

        splitView.addSubview(navSidebarView)
        splitView.addSubview(mainContainer)
        splitView.setHoldingPriority(.defaultHigh, forSubviewAt: 0)
        splitView.setHoldingPriority(.defaultLow, forSubviewAt: 1)
        splitView.setPosition(160, ofDividerAt: 0)

        buildClipListView()
        buildPlayerView()
        buildPlaceholders()

        showMainView(for: .allClips)

        window = w
    }

    // MARK: - Navigation Sidebar

    private func createNavSidebar() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = false
        scrollView.drawsBackground = false

        navTableView = NSTableView()
        navTableView.style = .plain
        navTableView.headerView = nil
        navTableView.rowHeight = 28
        navTableView.intercellSpacing = NSSize(width: 0, height: 2)
        navTableView.backgroundColor = .clear
        navTableView.selectionHighlightStyle = .regular
        navTableView.dataSource = self
        navTableView.delegate = self
        navTableView.target = self
        navTableView.action = #selector(navClicked)

        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("nav"))
        col.width = 140
        navTableView.addTableColumn(col)

        scrollView.documentView = navTableView

        container.addSubview(scrollView)

        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: 160),

            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        return container
    }

    // MARK: - Clip List View

    private func buildClipListView() {
        clipListView = NSView()
        clipListView.translatesAutoresizingMaskIntoConstraints = false

        sortPopup = NSPopUpButton()
        sortPopup.translatesAutoresizingMaskIntoConstraints = false
        for order in ClipLibrary.SortOrder.allCases {
            sortPopup.addItem(withTitle: order.title)
        }
        sortPopup.target = self
        sortPopup.action = #selector(sortChanged)
        clipListView.addSubview(sortPopup)

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        clipTableView = NSTableView()
        clipTableView.style = .plain
        clipTableView.headerView = nil
        clipTableView.rowHeight = 80
        clipTableView.intercellSpacing = NSSize(width: 0, height: 1)
        clipTableView.dataSource = self
        clipTableView.delegate = self
        clipTableView.target = self
        clipTableView.action = #selector(clipClicked)

        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("clip"))
        col.width = 500
        clipTableView.addTableColumn(col)

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Rename", action: #selector(contextRename), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Delete", action: #selector(contextDelete), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Show in Finder", action: #selector(contextShowInFinder), keyEquivalent: ""))
        for item in menu.items { item.target = self }
        clipTableView.menu = menu

        scrollView.documentView = clipTableView
        clipListView.addSubview(scrollView)

        NSLayoutConstraint.activate([
            sortPopup.leadingAnchor.constraint(equalTo: clipListView.leadingAnchor, constant: 12),
            sortPopup.topAnchor.constraint(equalTo: clipListView.topAnchor, constant: 8),

            scrollView.leadingAnchor.constraint(equalTo: clipListView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: clipListView.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: sortPopup.bottomAnchor, constant: 6),
            scrollView.bottomAnchor.constraint(equalTo: clipListView.bottomAnchor),
        ])
    }

    // MARK: - Player View

    private func buildPlayerView() {
        playerContainerView = NSView()
        playerContainerView.translatesAutoresizingMaskIntoConstraints = false
        playerContainerView.wantsLayer = true
        playerContainerView.layer?.backgroundColor = NSColor.black.cgColor

        playerBackButton = NSButton(title: "\u{2190} Back", target: self, action: #selector(backToList))
        playerBackButton.translatesAutoresizingMaskIntoConstraints = false
        playerBackButton.bezelStyle = .rounded
        playerBackButton.isBordered = false
        playerBackButton.font = .systemFont(ofSize: 13)
        playerBackButton.contentTintColor = .controlAccentColor
        playerContainerView.addSubview(playerBackButton)

        playerFullscreenButton = NSButton(image: NSImage(systemSymbolName: "arrow.up.left.and.arrow.down.right", accessibilityDescription: "Fullscreen")!, target: self, action: #selector(toggleFullscreen))
        playerFullscreenButton.translatesAutoresizingMaskIntoConstraints = false
        playerFullscreenButton.bezelStyle = .rounded
        playerFullscreenButton.isBordered = false
        playerFullscreenButton.contentTintColor = .controlAccentColor
        playerContainerView.addSubview(playerFullscreenButton)

        playerView = AVPlayerView()
        playerView.translatesAutoresizingMaskIntoConstraints = false
        playerView.controlsStyle = .floating
        playerView.videoGravity = .resizeAspect
        playerView.allowsPictureInPicturePlayback = true
        playerView.wantsLayer = true
        playerView.layer?.backgroundColor = NSColor.black.cgColor
        playerContainerView.addSubview(playerView)

        playerInfoLabel = NSTextField(labelWithString: "")
        playerInfoLabel.translatesAutoresizingMaskIntoConstraints = false
        playerInfoLabel.font = .systemFont(ofSize: 12)
        playerInfoLabel.textColor = .secondaryLabelColor
        playerInfoLabel.lineBreakMode = .byTruncatingTail
        playerInfoLabel.maximumNumberOfLines = 2
        playerContainerView.addSubview(playerInfoLabel)

        buttonStack = NSStackView()
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 8

        playerRenameButton = NSButton(title: "Rename", target: self, action: #selector(renameAction))
        playerRenameButton.bezelStyle = .rounded
        playerDeleteButton = NSButton(title: "Delete", target: self, action: #selector(deleteAction))
        playerDeleteButton.bezelStyle = .rounded
        playerFinderButton = NSButton(title: "Show in Finder", target: self, action: #selector(showInFinderAction))
        playerFinderButton.bezelStyle = .rounded

        buttonStack.addArrangedSubview(playerRenameButton)
        buttonStack.addArrangedSubview(playerDeleteButton)
        buttonStack.addArrangedSubview(playerFinderButton)
        // FUTURE: add Enhance, Share, Compress buttons to buttonStack
        playerContainerView.addSubview(buttonStack)

        NSLayoutConstraint.activate([
            playerBackButton.leadingAnchor.constraint(equalTo: playerContainerView.leadingAnchor, constant: 12),
            playerBackButton.topAnchor.constraint(equalTo: playerContainerView.topAnchor, constant: 8),

            playerFullscreenButton.trailingAnchor.constraint(equalTo: playerContainerView.trailingAnchor, constant: -12),
            playerFullscreenButton.centerYAnchor.constraint(equalTo: playerBackButton.centerYAnchor),

            playerView.leadingAnchor.constraint(equalTo: playerContainerView.leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: playerContainerView.trailingAnchor),

            playerInfoLabel.leadingAnchor.constraint(equalTo: playerContainerView.leadingAnchor, constant: 12),
            playerInfoLabel.trailingAnchor.constraint(equalTo: playerContainerView.trailingAnchor, constant: -12),
            playerInfoLabel.bottomAnchor.constraint(equalTo: buttonStack.topAnchor, constant: -6),

            buttonStack.leadingAnchor.constraint(equalTo: playerContainerView.leadingAnchor, constant: 12),
            buttonStack.bottomAnchor.constraint(equalTo: playerContainerView.bottomAnchor, constant: -10),
        ])

        playerNormalConstraints = [
            playerView.topAnchor.constraint(equalTo: playerBackButton.bottomAnchor, constant: 4),
            playerView.bottomAnchor.constraint(equalTo: playerInfoLabel.topAnchor, constant: -8),
        ]

        NSLayoutConstraint.activate(playerNormalConstraints)
    }

    // MARK: - Placeholder Views

    private func buildPlaceholders() {
        for item in [NavItem.search, NavItem.playlists, NavItem.settings] {
            let view = NSView()
            view.translatesAutoresizingMaskIntoConstraints = false

            // FUTURE: replace placeholder with real Search view (4B-5)
            // FUTURE: replace placeholder with real Playlists view (4B-7)
            // FUTURE: replace placeholder with real Settings view (4B-8)
            let label = NSTextField(labelWithString: "\(item.title) coming soon")
            label.translatesAutoresizingMaskIntoConstraints = false
            label.font = .systemFont(ofSize: 18, weight: .medium)
            label.textColor = .tertiaryLabelColor
            label.alignment = .center
            view.addSubview(label)

            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            ])

            placeholderViews[item] = view
        }
    }

    // MARK: - Main Area Switching

    private func showMainView(for item: NavItem) {
        for sub in mainContainer.subviews {
            sub.removeFromSuperview()
        }

        isShowingPlayer = false
        let target: NSView

        switch item {
        case .allClips:
            target = clipListView
        case .search, .playlists, .settings:
            target = placeholderViews[item]!
        }

        mainContainer.addSubview(target)
        NSLayoutConstraint.activate([
            target.leadingAnchor.constraint(equalTo: mainContainer.leadingAnchor),
            target.trailingAnchor.constraint(equalTo: mainContainer.trailingAnchor),
            target.topAnchor.constraint(equalTo: mainContainer.topAnchor),
            target.bottomAnchor.constraint(equalTo: mainContainer.bottomAnchor),
        ])
    }

    private func showPlayerInMain() {
        for sub in mainContainer.subviews {
            sub.removeFromSuperview()
        }

        isShowingPlayer = true
        mainContainer.addSubview(playerContainerView)
        NSLayoutConstraint.activate([
            playerContainerView.leadingAnchor.constraint(equalTo: mainContainer.leadingAnchor),
            playerContainerView.trailingAnchor.constraint(equalTo: mainContainer.trailingAnchor),
            playerContainerView.topAnchor.constraint(equalTo: mainContainer.topAnchor),
            playerContainerView.bottomAnchor.constraint(equalTo: mainContainer.bottomAnchor),
        ])
    }

    // MARK: - Data

    private func reloadClipList() {
        displayGroups = library.grouped(by: currentSort)
        flatList = displayGroups.flatMap(\.clips)
        clipTableView?.reloadData()
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView === navTableView {
            return NavItem.allCases.count
        }
        return flatList.count
    }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if tableView === navTableView {
            return navCell(for: row)
        }
        return clipCell(for: row)
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        if tableView === navTableView { return 28 }
        return 80
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        true
    }

    // MARK: - Nav Cells

    private func navCell(for row: Int) -> NSView {
        guard let item = NavItem(rawValue: row) else { return NSView() }

        let cell = NSView()

        let imageView = NSImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = NSImage(systemSymbolName: item.symbolName, accessibilityDescription: item.title)
        imageView.contentTintColor = .labelColor
        cell.addSubview(imageView)

        let label = NSTextField(labelWithString: item.title)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 13)
        label.lineBreakMode = .byTruncatingTail
        cell.addSubview(label)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 12),
            imageView.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 16),
            imageView.heightAnchor.constraint(equalToConstant: 16),

            label.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
            label.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])

        return cell
    }

    // MARK: - Clip Cells

    private func clipCell(for row: Int) -> NSView? {
        guard row < flatList.count else { return nil }
        let clip = flatList[row]

        let cell = NSView()

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

        let detail = "\(clip.durationFormatted) \u{00B7} \(clip.resolution) \u{00B7} \(clip.fileSizeFormatted)"
        let detailLabel = NSTextField(labelWithString: detail)
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

    // MARK: - Nav Selection

    @objc private func navClicked() {
        let row = navTableView.selectedRow
        guard row >= 0, let item = NavItem(rawValue: row) else { return }
        selectNav(item)
    }

    private func selectNav(_ item: NavItem) {
        currentNav = item
        navTableView?.selectRowIndexes(IndexSet(integer: item.rawValue), byExtendingSelection: false)
        showMainView(for: item)
    }

    // MARK: - Clip Selection & Player

    @objc private func clipClicked() {
        let row = clipTableView.selectedRow
        guard row >= 0, row < flatList.count else { return }
        openClipInPlayer(flatList[row])
    }

    private func openClipInPlayer(_ clip: ClipMetadata) {
        activeClip = clip
        let url = library.directory.appendingPathComponent(clip.filename)
        player?.pause()
        player = AVPlayer(url: url)
        playerView.player = player
        player?.play()
        updatePlayerInfo()
        showPlayerInMain()
    }

    private func updatePlayerInfo() {
        guard let clip = activeClip else { return }
        playerInfoLabel.stringValue = "\(clip.filename)\n\(clip.durationFormatted) \u{00B7} \(clip.resolution) \u{00B7} \(clip.fileSizeFormatted) \u{00B7} \(clip.relativeDateFormatted)"
    }

    @objc private func backToList() {
        player?.pause()
        activeClip = nil
        isShowingPlayer = false
        showMainView(for: .allClips)
    }

    // MARK: - Fullscreen

    @objc private func toggleFullscreen() {
        window?.toggleFullScreen(nil)
    }

    func windowDidEnterFullScreen(_ notification: Notification) {
        guard let contentView = window?.contentView else { return }
        window?.backgroundColor = .black

        splitView.isHidden = true

        playerView.removeFromSuperview()
        NSLayoutConstraint.deactivate(playerNormalConstraints)

        contentView.addSubview(playerView)
        fullscreenOverlayConstraints = [
            playerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            playerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            playerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ]
        NSLayoutConstraint.activate(fullscreenOverlayConstraints)
        contentView.layoutSubtreeIfNeeded()
    }

    func windowDidExitFullScreen(_ notification: Notification) {
        window?.backgroundColor = .windowBackgroundColor

        NSLayoutConstraint.deactivate(fullscreenOverlayConstraints)
        fullscreenOverlayConstraints = []
        playerView.removeFromSuperview()

        playerContainerView.addSubview(playerView, positioned: .below, relativeTo: playerBackButton)
        NSLayoutConstraint.activate([
            playerView.leadingAnchor.constraint(equalTo: playerContainerView.leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: playerContainerView.trailingAnchor),
        ])
        NSLayoutConstraint.activate(playerNormalConstraints)

        splitView.isHidden = false
        splitView.setPosition(160, ofDividerAt: 0)
        splitView.adjustSubviews()
    }

    // MARK: - Keyboard

    func handleKeyDown(_ event: NSEvent) {
        if event.keyCode == 53 {
            if let w = window, w.styleMask.contains(.fullScreen) {
                w.toggleFullScreen(nil)
            } else if isShowingPlayer {
                backToList()
            }
        }
        // 'F' key = keyCode 3
        if event.keyCode == 3 && isShowingPlayer && event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty {
            toggleFullscreen()
        }
    }

    // MARK: - Actions

    @objc private func sortChanged() {
        currentSort = ClipLibrary.SortOrder(rawValue: sortPopup.indexOfSelectedItem) ?? .newestFirst
        reloadClipList()
    }

    @objc private func renameAction() {
        guard let clip = activeClip else { return }
        performRename(clip)
    }

    @objc private func deleteAction() {
        guard let clip = activeClip else { return }
        performDelete(clip)
    }

    @objc private func showInFinderAction() {
        guard let clip = activeClip else { return }
        let url = library.directory.appendingPathComponent(clip.filename)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    // MARK: - Context Menu

    @objc private func contextRename() {
        let row = clipTableView.clickedRow
        guard row >= 0, row < flatList.count else { return }
        performRename(flatList[row])
    }

    @objc private func contextDelete() {
        let row = clipTableView.clickedRow
        guard row >= 0, row < flatList.count else { return }
        performDelete(flatList[row])
    }

    @objc private func contextShowInFinder() {
        let row = clipTableView.clickedRow
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
        activeClip = nil

        library.delete(clip: clip)
        backToList()
    }
}

// MARK: - ESC Key Window Subclass

class LibraryWindow: NSWindow {
    var keyHandler: ((NSEvent) -> Void)?

    override func keyDown(with event: NSEvent) {
        keyHandler?(event)
        super.keyDown(with: event)
    }
}
