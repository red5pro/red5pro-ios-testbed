# 02 — Minimal Subscribe

The fewest lines of code needed to subscribe to a live stream with the Red5 Pro iOS SDK.

**Documentation:** https://www.red5.net/docs/red5-cloud/development/sdks/ios-sdk/minimal-subscribe/

## What This Example Covers

- Building a `Red5WebrtcClient` configured for subscribing
- Attaching a remote `RTCMTLVideoView` renderer for the incoming stream
- The subscribe lifecycle: `subscribe()` → `onSubscribeStarted`
- How subscribing differs from publishing (no preview step required)

## Files

| File | Purpose |
|---|---|
| `Config.swift` | Server connection settings — edit before running |
| `MinimalSubscribeExample.swift` | Manager, SwiftUI view, and `@main` app entry point |

## Setup

1. Open or create an Xcode project targeting iOS 16+.
2. Add `Red5WebRTCKit` via Swift Package Manager.
3. Add both files in this folder to the project.
4. Edit `Config.swift` with your server IP, app name, stream name, and license key.
5. Ensure a publisher is already streaming to the configured `streamName` before tapping Subscribe.
6. Run on a physical device or simulator (subscribe does not require a camera).
