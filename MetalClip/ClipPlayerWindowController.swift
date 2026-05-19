import Cocoa
import AVKit

class ClipPlayerWindowController: NSObject {

    private var window: NSWindow?
    private var playerView: AVPlayerView?
    private var player: AVPlayer?

    func show(url: URL) {
        player?.pause()
        player = AVPlayer(url: url)

        if window == nil {
            createWindow()
        }

        window?.title = url.lastPathComponent
        playerView?.player = player
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        player?.play()
    }

    private func createWindow() {
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1280, height: 800),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        w.isReleasedWhenClosed = false
        w.minSize = NSSize(width: 640, height: 400)

        let pv = AVPlayerView()
        pv.translatesAutoresizingMaskIntoConstraints = false
        pv.controlsStyle = .floating
        w.contentView?.addSubview(pv)

        NSLayoutConstraint.activate([
            pv.leadingAnchor.constraint(equalTo: w.contentView!.leadingAnchor),
            pv.trailingAnchor.constraint(equalTo: w.contentView!.trailingAnchor),
            pv.topAnchor.constraint(equalTo: w.contentView!.topAnchor),
            pv.bottomAnchor.constraint(equalTo: w.contentView!.bottomAnchor),
        ])

        playerView = pv
        window = w
    }
}
