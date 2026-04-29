# 03 — Audio Only

Publish or subscribe to a live stream with video disabled — audio only.

**Documentation:** https://www.red5.net/docs/red5-cloud/development/sdks/ios-sdk/audio-only/

## What This Example Covers

- Using `.setVideoEnabled(false)` to disable the video track
- That no `RTCMTLVideoView` renderer is needed for audio-only sessions
- That camera permission is **not** required when video is disabled
- Switching between publish and subscribe roles with a single shared manager

## Files

| File | Purpose |
|---|---|
| `Config.swift` | Server connection settings — edit before running |
| `AudioOnlyExample.swift` | Manager, SwiftUI view, and `@main` app entry point |

## Setup

1. Open or create an Xcode project targeting iOS 16+.
2. Add `Red5WebRTCKit` via Swift Package Manager.
3. Add both files in this folder to the project.
4. Edit `Config.swift` with your server IP, app name, stream name, and license key.
5. Add `NSMicrophoneUsageDescription` to `Info.plist` (camera permission not required).
6. Run on a physical device or simulator.
