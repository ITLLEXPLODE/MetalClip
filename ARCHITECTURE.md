# Architecture

## Overview

MetalClip is a macOS menu bar application that continuously captures the screen into a disk-backed rolling buffer. When the user triggers a save, segments from the buffer are composed into a single MP4 file.

```
┌─────────────┐     ┌──────────────┐     ┌───────────────┐
│   Display    │────▶│ScreenCapture │────▶│ ScreenRecorder│
│  (ProMotion) │     │    Kit       │     │  (SCStream)   │
└─────────────┘     └──────────────┘     └───────┬───────┘
                                                  │
                                    CMSampleBuffer (video + audio)
                                                  │
                         ┌────────────────────────┼────────────────┐
                         │                        │                │
                         ▼                        ▼                ▼
                  ┌─────────────┐         ┌──────────────┐  ┌───────────┐
                  │RollingBuffer│         │  Continuous   │  │  (future) │
                  │ 15s segments│         │   Writer      │  │ Microphone│
                  │  on disk    │         │  single file  │  │   Input   │
                  └──────┬──────┘         └──────┬───────┘  └───────────┘
                         │                       │
                    takeSnapshot()          finishWriting()
                         │                       │
                         ▼                       ▼
                  ┌─────────────┐         ┌──────────┐
                  │ClipExporter │         │  Direct   │
                  │ compose +   │         │   MP4     │
                  │  export     │         │  output   │
                  └──────┬──────┘         └──────┬───┘
                         │                       │
                         ▼                       ▼
                  ┌─────────────┐         ┌─────────────┐
                  │    MP4      │         │    MP4      │
                  │   file      │         │   file      │
                  └──────┬──────┘         └──────┬──────┘
                         │                       │
                         └───────────┬───────────┘
                                     ▼
                              ┌─────────────┐
                              │ ClipPlayer  │
                              │  Window     │
                              └─────────────┘
```

## Components

### AppDelegate (`AppDelegate.swift`)

The central coordinator. Owns all other components and wires them together. Responsibilities:

- Menu bar setup and rebuild on state changes
- Global hotkey registration (via HotKeyManager)
- Settings persistence (UserDefaults)
- Coordinating save/export workflows
- Managing recording indicator visibility

### ScreenRecorder (`ScreenRecorder.swift`)

Wraps ScreenCaptureKit's `SCStream`. Handles:

- Permission checking (`CGPreflightScreenCaptureAccess`)
- Display discovery and configuration
- Resolution calculation (display × backingScaleFactor × qualityScale)
- Frame delivery via `SCStreamOutput` protocol
- Routing frames to RollingBuffer and optionally to continuous recording
- Continuous recording via a separate AVAssetWriter (parallel write path)

Key configuration:
- Pixel format: 32BGRA
- Color space: Display P3
- Queue depth: 8 (elevated from default 3 for 120fps)
- Frame delivery wrapped in `autoreleasepool` to prevent object accumulation

### RollingBuffer (`RollingBuffer.swift`)

The core innovation. Maintains a disk-backed circular buffer of video segments.

**How it works:**

1. Incoming `CMSampleBuffer` frames are written to an AVAssetWriter producing 15-second `.mov` segment files
2. Every 15 seconds, the current segment is finalized and a new one starts
3. Segments older than `maxDuration` (30 minutes) are deleted from disk
4. At any point, `takeSnapshot()` freezes the current state by finalizing the active segment and returning all segment URLs

**Why 15-second segments:**

- Small enough to discard with fine granularity (wastes at most 15s of storage)
- Large enough that segment rotation overhead is negligible
- AVAssetWriter file finalization is fast for short files
- Individual segments can be read while new ones are being written

**Why disk-backed (not RAM):**

- 30 minutes of 4K 120fps HEVC ≈ 9GB on disk — would exhaust RAM on most machines
- Disk I/O for HEVC is handled by Apple's hardware encoder, which writes directly
- No memory pressure on the app — segment files are write-once, read-on-demand
- Crash recovery: segments survive app crashes (though not currently recovered)

**Segment file format:**

- Container: `.mov` (QuickTime)
- Video codec: HEVC (H.265), B-frames disabled, 40Mbps bitrate
- Audio codec: AAC, 48kHz stereo, 128kbps
- Color: P3_D65 primaries, BT.709 transfer function, BT.709 YCbCr matrix
- Color attachments stamped on each pixel buffer via `CVBufferSetAttachment`

