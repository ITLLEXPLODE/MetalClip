import Cocoa
import AVKit

// MARK: - ClipCardItem

class ClipCardItem: NSCollectionViewItem {

    static let identifier = NSUserInterfaceItemIdentifier("ClipCardItem")
    private static let minCardWidth: CGFloat = 240

    private var thumbView: NSView!
    private var durationBadge: NSTextField!
    private var nameLabel: NSTextField!
    private var gameLabel: NSTextField!
    private var detailLabel: NSTextField!
    private var dateLabel: NSTextField!
    private var trackingArea: NSTrackingArea?

    override func loadView() {
        let card = NSView(frame: NSRect(x: 0, y: 0, width: 240, height: 220))
        card.wantsLayer = true
        card.layer?.cornerRadius = 8
        self.view = card

        thumbView = NSView()
        thumbView.translatesAutoresizingMaskIntoConstraints = false
        thumbView.wantsLayer = true
        thumbView.layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
        thumbView.layer?.cornerRadius = 6
        // FUTURE: load thumbnailPath image here
        card.addSubview(thumbView)

        durationBadge = NSTextField(labelWithString: "")
        durationBadge.translatesAutoresizingMaskIntoConstraints = false
        durationBadge.font = .monospacedDigitSystemFont(ofSize: 10, weight: .medium)
        durationBadge.textColor = .white
        durationBadge.wantsLayer = true
        durationBadge.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.7).cgColor
        durationBadge.layer?.cornerRadius = 3
        durationBadge.alignment = .center
        thumbView.addSubview(durationBadge)

        nameLabel = NSTextField(labelWithString: "")
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = .systemFont(ofSize: 12, weight: .medium)
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.maximumNumberOfLines = 1
        card.addSubview(nameLabel)

        gameLabel = NSTextField(labelWithString: "")
        gameLabel.translatesAutoresizingMaskIntoConstraints = false
        gameLabel.font = .systemFont(ofSize: 11)
        gameLabel.textColor = .secondaryLabelColor
        gameLabel.lineBreakMode = .byTruncatingTail
        gameLabel.maximumNumberOfLines = 1
        gameLabel.isHidden = true
        card.addSubview(gameLabel)

        detailLabel = NSTextField(labelWithString: "")
        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        detailLabel.font = .systemFont(ofSize: 10)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.lineBreakMode = .byTruncatingTail
        card.addSubview(detailLabel)

        dateLabel = NSTextField(labelWithString: "")
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        dateLabel.font = .systemFont(ofSize: 10)
        dateLabel.textColor = .tertiaryLabelColor
        card.addSubview(dateLabel)

        NSLayoutConstraint.activate([
            thumbView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 4),
            thumbView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -4),
            thumbView.topAnchor.constraint(equalTo: card.topAnchor, constant: 4),
            thumbView.heightAnchor.constraint(equalTo: thumbView.widthAnchor, multiplier: 9.0 / 16.0),

