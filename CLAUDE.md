# VideoSlicer iOS App — CLAUDE.md

## Project Overview
A SwiftUI/AVFoundation iOS app that slices videos into timed segments with configurable resolution and quality.

- **Target**: iOS 16.0+, Swift 5.9+, Xcode 15+
- **Language**: Swift 6.3+
- **UI Framework**: SwiftUI
- **Video Processing**: AVFoundation
- **Dependencies**: CocoaPods (Kingfisher, Quick, Nimble)

---

## Project Setup (New Machine / New Developer)

### Prerequisites
```bash
brew install xcodegen
brew install cocoapods
```

### First-Time Setup
```bash
cd /Users/ehsan/Documents/video-slicer-ios
xcodegen generate           # generates VideoSlicer.xcodeproj
pod install                 # installs Kingfisher, Quick, Nimble
open VideoSlicer.xcworkspace  # ALWAYS open .xcworkspace, never .xcodeproj
```

### After Editing project.yml
```bash
xcodegen generate
# Then re-open VideoSlicer.xcworkspace
```

---

## Architecture Rules (MUST NOT Violate)

### MVVM Strict Layer Separation
```
View → ViewModel → Service Protocol → Service Implementation
```

| Layer | Rules |
|-------|-------|
| **Views** | ONLY read `@Published` properties and call ViewModel methods. No business logic, no service calls. |
| **ViewModels** | NO `import SwiftUI`. Allowed: `Foundation`, `Combine`, `UIKit` (UIImage, UIViewController only). No concrete service types. |
| **Services** | NOT `@MainActor`. Do background AVFoundation work. Return from any thread. |
| **AppContainer** | ONLY place that instantiates concrete service types. Injects via protocol types. |

### Concurrency Rules
- ViewModels: `@MainActor`
- AppContainer: `@MainActor`
- Services: no `@MainActor` — they do background work
- Use `async/await` throughout. No `DispatchQueue` unless forced by legacy AVFoundation callbacks.
- `AsyncStream<SlicingProgress>` for streaming slicing progress.

---

## Constants Rule

**ALL magic values go in `AppConstants.swift`.**

No string literals, sizes, timeouts, or directory names outside `AppConstants.swift`. Every enum/value must have a comment explaining its purpose.

---

## File Organization Rules

### Adding a New Service
1. Add Protocol to `VideoSlicer/Protocols/`
2. Add implementation to `VideoSlicer/Services/`
3. Add Mock to `VideoSlicerTests/Mocks/`
4. Register concrete type in `AppContainer.swift`
5. Inject via Protocol in ViewModel `init`

### Adding a New View Component
1. Place in correct subdirectory (`Views/Main/` or `Views/Output/`)
2. Accept dependencies via `let` properties (not `@StateObject`)
3. Use `@Binding` or closures for upward communication (no `@Environment` shortcuts)

---

## Build & Test Commands

```bash
# Regenerate project after editing project.yml
xcodegen generate

# Install/update pods
pod install

# Type-check source files (without simulator — useful when simulator is unavailable)
# See build_typecheck.sh for the full command

# Build (requires running simulator or physical device)
xcodebuild -workspace VideoSlicer.xcworkspace \
           -scheme VideoSlicer \
           -destination 'platform=iOS Simulator,name=iPhone 17' \
           build

# Run unit tests only
xcodebuild -workspace VideoSlicer.xcworkspace \
           -scheme VideoSlicer \
           -destination 'platform=iOS Simulator,name=iPhone 17' \
           test -only-testing:VideoSlicerTests

# Run UI tests only
xcodebuild -workspace VideoSlicer.xcworkspace \
           -scheme VideoSlicer \
           -destination 'platform=iOS Simulator,name=iPhone 17' \
           test -only-testing:VideoSlicerUITests
```

---

## Quality Gates (Must Pass Before Every Commit)

- [ ] **No ViewModel imports SwiftUI** — grep for `import SwiftUI` in `ViewModels/` directory → must be empty
- [ ] **No concrete service types outside AppContainer** — grep for `VideoSlicerService()`, `VideoExportService()`, `GalleryService()`, `VideoThumbnailService()` outside `AppContainer.swift` → must be empty
- [ ] **All new services have a Protocol** — every `*Service.swift` has a matching `*ServiceProtocol.swift`
- [ ] **All new services have a Mock** — every `*Service.swift` has a matching `Mock*Service.swift` in tests
- [ ] **No magic values outside AppConstants** — no raw strings for paths, durations, sizes
- [ ] **No force unwraps (`!`) in production code** — allowed only in test fixtures
- [ ] **All unit tests pass** — `VideoSlicerTests` scheme: 0 failures
- [ ] **Integration test passes with real AVFoundation** — `SlicingIntegrationTests` passes

---

## Dependency Decisions

| Dependency | Version | Purpose |
|-----------|---------|---------|
| Kingfisher | ~7.0 | Video thumbnail disk/memory caching |
| Quick | ~7.0 | BDD test spec structure |
| Nimble | ~13.0 | Expressive matchers (beCloseTo, haveCount, etc.) |

---

## AVFoundation Key Notes

- Use `AVAssetExportSession` for time-range slicing (not `AVAssetWriter`)
- Native presets available:
  - `AVAssetExportPreset1920x1080` → 1080p
  - `AVAssetExportPreset1280x720` → 720p
  - `AVAssetExportPresetMediumQuality` → 480p
- All three resolutions use native AVFoundation presets — no custom `AVVideoComposition` needed
- `PHPickerViewController` on iOS 16+ requires no permissions (limited library model)
- Background export for large videos: register `BGProcessingTask` with `com.ehsan.VideoSlicer.export`

---

## UI Test Strategy for PHPickerViewController

`PHPickerViewController` is a system UI that cannot be tapped by XCUITest. Use the **launch argument injection** pattern:

1. Pass `-UITestVideoURL <path>` as launch argument
2. `MainViewModel.init()` detects this via `ProcessInfo.processInfo.arguments`
3. Auto-loads the video at that path as the selected asset
4. Tests can then interact with the rest of the UI normally

---

## Common Pitfalls

| Issue | Root Cause | Fix |
|-------|-----------|-----|
| `AnyShapeStyle(.accentColor)` type error | `.accentColor` is `Color`, not `ShapeStyle` | Use `Color.accentColor` |
| `ContentUnavailableView` not found | Requires iOS 17+ | Use a manual VStack fallback for iOS 16 |
| `AVURLAsset` not found in ViewModel | Missing `import AVFoundation` | Add import |
| Simulator not found | CoreSimulator version mismatch | Boot simulator explicitly with `xcrun simctl boot <UDID>` |

---

## Resolution Options

The app supports three output resolutions, all with native AVFoundation presets:

| Label | Resolution | AVFoundation Preset |
|-------|-----------|-------------------|
| 1080p | 1920×1080 | `AVAssetExportPreset1920x1080` |
| 720p | 1280×720 | `AVAssetExportPreset1280x720` |
| 480p | 854×480 | `AVAssetExportPresetMediumQuality` |