**Snapshot freezing:**

When `takeSnapshot()` is called (at hotkey press time):
1. The current in-progress segment is finalized (so no data is lost)
2. A new segment starts immediately (so capture continues without gaps)
3. The array of finalized segment URLs is returned
4. These URLs are passed to ClipExporter — they represent the buffer state at the exact moment of the hotkey press

This is what makes "clip ends when you press the hotkey" work.

### ClipExporter (`ClipExporter.swift`)

Takes an array of segment URLs and produces a single MP4 file.

**Process:**

1. Select the needed segments from the end of the array (based on requested duration)
2. Create an `AVMutableComposition` with video + audio tracks
3. For each segment, load the video track's actual time range and insert into the composition
4. If the total exceeds the requested duration, trim from the beginning
5. Export via `AVAssetExportSession` with quality-appropriate preset

**Quality presets:**

| Quality | Preset | Effect |
|---------|--------|--------|
| High | `HEVCHighestQuality` | Re-encodes at highest quality, normalizes timing |
| Medium | `HEVC1920x1080` | Re-encodes, scales to 1080p |
| Low | `1280x720` | Re-encodes, scales to 720p |

High uses `HEVCHighestQuality` instead of `Passthrough` to normalize timing metadata across segments, which prevents VFR playback issues in QuickTime.

### ClipPlayerWindowController (`ClipPlayerWindowController.swift`)

Thin wrapper around AVKit's `AVPlayerView`. Opens after every clip save. Reuses a single window — calling `show(url:)` replaces the current content and auto-plays.

### HotKeyManager / HotKey (`HotKey.swift`)

Global hotkey system using the Carbon Event API (`InstallEventHandler`, `RegisterEventHotKey`). Carbon is used because there's no AppKit/SwiftUI API for system-wide hotkeys that work when the app isn't focused.

Each hotkey is a struct with a `keyCode` (virtual key code) and `modifiers` (Carbon modifier flags). The manager maintains a dictionary mapping Carbon hotkey IDs to Swift closures.

### RecordingIndicatorWindow (`AppDelegate.swift`)

A borderless 12px red dot window. Uses `sharingType = .none` to exclude itself from ScreenCaptureKit's capture — so the indicator is visible to the user but never appears in recordings.

## Color Pipeline

```
Display (P3-1600, XDR)
    │
    ▼
SCStreamConfiguration.colorSpaceName = displayP3
    │
    ▼
CMSampleBuffer with BGRA pixels in P3 color space
    │
    ▼
CVBufferSetAttachment on each pixel buffer:
  - kCVImageBufferColorPrimariesKey = P3_D65
  - kCVImageBufferTransferFunctionKey = ITU_R_709_2
  - kCVImageBufferYCbCrMatrixKey = ITU_R_709_2
    │
    ▼
AVAssetWriter (HEVC) encodes with P3 color metadata
    │
    ▼
Segment .mov files with correct color tags
    │
    ▼
AVAssetExportSession re-encodes preserving color metadata
    │
    ▼
Final .mp4 with P3 color (verified via format description)
```

The color attachments must be stamped on the `CVPixelBuffer` directly because the HEVC hardware encoder ignores `AVVideoColorPropertiesKey` in the output settings dictionary. The top-level `AVVideoColorPropertiesKey` in writer settings is kept as a hint but is not sufficient alone.

## Continuous Recording (Parallel Path)

When the user presses ⇧⌘R, a separate `AVAssetWriter` is created alongside the rolling buffer. Each incoming frame is written to both:

1. The rolling buffer (always)
2. The continuous recording writer (only while recording)

This means the rolling buffer continues to function normally during a recording session. The continuous recording produces a single `.mp4` file directly — no composition step needed.

## Threading Model

- **Main thread**: UI (menu bar, windows, alerts)
- **ScreenCaptureKit delivery queue**: `.global(qos: .userInitiated)` — frame callbacks
- **RollingBuffer serial queue**: `com.metalclip.rollingbuffer` — all segment operations
- **Continuous recording serial queue**: `com.metalclip.continuous` — continuous writer operations
- **Task (structured concurrency)**: Capture start/stop, clip export
