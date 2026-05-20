# UI Inventory

Reference document for every UI element currently in MetalClip.

## 1. Menu Bar (Status Item)

**Icon**: SF Symbol `record.circle`, variable length, always visible in system tray.

**Menu items** (top to bottom). The entire menu is destroyed and rebuilt via `rebuildMenu()` on every state change.

| # | Item | Action | Dynamic | Notes |
|---|------|--------|---------|-------|
| 1 | `"MetalClip — Ready"` / `"● Recording in Progress..."` | none | Yes | Disabled, text changes with `isRecording` |
| — | separator | | | |
| 2 | `"Save Clip (Last 2m)"` | `saveClipAction()` | Yes | Duration text changes with `currentClipLength` |
| 3 | `"Save Custom Clip..."` | `saveCustomClipAction()` | No | |
| — | separator | | | |
| 4 | `"● Start Recording"` / `"■ Stop Recording"` | `toggleRecordingAction()` | Yes | Text changes with `isRecording` |
| — | separator | | | |
| 5 | **Clip Length** → submenu | | Yes | Checkmark on current selection |
| | `30s` | `setClipLengthAction(_:)` | | tag = 30 |
| | `1m` | `setClipLengthAction(_:)` | | tag = 60 |
| | `2m` | `setClipLengthAction(_:)` | | tag = 120 (default) |
| | `5m` | `setClipLengthAction(_:)` | | tag = 300 |
| | `10m` | `setClipLengthAction(_:)` | | tag = 600 |
| | `30m` | `setClipLengthAction(_:)` | | tag = 1800 |
| 6 | **Frame Rate** → submenu | | Yes | Checkmark on current selection |
| | `15 fps` | `setFPSAction(_:)` | | tag = 15 |
| | `30 fps` | `setFPSAction(_:)` | | tag = 30 |
| | `60 fps` | `setFPSAction(_:)` | | tag = 60 (default) |
| | `120 fps` | `setFPSAction(_:)` | | tag = 120 |
| 7 | **Quality** → submenu | | Yes | Checkmark on current selection |
| | `High` | `setQualityAction(_:)` | | representedObject = "High" (default) |
| | `Medium` | `setQualityAction(_:)` | | representedObject = "Medium" |
| | `Low` | `setQualityAction(_:)` | | representedObject = "Low" |
| 8 | `"Force Apply Settings"` | `toggleForceApplyAction()` | Yes | Checkmark when ON |
| 9 | **Microphone** → submenu | | Yes | Checkmark on current selection |
| | `Off` | `setMicrophoneAction(_:)` | | representedObject = "Off" (default) |
| | `MacBook Pro Microphone` | `setMicrophoneAction(_:)` | | representedObject (hardcoded name) |
| — | separator | | | |
| 10 | `"Open Clips Folder"` | `openClipsFolderAction()` | No | |
| 11 | `"Quit MetalClip"` | `NSApplication.terminate(_:)` | No | keyEquivalent = `"q"` |

**Note**: Only "Quit MetalClip" has a visible keyboard equivalent in the menu. Global hotkeys are registered separately via Carbon and are not displayed in the menu.

---

## 2. Windows

### CustomClipWindowController

| Property | Value |
|----------|-------|
| Class | `NSObject` (manages `NSWindow` directly) |
| Title | `"Save Custom Clip"` |
| Size | 420×270 |
| Resizable | No |
| Style | `.titled`, `.closable` |
| Level | `.floating` |
| Modal | No |
| Trigger | `⇧⌘2` hotkey or "Save Custom Clip..." menu item |

**Controls**:

| Control | Type | Details |
|---------|------|---------|
| Minutes | `NSTextField` + `NumberFormatter` | Range 0–30, placeholder "0" |
| min | `NSTextField` (label) | Unit label |
| Seconds | `NSTextField` + `NumberFormatter` | Range 0–59, placeholder "0" |
| sec | `NSTextField` (label) | Unit label |
| Clip Name | `NSTextField` | Placeholder "Auto-generated", pre-filled with `yyyy-MM-dd_HH-mm-ss` |
| Save to | `NSTextField` (label, read-only) | Path display, truncated middle, secondary color, 11pt |
| Browse... | `NSButton` (.rounded, small, 70px) | Opens `NSOpenPanel` (directories only) |
| Quality | `NSPopUpButton` (120px) | Items: High, Medium, Low |
| Cancel | `NSButton` (.rounded) | keyEquivalent = Escape |
| Save Clip | `NSButton` (.rounded) | keyEquivalent = Return |

### ClipPlayerWindowController

| Property | Value |
|----------|-------|
| Class | `NSObject` (manages `NSWindow` directly) |
| Title | Dynamic — clip filename (e.g., `"2026-05-19_22-04-30.mp4"`) |
| Size | 1280×800 default |
| Min size | 640×400 |
| Resizable | Yes |
| Style | `.titled`, `.closable`, `.resizable`, `.miniaturizable` |
| Level | Default (not floating) |
| Modal | No |
| Trigger | Automatically after any clip/recording save |

**Controls**:

| Control | Type | Details |
|---------|------|---------|
| Player | `AVPlayerView` | `.floating` controls style, fills window, auto-plays |

Reuses single window instance. Each `show(url:)` replaces the player content.

---

## 3. Custom Views / Controls

### RecordingIndicatorWindow

