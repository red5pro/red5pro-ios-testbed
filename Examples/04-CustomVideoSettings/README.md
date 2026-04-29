# 04 — Custom Video Settings

Configure video resolution, frame rate, and bitrate before starting a publish session.

**Documentation:** https://www.red5.net/docs/red5-cloud/development/sdks/ios-sdk/custom-video-settings/

## What This Example Covers

- `setVideoWidth` / `setVideoHeight` — capture resolution
- `setVideoFps` — target frame rate
- `setVideoBitrate` — target bitrate in kbps
- A preset picker UI to select common quality profiles before publishing

## Presets

| Label | Resolution | FPS | Bitrate |
|---|---|---|---|
| 360p | 640 × 360 | 30 | 400 kbps |
| 480p | 854 × 480 | 30 | 750 kbps |
| 720p | 1280 × 720 | 30 | 1500 kbps |
| 720p 60fps | 1280 × 720 | 60 | 2500 kbps |
| 1080p | 1920 × 1080 | 30 | 3000 kbps |

## Files

| File | Purpose |
|---|---|
| `Config.swift` | Server connection settings — edit before running |
| `CustomVideoSettingsExample.swift` | Manager, SwiftUI view, and `@main` app entry point |

## Setup

1. Open or create an Xcode project targeting iOS 16+.
2. Add `Red5WebRTCKit` via Swift Package Manager.
3. Add both files in this folder to the project.
4. Edit `Config.swift` with your server IP, app name, stream name, and license key.
5. Add `NSCameraUsageDescription` and `NSMicrophoneUsageDescription` to `Info.plist`.
6. Run on a physical device (camera required for publish).
