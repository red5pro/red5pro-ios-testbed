# 01 — Minimal Publish

The fewest lines of code needed to publish a live stream with the Red5 Pro iOS SDK.

**Documentation:** https://www.red5.net/docs/red5-cloud/development/sdks/ios-sdk/minimal-publish/

## What This Example Covers

- Building a `Red5WebrtcClient` with `Red5WebrtcClientBuilder`
- Attaching a local `RTCMTLVideoView` renderer
- The correct publish lifecycle: `startPreview()` → `onPreviewStarted` → `publish()`
- Handling the essential delegate callbacks

## Files

| File | Purpose |
|---|---|
| `Config.swift` | Server connection settings — edit before running |
| `MinimalPublishExample.swift` | Manager, SwiftUI view, and `@main` app entry point |

## Setup

1. Open or create an Xcode project targeting iOS 16+.
2. Add `Red5WebRTCKit` via Swift Package Manager.
3. Add both files in this folder to the project.
4. Edit `Config.swift` with your server IP, app name, stream name, and license key.
5. Add `NSCameraUsageDescription` and `NSMicrophoneUsageDescription` to `Info.plist`.
6. Run on a physical device (camera is not available in the simulator).
