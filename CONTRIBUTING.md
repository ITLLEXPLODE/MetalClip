# Contributing

## Build from Source

```bash
git clone https://github.com/ITLLEXPLODE/MetalClip.git
cd MetalClip
open MetalClip.xcodeproj
```

Select the MetalClip scheme and run (Cmd+R). Grant Screen Recording permission when prompted.

**Requirements:**
- Xcode 15+
- macOS 13.0+ SDK
- Apple Silicon recommended (Intel works but HEVC encoding is slower)

## Code Style

- Swift conventions: PascalCase for types, camelCase for properties/methods
- 4-space indentation
- `let` over `var` when possible
- Comments in Korean are fine — this project started in Korean
- No SwiftUI (yet) — UI is AppKit/programmatic
- Prefer `async/await` over Combine
- No third-party dependencies

## Project Structure

See [CODE_GUIDE.md](CODE_GUIDE.md) for a file-by-file walkthrough and [ARCHITECTURE.md](ARCHITECTURE.md) for the data flow.

## Submitting Issues

Open an issue on GitHub with:
- macOS version and Mac model
- Steps to reproduce
- Expected vs actual behavior
- Console output if relevant (filter by `MetalClip` in Console.app)

## Pull Requests

1. Fork the repo
2. Create a feature branch (`git checkout -b feature/my-change`)
3. Make your changes
4. Test manually — build, run, save a clip, verify playback
5. Push and open a PR against `main`

Keep PRs focused. One feature or fix per PR. If a refactor is needed, submit it separately.

## Architecture Decisions

If your change affects the data flow (capture → buffer → export → playback), read [ARCHITECTURE.md](ARCHITECTURE.md) first. The rolling buffer's segment-based design is intentional — don't try to replace it with a single-file approach.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
