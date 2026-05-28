# VideoSlicer

A SwiftUI/AVFoundation iOS app that slices a video into evenly-timed segments at a chosen resolution and quality. Pick a video from your photo library, set a maximum slice duration, and the app produces a series of clips you can preview, share, or save.

## Features

- Pick videos from the photo library via `PHPickerViewController` (no permission prompt on iOS 16+).
- Slices `PHImageManager`-served `AVAsset`s directly — no input copy into the app sandbox.
- iCloud download progress surfaced while fetching cloud-only videos.
- Slice a video into fixed-duration segments (5s–600s; presets at 15/30/60/90/120/300s).
- Choose output resolution: **1080p**, **720p**, or **480p** (native `AVAssetExportSession` presets).
- Choose output quality: **Low**, **Medium**, **High**.
- Live per-segment progress via `AsyncThrowingStream<SlicingProgress>`.
- Browse, share, and delete previously sliced videos.
- Disk + memory thumbnail caching via Kingfisher.

Defaults: **480p**, **Low** quality, **90s** max slice duration (configured in `AppConstants.Defaults`).

## Requirements

| | |
|---|---|
| iOS | 16.0+ |
| Swift | 5.9+ |
| Xcode | 15+ |
| Build tools | [XcodeGen](https://github.com/yonoz/XcodeGen), [CocoaPods](https://cocoapods.org) |

## Getting Started

```bash
brew install xcodegen cocoapods

cd <repo-root>
xcodegen generate          # creates VideoSlicer.xcodeproj from project.yml
pod install                # installs Kingfisher, Quick, Nimble
open VideoSlicer.xcworkspace
```

> Always open `VideoSlicer.xcworkspace` — never `VideoSlicer.xcodeproj`.

After editing `project.yml`, re-run `xcodegen generate` and re-open the workspace.

### Signing

Simulator builds skip code signing (no Apple Developer account required). Device builds use automatic signing — set `DEVELOPMENT_TEAM` in `project.yml` to your team ID (Xcode → Settings → Accounts → Manage Certificates, or developer.apple.com → Membership) and re-run `xcodegen generate`.

## Build & Test

```bash
# Build
xcodebuild -workspace VideoSlicer.xcworkspace \
           -scheme VideoSlicer \
           -destination 'platform=iOS Simulator,name=iPhone 17' \
           build

# Unit tests
xcodebuild -workspace VideoSlicer.xcworkspace \
           -scheme VideoSlicer \
           -destination 'platform=iOS Simulator,name=iPhone 17' \
           test -only-testing:VideoSlicerTests

# UI tests
xcodebuild -workspace VideoSlicer.xcworkspace \
           -scheme VideoSlicer \
           -destination 'platform=iOS Simulator,name=iPhone 17' \
           test -only-testing:VideoSlicerUITests
```

## Architecture

Strict MVVM with protocol-based dependency injection:

```
View  ──▶  ViewModel  ──▶  ServiceProtocol  ──▶  Service
                                                    │
                                          AVFoundation / PhotoKit
```

| Layer | Rules |
|-------|-------|
| **Views** (`Views/`) | Read `@Published` state and call ViewModel methods. No business logic. |
| **ViewModels** (`ViewModels/`) | `@MainActor`. No `import SwiftUI`. Depend only on service protocols. |
| **Services** (`Services/`) | Background work, not `@MainActor`. Pure `async/await`; no Combine. |
| **AppContainer** | The only place concrete services are instantiated. |

All magic values live in `AppConstants.swift` — no raw paths, sizes, or durations elsewhere.

## Project Layout

```
VideoSlicer/
├── App/                  AppContainer, VideoSlicerApp
├── Constants/            AppConstants
├── Models/               VideoAsset, SliceSettings, VideoResolution, VideoQuality, …
├── Protocols/            *ServiceProtocol definitions
├── Services/             VideoSlicerService, VideoExportService, GalleryService, VideoThumbnailService
├── ViewModels/           MainViewModel, OutputViewModel
├── Views/Main/           Picker, settings, action button
├── Views/Output/         Output list, group sections, share sheet
└── Resources/            Assets.xcassets, Info.plist

VideoSlicerTests/         Unit + integration tests (Quick / Nimble)
VideoSlicerUITests/       XCUITest UI tests
```

## Resolution Map

| Label | Pixels | AVFoundation Preset |
|-------|--------|---------------------|
| 1080p | 1920×1080 | `AVAssetExportPreset1920x1080` |
| 720p | 1280×720 | `AVAssetExportPreset1280x720` |
| 480p | 854×480 | `AVAssetExportPresetMediumQuality` |

> **Quality caveat:** `AVAssetExportSession` does not accept custom bitrates, so `medium` and `high` at the same resolution currently map to the same preset. `VideoQuality.targetBitrate` is retained for a future `AVAssetWriter`-based pipeline. See `VideoExportService.exportPreset(for:quality:)`.

## Dependencies

| Pod | Version | Purpose |
|-----|---------|---------|
| [Kingfisher](https://github.com/onevcat/Kingfisher) | `~> 7.0` | Thumbnail disk/memory caching |
| [Quick](https://github.com/Quick/Quick) | `~> 7.0` | BDD test spec structure |
| [Nimble](https://github.com/Quick/Nimble) | `~> 13.0` | Expressive matchers |

## UI Testing Notes

`PHPickerViewController` is system UI and cannot be driven by XCUITest. Tests inject a video via launch arguments:

```
-UITestVideoURL <path-to-video>
```

`MainViewModel.init()` detects this argument and loads the video automatically, letting tests exercise the rest of the flow.

## Quality Gates

Before every commit:

- No `import SwiftUI` in `ViewModels/`
- No concrete service constructors outside `AppContainer.swift`
- Every service has a `Protocol` and a `Mock`
- No magic values outside `AppConstants.swift`
- No force-unwraps (`!`) in production code
- All unit and integration tests pass

See `CLAUDE.md` for the full set of project conventions.
