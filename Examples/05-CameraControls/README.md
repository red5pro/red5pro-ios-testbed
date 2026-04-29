# 05 — Camera Controls

Flip the camera and mute/unmute video and audio while a publish session is live.

**Documentation:** https://www.red5.net/docs/red5-cloud/development/sdks/ios-sdk/camera-controls/

## What This Example Covers

- `switchCamera()` — toggle between front and rear camera
- `setVideoEnabled(_:)` — mute/unmute the video track
- `setAudioEnabled(_:)` — mute/unmute the audio track
- All three controls work during an active live session without interrupting the stream

## Files

| File | Purpose |
|---|---|
| `Config.swift` | Server connection settings — edit before running |
| `CameraControlsExample.swift` | Manager, SwiftUI view, and `@main` app entry point |

## Setup

1. Open or create an Xcode project targeting iOS 16+.
2. Add `Red5WebRTCKit` via Swift Package Manager.
3. Add both files in this folder to the project.
4. Edit `Config.swift` with your server IP, app name, stream name, and license key.
5. Add `NSCameraUsageDescription` and `NSMicrophoneUsageDescription` to `Info.plist`.
6. Run on a physical device — camera switching requires two physical cameras.
