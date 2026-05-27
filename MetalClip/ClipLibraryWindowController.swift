import Cocoa
import AVKit
import ServiceManagement

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
    private var starButton: NSButton!
    private var trackingArea: NSTrackingArea?
    private var currentIsFavorite = false
    private var isHovering = false
    var onFavoriteToggle: ((Bool) -> Void)?

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
        thumbView.layer?.contentsGravity = .resizeAspectFill
        thumbView.layer?.masksToBounds = true
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

        starButton = NSButton(image: NSImage(systemSymbolName: "star", accessibilityDescription: "Favorite")!, target: self, action: #selector(starTapped))
        starButton.translatesAutoresizingMaskIntoConstraints = false
        starButton.isBordered = false
        starButton.wantsLayer = true
        starButton.layer?.cornerRadius = 10
        starButton.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.5).cgColor
        starButton.contentTintColor = .white
        starButton.imageScaling = .scaleProportionallyDown
        starButton.isHidden = true
        thumbView.addSubview(starButton)

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

            starButton.topAnchor.constraint(equalTo: thumbView.topAnchor, constant: 6),
            starButton.trailingAnchor.constraint(equalTo: thumbView.trailingAnchor, constant: -6),
            starButton.widthAnchor.constraint(equalToConstant: 20),
            starButton.heightAnchor.constraint(equalToConstant: 20),

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
        if let thumbPath = clip.thumbnailPath,
           let image = NSImage(contentsOfFile: thumbPath),
           let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            thumbView.layer?.contents = cgImage
        } else {
            thumbView.layer?.contents = nil
        }

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

        currentIsFavorite = clip.isFavorite
        isHovering = false
        updateStarAppearance()
    }

    @objc private func starTapped() {
        currentIsFavorite.toggle()
        updateStarAppearance()
        onFavoriteToggle?(currentIsFavorite)
    }

    private func updateStarAppearance() {
        let symbolName = currentIsFavorite ? "star.fill" : "star"
        starButton.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Favorite")
        starButton.contentTintColor = currentIsFavorite ? .systemYellow : .white
        if !isHovering {
            starButton.isHidden = !currentIsFavorite
        }
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
        isHovering = true
        starButton.isHidden = false
        if !isSelected {
            view.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.04).cgColor
        }
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        if !currentIsFavorite {
            starButton.isHidden = true
        }
        if !isSelected {
            view.layer?.backgroundColor = nil
        }
    }

    static func cardHeight(for width: CGFloat) -> CGFloat {
        let thumbH = (width - 8) * 9.0 / 16.0
        return thumbH + 4 + 6 + 14 + 2 + 14 + 2 + 12 + 2 + 12 + 8
    }
}

// MARK: - PlaylistCardItem

class PlaylistCardItem: NSCollectionViewItem {

    static let identifier = NSUserInterfaceItemIdentifier("PlaylistCardItem")

    private var coverView: NSView!
    private var countBadge: NSTextField!
    private var nameLabel: NSTextField!
    private var trackingArea: NSTrackingArea?

    override func loadView() {
        let card = NSView(frame: NSRect(x: 0, y: 0, width: 240, height: 180))
        card.wantsLayer = true
        card.layer?.cornerRadius = 8
        self.view = card

        coverView = NSView()
        coverView.translatesAutoresizingMaskIntoConstraints = false
        coverView.wantsLayer = true
        coverView.layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
        coverView.layer?.cornerRadius = 6
        coverView.layer?.contentsGravity = .resizeAspectFill
        coverView.layer?.masksToBounds = true
        card.addSubview(coverView)

        countBadge = NSTextField(labelWithString: "")
        countBadge.translatesAutoresizingMaskIntoConstraints = false
        countBadge.font = .monospacedDigitSystemFont(ofSize: 10, weight: .medium)
        countBadge.textColor = .white
        countBadge.wantsLayer = true
        countBadge.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.7).cgColor
        countBadge.layer?.cornerRadius = 3
        countBadge.alignment = .center
        coverView.addSubview(countBadge)

        nameLabel = NSTextField(labelWithString: "")
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = .systemFont(ofSize: 12, weight: .medium)
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.maximumNumberOfLines = 1
        card.addSubview(nameLabel)

        NSLayoutConstraint.activate([
            coverView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 4),
            coverView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -4),
            coverView.topAnchor.constraint(equalTo: card.topAnchor, constant: 4),
            coverView.heightAnchor.constraint(equalTo: coverView.widthAnchor, multiplier: 9.0 / 16.0),

            countBadge.trailingAnchor.constraint(equalTo: coverView.trailingAnchor, constant: -6),
            countBadge.bottomAnchor.constraint(equalTo: coverView.bottomAnchor, constant: -6),
            countBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 36),

            nameLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 8),
            nameLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -8),
            nameLabel.topAnchor.constraint(equalTo: coverView.bottomAnchor, constant: 6),
        ])
    }

    func configure(name: String, clipCount: Int, coverThumbnailPath: String?) {
        nameLabel.stringValue = name
        countBadge.stringValue = " \(clipCount) clip\(clipCount == 1 ? "" : "s") "

        if let path = coverThumbnailPath,
           let image = NSImage(contentsOfFile: path),
           let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            coverView.layer?.contents = cgImage
        } else {
            coverView.layer?.contents = nil
        }
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
        let coverH = (width - 8) * 9.0 / 16.0
        return coverH + 4 + 6 + 14 + 8
    }
}

// MARK: - ClipLibraryWindowController

class ClipLibraryWindowController: NSObject, ClipLibraryDelegate, NSTableViewDataSource, NSTableViewDelegate, NSCollectionViewDataSource, NSCollectionViewDelegate, NSWindowDelegate, NSSearchFieldDelegate, NSMenuDelegate {

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
    private var allClipsFavoritesButton: NSButton!
    private var allClipsFavoritesOnly = false

    private var playerContainerView: NSView!
    private var playerView: AVPlayerView!
    private var player: AVPlayer?
    private var playerBackButton: NSButton!
    private var playerFullscreenButton: NSButton!
    private var playerFilenameLabel: NSTextField!
    private var playerDetailsLabel: NSTextField!
    private var playerInfoBar: NSView!
    private var playerFavoriteButton: NSButton!
    private var playerPlaylistPopup: NSPopUpButton!
    private var playerRenameButton: NSButton!
    private var playerDeleteButton: NSButton!
    private var playerFinderButton: NSButton!

    private var playerNormalConstraints: [NSLayoutConstraint] = []
    private var fullscreenOverlayConstraints: [NSLayoutConstraint] = []

    private var searchView: NSView!
    private var searchField: NSSearchField!
    private var dateChipRow: NSStackView!
    private var lengthChipRow: NSStackView!
    private var gameChipRow: NSStackView!
    private var favoritesChipRow: NSStackView!
    private var searchCollectionView: NSCollectionView!
    private var searchScrollView: NSScrollView!
    private var searchEmptyLabel: NSTextField!

    private var playlistsListView: NSView!
    private var playlistCollectionView: NSCollectionView!
    private var playlistScrollView: NSScrollView!
    private var playlistDetailView: NSView!
    private var playlistDetailTableView: NSTableView!
    private var playlistDetailScrollView: NSScrollView!
    private var playlistDetailBackButton: NSButton!
    private var playlistDetailTitle: NSTextField!
    private var playlistDetailCoverView: NSImageView!
    private var playlistDetailCountLabel: NSTextField!
    private var playlistDetailSort: ClipLibrary.SortOrder = .newestFirst

    let library: ClipLibrary

    private var currentNav: NavItem = .allClips
    private var currentSort: ClipLibrary.SortOrder = .newestFirst
    private var displayGroups: [ClipLibrary.DateGroup] = []
    private var flatList: [ClipMetadata] = []
    private var activeClip: ClipMetadata?
    private var isShowingPlayer = false
    private var pendingSelectFilename: String?

    private var searchText: String = ""
    private var selectedDateFilters: Set<ClipLibrary.DateFilter> = []
    private var selectedLengthFilters: Set<ClipLibrary.LengthFilter> = []
    private var selectedGameFilters: Set<String> = []
    private var searchResults: [ClipMetadata] = []
    private var filterFavoritesOnly = false
    private var customDateChip: NSButton!
    private var customDateStart: Date?
    private var customDateEnd: Date?

    private var activePlaylist: ClipLibrary.Playlist?
    private var playlistDetailClips: [ClipMetadata] = []
    private var isShowingPlaylistDetail = false
    private var contextMenuClip: ClipMetadata?
    private var contextMenuPlaylist: ClipLibrary.Playlist?