            durationBadge.trailingAnchor.constraint(equalTo: thumbView.trailingAnchor, constant: -6),
            durationBadge.bottomAnchor.constraint(equalTo: thumbView.bottomAnchor, constant: -6),
            durationBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 36),

            nameLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 8),
            nameLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -8),
            nameLabel.topAnchor.constraint(equalTo: thumbView.bottomAnchor, constant: 6),

            gameLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            gameLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            gameLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),

            detailLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            detailLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            detailLabel.topAnchor.constraint(equalTo: gameLabel.bottomAnchor, constant: 2),

            dateLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            dateLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            dateLabel.topAnchor.constraint(equalTo: detailLabel.bottomAnchor, constant: 2),
        ])
    }

    func configure(with clip: ClipMetadata) {
        durationBadge.stringValue = " \(clip.durationFormatted) "
        nameLabel.stringValue = clip.filename

        if let game = clip.gameLabel, !game.isEmpty {
            gameLabel.stringValue = game
            gameLabel.isHidden = false
        } else {
            gameLabel.isHidden = true
        }

        detailLabel.stringValue = "\(clip.resolution) \u{00B7} \(clip.fileSizeFormatted)"
        dateLabel.stringValue = clip.relativeDateFormatted
    }

    override var isSelected: Bool {
        didSet {
            view.layer?.backgroundColor = isSelected
                ? NSColor.controlAccentColor.withAlphaComponent(0.15).cgColor
                : nil
        }
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        if let ta = trackingArea { view.removeTrackingArea(ta) }
        trackingArea = NSTrackingArea(rect: view.bounds, options: [.mouseEnteredAndExited, .activeInKeyWindow], owner: self)
        view.addTrackingArea(trackingArea!)
    }

    override func mouseEntered(with event: NSEvent) {
        if !isSelected {
            view.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.04).cgColor
        }
    }

    override func mouseExited(with event: NSEvent) {
        if !isSelected {
            view.layer?.backgroundColor = nil
        }
    }

    static func cardHeight(for width: CGFloat) -> CGFloat {
        let thumbH = (width - 8) * 9.0 / 16.0
        return thumbH + 4 + 6 + 14 + 2 + 14 + 2 + 12 + 2 + 12 + 8
    }
}

// MARK: - ClipLibraryWindowController

class ClipLibraryWindowController: NSObject, ClipLibraryDelegate, NSTableViewDataSource, NSTableViewDelegate, NSCollectionViewDataSource, NSCollectionViewDelegate, NSWindowDelegate {

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

    private var clipGridView: NSView!
    private var clipCollectionView: NSCollectionView!
    private var gridScrollView: NSScrollView!
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
        reloadClipGrid()

        if let name = selectingFilename, let idx = flatList.firstIndex(where: { $0.filename == name }) {
            let indexPath = IndexPath(item: idx, section: 0)
            clipCollectionView.selectItems(at: [indexPath], scrollPosition: .centeredVertically)
            openClipInPlayer(flatList[idx])
        }

        pendingSelectFilename = nil

        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - ClipLibraryDelegate

    func clipLibraryDidUpdate() {
        reloadClipGrid()
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

        buildClipGridView()
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

    // MARK: - Clip Grid View

    private func buildClipGridView() {
        clipGridView = NSView()
        clipGridView.translatesAutoresizingMaskIntoConstraints = false

        sortPopup = NSPopUpButton()
        sortPopup.translatesAutoresizingMaskIntoConstraints = false
        for order in ClipLibrary.SortOrder.allCases {
            sortPopup.addItem(withTitle: order.title)
        }
        sortPopup.target = self
        sortPopup.action = #selector(sortChanged)
        clipGridView.addSubview(sortPopup)

        let flowLayout = NSCollectionViewFlowLayout()
        flowLayout.minimumInteritemSpacing = 12
        flowLayout.minimumLineSpacing = 16
        flowLayout.sectionInset = NSEdgeInsets(top: 8, left: 12, bottom: 12, right: 12)

        clipCollectionView = NSCollectionView()
        clipCollectionView.collectionViewLayout = flowLayout
        clipCollectionView.isSelectable = true
        clipCollectionView.allowsMultipleSelection = false
        clipCollectionView.dataSource = self
        clipCollectionView.delegate = self
        clipCollectionView.register(ClipCardItem.self, forItemWithIdentifier: ClipCardItem.identifier)
        clipCollectionView.backgroundColors = [.clear]

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Rename", action: #selector(contextRename), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Delete", action: #selector(contextDelete), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Show in Finder", action: #selector(contextShowInFinder), keyEquivalent: ""))
        for item in menu.items { item.target = self }
        clipCollectionView.menu = menu

        gridScrollView = NSScrollView()
        gridScrollView.translatesAutoresizingMaskIntoConstraints = false
        gridScrollView.hasVerticalScroller = true
        gridScrollView.autohidesScrollers = true
        gridScrollView.documentView = clipCollectionView
        clipGridView.addSubview(gridScrollView)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(gridFrameChanged),
            name: NSView.frameDidChangeNotification,
            object: gridScrollView
        )
        gridScrollView.postsFrameChangedNotifications = true

        NSLayoutConstraint.activate([
            sortPopup.leadingAnchor.constraint(equalTo: clipGridView.leadingAnchor, constant: 12),
            sortPopup.topAnchor.constraint(equalTo: clipGridView.topAnchor, constant: 8),

            gridScrollView.leadingAnchor.constraint(equalTo: clipGridView.leadingAnchor),
            gridScrollView.trailingAnchor.constraint(equalTo: clipGridView.trailingAnchor),
            gridScrollView.topAnchor.constraint(equalTo: sortPopup.bottomAnchor, constant: 6),
            gridScrollView.bottomAnchor.constraint(equalTo: clipGridView.bottomAnchor),
        ])
    }

