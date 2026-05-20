# Known Issues

## Resolved

### QuickTime slow-motion scrub artifacts

**Symptom**: Exported clips played in QuickTime showed slow-motion sections, especially in the middle of clips at 120fps.

**Root cause**: Segment files from the rolling buffer had VFR (variable frame rate) timing due to ScreenCaptureKit's frame delivery. When composed and exported with `AVAssetExportPresetPassthrough`, the original timing metadata was preserved without normalization, causing QuickTime's player to misinterpret frame durations.

**Fix**: Changed High quality export preset from `Passthrough` to `HEVCHighestQuality`, which re-encodes and normalizes timing. Also disabled HEVC B-frames (`AVVideoAllowFrameReorderingKey: false`) to prevent DTS/PTS reordering.

**Workaround (before fix)**: The built-in clip player (AVKit) handled VFR correctly, so clips played fine there even before the export fix.

---

## Expected Behavior

### P3 colors appear slightly different from live screen

**Symptom**: Recorded video looks subtly "duller" than the live display, especially on XDR displays at high brightness.

**Explanation**: This is expected. The live screen on a P3-1600 XDR display can show a wider brightness range and color gamut than any SDR video format can encode. MetalClip captures in Display P3 color space with BT.709 transfer function (SDR gamma curve), which preserves the full P3 color gamut but clips the extended brightness range to SDR levels.

**Verification**: Color metadata is correctly embedded in both segment files and exported clips (confirmed via `CMFormatDescriptionGetExtensions`: primaries = P3_D65, transfer = ITU_R_709_2, matrix = ITU_R_709_2).

**Potential future improvement**: HDR10 capture (PQ transfer function + 10-bit HEVC) would preserve more of the XDR brightness range, at the cost of larger files and requiring HDR-capable players.

---

## Open Issues

### High CPU usage at 4K 120fps during intensive content

**Symptom**: CPU usage spikes during fast-moving content (gaming, video playback) when capturing at native resolution with 120fps.

**Cause**: HEVC hardware encoding at full retina resolution (e.g., 3024x1964 on 14" MacBook Pro) at 120fps pushes the media engine hard. The 40Mbps bitrate cap helps but encoding is still intensive.

**Mitigation**: Use "Force Apply" with lower FPS (60) or quality (Medium/Low) during gaming to reduce encoding load. When Force Apply is OFF, the app captures at 120fps regardless.

**Future**: Investigate adaptive frame rate (match capture FPS to display refresh rate) and hardware encoder occupancy monitoring.

### Microphone input not wired to capture

**Symptom**: The Microphone submenu in the menu bar shows "Off" and "MacBook Pro Microphone" options, but selecting a microphone has no effect on recordings.

**Cause**: The UI was implemented but the actual audio input capture is not connected. `ScreenCaptureKit`'s `capturesAudio = true` captures system audio only, not microphone input.

**Fix needed**: Add a separate `AVCaptureDevice` audio input for the microphone and mix it with the system audio track in the rolling buffer and continuous recording.

### Recording indicator position is fixed

**Symptom**: The red recording dot always appears in the top-right corner of the main display.

**Cause**: Position is hardcoded in `RecordingIndicatorWindow.init()` using `NSScreen.main?.frame`.

**Future**: Allow user to configure position, or move to a different indicator style (e.g., menu bar icon change).

### Menu bar icon doesn't reflect recording state

**Symptom**: The menu bar icon always shows `record.circle` regardless of whether continuous recording is active.

**Cause**: `setupMenuBar()` sets the icon once and never updates it. Only the menu text changes to reflect recording state.

**Future**: Switch to `record.circle.fill` (filled red) during recording, or use a template image with tinting.

### No error notification for clip save failures

**Symptom**: If a quick clip save (Shift+Cmd+1) fails, the error is only printed to console. No user-visible alert appears.

**Cause**: `saveClipAction()` catches the error with `print("Clip save failed:")` but doesn't show an `NSAlert`.

**Fix**: Add an alert in the error path, matching the custom clip window's behavior.

### Segment cleanup not triggered on app crash

**Symptom**: If the app crashes or is force-quit, segment files in `$TMPDIR/MetalClipBuffer/` are not cleaned up.

**Cause**: Cleanup only runs in `applicationWillTerminate`, which is not called on crashes.

**Mitigation**: macOS eventually cleans `$TMPDIR` on reboot. A startup cleanup of stale segment directories could be added.
