# Code Guide

File-by-file walkthrough of every Swift source file in MetalClip.

## File Map

```
MetalClip/
├── main.swift                        Entry point
├── MetalClip/
│   ├── AppDelegate.swift             Central coordinator + UI
│   ├── ScreenRecorder.swift          ScreenCaptureKit wrapper
│   ├── RollingBuffer.swift           Disk-backed segment buffer
│   ├── ClipExporter.swift            Segment → MP4 composition
│   ├── ClipPlayerWindowController.swift  Built-in video player
│   ├── CustomClipWindowController.swift  Custom clip save UI
│   └── Info.plist                    App metadata
└── HotKey.swift                      Global hotkey system (Carbon)
```

---

## main.swift

**Purpose**: Manual app entry point.

MetalClip doesn't use `@main` or a storyboard. Instead, `main.swift` creates the `NSApplication` instance, assigns the `AppDelegate`, and calls `run()`. This is necessary because the app has no `MainMenu.xib` — the entire UI is built programmatically.

---

## AppDelegate.swift

**Purpose**: Central coordinator. Owns every other component and wires them together.

**Contains two classes:**

### `RecordingIndicatorWindow` (lines 6–34)

`NSWindow` subclass. A 12×12px red dot shown in the top-right corner during continuous recording.

Key details:
- `sharingType = .none` — invisible to ScreenCaptureKit, so it never appears in recordings
- `.borderless` with transparent background — just a floating circle
- `ignoresMouseEvents = true` — click-through
- `collectionBehavior = [.canJoinAllSpaces, .stationary]` — follows across Spaces

### `AppDelegate` (lines 38–545)

The largest file. Responsibilities grouped by MARK sections:

#### Properties

| Property | Type | Purpose |
|----------|------|---------|
| `statusItem` | `NSStatusItem` | Menu bar icon |
| `hotKeyManager` | `HotKeyManager` | Carbon hotkey registrations |
| `customClipWindowController` | `CustomClipWindowController` | Custom save window |
| `clipPlayer` | `ClipPlayerWindowController` | Built-in clip player |
| `screenRecorder` | `ScreenRecorder` | Capture engine |
| `recordingIndicator` | `RecordingIndicatorWindow?` | Red dot (lazy) |
| `bufferStartDate` | `Date` | When buffer started (for available-seconds calculation) |
| `currentClipLength` | `Int` | Quick-save duration in seconds |
| `currentFPS` | `Int` | Frame rate setting |
| `currentQuality` | `String` | "High", "Medium", or "Low" |
| `forceApply` | `Bool` | Whether to apply settings at capture time |
| `currentMicrophone` | `String` | Mic selection (not yet wired) |
| `isRecording` | `Bool` | Continuous recording state |

Hotkey definitions use Carbon virtual key codes:
- `keyCode: 18` = `1` key (⇧⌘1)
- `keyCode: 19` = `2` key (⇧⌘2)
- `keyCode: 15` = `R` key (⇧⌘R)

#### `applicationDidFinishLaunching(_:)`

Initialization order matters:
1. `loadSettings()` — must be first, other components read these values
2. `setupMenuBar()` — creates status item
3. `setupHotKeys()` — registers global hotkeys
4. `setupCustomClipWindow()` — creates window + wires save callback
5. `clipPlayer = ClipPlayerWindowController()` — creates player
6. `startScreenCapture()` — begins capture (async, may show permission alert)

#### `startScreenCapture()`