| Property | Value |
|----------|-------|
| Class | `NSWindow` subclass |
| Size | 12×12px |
| Position | Top-right of main screen (20px from right, 8px from top) |
| Appearance | Solid red circle (NSView with red backgroundColor, cornerRadius 6) |
| Style | `.borderless`, transparent, no shadow |
| Level | `.floating` |
| Sharing | `sharingType = .none` (excluded from screen capture) |
| Mouse | `ignoresMouseEvents = true` |
| Spaces | `[.canJoinAllSpaces, .stationary]` |
| Created | Lazily on first recording start |
| Shows | When continuous recording starts |
| Hides | When continuous recording stops |

No other custom `NSView` subclasses exist.

---

## 4. Hotkeys

All registered in `AppDelegate.setupHotKeys()` via `HotKeyManager` (Carbon API).

| Hotkey | Key Code | Modifiers | Action | Method |
|--------|----------|-----------|--------|--------|
| `⇧⌘1` | 18 | cmdKey \| shiftKey | Save quick clip | `saveClipAction()` |
| `⇧⌘2` | 19 | cmdKey \| shiftKey | Open custom clip window | `saveCustomClipAction()` |
| `⇧⌘R` | 15 | cmdKey \| shiftKey | Toggle continuous recording | `toggleRecordingAction()` |

Hotkeys work globally (when app is in background). Registered via Carbon `RegisterEventHotKey`.

---

## 5. User Feedback

### Console Logs

| Source | Message | When |
|--------|---------|------|
| RollingBuffer | `📝 New segment: seg_xxx.mov` | Every 15s segment rotation |
| RollingBuffer | `📼 Segment done: v=N a=N size=NKB status=N` | Segment finalized |
| RollingBuffer | `❌ Segment write failed: ...` | Writer status failed |
| RollingBuffer | `⚠️ Dropped N video frames (input not ready)` | Every 30th dropped frame |
| RollingBuffer | `⚠️ No segments available` | Export with empty buffer |
| RollingBuffer | `📦 Exporting N segments → file` | Export starts |
| RollingBuffer | `✅ Clip saved → file` | Export success |
| RollingBuffer | `❌ Export failed: ...` | Export failure |
| ScreenRecorder | `✅ Screen capture started (WxH @ Nfps)` | Capture begins |
| ScreenRecorder | `❌ Stream error: ...` | SCStream delegate error |
| ScreenRecorder | `⏺ Recording started → file` | Continuous recording starts |
| ScreenRecorder | `⏹ Recording saved → file` | Continuous recording stops |
| AppDelegate | `❌ Clip save failed: ...` | saveClipAction export error |
| AppDelegate | `❌ Recording failed: ...` | startContinuousRecording throws |
| AppDelegate | `❌ Restart failed: ...` | restartCapture error |

### Alerts (NSAlert)

| Title | Message | When | Style | Buttons |
|-------|---------|------|-------|---------|
| Screen Capture Failed | Error description + relaunch hint | `startCapture()` throws | `.warning` | OK |
| Save Failed | "No recorded content available." | Custom clip empty snapshot | `.warning` | OK |
| Save Failed | Error description | Custom clip export fails | `.warning` | OK |
| Invalid Duration | "Please enter a clip length greater than 0 seconds." | Custom clip duration ≤ 0 | `.warning` | OK |
| Duration Too Long | "Maximum clip length is 30 minutes." | Custom clip > 1800s | `.warning` | OK |
| Clip will be shorter | Available time description | Requested > available buffer | `.informational` | Save Anyway, Cancel |

### Status Bar Icon

- Always shows `record.circle` SF Symbol
- No visual change between idle and recording states
- No badge or color change

---

## 6. Persistence (UserDefaults)

### Registered Defaults

| Key | Default Value | Type | Used By |
|-----|---------------|------|---------|
| `"clipLength"` | `120` | Int | Quick-save duration |
| `"fps"` | `60` | Int | Frame rate setting |
| `"quality"` | `"High"` | String | Quality preset |
| `"forceApply"` | `false` | Bool | Capture-time vs export-time settings |
| `"microphone"` | `"Off"` | String | Mic selection (UI only, not wired) |

- **Loaded**: `applicationDidFinishLaunching` → `loadSettings()`
- **Saved**: On every individual setting change via `saveSettings()`
- **All five keys** are written on every save (not just the changed one)

---

## 7. File Outputs

### Output Directory

`~/Movies/MetalClip/` — created on demand via `clipsDirectory()`.

### File Types

| Type | Filename Pattern | Format | Trigger |
|------|-----------------|--------|---------|
| Quick clip | `yyyy-MM-dd_HH-mm-ss.mp4` | .mp4 | `⇧⌘1` |
| Custom clip | User name or `yyyy-MM-dd_HH-mm-ss.mp4` | .mp4 | `⇧⌘2` → Save |
| Recording | `Recording_yyyy-MM-dd_HH-mm-ss.mp4` | .mp4 | `⇧⌘R` stop |

Custom clips can be saved to any user-selected directory (defaults to `~/Movies/MetalClip/`).

### Temporary Files

| Location | Pattern | Cleaned Up |
|----------|---------|------------|
| `$TMPDIR/MetalClipBuffer/` | `seg_<unix_ms>.mov` | On app quit (`applicationWillTerminate`) |
| `$TMPDIR/` | `<UUID>.mp4` | After export moves to final location |