    private var settingsView: NSView!
    private var qualityPopup: NSPopUpButton!
    private var bufferPopup: NSPopUpButton!
    private var clipLengthPopup: NSPopUpButton!
    private var storageInfoLabel: NSTextField!

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
        if isShowingPlaylistDetail { reloadPlaylistDetail() }
        library.generateMissingThumbnails { [weak self] clipID in
            self?.updateThumbnail(for: clipID)
        }
    }

    private func updateThumbnail(for clipID: UUID) {
        let libClip = library.clips.first(where: { $0.id == clipID })
        if let idx = flatList.firstIndex(where: { $0.id == clipID }) {
            flatList[idx].thumbnailPath = libClip?.thumbnailPath
            clipCollectionView?.reloadItems(at: [IndexPath(item: idx, section: 0)])
        }
        if let idx = searchResults.firstIndex(where: { $0.id == clipID }) {
            searchResults[idx].thumbnailPath = libClip?.thumbnailPath
            searchCollectionView?.reloadItems(at: [IndexPath(item: idx, section: 0)])
        }
        if let idx = playlistDetailClips.firstIndex(where: { $0.id == clipID }) {
            playlistDetailClips[idx].thumbnailPath = libClip?.thumbnailPath
            playlistDetailTableView?.reloadData(forRowIndexes: IndexSet(integer: idx), columnIndexes: IndexSet(integer: 0))
        }
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
        buildSearchView()
        buildPlaylistsView()
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

        allClipsFavoritesButton = NSButton(title: "Favorites", image: NSImage(systemSymbolName: "star", accessibilityDescription: "Favorites")!, target: self, action: #selector(allClipsFavoritesToggled))
        allClipsFavoritesButton.translatesAutoresizingMaskIntoConstraints = false
        allClipsFavoritesButton.setButtonType(.pushOnPushOff)
        allClipsFavoritesButton.bezelStyle = .rounded
        allClipsFavoritesButton.imagePosition = .imageLeading
        clipGridView.addSubview(allClipsFavoritesButton)

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
        menu.delegate = self
        menu.addItem(NSMenuItem(title: "Add to Favorites", action: #selector(contextToggleFavorite), keyEquivalent: ""))
        let addToPlaylistItem = NSMenuItem(title: "Add to Playlist", action: nil, keyEquivalent: "")
        addToPlaylistItem.tag = 999
        addToPlaylistItem.submenu = NSMenu()
        menu.addItem(addToPlaylistItem)
        menu.addItem(NSMenuItem.separator())
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

            allClipsFavoritesButton.leadingAnchor.constraint(equalTo: sortPopup.trailingAnchor, constant: 8),
            allClipsFavoritesButton.centerYAnchor.constraint(equalTo: sortPopup.centerYAnchor),

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
        let availableWidth = gridScrollView.contentView.bounds.width - flowLayout.sectionInset.left - flowLayout.sectionInset.right
        guard availableWidth > 0 else { return }

        let minWidth: CGFloat = 240
        let spacing = flowLayout.minimumInteritemSpacing
        let columns = min(3, max(1, floor(availableWidth / minWidth)))
        let itemWidth = floor((availableWidth - (columns - 1) * spacing) / columns)
        let itemHeight = ClipCardItem.cardHeight(for: itemWidth)

        flowLayout.itemSize = NSSize(width: itemWidth, height: itemHeight)
    }

    // MARK: - Search View

    private func buildSearchView() {
        searchView = NSView()
        searchView.translatesAutoresizingMaskIntoConstraints = false

        searchField = NSSearchField()
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.placeholderString = "Search clips..."
        searchField.delegate = self
        searchView.addSubview(searchField)

        dateChipRow = NSStackView()
        dateChipRow.translatesAutoresizingMaskIntoConstraints = false
        dateChipRow.orientation = .horizontal
        dateChipRow.spacing = 6
        for filter in ClipLibrary.DateFilter.allCases {
            dateChipRow.addArrangedSubview(makeChip(title: filter.title, action: #selector(dateChipToggled(_:)), tag: filter.rawValue))
        }
        customDateChip = makeChip(title: "Custom", action: #selector(customDateChipToggled(_:)), tag: 100)
        dateChipRow.addArrangedSubview(customDateChip)
        searchView.addSubview(dateChipRow)

        lengthChipRow = NSStackView()
        lengthChipRow.translatesAutoresizingMaskIntoConstraints = false
        lengthChipRow.orientation = .horizontal
        lengthChipRow.spacing = 6
        for filter in ClipLibrary.LengthFilter.allCases {
            lengthChipRow.addArrangedSubview(makeChip(title: filter.title, action: #selector(lengthChipToggled(_:)), tag: filter.rawValue))
        }
        searchView.addSubview(lengthChipRow)

        favoritesChipRow = NSStackView()
        favoritesChipRow.translatesAutoresizingMaskIntoConstraints = false
        favoritesChipRow.orientation = .horizontal
        favoritesChipRow.spacing = 6
        favoritesChipRow.addArrangedSubview(makeChip(title: "\u{2B50} Favorites", action: #selector(favoritesChipToggled(_:)), tag: 0))
        searchView.addSubview(favoritesChipRow)

        // FUTURE: game chips populate when gameLabel is set
        gameChipRow = NSStackView()
        gameChipRow.translatesAutoresizingMaskIntoConstraints = false
        gameChipRow.orientation = .horizontal
        gameChipRow.spacing = 6
        gameChipRow.isHidden = true
        searchView.addSubview(gameChipRow)

        searchEmptyLabel = NSTextField(labelWithString: "필터를 선택하세요")
        searchEmptyLabel.translatesAutoresizingMaskIntoConstraints = false
        searchEmptyLabel.font = .systemFont(ofSize: 16, weight: .medium)
        searchEmptyLabel.textColor = .tertiaryLabelColor
        searchEmptyLabel.alignment = .center
        searchView.addSubview(searchEmptyLabel)

        let flowLayout = NSCollectionViewFlowLayout()
        flowLayout.minimumInteritemSpacing = 12
        flowLayout.minimumLineSpacing = 16
        flowLayout.sectionInset = NSEdgeInsets(top: 8, left: 12, bottom: 12, right: 12)

        searchCollectionView = NSCollectionView()
        searchCollectionView.collectionViewLayout = flowLayout
        searchCollectionView.isSelectable = true
        searchCollectionView.allowsMultipleSelection = false
        searchCollectionView.dataSource = self
        searchCollectionView.delegate = self
        searchCollectionView.register(ClipCardItem.self, forItemWithIdentifier: ClipCardItem.identifier)
        searchCollectionView.backgroundColors = [.clear]

        let searchMenu = NSMenu()
        searchMenu.delegate = self
        searchMenu.addItem(NSMenuItem(title: "Add to Favorites", action: #selector(contextToggleFavorite), keyEquivalent: ""))
        let searchAddToPlaylistItem = NSMenuItem(title: "Add to Playlist", action: nil, keyEquivalent: "")
        searchAddToPlaylistItem.tag = 999
        searchAddToPlaylistItem.submenu = NSMenu()
        searchMenu.addItem(searchAddToPlaylistItem)
        searchMenu.addItem(NSMenuItem.separator())
        searchMenu.addItem(NSMenuItem(title: "Rename", action: #selector(contextRename), keyEquivalent: ""))
        searchMenu.addItem(NSMenuItem(title: "Delete", action: #selector(contextDelete), keyEquivalent: ""))
        searchMenu.addItem(NSMenuItem.separator())
        searchMenu.addItem(NSMenuItem(title: "Show in Finder", action: #selector(contextShowInFinder), keyEquivalent: ""))
        for item in searchMenu.items { item.target = self }
        searchCollectionView.menu = searchMenu

        searchScrollView = NSScrollView()
        searchScrollView.translatesAutoresizingMaskIntoConstraints = false
        searchScrollView.hasVerticalScroller = true
        searchScrollView.autohidesScrollers = true
        searchScrollView.documentView = searchCollectionView
        searchScrollView.isHidden = true
        searchView.addSubview(searchScrollView)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(searchGridFrameChanged),
            name: NSView.frameDidChangeNotification,
            object: searchScrollView
        )
        searchScrollView.postsFrameChangedNotifications = true

        NSLayoutConstraint.activate([
            searchField.leadingAnchor.constraint(equalTo: searchView.leadingAnchor, constant: 12),
            searchField.trailingAnchor.constraint(equalTo: searchView.trailingAnchor, constant: -12),
            searchField.topAnchor.constraint(equalTo: searchView.topAnchor, constant: 12),

            dateChipRow.leadingAnchor.constraint(equalTo: searchView.leadingAnchor, constant: 12),
            dateChipRow.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 10),

            lengthChipRow.leadingAnchor.constraint(equalTo: searchView.leadingAnchor, constant: 12),
            lengthChipRow.topAnchor.constraint(equalTo: dateChipRow.bottomAnchor, constant: 6),

            favoritesChipRow.leadingAnchor.constraint(equalTo: searchView.leadingAnchor, constant: 12),
            favoritesChipRow.topAnchor.constraint(equalTo: lengthChipRow.bottomAnchor, constant: 6),

            gameChipRow.leadingAnchor.constraint(equalTo: searchView.leadingAnchor, constant: 12),
            gameChipRow.topAnchor.constraint(equalTo: favoritesChipRow.bottomAnchor, constant: 6),

            searchScrollView.leadingAnchor.constraint(equalTo: searchView.leadingAnchor),
            searchScrollView.trailingAnchor.constraint(equalTo: searchView.trailingAnchor),
            searchScrollView.topAnchor.constraint(equalTo: gameChipRow.bottomAnchor, constant: 10),
            searchScrollView.bottomAnchor.constraint(equalTo: searchView.bottomAnchor),

            searchEmptyLabel.centerXAnchor.constraint(equalTo: searchView.centerXAnchor),
            searchEmptyLabel.centerYAnchor.constraint(equalTo: searchView.centerYAnchor, constant: 30),
        ])
    }

    private func makeChip(title: String, action: Selector, tag: Int) -> NSButton {
        let btn = NSButton(title: title, target: self, action: action)
        btn.setButtonType(.pushOnPushOff)
        btn.bezelStyle = .recessed
        btn.tag = tag
        btn.font = .systemFont(ofSize: 12)
        return btn
    }

    @objc private func searchGridFrameChanged() {
        updateSearchFlowLayoutItemSize()
    }

    private func updateSearchFlowLayoutItemSize() {
        guard let flowLayout = searchCollectionView?.collectionViewLayout as? NSCollectionViewFlowLayout else { return }
        let availableWidth = searchScrollView.contentView.bounds.width - flowLayout.sectionInset.left - flowLayout.sectionInset.right
        guard availableWidth > 0 else { return }

        let minWidth: CGFloat = 240
        let spacing = flowLayout.minimumInteritemSpacing
        let columns = min(3, max(1, floor(availableWidth / minWidth)))
        let itemWidth = floor((availableWidth - (columns - 1) * spacing) / columns)
        let itemHeight = ClipCardItem.cardHeight(for: itemWidth)

        flowLayout.itemSize = NSSize(width: itemWidth, height: itemHeight)
    }

    // MARK: - Playlists View

    private func buildPlaylistsView() {
        // List view (playlist cards)
        playlistsListView = NSView()
        playlistsListView.translatesAutoresizingMaskIntoConstraints = false

        let newBtn = NSButton(title: "+ New Playlist", target: self, action: #selector(createNewPlaylist))
        newBtn.translatesAutoresizingMaskIntoConstraints = false
        newBtn.bezelStyle = .rounded
        playlistsListView.addSubview(newBtn)

        let flowLayout = NSCollectionViewFlowLayout()
        flowLayout.minimumInteritemSpacing = 12
        flowLayout.minimumLineSpacing = 16
        flowLayout.sectionInset = NSEdgeInsets(top: 8, left: 12, bottom: 12, right: 12)

        playlistCollectionView = NSCollectionView()
        playlistCollectionView.collectionViewLayout = flowLayout
        playlistCollectionView.isSelectable = true
        playlistCollectionView.allowsMultipleSelection = false
        playlistCollectionView.dataSource = self
        playlistCollectionView.delegate = self
        playlistCollectionView.register(PlaylistCardItem.self, forItemWithIdentifier: PlaylistCardItem.identifier)
        playlistCollectionView.backgroundColors = [.clear]

        let plMenu = NSMenu()
        plMenu.delegate = self
        plMenu.addItem(NSMenuItem(title: "Rename", action: #selector(contextRenamePlaylist), keyEquivalent: ""))
        plMenu.addItem(NSMenuItem(title: "Delete", action: #selector(contextDeletePlaylist), keyEquivalent: ""))
        for item in plMenu.items { item.target = self }
        playlistCollectionView.menu = plMenu

        playlistScrollView = NSScrollView()
        playlistScrollView.translatesAutoresizingMaskIntoConstraints = false
        playlistScrollView.hasVerticalScroller = true
        playlistScrollView.autohidesScrollers = true
        playlistScrollView.documentView = playlistCollectionView
        playlistsListView.addSubview(playlistScrollView)

        NotificationCenter.default.addObserver(self, selector: #selector(playlistGridFrameChanged), name: NSView.frameDidChangeNotification, object: playlistScrollView)
        playlistScrollView.postsFrameChangedNotifications = true

        NSLayoutConstraint.activate([
            newBtn.leadingAnchor.constraint(equalTo: playlistsListView.leadingAnchor, constant: 12),
            newBtn.topAnchor.constraint(equalTo: playlistsListView.topAnchor, constant: 8),

            playlistScrollView.leadingAnchor.constraint(equalTo: playlistsListView.leadingAnchor),
            playlistScrollView.trailingAnchor.constraint(equalTo: playlistsListView.trailingAnchor),
            playlistScrollView.topAnchor.constraint(equalTo: newBtn.bottomAnchor, constant: 6),
            playlistScrollView.bottomAnchor.constraint(equalTo: playlistsListView.bottomAnchor),
        ])

        // Detail view (YouTube-style: left panel + right clip list)
        playlistDetailView = NSView()
        playlistDetailView.translatesAutoresizingMaskIntoConstraints = false

        // --- Left Panel ---
        let leftPanel = NSView()
        leftPanel.translatesAutoresizingMaskIntoConstraints = false
        playlistDetailView.addSubview(leftPanel)

        playlistDetailCoverView = NSImageView()
        playlistDetailCoverView.translatesAutoresizingMaskIntoConstraints = false
        playlistDetailCoverView.wantsLayer = true
        playlistDetailCoverView.layer?.cornerRadius = 8
        playlistDetailCoverView.layer?.masksToBounds = true
        playlistDetailCoverView.layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
        playlistDetailCoverView.imageScaling = .scaleProportionallyUpOrDown
        playlistDetailCoverView.imageAlignment = .alignCenter
        leftPanel.addSubview(playlistDetailCoverView)

        playlistDetailTitle = NSTextField(labelWithString: "")
        playlistDetailTitle.translatesAutoresizingMaskIntoConstraints = false
        playlistDetailTitle.font = .systemFont(ofSize: 18, weight: .bold)
        playlistDetailTitle.lineBreakMode = .byTruncatingTail
        playlistDetailTitle.maximumNumberOfLines = 2
        leftPanel.addSubview(playlistDetailTitle)

        playlistDetailCountLabel = NSTextField(labelWithString: "")
        playlistDetailCountLabel.translatesAutoresizingMaskIntoConstraints = false
        playlistDetailCountLabel.font = .systemFont(ofSize: 12)
        playlistDetailCountLabel.textColor = .secondaryLabelColor
        leftPanel.addSubview(playlistDetailCountLabel)

        let playAllButton = NSButton(title: "▶ Play All", target: self, action: #selector(playlistDetailPlayAll))
        playAllButton.translatesAutoresizingMaskIntoConstraints = false
        playAllButton.bezelStyle = .rounded
        playAllButton.controlSize = .large
        leftPanel.addSubview(playAllButton)

        let actionRow = NSStackView()
        actionRow.translatesAutoresizingMaskIntoConstraints = false
        actionRow.orientation = .horizontal
        actionRow.spacing = 8

        let renameBtn = NSButton(image: NSImage(systemSymbolName: "pencil", accessibilityDescription: "Rename")!, target: self, action: #selector(playlistDetailRenameAction))
        renameBtn.bezelStyle = .rounded
        renameBtn.isBordered = false
        renameBtn.toolTip = "Rename Playlist"
        actionRow.addArrangedSubview(renameBtn)

        let deleteBtn = NSButton(image: NSImage(systemSymbolName: "trash", accessibilityDescription: "Delete")!, target: self, action: #selector(playlistDetailDeleteAction))
        deleteBtn.bezelStyle = .rounded
        deleteBtn.isBordered = false
        deleteBtn.toolTip = "Delete Playlist"
        actionRow.addArrangedSubview(deleteBtn)

        leftPanel.addSubview(actionRow)

        playlistDetailBackButton = NSButton(title: "\u{2190} Back", target: self, action: #selector(backToPlaylistList))
        playlistDetailBackButton.translatesAutoresizingMaskIntoConstraints = false
        playlistDetailBackButton.bezelStyle = .rounded
        playlistDetailBackButton.isBordered = false
        playlistDetailBackButton.font = .systemFont(ofSize: 13)
        playlistDetailBackButton.contentTintColor = .controlAccentColor
        leftPanel.addSubview(playlistDetailBackButton)

        NSLayoutConstraint.activate([
            leftPanel.leadingAnchor.constraint(equalTo: playlistDetailView.leadingAnchor),
            leftPanel.topAnchor.constraint(equalTo: playlistDetailView.topAnchor),
            leftPanel.bottomAnchor.constraint(equalTo: playlistDetailView.bottomAnchor),
            leftPanel.widthAnchor.constraint(equalToConstant: 280),

            playlistDetailCoverView.leadingAnchor.constraint(equalTo: leftPanel.leadingAnchor, constant: 16),
            playlistDetailCoverView.trailingAnchor.constraint(equalTo: leftPanel.trailingAnchor, constant: -16),
            playlistDetailCoverView.topAnchor.constraint(equalTo: leftPanel.topAnchor, constant: 16),
            playlistDetailCoverView.heightAnchor.constraint(equalTo: playlistDetailCoverView.widthAnchor, multiplier: 9.0 / 16.0),

            playlistDetailTitle.leadingAnchor.constraint(equalTo: leftPanel.leadingAnchor, constant: 16),
            playlistDetailTitle.trailingAnchor.constraint(equalTo: leftPanel.trailingAnchor, constant: -16),
            playlistDetailTitle.topAnchor.constraint(equalTo: playlistDetailCoverView.bottomAnchor, constant: 12),

            playlistDetailCountLabel.leadingAnchor.constraint(equalTo: leftPanel.leadingAnchor, constant: 16),
            playlistDetailCountLabel.topAnchor.constraint(equalTo: playlistDetailTitle.bottomAnchor, constant: 4),

            playAllButton.leadingAnchor.constraint(equalTo: leftPanel.leadingAnchor, constant: 16),
            playAllButton.trailingAnchor.constraint(equalTo: leftPanel.trailingAnchor, constant: -16),
            playAllButton.topAnchor.constraint(equalTo: playlistDetailCountLabel.bottomAnchor, constant: 12),

            actionRow.leadingAnchor.constraint(equalTo: leftPanel.leadingAnchor, constant: 16),
            actionRow.topAnchor.constraint(equalTo: playAllButton.bottomAnchor, constant: 12),

            playlistDetailBackButton.leadingAnchor.constraint(equalTo: leftPanel.leadingAnchor, constant: 16),
            playlistDetailBackButton.bottomAnchor.constraint(equalTo: leftPanel.bottomAnchor, constant: -12),
        ])

        // --- Right Panel (sort + table view) ---
        let rightPanel = NSView()
        rightPanel.translatesAutoresizingMaskIntoConstraints = false
        playlistDetailView.addSubview(rightPanel)

        let detailSortPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        detailSortPopup.translatesAutoresizingMaskIntoConstraints = false
        detailSortPopup.controlSize = .small
        detailSortPopup.font = .systemFont(ofSize: 11)
        for order in ClipLibrary.SortOrder.allCases {
            detailSortPopup.addItem(withTitle: order.title)
        }
        detailSortPopup.target = self
        detailSortPopup.action = #selector(playlistDetailSortChanged(_:))
        rightPanel.addSubview(detailSortPopup)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("clip"))
        column.title = ""

        playlistDetailTableView = NSTableView()
        playlistDetailTableView.addTableColumn(column)
        playlistDetailTableView.headerView = nil
        playlistDetailTableView.rowHeight = 76
        playlistDetailTableView.style = .plain
        playlistDetailTableView.dataSource = self
        playlistDetailTableView.delegate = self
        playlistDetailTableView.target = self
        playlistDetailTableView.doubleAction = #selector(playlistDetailRowDoubleClicked)
        playlistDetailTableView.selectionHighlightStyle = .regular
        playlistDetailTableView.usesAlternatingRowBackgroundColors = false

        let detailMenu = NSMenu()
        detailMenu.delegate = self
        detailMenu.addItem(NSMenuItem(title: "Remove from Playlist", action: #selector(contextRemoveFromPlaylist), keyEquivalent: ""))
        detailMenu.addItem(NSMenuItem(title: "Set as Playlist Cover", action: #selector(contextSetAsPlaylistCover), keyEquivalent: ""))
        detailMenu.addItem(NSMenuItem.separator())
        detailMenu.addItem(NSMenuItem(title: "Add to Favorites", action: #selector(contextToggleFavorite), keyEquivalent: ""))
        let detailAddItem = NSMenuItem(title: "Add to Playlist", action: nil, keyEquivalent: "")
        detailAddItem.tag = 999
        detailAddItem.submenu = NSMenu()
        detailMenu.addItem(detailAddItem)
        detailMenu.addItem(NSMenuItem.separator())
        detailMenu.addItem(NSMenuItem(title: "Rename", action: #selector(contextRename), keyEquivalent: ""))
        detailMenu.addItem(NSMenuItem(title: "Delete", action: #selector(contextDelete), keyEquivalent: ""))
        detailMenu.addItem(NSMenuItem.separator())
        detailMenu.addItem(NSMenuItem(title: "Show in Finder", action: #selector(contextShowInFinder), keyEquivalent: ""))
        for item in detailMenu.items { item.target = self }
        playlistDetailTableView.menu = detailMenu

        playlistDetailScrollView = NSScrollView()
        playlistDetailScrollView.translatesAutoresizingMaskIntoConstraints = false
        playlistDetailScrollView.hasVerticalScroller = true
        playlistDetailScrollView.autohidesScrollers = true
        playlistDetailScrollView.documentView = playlistDetailTableView
        rightPanel.addSubview(playlistDetailScrollView)

        NSLayoutConstraint.activate([
            rightPanel.leadingAnchor.constraint(equalTo: leftPanel.trailingAnchor),
            rightPanel.trailingAnchor.constraint(equalTo: playlistDetailView.trailingAnchor),
            rightPanel.topAnchor.constraint(equalTo: playlistDetailView.topAnchor),
            rightPanel.bottomAnchor.constraint(equalTo: playlistDetailView.bottomAnchor),

            detailSortPopup.trailingAnchor.constraint(equalTo: rightPanel.trailingAnchor, constant: -12),
            detailSortPopup.topAnchor.constraint(equalTo: rightPanel.topAnchor, constant: 12),

            playlistDetailScrollView.leadingAnchor.constraint(equalTo: rightPanel.leadingAnchor),
            playlistDetailScrollView.trailingAnchor.constraint(equalTo: rightPanel.trailingAnchor),
            playlistDetailScrollView.topAnchor.constraint(equalTo: detailSortPopup.bottomAnchor, constant: 8),
            playlistDetailScrollView.bottomAnchor.constraint(equalTo: rightPanel.bottomAnchor),
        ])
    }

    @objc private func playlistGridFrameChanged() {
        updatePlaylistFlowLayoutItemSize()
    }

    private func updatePlaylistFlowLayoutItemSize() {
        guard let flowLayout = playlistCollectionView?.collectionViewLayout as? NSCollectionViewFlowLayout else { return }
        let availableWidth = playlistScrollView.contentView.bounds.width - flowLayout.sectionInset.left - flowLayout.sectionInset.right
        guard availableWidth > 0 else { return }
        let minWidth: CGFloat = 240
        let spacing = flowLayout.minimumInteritemSpacing
        let columns = min(3, max(1, floor(availableWidth / minWidth)))
        let itemWidth = floor((availableWidth - (columns - 1) * spacing) / columns)
        flowLayout.itemSize = NSSize(width: itemWidth, height: PlaylistCardItem.cardHeight(for: itemWidth))
    }

    @objc private func playlistDetailSortChanged(_ sender: NSPopUpButton) {
        guard let order = ClipLibrary.SortOrder(rawValue: sender.indexOfSelectedItem) else { return }
        playlistDetailSort = order
        reloadPlaylistDetail()
    }

    @objc private func playlistDetailPlayAll() {
        // FUTURE: Stage R-3 — sequential playback
        guard let first = playlistDetailClips.first else { return }
        openClipInPlayer(first)
    }

    @objc private func playlistDetailRenameAction() {
        guard let playlist = activePlaylist else { return }
        let alert = NSAlert()
        alert.messageText = "Rename Playlist"
        alert.informativeText = "Enter a new name:"
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 250, height: 24))
        field.stringValue = playlist.name
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = field.stringValue.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        library.renamePlaylist(playlist, to: name)
        activePlaylist = library.playlists.first(where: { $0.id == playlist.id })
        playlistDetailTitle.stringValue = name
    }

    @objc private func playlistDetailDeleteAction() {
        guard let playlist = activePlaylist else { return }
        let alert = NSAlert()
        alert.messageText = "Delete Playlist?"
        alert.informativeText = "This removes the playlist \"\(playlist.name)\". The clips themselves are not deleted."
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        library.deletePlaylist(playlist)
        backToPlaylistList()
    }

    @objc private func playlistDetailRowDoubleClicked() {
        let row = playlistDetailTableView.clickedRow
        guard row >= 0, row < playlistDetailClips.count else { return }
        openClipInPlayer(playlistDetailClips[row])
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
        playerView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        playerContainerView.addSubview(playerView)

        // Info/action bar
        playerInfoBar = NSView()
        playerInfoBar.translatesAutoresizingMaskIntoConstraints = false
        playerInfoBar.wantsLayer = true
        playerInfoBar.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        playerContainerView.addSubview(playerInfoBar)

        playerFilenameLabel = NSTextField(labelWithString: "")
        playerFilenameLabel.translatesAutoresizingMaskIntoConstraints = false
        playerFilenameLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        playerFilenameLabel.textColor = .labelColor
        playerFilenameLabel.lineBreakMode = .byTruncatingTail
        playerInfoBar.addSubview(playerFilenameLabel)

        playerDetailsLabel = NSTextField(labelWithString: "")
        playerDetailsLabel.translatesAutoresizingMaskIntoConstraints = false
        playerDetailsLabel.font = .systemFont(ofSize: 12)
        playerDetailsLabel.textColor = .secondaryLabelColor
        playerDetailsLabel.lineBreakMode = .byTruncatingTail
        playerInfoBar.addSubview(playerDetailsLabel)

        let separator = NSView()
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.wantsLayer = true
        separator.layer?.backgroundColor = NSColor.separatorColor.cgColor
        playerInfoBar.addSubview(separator)

        let buttonStack = NSStackView()
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 8

        playerFavoriteButton = NSButton(title: "Favorite", image: NSImage(systemSymbolName: "star", accessibilityDescription: "Favorite")!, target: self, action: #selector(playerFavoriteToggled))
        playerFavoriteButton.bezelStyle = .rounded
        playerFavoriteButton.imagePosition = .imageLeading

        playerPlaylistPopup = NSPopUpButton()
        playerPlaylistPopup.bezelStyle = .rounded
        playerPlaylistPopup.pullsDown = true
        playerPlaylistPopup.imagePosition = .imageLeading

        playerRenameButton = NSButton(title: "Rename", image: NSImage(systemSymbolName: "pencil", accessibilityDescription: "Rename")!, target: self, action: #selector(renameAction))
        playerRenameButton.bezelStyle = .rounded
        playerRenameButton.imagePosition = .imageLeading

        playerDeleteButton = NSButton(title: "Delete", image: NSImage(systemSymbolName: "trash", accessibilityDescription: "Delete")!, target: self, action: #selector(deleteAction))
        playerDeleteButton.bezelStyle = .rounded
        playerDeleteButton.imagePosition = .imageLeading

        playerFinderButton = NSButton(title: "Finder", image: NSImage(systemSymbolName: "folder", accessibilityDescription: "Show in Finder")!, target: self, action: #selector(showInFinderAction))
        playerFinderButton.bezelStyle = .rounded
        playerFinderButton.imagePosition = .imageLeading

        buttonStack.addArrangedSubview(playerFavoriteButton)
        buttonStack.addArrangedSubview(playerPlaylistPopup)
        buttonStack.addArrangedSubview(playerRenameButton)
        buttonStack.addArrangedSubview(playerDeleteButton)
        buttonStack.addArrangedSubview(playerFinderButton)
        // FUTURE: [Enhance] (Stage 6)  [Export]  [Trim]
        playerInfoBar.addSubview(buttonStack)

        NSLayoutConstraint.activate([
            playerBackButton.leadingAnchor.constraint(equalTo: playerContainerView.leadingAnchor, constant: 12),
            playerBackButton.topAnchor.constraint(equalTo: playerContainerView.topAnchor, constant: 8),

            playerFullscreenButton.trailingAnchor.constraint(equalTo: playerContainerView.trailingAnchor, constant: -12),
            playerFullscreenButton.centerYAnchor.constraint(equalTo: playerBackButton.centerYAnchor),

            playerView.leadingAnchor.constraint(equalTo: playerContainerView.leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: playerContainerView.trailingAnchor),

            playerInfoBar.leadingAnchor.constraint(equalTo: playerContainerView.leadingAnchor),
            playerInfoBar.trailingAnchor.constraint(equalTo: playerContainerView.trailingAnchor),
            playerInfoBar.bottomAnchor.constraint(equalTo: playerContainerView.bottomAnchor),
            playerInfoBar.heightAnchor.constraint(equalToConstant: 90),

            playerFilenameLabel.leadingAnchor.constraint(equalTo: playerInfoBar.leadingAnchor, constant: 12),
            playerFilenameLabel.trailingAnchor.constraint(equalTo: playerInfoBar.trailingAnchor, constant: -12),
            playerFilenameLabel.topAnchor.constraint(equalTo: playerInfoBar.topAnchor, constant: 8),

            playerDetailsLabel.leadingAnchor.constraint(equalTo: playerInfoBar.leadingAnchor, constant: 12),
            playerDetailsLabel.trailingAnchor.constraint(equalTo: playerInfoBar.trailingAnchor, constant: -12),
            playerDetailsLabel.topAnchor.constraint(equalTo: playerFilenameLabel.bottomAnchor, constant: 2),

            separator.leadingAnchor.constraint(equalTo: playerInfoBar.leadingAnchor, constant: 12),
            separator.trailingAnchor.constraint(equalTo: playerInfoBar.trailingAnchor, constant: -12),
            separator.topAnchor.constraint(equalTo: playerDetailsLabel.bottomAnchor, constant: 6),
            separator.heightAnchor.constraint(equalToConstant: 1),

            buttonStack.leadingAnchor.constraint(equalTo: playerInfoBar.leadingAnchor, constant: 12),
            buttonStack.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 6),
            buttonStack.bottomAnchor.constraint(equalTo: playerInfoBar.bottomAnchor, constant: -8),
        ])

        playerNormalConstraints = [
            playerView.topAnchor.constraint(equalTo: playerBackButton.bottomAnchor, constant: 4),
            playerView.bottomAnchor.constraint(equalTo: playerInfoBar.topAnchor),
        ]

        NSLayoutConstraint.activate(playerNormalConstraints)
    }

    // MARK: - Placeholder Views

    private func buildPlaceholders() {
        buildSettingsView()
    }

    // MARK: - Settings View

    private func makeSectionHeader(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 13, weight: .bold)
        label.textColor = .labelColor
        return label
    }

    private func makeToggleRow(title: String, isOn: Bool, action: Selector) -> (row: NSView, toggle: NSSwitch) {
        let row = NSView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let label = NSTextField(labelWithString: title)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 13)
        label.lineBreakMode = .byTruncatingTail
        row.addSubview(label)

        let toggle = NSSwitch()
        toggle.translatesAutoresizingMaskIntoConstraints = false
        toggle.target = self
        toggle.action = action
        toggle.state = isOn ? .on : .off
        row.addSubview(toggle)

        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 28),
            label.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            label.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            toggle.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            toggle.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: toggle.leadingAnchor, constant: -8),
        ])

        return (row, toggle)
    }

    private func makeDropdownRow(title: String, items: [String], selected: Int, action: Selector) -> (row: NSView, popup: NSPopUpButton) {
        let row = NSView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let label = NSTextField(labelWithString: title)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 13)
        label.lineBreakMode = .byTruncatingTail
        row.addSubview(label)

        let popup = NSPopUpButton()
        popup.translatesAutoresizingMaskIntoConstraints = false
        popup.target = self
        popup.action = action
        for item in items { popup.addItem(withTitle: item) }
        if selected >= 0 && selected < items.count {
            popup.selectItem(at: selected)
        }
        row.addSubview(popup)

        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 28),
            label.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            label.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            popup.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            popup.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            popup.widthAnchor.constraint(greaterThanOrEqualToConstant: 200),
            label.trailingAnchor.constraint(lessThanOrEqualTo: popup.leadingAnchor, constant: -8),
        ])

        return (row, popup)
    }

    private func makeButtonRow(title: String, style: NSButton.BezelStyle = .rounded, action: Selector) -> NSView {
        let row = NSView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let button = NSButton(title: title, target: self, action: action)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.bezelStyle = style
        row.addSubview(button)

        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 32),
            button.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            button.centerYAnchor.constraint(equalTo: row.centerYAnchor),
        ])

        return row
    }

    private func makeInfoRow(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 13)
        label.textColor = .secondaryLabelColor
        label.lineBreakMode = .byTruncatingTail
        return label
    }

    private func makeDisabledRow(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 13)
        label.textColor = .tertiaryLabelColor
        return label
    }

    private func makeSeparator() -> NSView {
        let sep = NSView()
        sep.translatesAutoresizingMaskIntoConstraints = false
        sep.wantsLayer = true
        sep.layer?.backgroundColor = NSColor.separatorColor.cgColor
        sep.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return sep
    }

    private func buildSettingsView() {
        settingsView = NSView()
        settingsView.translatesAutoresizingMaskIntoConstraints = false

        let appDelegate = NSApp.delegate as! AppDelegate

        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8

        // ── Capture Defaults ──

        stack.addArrangedSubview(makeSectionHeader("Capture Defaults"))

        let qualityItems = buildQualityDropdownItems()
        let qualitySelected = qualitySelectedIndex()
        let (qualityRow, qPopup) = makeDropdownRow(title: "Quality:", items: qualityItems, selected: qualitySelected, action: #selector(settingsQualityChanged))
        qualityPopup = qPopup
        stack.addArrangedSubview(qualityRow)

        let bufferItems = buildBufferDropdownItems()
        let bufferSelected = bufferSelectedIndex()
        let (bufferRow, bPopup) = makeDropdownRow(title: "Buffer:", items: bufferItems, selected: bufferSelected, action: #selector(settingsBufferChanged))
        bufferPopup = bPopup
        stack.addArrangedSubview(bufferRow)

        let clipItems = buildClipLengthDropdownItems()
        let clipSelected = clipLengthSelectedIndex()
        let (clipRow, cPopup) = makeDropdownRow(title: "Clip Length:", items: clipItems, selected: clipSelected, action: #selector(settingsClipLengthChanged))
        clipLengthPopup = cPopup
        stack.addArrangedSubview(clipRow)
        updateClipLengthEnabledStates()

        let (autoStartRow, _) = makeToggleRow(title: "Start capturing on launch", isOn: appDelegate.autoStartCapture, action: #selector(settingsAutoStartChanged))
        stack.addArrangedSubview(autoStartRow)

        stack.addArrangedSubview(makeSeparator())

        // ── Behavior ──

        stack.addArrangedSubview(makeSectionHeader("Behavior"))

        let (openLibRow, _) = makeToggleRow(title: "Open library when a clip is saved", isOn: appDelegate.openLibraryOnSave, action: #selector(settingsOpenLibraryChanged))
        stack.addArrangedSubview(openLibRow)

        let (notifyRow, _) = makeToggleRow(title: "Notify when a clip is saved", isOn: appDelegate.notifyOnSave, action: #selector(settingsNotifyChanged))
        stack.addArrangedSubview(notifyRow)

        let (loginRow, _) = makeToggleRow(title: "Launch at login", isOn: appDelegate.launchAtLogin, action: #selector(settingsLaunchAtLoginChanged))
        stack.addArrangedSubview(loginRow)

        stack.addArrangedSubview(makeSeparator())

        // ── Storage ──

        stack.addArrangedSubview(makeSectionHeader("Storage"))

        storageInfoLabel = makeInfoRow("Calculating…")
        stack.addArrangedSubview(storageInfoLabel)

        stack.addArrangedSubview(makeSeparator())

        // ── Reset ──

        stack.addArrangedSubview(makeSectionHeader("Reset"))

        stack.addArrangedSubview(makeButtonRow(title: "Reset Warning Dialogs", action: #selector(settingsResetWarnings)))
        stack.addArrangedSubview(makeButtonRow(title: "Reset All Settings", action: #selector(settingsResetAll)))

        stack.addArrangedSubview(makeSeparator())

        // ── About ──

        stack.addArrangedSubview(makeSectionHeader("About"))

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        stack.addArrangedSubview(makeInfoRow("MetalClip v\(version)"))

        let linkButton = NSButton(title: "GitHub: ITLLEXPLODE/MetalClip", target: self, action: #selector(settingsOpenGitHub))
        linkButton.isBordered = false
        linkButton.contentTintColor = .controlAccentColor
        linkButton.font = .systemFont(ofSize: 13)
        stack.addArrangedSubview(linkButton)

        stack.addArrangedSubview(makeSeparator())

        // ── Coming Soon ──
        // ROADMAP: Enable these rows as features ship

        stack.addArrangedSubview(makeSectionHeader("Coming Soon"))
        stack.addArrangedSubview(makeDisabledRow("Microphone input (coming soon)"))        // ROADMAP: Stage 5
        stack.addArrangedSubview(makeDisabledRow("Compressed storage (coming soon)"))      // ROADMAP: Stage 6
        stack.addArrangedSubview(makeDisabledRow("Auto game detection (coming soon)"))     // ROADMAP: Stage 7
        stack.addArrangedSubview(makeDisabledRow("Auto-delete old clips (coming soon)"))   // ROADMAP: storage mgmt
        stack.addArrangedSubview(makeDisabledRow("Custom hotkeys (coming soon)"))          // ROADMAP: hotkey editor

        // ── Layout ──

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false

        let documentView = NSView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(stack)
        scrollView.documentView = documentView

        settingsView.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: settingsView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: settingsView.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: settingsView.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: settingsView.bottomAnchor),

            stack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: documentView.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: documentView.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: documentView.bottomAnchor, constant: -16),

            documentView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            documentView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            documentView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
        ])

        for subview in stack.arrangedSubviews {
            if subview is NSTextField || subview is NSButton { continue }
            subview.leadingAnchor.constraint(equalTo: stack.leadingAnchor).isActive = true
            subview.trailingAnchor.constraint(equalTo: stack.trailingAnchor).isActive = true
        }
    }

    // MARK: - Settings Dropdown Data

    private func buildQualityDropdownItems() -> [String] {
        let appDelegate = NSApp.delegate as! AppDelegate
        var items: [String] = CaptureQualityPreset.allCases.map(\.displayName)
        for custom in appDelegate.customPresets {
            items.append(custom.displayName)
        }
        return items
    }

    private func qualitySelectedIndex() -> Int {
        let appDelegate = NSApp.delegate as! AppDelegate
        if let customName = appDelegate.selectedCustomPresetName,
           let idx = appDelegate.customPresets.firstIndex(where: { $0.name == customName }) {
            return CaptureQualityPreset.allCases.count + idx
        }
        return CaptureQualityPreset.allCases.firstIndex(of: appDelegate.currentPreset) ?? 1
    }

    private func buildBufferDropdownItems() -> [String] {
        let appDelegate = NSApp.delegate as! AppDelegate
        var items = appDelegate.bufferSizePresets.map { "\($0) minutes" }
        if !appDelegate.bufferSizePresets.contains(appDelegate.currentBufferMinutes) {
            items.append("\(appDelegate.currentBufferMinutes) minutes")
        }
        return items
    }

    private func bufferSelectedIndex() -> Int {
        let appDelegate = NSApp.delegate as! AppDelegate
        if let idx = appDelegate.bufferSizePresets.firstIndex(of: appDelegate.currentBufferMinutes) {
            return idx
        }
        return appDelegate.bufferSizePresets.count
    }

    private func buildClipLengthDropdownItems() -> [String] {
        let appDelegate = NSApp.delegate as! AppDelegate
        return appDelegate.clipLengthPresets.map { appDelegate.formatDuration($0) }
    }

    private func clipLengthSelectedIndex() -> Int {
        let appDelegate = NSApp.delegate as! AppDelegate
        return appDelegate.clipLengthPresets.firstIndex(of: appDelegate.currentClipLength) ?? 2
    }

    private func updateClipLengthEnabledStates() {
        let appDelegate = NSApp.delegate as! AppDelegate
        let bufferSeconds = appDelegate.currentBufferMinutes * 60
        guard let menu = clipLengthPopup?.menu else { return }
        for (i, seconds) in appDelegate.clipLengthPresets.enumerated() where i < menu.items.count {
            menu.items[i].isEnabled = seconds <= bufferSeconds
        }
    }

    private func refreshSettingsControls() {
        qualityPopup?.removeAllItems()
        for title in buildQualityDropdownItems() { qualityPopup?.addItem(withTitle: title) }
        qualityPopup?.selectItem(at: qualitySelectedIndex())

        bufferPopup?.removeAllItems()
        for title in buildBufferDropdownItems() { bufferPopup?.addItem(withTitle: title) }
        bufferPopup?.selectItem(at: bufferSelectedIndex())

        clipLengthPopup?.removeAllItems()
        for title in buildClipLengthDropdownItems() { clipLengthPopup?.addItem(withTitle: title) }
        clipLengthPopup?.selectItem(at: clipLengthSelectedIndex())
        updateClipLengthEnabledStates()

        updateStorageInfo()
    }

    private func updateStorageInfo() {
        let totalBytes = library.clips.reduce(Int64(0)) { $0 + $1.fileSize }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        storageInfoLabel?.stringValue = "\(formatter.string(fromByteCount: totalBytes)) \u{00B7} \(library.clips.count) clip\(library.clips.count == 1 ? "" : "s")"
    }

    // MARK: - Settings Actions

    @objc private func settingsQualityChanged() {
        let appDelegate = NSApp.delegate as! AppDelegate
        let idx = qualityPopup.indexOfSelectedItem
        let builtInCount = CaptureQualityPreset.allCases.count

        if idx < builtInCount {
            let preset = CaptureQualityPreset.allCases[idx]
            guard preset != appDelegate.currentPreset || appDelegate.selectedCustomPresetName != nil else { return }
            guard appDelegate.offerBufferSave(presetName: preset.displayName) else {
                qualityPopup.selectItem(at: qualitySelectedIndex())
                return
            }
            appDelegate.currentPreset = preset
            appDelegate.selectedCustomPresetName = nil
        } else {
            let customIdx = idx - builtInCount
            guard customIdx < appDelegate.customPresets.count else { return }
            let custom = appDelegate.customPresets[customIdx]
            guard appDelegate.selectedCustomPresetName != custom.name else { return }
            guard appDelegate.offerBufferSave(presetName: custom.displayName) else {
                qualityPopup.selectItem(at: qualitySelectedIndex())
                return
            }
            appDelegate.selectedCustomPresetName = custom.name
        }

        appDelegate.saveSettings()
        appDelegate.rebuildMenu()
        appDelegate.restartCapture()
    }

    @objc private func settingsBufferChanged() {
        let appDelegate = NSApp.delegate as! AppDelegate
        let idx = bufferPopup.indexOfSelectedItem
        let minutes: Int
        if idx < appDelegate.bufferSizePresets.count {
            minutes = appDelegate.bufferSizePresets[idx]
        } else {
            minutes = appDelegate.currentBufferMinutes
        }
        guard minutes != appDelegate.currentBufferMinutes else { return }
        appDelegate.applyBufferSize(minutes)
        refreshSettingsControls()
    }

    @objc private func settingsClipLengthChanged() {
        let appDelegate = NSApp.delegate as! AppDelegate
        let idx = clipLengthPopup.indexOfSelectedItem
        guard idx < appDelegate.clipLengthPresets.count else { return }
        let seconds = appDelegate.clipLengthPresets[idx]
        appDelegate.currentClipLength = seconds
        appDelegate.saveSettings()
        appDelegate.rebuildMenu()
    }

    @objc private func settingsAutoStartChanged(_ sender: NSSwitch) {
        let appDelegate = NSApp.delegate as! AppDelegate
        appDelegate.autoStartCapture = sender.state == .on
        appDelegate.saveSettings()
    }

    @objc private func settingsOpenLibraryChanged(_ sender: NSSwitch) {
        let appDelegate = NSApp.delegate as! AppDelegate
        appDelegate.openLibraryOnSave = sender.state == .on
        appDelegate.saveSettings()
    }

    @objc private func settingsNotifyChanged(_ sender: NSSwitch) {
        let appDelegate = NSApp.delegate as! AppDelegate
        appDelegate.notifyOnSave = sender.state == .on
        appDelegate.saveSettings()
    }

    @objc private func settingsLaunchAtLoginChanged(_ sender: NSSwitch) {
        let appDelegate = NSApp.delegate as! AppDelegate
        let enabled = sender.state == .on
        appDelegate.launchAtLogin = enabled
        appDelegate.saveSettings()
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("SMAppService error: \(error)")
            }
        }
    }

    @objc private func settingsResetWarnings() {
        let alert = NSAlert()
        alert.messageText = "Reset Warning Dialogs"
        alert.informativeText = "All warning dialogs will be shown again."
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let appDelegate = NSApp.delegate as! AppDelegate
        appDelegate.resetWarningDialogs()
    }

    @objc private func settingsResetAll() {
        let alert = NSAlert()
        alert.messageText = "Reset All Settings?"
        alert.informativeText = "This resets all settings to default. Your clips and playlists are kept. Continue?"
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let appDelegate = NSApp.delegate as! AppDelegate
        appDelegate.resetAllSettings()
        refreshSettingsControls()
    }

    @objc private func settingsOpenGitHub() {
        NSWorkspace.shared.open(URL(string: "https://github.com/ITLLEXPLODE/MetalClip")!)
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
        case .search:
            target = searchView
        case .playlists:
            target = isShowingPlaylistDetail ? playlistDetailView : playlistsListView
        case .settings:
            target = settingsView
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

        if item == .search {
            refreshGameChips()
            DispatchQueue.main.async { [weak self] in
                self?.updateSearchFlowLayoutItemSize()
                self?.window?.makeFirstResponder(self?.searchField)
            }
        }

        if item == .playlists {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if !self.isShowingPlaylistDetail {
                    self.updatePlaylistFlowLayoutItemSize()
                    self.playlistCollectionView?.reloadData()
                }
            }
        }

        if item == .settings {
            refreshSettingsControls()
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
        if allClipsFavoritesOnly {
            flatList = flatList.filter { $0.isFavorite }
        }
        clipCollectionView?.reloadData()
    }

    // MARK: - NSCollectionViewDataSource

    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        1
    }

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView == playlistCollectionView { return library.playlists.count }
        if collectionView == searchCollectionView { return searchResults.count }
        return flatList.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        if collectionView == playlistCollectionView {
            let item = collectionView.makeItem(withIdentifier: PlaylistCardItem.identifier, for: indexPath) as! PlaylistCardItem
            if indexPath.item < library.playlists.count {
                let playlist = library.playlists[indexPath.item]
                let clips = library.clips(in: playlist)
                item.configure(name: playlist.name, clipCount: clips.count, coverThumbnailPath: library.coverThumbnailPath(for: playlist))
            }
            return item
        }

        let item = collectionView.makeItem(withIdentifier: ClipCardItem.identifier, for: indexPath) as! ClipCardItem
        let list: [ClipMetadata]
        if collectionView == searchCollectionView { list = searchResults }
        else { list = flatList }

        if indexPath.item < list.count {
            let clip = list[indexPath.item]
            item.configure(with: clip)
            item.onFavoriteToggle = { [weak self] isFavorite in
                guard let self else { return }
                self.library.setFavorite(clip, isFavorite)
                if let idx = self.flatList.firstIndex(where: { $0.id == clip.id }) {
                    self.flatList[idx].isFavorite = isFavorite
                }
                if let idx = self.searchResults.firstIndex(where: { $0.id == clip.id }) {
                    self.searchResults[idx].isFavorite = isFavorite
                }
                if let idx = self.playlistDetailClips.firstIndex(where: { $0.id == clip.id }) {
                    self.playlistDetailClips[idx].isFavorite = isFavorite
                }
                if self.filterFavoritesOnly { self.updateSearchResults() }
            }
        }
        return item
    }

    // MARK: - NSCollectionViewDelegate

    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        guard let indexPath = indexPaths.first else { return }

        if collectionView == playlistCollectionView {
            guard indexPath.item < library.playlists.count else { return }
            showPlaylistDetail(library.playlists[indexPath.item])
            return
        }

        let list: [ClipMetadata]
        if collectionView == searchCollectionView { list = searchResults }
        else { list = flatList }
        guard indexPath.item < list.count else { return }
        openClipInPlayer(list[indexPath.item])
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView == playlistDetailTableView { return playlistDetailClips.count }
        return NavItem.allCases.count
    }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if tableView == playlistDetailTableView {
            return playlistDetailCell(for: row)
        }
        return navCell(for: row)
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        if tableView == playlistDetailTableView { return 76 }
        return 28
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

    // MARK: - Playlist Detail Cells

    private func playlistDetailCell(for row: Int) -> NSView {
        guard row < playlistDetailClips.count else { return NSView() }
        let clip = playlistDetailClips[row]

        let cell = NSView()

        let handle = NSTextField(labelWithString: "☰")
        handle.translatesAutoresizingMaskIntoConstraints = false
        handle.font = .systemFont(ofSize: 14)
        handle.textColor = .tertiaryLabelColor
        handle.toolTip = "Drag to reorder (coming soon)"
        cell.addSubview(handle)

        let thumbView = NSView()
        thumbView.translatesAutoresizingMaskIntoConstraints = false
        thumbView.wantsLayer = true
        thumbView.layer?.cornerRadius = 4
        thumbView.layer?.masksToBounds = true
        thumbView.layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
        thumbView.layer?.contentsGravity = .resizeAspectFill
        if let path = clip.thumbnailPath, let image = NSImage(contentsOfFile: path) {
            thumbView.layer?.contents = image
        }
        cell.addSubview(thumbView)

        let durationBadge = NSTextField(labelWithString: formatDuration(clip.duration))
        durationBadge.translatesAutoresizingMaskIntoConstraints = false
        durationBadge.font = .monospacedDigitSystemFont(ofSize: 9, weight: .medium)
        durationBadge.textColor = .white
        durationBadge.wantsLayer = true
        durationBadge.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.7).cgColor
        durationBadge.layer?.cornerRadius = 2
        durationBadge.alignment = .center
        thumbView.addSubview(durationBadge)

        let baseName = (clip.filename as NSString).deletingPathExtension
        let nameLabel = NSTextField(labelWithString: baseName)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = .systemFont(ofSize: 12, weight: .medium)
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.maximumNumberOfLines = 1
        cell.addSubview(nameLabel)

        let sizeStr = ByteCountFormatter.string(fromByteCount: clip.fileSize, countStyle: .file)
        let detailStr = [clip.resolution, sizeStr].filter { !$0.isEmpty }.joined(separator: " · ")
        let detailLabel = NSTextField(labelWithString: detailStr)
        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        detailLabel.font = .systemFont(ofSize: 10)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.lineBreakMode = .byTruncatingTail
        cell.addSubview(detailLabel)

        NSLayoutConstraint.activate([
            handle.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
            handle.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            handle.widthAnchor.constraint(equalToConstant: 16),

            thumbView.leadingAnchor.constraint(equalTo: handle.trailingAnchor, constant: 8),
            thumbView.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            thumbView.widthAnchor.constraint(equalToConstant: 120),
            thumbView.heightAnchor.constraint(equalToConstant: 68),

            durationBadge.trailingAnchor.constraint(equalTo: thumbView.trailingAnchor, constant: -4),
            durationBadge.bottomAnchor.constraint(equalTo: thumbView.bottomAnchor, constant: -4),

            nameLabel.leadingAnchor.constraint(equalTo: thumbView.trailingAnchor, constant: 10),
            nameLabel.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -12),
            nameLabel.topAnchor.constraint(equalTo: thumbView.topAnchor, constant: 8),

            detailLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            detailLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            detailLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
        ])

        return cell
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let total = Int(duration)
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
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
        playerFilenameLabel.stringValue = clip.filename

        var details = [clip.durationFormatted, clip.resolution, clip.fileSizeFormatted, clip.relativeDateFormatted]
        if let game = clip.gameLabel, !game.isEmpty {
            details.append(game)
        }
        playerDetailsLabel.stringValue = details.joined(separator: " \u{00B7} ")

        updatePlayerFavoriteButton()
        updatePlayerPlaylistPopup()
    }

    private func updatePlayerFavoriteButton() {
        guard let clip = activeClip else { return }
        let symbolName = clip.isFavorite ? "star.fill" : "star"
        playerFavoriteButton.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Favorite")
        playerFavoriteButton.contentTintColor = clip.isFavorite ? .systemYellow : nil
        playerFavoriteButton.title = clip.isFavorite ? "Favorited" : "Favorite"
    }

    private func updatePlayerPlaylistPopup() {
        playerPlaylistPopup.removeAllItems()
        let headerItem = NSMenuItem(title: "Add to Playlist", action: nil, keyEquivalent: "")
        headerItem.image = NSImage(systemSymbolName: "list.bullet.rectangle", accessibilityDescription: "Add to Playlist")
        playerPlaylistPopup.menu?.addItem(headerItem)

        for playlist in library.playlists {
            let mi = NSMenuItem(title: playlist.name, action: #selector(playerAddToPlaylist(_:)), keyEquivalent: "")
            mi.target = self
            mi.representedObject = playlist.id
            if let clip = activeClip, playlist.clipIDs.contains(clip.id) {
                mi.state = .on
            }
            playerPlaylistPopup.menu?.addItem(mi)
        }
        if !library.playlists.isEmpty {
            playerPlaylistPopup.menu?.addItem(NSMenuItem.separator())
        }
        let newItem = NSMenuItem(title: "New Playlist\u{2026}", action: #selector(playerAddToNewPlaylist), keyEquivalent: "")
        newItem.target = self
        playerPlaylistPopup.menu?.addItem(newItem)
    }

    @objc private func backToList() {
        player?.pause()
        activeClip = nil
        isShowingPlayer = false
        showMainView(for: currentNav)
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
            } else if isShowingPlaylistDetail && currentNav == .playlists {
                backToPlaylistList()
            }
        }
        if event.keyCode == 3 && isShowingPlayer && event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty {
            toggleFullscreen()
        }
    }

    // MARK: - Search Logic

    @objc private func dateChipToggled(_ sender: NSButton) {
        guard let filter = ClipLibrary.DateFilter(rawValue: sender.tag) else { return }

        // Deselect Custom when any preset is selected
        customDateChip.state = .off
        customDateStart = nil
        customDateEnd = nil
        customDateChip.title = "Custom"

        if filter == .all {
            if sender.state == .on {
                selectedDateFilters = [.all]
                for view in dateChipRow.arrangedSubviews where view !== sender && view !== customDateChip {
                    (view as? NSButton)?.state = .off
                }
            } else {
                selectedDateFilters.remove(.all)
            }
        } else {
            if sender.state == .on {
                selectedDateFilters.insert(filter)
                selectedDateFilters.remove(.all)
                for view in dateChipRow.arrangedSubviews {
                    if let btn = view as? NSButton, btn.tag == ClipLibrary.DateFilter.all.rawValue {
                        btn.state = .off
                    }
                }
            } else {
                selectedDateFilters.remove(filter)
            }
        }
        updateSearchResults()
    }

    @objc private func customDateChipToggled(_ sender: NSButton) {
        if sender.state == .on {
            // Deselect all preset date chips
            selectedDateFilters.removeAll()
            for view in dateChipRow.arrangedSubviews where view !== customDateChip {
                (view as? NSButton)?.state = .off
            }
            showCustomDatePicker()
        } else {
            customDateStart = nil
            customDateEnd = nil
            customDateChip.title = "Custom"
            updateSearchResults()
        }
    }

    private func showCustomDatePicker() {
        let alert = NSAlert()
        alert.messageText = "Custom Date Range"
        alert.informativeText = "Select start and end dates:"
        alert.addButton(withTitle: "Apply")
        alert.addButton(withTitle: "Cancel")

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 60))

        let startLabel = NSTextField(labelWithString: "From:")
        startLabel.frame = NSRect(x: 0, y: 32, width: 40, height: 20)
        startLabel.font = .systemFont(ofSize: 12)
        container.addSubview(startLabel)

        let startPicker = NSDatePicker()
        startPicker.frame = NSRect(x: 44, y: 30, width: 240, height: 24)
        startPicker.datePickerStyle = .textFieldAndStepper
        startPicker.datePickerElements = .yearMonthDay
        startPicker.dateValue = customDateStart ?? Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        container.addSubview(startPicker)

        let endLabel = NSTextField(labelWithString: "To:")
        endLabel.frame = NSRect(x: 0, y: 2, width: 40, height: 20)
        endLabel.font = .systemFont(ofSize: 12)
        container.addSubview(endLabel)

        let endPicker = NSDatePicker()
        endPicker.frame = NSRect(x: 44, y: 0, width: 240, height: 24)
        endPicker.datePickerStyle = .textFieldAndStepper
        endPicker.datePickerElements = .yearMonthDay
        endPicker.dateValue = customDateEnd ?? Date()
        container.addSubview(endPicker)

        alert.accessoryView = container

        if alert.runModal() == .alertFirstButtonReturn {
            customDateStart = startPicker.dateValue
            customDateEnd = endPicker.dateValue

            let fmt = DateFormatter()
            fmt.dateStyle = .medium
            fmt.timeStyle = .none
            customDateChip.title = "\(fmt.string(from: customDateStart!)) – \(fmt.string(from: customDateEnd!))"

            updateSearchResults()
        } else {
            // Cancelled — turn off chip if no range was set
            if customDateStart == nil {
                customDateChip.state = .off
            }
        }
    }

    @objc private func lengthChipToggled(_ sender: NSButton) {
        guard let filter = ClipLibrary.LengthFilter(rawValue: sender.tag) else { return }
        if sender.state == .on {
            selectedLengthFilters.insert(filter)
        } else {
            selectedLengthFilters.remove(filter)
        }
        updateSearchResults()
    }

    @objc private func gameChipToggled(_ sender: NSButton) {
        let game = sender.title
        if sender.state == .on {
            selectedGameFilters.insert(game)
        } else {
            selectedGameFilters.remove(game)
        }
        updateSearchResults()
    }

    @objc private func favoritesChipToggled(_ sender: NSButton) {
        filterFavoritesOnly = sender.state == .on
        updateSearchResults()
    }

    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSSearchField, field == searchField else { return }
        searchText = field.stringValue
        updateSearchResults()
    }

    private func updateSearchResults() {
        let hasCustomDate = customDateStart != nil && customDateEnd != nil
        let hasActiveFilter = !searchText.isEmpty || !selectedDateFilters.isEmpty || !selectedLengthFilters.isEmpty || !selectedGameFilters.isEmpty || filterFavoritesOnly || hasCustomDate

        if !hasActiveFilter {
            searchResults = []
            searchCollectionView?.reloadData()
            searchScrollView?.isHidden = true
            searchEmptyLabel?.isHidden = false
            searchEmptyLabel?.stringValue = "필터를 선택하세요"
            return
        }

        let customRange: (start: Date, end: Date)? = hasCustomDate ? (customDateStart!, customDateEnd!) : nil
        searchResults = library.search(text: searchText, dateFilters: selectedDateFilters, lengthFilters: selectedLengthFilters, gameFilters: selectedGameFilters, favoritesOnly: filterFavoritesOnly, customDateRange: customRange)
        searchCollectionView?.reloadData()

        if searchResults.isEmpty {
            searchScrollView?.isHidden = true
            searchEmptyLabel?.isHidden = false
            searchEmptyLabel?.stringValue = "결과 없음"
        } else {
            searchScrollView?.isHidden = false
            searchEmptyLabel?.isHidden = true
        }
    }

    private func refreshGameChips() {
        for view in gameChipRow.arrangedSubviews { view.removeFromSuperview() }
        selectedGameFilters.removeAll()

        // FUTURE: game chips populate when gameLabel is set
        let games = library.distinctGameLabels
        gameChipRow.isHidden = games.isEmpty

        for game in games {
            gameChipRow.addArrangedSubview(makeChip(title: game, action: #selector(gameChipToggled(_:)), tag: 0))
        }
    }

    // MARK: - Actions

    @objc private func sortChanged() {
        currentSort = ClipLibrary.SortOrder(rawValue: sortPopup.indexOfSelectedItem) ?? .newestFirst
        reloadClipGrid()
    }

    @objc private func allClipsFavoritesToggled() {
        allClipsFavoritesOnly = allClipsFavoritesButton.state == .on
        let symbolName = allClipsFavoritesOnly ? "star.fill" : "star"
        allClipsFavoritesButton.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Favorites")
        allClipsFavoritesButton.contentTintColor = allClipsFavoritesOnly ? .systemYellow : nil
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

    @objc private func playerFavoriteToggled() {
        guard var clip = activeClip else { return }
        clip.isFavorite.toggle()
        library.setFavorite(clip, clip.isFavorite)
        activeClip = clip
        if let idx = flatList.firstIndex(where: { $0.id == clip.id }) {
            flatList[idx].isFavorite = clip.isFavorite
        }
        if let idx = searchResults.firstIndex(where: { $0.id == clip.id }) {
            searchResults[idx].isFavorite = clip.isFavorite
        }
        if let idx = playlistDetailClips.firstIndex(where: { $0.id == clip.id }) {
            playlistDetailClips[idx].isFavorite = clip.isFavorite
        }
        updatePlayerFavoriteButton()
    }

    @objc private func playerAddToPlaylist(_ sender: NSMenuItem) {
        guard let clip = activeClip, let playlistID = sender.representedObject as? UUID else { return }
        guard let playlist = library.playlists.first(where: { $0.id == playlistID }) else { return }
        if playlist.clipIDs.contains(clip.id) {
            library.removeClip(clip, fromPlaylist: playlist)
        } else {
            library.addClip(clip, toPlaylist: playlist)
        }
        if isShowingPlaylistDetail && activePlaylist?.id == playlistID {
            reloadPlaylistDetail()
        }
    }

    @objc private func playerAddToNewPlaylist() {
        guard let clip = activeClip else { return }
        let alert = NSAlert()
        alert.messageText = "New Playlist"
        alert.informativeText = "Enter a name for the playlist:"
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 250, height: 24))
        field.stringValue = "My Playlist"
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = field.stringValue.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let playlist = library.createPlaylist(name: name)
        library.addClip(clip, toPlaylist: playlist)
    }

    // MARK: - Context Menu

    private func clipAtClickPoint(in collectionView: NSCollectionView, from list: [ClipMetadata]) -> ClipMetadata? {
        let point = collectionView.convert(collectionView.window!.mouseLocationOutsideOfEventStream, from: nil)
        guard let indexPath = collectionView.indexPathForItem(at: point), indexPath.item < list.count else { return nil }
        return list[indexPath.item]
    }

    private func playlistAtClickPoint() -> ClipLibrary.Playlist? {
        let point = playlistCollectionView.convert(playlistCollectionView.window!.mouseLocationOutsideOfEventStream, from: nil)
        guard let indexPath = playlistCollectionView.indexPathForItem(at: point), indexPath.item < library.playlists.count else { return nil }
        return library.playlists[indexPath.item]
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        // Playlist card context menu
        if menu == playlistCollectionView.menu {
            contextMenuPlaylist = playlistAtClickPoint()
            for item in menu.items { item.isHidden = contextMenuPlaylist == nil }
            return
        }

        // Determine which clip collection/table view this menu belongs to
        let clip: ClipMetadata?
        if menu == playlistDetailTableView.menu {
            let row = playlistDetailTableView.clickedRow
            clip = (row >= 0 && row < playlistDetailClips.count) ? playlistDetailClips[row] : nil
        } else if menu == searchCollectionView.menu {
            clip = clipAtClickPoint(in: searchCollectionView, from: searchResults)
        } else {
            clip = clipAtClickPoint(in: clipCollectionView, from: flatList)
        }
        contextMenuClip = clip

        if clip == nil {
            for item in menu.items { item.isHidden = true }
            return
        }

        for item in menu.items { item.isHidden = false }

        // Update favorites label
        for item in menu.items where item.action == #selector(contextToggleFavorite) {
            item.title = clip!.isFavorite ? "Remove from Favorites" : "Add to Favorites"
        }

        // Populate "Add to Playlist" submenu
        if let clip, let submenuItem = menu.items.first(where: { $0.tag == 999 }), let submenu = submenuItem.submenu {
            submenu.removeAllItems()
            for playlist in library.playlists {
                let mi = NSMenuItem(title: playlist.name, action: #selector(contextAddToPlaylist(_:)), keyEquivalent: "")
                mi.target = self
                mi.representedObject = playlist.id
                mi.state = playlist.clipIDs.contains(clip.id) ? .on : .off
                submenu.addItem(mi)
            }
            if !library.playlists.isEmpty {
                submenu.addItem(NSMenuItem.separator())
            }
            let newItem = NSMenuItem(title: "New Playlist…", action: #selector(contextAddToNewPlaylist), keyEquivalent: "")
            newItem.target = self
            submenu.addItem(newItem)
        }
    }

    @objc private func contextToggleFavorite() {
        guard let clip = contextMenuClip else { return }
        library.setFavorite(clip, !clip.isFavorite)
        reloadClipGrid()
        if currentNav == .search { updateSearchResults() }
        if isShowingPlaylistDetail { reloadPlaylistDetail() }
    }

    @objc private func contextRename() {
        guard let clip = contextMenuClip else { return }
        performRename(clip)
    }

    @objc private func contextDelete() {
        guard let clip = contextMenuClip else { return }
        performDelete(clip)
    }

    @objc private func contextShowInFinder() {
        guard let clip = contextMenuClip else { return }
        let url = library.directory.appendingPathComponent(clip.filename)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    // MARK: - Playlist Actions

    @objc private func createNewPlaylist() {
        let alert = NSAlert()
        alert.messageText = "New Playlist"
        alert.informativeText = "Enter a name for the playlist:"
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 250, height: 24))
        field.stringValue = "My Playlist"
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = field.stringValue.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        library.createPlaylist(name: name)
        playlistCollectionView?.reloadData()
    }

    @objc private func contextRenamePlaylist() {
        guard let playlist = contextMenuPlaylist else { return }
        let alert = NSAlert()
        alert.messageText = "Rename Playlist"
        alert.informativeText = "Enter a new name:"
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 250, height: 24))
        field.stringValue = playlist.name
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = field.stringValue.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        library.renamePlaylist(playlist, to: name)
        playlistCollectionView?.reloadData()
    }

    @objc private func contextDeletePlaylist() {
        guard let playlist = contextMenuPlaylist else { return }
        let alert = NSAlert()
        alert.messageText = "Delete Playlist?"
        alert.informativeText = "Are you sure you want to delete \"\(playlist.name)\"? Clips will not be deleted."
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        library.deletePlaylist(playlist)
        playlistCollectionView?.reloadData()
    }

    @objc private func contextRemoveFromPlaylist() {
        guard let clip = contextMenuClip, let playlist = activePlaylist else { return }
        library.removeClip(clip, fromPlaylist: playlist)
        reloadPlaylistDetail()
    }

    @objc private func contextSetAsPlaylistCover() {
        guard let clip = contextMenuClip, let playlist = activePlaylist else { return }
        library.setPlaylistCover(playlist, clipID: clip.id)
    }

    @objc private func contextAddToPlaylist(_ sender: NSMenuItem) {
        guard let clip = contextMenuClip, let playlistID = sender.representedObject as? UUID else { return }
        guard let playlist = library.playlists.first(where: { $0.id == playlistID }) else { return }
        if playlist.clipIDs.contains(clip.id) {
            library.removeClip(clip, fromPlaylist: playlist)
        } else {
            library.addClip(clip, toPlaylist: playlist)
        }
        if isShowingPlaylistDetail && activePlaylist?.id == playlistID {
            reloadPlaylistDetail()
        }
    }

    @objc private func contextAddToNewPlaylist() {
        guard let clip = contextMenuClip else { return }
        let alert = NSAlert()
        alert.messageText = "New Playlist"
        alert.informativeText = "Enter a name for the playlist:"
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 250, height: 24))
        field.stringValue = "My Playlist"
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = field.stringValue.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let playlist = library.createPlaylist(name: name)
        library.addClip(clip, toPlaylist: playlist)
    }

    private func showPlaylistDetail(_ playlist: ClipLibrary.Playlist) {
        activePlaylist = playlist
        isShowingPlaylistDetail = true
        playlistDetailTitle.stringValue = playlist.name
        reloadPlaylistDetail()
        showMainView(for: .playlists)
    }

    @objc private func backToPlaylistList() {
        activePlaylist = nil
        isShowingPlaylistDetail = false
        playlistDetailClips = []
        showMainView(for: .playlists)
    }

    private func reloadPlaylistDetail() {
        guard let playlist = activePlaylist,
              let current = library.playlists.first(where: { $0.id == playlist.id }) else { return }
        activePlaylist = current
        playlistDetailTitle.stringValue = current.name

        let clips = library.clips(in: current)
        switch playlistDetailSort {
        case .newestFirst: playlistDetailClips = clips.sorted { $0.dateCreated > $1.dateCreated }
        case .oldestFirst: playlistDetailClips = clips.sorted { $0.dateCreated < $1.dateCreated }
        case .longestFirst: playlistDetailClips = clips.sorted { $0.duration > $1.duration }
        case .shortestFirst: playlistDetailClips = clips.sorted { $0.duration < $1.duration }
        }

        playlistDetailCountLabel?.stringValue = "\(playlistDetailClips.count) clip\(playlistDetailClips.count == 1 ? "" : "s")"

        if let coverPath = library.coverThumbnailPath(for: current) {
            playlistDetailCoverView?.image = NSImage(contentsOfFile: coverPath)
        } else {
            playlistDetailCoverView?.image = nil
        }

        playlistDetailTableView?.reloadData()
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