Creates a `ScreenRecorder` and configures it based on `forceApply`:
- OFF: `requestedFPS = 120`, `qualityScale = 1.0` (max quality always)
- ON: uses `currentFPS` and `qualityScaleValue()` (user's menu settings)

The capture start is wrapped in a Task because `startCapture()` is async. Errors show an alert on the main thread.

#### `rebuildMenu()`

Destroys and recreates the entire `NSMenu` from scratch. Called on every state change (recording toggle, setting change). Submenus for Clip Length, Frame Rate, Quality, and Microphone each iterate over their option arrays and mark the current selection with `.on` state.

#### `saveClipAction()` — triggered by ⇧⌘1

1. Checks available buffer time
2. Calls `rollingBuffer.takeSnapshot()` — freezes segment state at this exact moment
3. Passes snapshot URLs + duration to `ClipExporter.export()`
4. On success, opens the clip in `clipPlayer`

The snapshot is taken synchronously before the async export Task, ensuring the clip ends at the hotkey press time.

#### `saveCustomClipAction()` — triggered by ⇧⌘2

1. Takes snapshot + records timestamp
2. Opens `CustomClipWindowController` with the snapshot data
3. The window's `onSave` callback (set in `setupCustomClipWindow()`) handles the export

#### `toggleRecordingAction()` — triggered by ⇧⌘R

Two branches:
- **Start**: Creates output URL, calls `screenRecorder.startContinuousRecording(to:)`, shows red dot
- **Stop**: Hides red dot, calls `stopContinuousRecording`, opens result in player

#### `restartCapture()`

Stops current capture, creates a fresh `ScreenRecorder`, and restarts. Called when Force Apply or quality/FPS settings change. Resets `bufferStartDate` because the buffer is now empty.

#### `qualityScaleValue()`

Maps quality string to a multiplier applied to capture resolution:
- High → 1.0 (native)
- Medium → 0.85
- Low → 0.7

---

## HotKey.swift

**Purpose**: Global hotkey registration using the Carbon Event API.

### `HotKey` struct

Simple data holder:
```swift
struct HotKey {
    let keyCode: UInt32     // Carbon virtual key code
    let modifiers: UInt32   // Carbon modifier mask (cmdKey | shiftKey etc.)
}
```

### `HotKeyManager` class

Maintains a dictionary mapping Carbon event hot key IDs to Swift closures. Uses:
- `InstallEventHandler` — registers a C callback for `kEventHotKeyPressed`
- `RegisterEventHotKey` — registers each individual hotkey with the system

Carbon is used because there's no public macOS API for intercepting global hotkeys when the app isn't focused. `NSEvent.addGlobalMonitorForEvents` can observe but not consume key events, and doesn't work for modifier+key combinations reliably.

The C callback bridges to Swift via `GetEventParameter` to extract the hotkey ID, then looks up and calls the corresponding closure.

---

## ScreenRecorder.swift

**Purpose**: Wraps ScreenCaptureKit for continuous screen + audio capture.

### `RecorderError` enum

Three cases: `noDisplay`, `notCapturing`, `permissionNeeded`. All conform to `LocalizedError` with user-facing descriptions.

### `ScreenRecorder` class

Conforms to `SCStreamOutput` and `SCStreamDelegate`.

#### Key Properties

Most properties are marked `nonisolated(unsafe)` because they're accessed from multiple threads (ScreenCaptureKit callbacks, continuous recording queue, main thread). Thread safety is managed by dispatch queues, not Swift concurrency.

#### `startCapture()` async throws

1. **Permission**: `CGPreflightScreenCaptureAccess()` → `CGRequestScreenCaptureAccess()`. If not granted, throws immediately. The system shows its own permission dialog.
2. **Display**: Gets `SCShareableContent`, takes first display.
3. **Resolution**: `display.width × backingScaleFactor × qualityScale`. Dimensions forced even with `& ~1` (HEVC requirement).
4. **Config**: Sets `SCStreamConfiguration` — width, height, frame interval, audio, pixel format, color space, queue depth.
5. **Buffer**: Creates temp directory, initializes `RollingBuffer`.
6. **Stream**: Creates `SCStream`, adds self as output for `.screen` and `.audio`, starts capture.

#### `stream(_:didOutputSampleBuffer:of:)` — SCStreamOutput

Called by ScreenCaptureKit on a background queue for every captured frame. Wrapped in `autoreleasepool` to prevent AVFoundation object accumulation at 120fps.

Routes each sample buffer to:
1. `rollingBuffer.appendVideoSample()` or `appendAudioSample()` (always)
2. `appendToContinuous()` (only if `isContinuousRecording`)

The stream handler itself does not modify the sample buffers — it only routes them. P3 color attachments (`CVBufferSetAttachment`) are stamped on the pixel buffer at two separate points downstream:
- `RollingBuffer.appendVideoSample()` — stamps before writing to segment files
- `ScreenRecorder.appendToContinuous()` — stamps before writing to the continuous recording file

This ensures both code paths produce correctly color-tagged output independently.

#### Continuous Recording

`startContinuousRecording(to:)` / `stopContinuousRecording(completion:)` manage a separate `AVAssetWriter` that runs in parallel with the rolling buffer. Same HEVC + AAC settings, but no explicit bitrate cap (uses encoder default). The `continuousQueue` serializes all writes.

`appendToContinuous()` stamps P3 color attachments on video pixel buffers via `CVBufferSetAttachment`, then appends to the continuous writer's video or audio input.

---

## RollingBuffer.swift

**Purpose**: Disk-backed circular buffer of HEVC video segments.

### `Segment` struct

```swift
struct Segment {
    let url: URL          // Path to .mov file
    let startTime: Date   // When segment started
    var endTime: Date     // When segment was finalized
    var isFinalized: Bool // Whether writing is complete
}
```

### `RollingBuffer` class

Marked `@unchecked Sendable` — thread safety is provided by the serial `queue`.

#### Segment Lifecycle

1. **`startNewSegment()`**: Creates AVAssetWriter → `.mov` file with HEVC video (40Mbps, no B-frames, P3 color properties) + AAC audio. Names segments with Unix timestamp in milliseconds for uniqueness.

2. **`appendVideoSample(_:)`**: Dispatches to serial queue. Ensures writer exists, rotates if 15s elapsed. Stamps P3 color attachments on pixel buffer. Checks `isReadyForMoreMediaData` — if false, increments drop counter and logs every 30th drop. Starts the writer session on the first frame's PTS.

3. **`rotateIfNeeded()`**: If 15 seconds since segment start → finalize + start new + cleanup old.

4. **`finalizeCurrentSegment()`**: Marks inputs finished, calls `finishWriting` synchronously (semaphore), adds to segments array if successful.

5. **`cleanupOldSegments()`**: Removes segments whose `endTime` is older than `maxDuration` from both the array and disk.

#### `takeSnapshot() -> [URL]`

The critical method for clip saving. Runs synchronously on the buffer's serial queue:
1. Finalizes the current in-progress segment (captures all frames up to now)
2. Starts a new segment (so capture continues without gap)
3. Returns URLs of all finalized segments

The caller receives a frozen snapshot of the buffer state at call time. The returned URLs remain valid because segments aren't cleaned up until they expire.

#### `exportClip(lastSeconds:to:completion:)`

Older code path (used by `ScreenRecorder.saveClip`). Finalizes, filters relevant segments by time, delegates to `ClipExporter`. The `saveClipAction` in AppDelegate now uses `takeSnapshot()` + `ClipExporter.export()` directly instead.

---

## ClipExporter.swift

**Purpose**: Composes segment files into a single MP4.

### `ExporterError` enum

Three cases: `noSegments`, `noTracks`, `exportFailed(String)`.

### `ClipExporter.export()` static async method

**Parameters**: segment URLs, duration, output URL, quality string.

**Process**:

1. **Segment selection**: Calculates how many 15s segments are needed for the requested duration, takes that many from the end of the array (plus 2 extra for safety margin).

2. **Composition building**: Creates `AVMutableComposition` with one video and one audio track. For each segment:
   - Opens as `AVURLAsset`
   - Loads the video track's `.timeRange` (not `.duration` — this is important because segment tracks may have non-zero start times due to absolute PTS from ScreenCaptureKit)
   - Inserts at `insertTime` in the composition
   - Advances `insertTime` by the segment's duration
   - Also inserts audio if present

3. **Trimming**: If total composition duration exceeds requested, removes excess from the beginning (`removeTimeRange` from zero).

4. **Export**: Uses `AVAssetExportSession` with quality-appropriate preset. Writes to temp file first, then moves to final location. This prevents partial files on failure.

Why `HEVCHighestQuality` instead of `Passthrough` for High quality: Passthrough preserves the original segment timing metadata, which can contain VFR (variable frame rate) artifacts from segment boundaries. Re-encoding normalizes timing across the composition.

---

## ClipPlayerWindowController.swift

**Purpose**: Built-in video player that opens after saving a clip.

Simple class managing a single `NSWindow` with an `AVPlayerView`. The `show(url:)` method:
1. Creates an `AVPlayer` with the URL
2. Creates the window lazily (1280×800, resizable, min 640×400)
3. Assigns the player to the `AVPlayerView`
4. Brings the window to front and auto-plays

Reuses the same window instance — each `show(url:)` replaces the player. Controls style is `.floating` (semi-transparent overlay controls).

---

## CustomClipWindowController.swift

**Purpose**: UI window for saving clips with custom parameters.

### Window Layout (420×270, floating)

```
┌──────────────────────────────────┐
│  Minutes:  [___] min             │
│  Seconds:  [___] sec             │
│  Clip Name: [________________]   │
│  Save to:  /path/to/...  Browse… │
│  Quality:  [High ▾]             │
│                                  │
│              [Cancel] [Save Clip] │
└──────────────────────────────────┘
```

### Key Behaviors

- **`showWindow(snapshotURLs:captureTimestamp:)`**: Called with pre-frozen snapshot URLs and timestamp. Pre-fills the name field with the timestamp. Resets minutes/seconds fields.

- **`saveAction()`**: Validates duration (> 0, ≤ 1800). If requested duration exceeds available buffer, shows a confirmation alert. Calls `onSave` callback with parameters.

- **`browseAction()`**: Opens `NSOpenPanel` for directory selection. Can create directories.

- **`onSave` callback**: Set by AppDelegate during `setupCustomClipWindow()`. Receives `(totalSeconds, clipName, saveFolder, quality)`. The callback accesses `snapshotURLs` from the controller and delegates to `ClipExporter`.

### Stored State

- `snapshotURLs: [URL]` — frozen segment URLs from hotkey press time
- `captureTimestamp: Date?` — when ⇧⌘2 was pressed
- `selectedFolder: URL` — defaults to `~/Movies/MetalClip/`
- `defaultQuality: String` — synced from AppDelegate's current quality

---

## Cross-Reference Map

```
AppDelegate
  ├── owns → ScreenRecorder
  │            ├── owns → RollingBuffer
  │            │            └── uses → ClipExporter (via exportClip)
  │            └── manages → continuous AVAssetWriter
  ├── owns → CustomClipWindowController
  │            └── callback uses → ClipExporter
  ├── owns → ClipPlayerWindowController
  ├── owns → HotKeyManager
  │            └── holds → HotKey structs
  ├── owns → RecordingIndicatorWindow
  └── directly uses → ClipExporter (via saveClipAction)
```
