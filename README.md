# Red5 Pro iOS Testbed

This repo contains:

- **SampleApp** — a SwiftUI app demonstrating Loopback, Publish, and Subscribe with a bitrate selector and basic stats (↑/↓ kbps, res, fps, RTT, jitter).

## Quick start

1. **Generate the Xcode project**

   ```bash
   ./bootstrap.sh
   cd SampleApp
   xcodegen generate
   open SampleApp.xcodeproj

2. **Dependencies**

The project uses the prebuilt WebRTC.xcframework via SPM:
    •   Package: https://github.com/stasel/WebRTC (declared in project.yml)
If you prefer your own build, remove the package and add your WebRTC.xcframework to the app target.

3.  **iOS permissions**

Info.plist already includes:
    •   NSCameraUsageDescription
    •   NSMicrophoneUsageDescription

4.  **Run**
    •   Select a physical iPhone (recommended).
    •   Build & Run.
    •   Choose Loopback, or fill Stream Manager fields and use Publish / Subscribe.
    •   Switch Signaling between Proxy (WebSocket) and WHIP/WHEP (HTTP).
    •   Pick a Bitrate preset (e.g., VP8 720p @ 1.5 Mbps).

## Stream Manager notes

   Proxy WS URL is built as:

   ```bash
    wss://<sm-host>/as/v1/proxy/ws/(publish|subscribe)/<app>/<stream>?id=<uuid>&nodeGroup=<group>
   ```
    
   The SDK constructs this for you; just set Base URL, App, Stream, and Node Group.

   For WHIP/WHEP, supply full endpoints, e.g.:

   ```bash
    https://<sm-host>/as/v1/whip/<app>/<stream>
    https://<sm-host>/as/v1/whep/<app>/<stream>
   ```
 (Auth headers supported via the “Authorization" field.)

   Add TURN if needed (turn: or turns:) with username/credential.


## SDK surface
    •   WebRTCClient — camera/mic capture, offer/answer helpers, ICE, stats callbacks.
    •   BitrateController / VideoEncodingPreset — codec preference (VP8/H264), resolution/FPS, max/min bitrate.
    •   Red5ProxySignaling — WebSocket signaling to Stream Manager Proxy.
    •   WhipClient / WhepClient — HTTP-based publish/subscribe with POST + PATCH trickle.
    •   WebRTCStatsSnapshot — iceConnection, outboundKbps, inboundKbps, width, height, fps, rttMs, jitterMs.

## Customization ideas
    •   Add simulcast (multiple encodings) with different scaleResolutionDownBy.
    •   Integrate ReplayKit for screen share.
    •   Expose CallKit for VoIP UX.
    •   Persist settings in UserDefaults.

## Troubleshooting
    •   If Xcode can't resolve packages after xcodegen generate, hit File → Packages → Reset Package Caches.
    •   Ensure your Stream Manager uses valid HTTPS/WSS (ATS blocks self-signed certs).
    •   On first run, allow Camera + Mic permissions.

⸻
