# MetalClip

A lightweight, open-source screen clip recorder for macOS — the Medal/ShadowPlay alternative Apple Silicon deserves.

![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-blue)
![Architecture](https://img.shields.io/badge/arch-Apple%20Silicon-green)
![License](https://img.shields.io/badge/license-MIT-brightgreen)
![Status](https://img.shields.io/badge/status-beta-orange)

## What is MetalClip?

MetalClip continuously records your screen in the background using a rolling buffer. When something worth saving happens, press a hotkey and the last N seconds are exported as an MP4 — no need to have been "recording" first.

Built natively for macOS with ScreenCaptureKit and hardware-accelerated HEVC encoding. Runs as a lightweight menu bar app with minimal CPU/memory footprint thanks to a disk-backed segment architecture.

## Screenshots

<!-- TODO: Add screenshots of menu bar, custom clip window, player -->

## Features

- **Instant replay**: Save the last 30s to 30min with a single hotkey
- **Custom clips**: Choose exact duration, filename, save location, and quality
- **Continuous recording**: Traditional start/stop recording mode
- **Built-in clip player**: AVKit-based player opens automatically after saving
- **120fps capture**: ProMotion display support at native refresh rate
- **P3 wide color**: Captures and preserves Display P3 color gamut
- **HEVC encoding**: Hardware-accelerated H.265 for small file sizes
- **Rolling buffer**: 30-minute disk-backed buffer using 15-second segments
- **Quality presets**: High (native), Medium (1080p HEVC), Low (720p)
- **Force Apply mode**: Choose between max-quality capture or resource-saving presets
- **Settings persistence**: All preferences saved across app restarts
- **Recording indicator**: Red dot overlay excluded from capture
- **Menu bar app**: Lives in the system tray, no Dock icon
- **Microphone input** *(planned)*: UI present, capture integration coming in v0.5

## Requirements

- macOS 13.0 (Ventura) or later
- Apple Silicon (M1 or later) recommended
- Screen Recording permission (prompted on first launch)

## Installation

### Download

Download the latest `.app` from [Releases](https://github.com/ITLLEXPLODE/MetalClip/releases).

### Build from Source

```bash
git clone https://github.com/ITLLEXPLODE/MetalClip.git
cd MetalClip
open MetalClip.xcodeproj
```

Build and run in Xcode (Cmd+R). Grant Screen Recording permission when prompted.

## Quick Start

1. Launch MetalClip — a record icon appears in your menu bar
2. The rolling buffer starts capturing immediately
3. Play your game or use your Mac normally
4. Press **⇧⌘1** to save the last 2 minutes as a clip
5. The clip player opens automatically with your saved clip

## Hotkeys

| Shortcut | Action |
|----------|--------|
| `⇧⌘1` | Save clip (last N seconds, configurable) |
| `⇧⌘2` | Open custom clip window (choose duration, name, quality) |
| `⇧⌘R` | Start/stop continuous recording |

## Settings

All settings are accessible from the menu bar dropdown:

- **Clip Length**: 30s, 1m, 2m (default), 5m, 10m, 30m
- **Frame Rate**: 15, 30, 60 (default), 120 fps
- **Quality**: High (default), Medium, Low
- **Force Apply**: When OFF, captures at max quality (120fps, native resolution). When ON, applies your FPS/quality settings during capture to save resources.
- **Microphone**: Off (default) — *microphone capture is planned but not yet functional; the UI is present but selecting a mic has no effect on recordings*

Clips are saved to `~/Movies/MetalClip/`.

## Tech Stack

- Swift 6 / AppKit
- ScreenCaptureKit (screen + audio capture)
- AVFoundation (HEVC encoding, composition, export)
- AVKit (clip player)
- Carbon (global hotkeys)

## License

MIT — see [LICENSE](LICENSE) for details.

## Author

**Inho Yoon** — [@ITLLEXPLODE](https://github.com/ITLLEXPLODE)
