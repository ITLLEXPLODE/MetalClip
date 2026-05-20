# Roadmap

## v0.1.0-beta (current)

The foundation. Everything needed for basic clip saving works.

### Done

- [x] Rolling buffer architecture (15s segments, up to 30min)
- [x] ScreenCaptureKit capture with P3 color space
- [x] HEVC hardware encoding (40Mbps, no B-frames)
- [x] Quick clip save (⇧⌘1) with configurable duration
- [x] Custom clip window (⇧⌘2) with duration, name, folder, quality
- [x] Continuous recording mode (⇧⌘R)
- [x] Built-in clip player (AVKit)
- [x] Menu bar app with settings submenus
- [x] Quality presets (High/Medium/Low)
- [x] FPS options (15/30/60/120)
- [x] Force Apply toggle (capture-time vs export-time settings)
- [x] UserDefaults persistence
- [x] Recording indicator (red dot, excluded from capture)
- [x] P3 color metadata on pixel buffers (CVBufferSetAttachment)
- [x] VFR normalization via HEVCHighestQuality export

---

## v0.2.0 — Performance and Polish

Focus: reduce resource usage, improve export quality.

- [ ] Adaptive frame rate (match capture to display refresh, drop during idle)
- [ ] Hardware encoder occupancy monitoring
- [ ] Export progress indicator (progress bar or percentage)
- [ ] Notification sound or system notification on clip save
- [ ] Menu bar icon state change during recording (filled vs outline)
- [ ] Error alerts for quick clip save failures (currently console-only)
- [ ] Startup cleanup of stale segment directories from crashes

---

## v0.3.0 — Preferences Window and Hotkey Customization

Focus: proper settings UI, user-configurable hotkeys.

- [ ] Native preferences window (NSWindow or SwiftUI)
- [ ] All settings from menu bar moved to preferences
- [ ] Custom hotkey binding UI (record key combos)
- [ ] Launch at login toggle
- [ ] Default save directory preference
- [ ] Segment duration preference (currently hardcoded 15s)
- [ ] Buffer duration preference (currently hardcoded 30min)
- [ ] About window with version info

---

## v0.4.0 — Clip Library

Focus: browse and manage saved clips without leaving the app.

- [ ] Clip library sidebar or window
- [ ] Thumbnail generation for saved clips
- [ ] Clip metadata display (duration, resolution, file size, date)
- [ ] Delete clips from library
- [ ] Rename clips
- [ ] Open in Finder from library
- [ ] Sort/filter by date, duration, size

---

## v0.5.0 — Microphone Capture

Focus: add microphone input for commentary/voice.

- [ ] AVCaptureDevice microphone input
- [ ] Mix microphone audio with system audio
- [ ] Per-source volume control (system vs mic)
- [ ] Microphone selection from available devices (not hardcoded)
- [ ] Audio level meter in menu bar or preferences
- [ ] Push-to-talk option

---

## v1.0.0 — Release Candidate

Criteria for 1.0:

- [ ] All v0.2–v0.5 features complete and stable
- [ ] No known data-loss bugs
- [ ] CPU usage < 10% idle, < 25% during 4K 120fps capture
- [ ] Memory usage < 100MB RSS (segments are on disk)
- [ ] Passes 24-hour soak test without crashes or memory leaks
- [ ] Code signing and notarization
- [ ] DMG installer with drag-to-Applications
- [ ] App icon designed
- [ ] First-launch onboarding (permission request, quick tutorial)

---

## Future Ideas

Not committed, exploring feasibility.

- **HDR10 capture**: PQ transfer function + 10-bit HEVC for XDR displays
- **Clip trimming**: In-app trim editor before saving
- **Instant GIF**: Export selection as animated GIF
- **Discord/Slack upload**: Share clips directly from player
- **Game detection**: Auto-adjust quality when specific games are running
- **Multi-display**: Capture specific display or region
- **Window capture**: Capture a single window instead of full screen
- **Webcam overlay**: PiP webcam feed composited into recording
- **Cloud backup**: Optional sync to iCloud Drive or custom cloud
- **CLI tool**: `metalclip save --last 60s` for scripting