    @objc private func gridFrameChanged() {
        updateFlowLayoutItemSize()
    }

    private func updateFlowLayoutItemSize() {
        guard let flowLayout = clipCollectionView?.collectionViewLayout as? NSCollectionViewFlowLayout else { return }
        let availableWidth = gridScrollView.frame.width - flowLayout.sectionInset.left - flowLayout.sectionInset.right
        guard availableWidth > 0 else { return }

        let minWidth: CGFloat = 240
        let spacing = flowLayout.minimumInteritemSpacing
        let columns = min(3, max(1, floor((availableWidth + spacing) / (minWidth + spacing))))
        let itemWidth = floor((availableWidth - (columns - 1) * spacing) / columns)
        let itemHeight = ClipCardItem.cardHeight(for: itemWidth)

        flowLayout.itemSize = NSSize(width: itemWidth, height: itemHeight)
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
            target = clipGridView
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

        if item == .allClips {
            DispatchQueue.main.async { [weak self] in
                self?.updateFlowLayoutItemSize()
            }
        }
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

    private func reloadClipGrid() {
        displayGroups = library.grouped(by: currentSort)
        flatList = displayGroups.flatMap(\.clips)
        clipCollectionView?.reloadData()
    }

    // MARK: - NSCollectionViewDataSource

    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        1
    }

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        flatList.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: ClipCardItem.identifier, for: indexPath) as! ClipCardItem
        if indexPath.item < flatList.count {
            item.configure(with: flatList[indexPath.item])
        }
        return item
    }

    // MARK: - NSCollectionViewDelegate

    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        guard let indexPath = indexPaths.first, indexPath.item < flatList.count else { return }
        openClipInPlayer(flatList[indexPath.item])
    }

    // MARK: - NSTableViewDataSource (nav only)

    func numberOfRows(in tableView: NSTableView) -> Int {
        NavItem.allCases.count
    }

    // MARK: - NSTableViewDelegate (nav only)

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        navCell(for: row)
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        28
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
        if event.keyCode == 3 && isShowingPlayer && event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty {
            toggleFullscreen()
        }
    }

    // MARK: - Actions

    @objc private func sortChanged() {
        currentSort = ClipLibrary.SortOrder(rawValue: sortPopup.indexOfSelectedItem) ?? .newestFirst
        reloadClipGrid()
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

    private func clipAtClickPoint() -> ClipMetadata? {
        let point = clipCollectionView.convert(
            clipCollectionView.window!.mouseLocationOutsideOfEventStream,
            from: nil
        )
        guard let indexPath = clipCollectionView.indexPathForItem(at: point),
              indexPath.item < flatList.count else { return nil }
        return flatList[indexPath.item]
    }

    @objc private func contextRename() {
        guard let clip = clipAtClickPoint() else { return }
        performRename(clip)
    }

    @objc private func contextDelete() {
        guard let clip = clipAtClickPoint() else { return }
        performDelete(clip)
    }

    @objc private func contextShowInFinder() {
        guard let clip = clipAtClickPoint() else { return }
        let url = library.directory.appendingPathComponent(clip.filename)
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
