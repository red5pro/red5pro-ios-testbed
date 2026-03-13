# Red5 iOS WebRTC SDK Testbed

## Introduction

The Red5 iOS WebRTC SDK Testbed is a comprehensive example application that demonstrates the capabilities of the Red5 iOS WebRTC SDK. This testbed provides working examples of publishing and subscribing to streams on both Red5 Cloud (Stream Manager) and standalone Red5Pro servers.

## Table of Contents

1. [Introduction](#introduction)
2. [Features](#features)
3. [Requirements](#requirements)
4. [Installation](#installation)
5. [Configuration](#configuration)
6. [Usage](#usage)
   - 6.1 [Settings Screen](#settings-screen)
   - 6.2 [Publishing Examples](#publishing-examples)
   - 6.3 [Subscribing Examples](#subscribing-examples)
7. [Testing](#testing)
8. [Troubleshooting](#troubleshooting)

## Features

The testbed includes the following features:

- **Stream Manager Publishing**: Publish streams to Red5 Cloud using Stream Manager
- **Standalone Publishing**: Publish streams to standalone Red5Pro servers
- **Stream Manager Subscribing**: Subscribe to streams from Red5 Cloud
- **Standalone Subscribing**: Subscribe to streams from standalone Red5Pro servers
- **Settings Management**: Persistent settings for stream configuration
- **Camera Controls**: Switch between front and back cameras
- **Audio/Video Controls**: Mute/unmute microphone and enable/disable camera
- **SwiftUI Interface**: Modern SwiftUI-based user interface
- **Real-time Status Updates**: Live connection status and event notifications

## Requirements

- iOS 13.0 or later
- Xcode 14.0 or later
- Swift 5.5 or later
- Red5Pro SDK license key
- Red5Pro server (Cloud or standalone)

## Installation

1. Clone the repository:
```bash
git clone https://github.com/red5pro/red5pro-ios-testbed.git
cd red5pro-ios-testbed
```

2. Open the project in Xcode:
```bash
open SampleApp.xcodeproj
```

3. Install dependencies (if using CocoaPods):
```bash
pod install
open SampleApp.xcworkspace
```

4. Add the Red5 iOS WebRTC SDK framework to the project:
   - Drag and drop the Red5WebRTCKit framework into your project
   - Ensure it's added to "Frameworks, Libraries, and Embedded Content"

5. Configure your Info.plist with the required permissions:
```xml
<key>NSCameraUsageDescription</key>
<string>This app needs camera access to stream video</string>
<key>NSMicrophoneUsageDescription</key>
<string>This app needs microphone access to stream audio</string>
```

6. Build and run the project on a physical device (camera functionality requires a real device).

## Configuration

The testbed uses a settings manager to store and retrieve configuration values. All settings are persisted using UserDefaults.

### Settings Manager

The `SettingsManager` class handles all configuration:

```swift
class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    // Configuration properties
    @Published var streamManagerHost: String
    @Published var standaloneServerIp: String
    @Published var appName: String
    @Published var nodeGroup: String
    @Published var streamName: String
    @Published var userName: String
    @Published var password: String
    @Published var dtlsSetup: DTLSSetup
}
```

### Configuration Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `streamManagerHost` | Stream Manager host for Red5 Cloud | Empty |
| `standaloneServerIp` | IP address for standalone server | Empty |
| `appName` | Application name on Red5 server | "live" |
| `nodeGroup` | Node group for Stream Manager | "default" |
| `streamName` | Name of the stream to publish/subscribe | "myStream" |
| `userName` | Username for authentication (if enabled) | Empty |
| `password` | Password for authentication (if enabled) | Empty |
| `dtlsSetup` | DTLS setup mode (actpass/active/passive) | "actpass" |

### Getting Configuration Values

The SettingsManager provides static getter methods:

```swift
let streamManagerHost = SettingsManager.getStreamManagerHost()
let appName = SettingsManager.getAppName()
let streamName = SettingsManager.getStreamName()
let userName = SettingsManager.getUserName()
let password = SettingsManager.getPassword()
```

## Usage

### Settings Screen

1. Launch the app
2. Navigate to the Settings screen
3. Configure your connection parameters:
   - **For Red5 Cloud**: Enter your Stream Manager host (e.g., `userid-755-2ccfa36e4c.cloud.red5.net`)
   - **For Standalone**: Enter your server IP address (e.g., `192.168.1.100`)
   - Set the app name (default: "live")
   - Set the stream name
   - Enter credentials if authentication is enabled
   - Select DTLS setup mode
4. Tap "Save Settings" to persist your configuration

### Publishing Examples

#### Cloud Publishing (Stream Manager)

1. Configure Stream Manager settings in the Settings screen
2. Navigate to "Stream Manager Publish" or "Cloud Publish"
3. Grant camera and microphone permissions when prompted
4. The preview will start automatically after license validation
5. Tap "Start Publish" to begin streaming
6. Use controls to:
   - Mute/unmute microphone
   - Enable/disable camera
   - Switch between front and back cameras
7. Tap "Stop Publish" to end the stream

#### Standalone Publishing

1. Configure standalone server IP in the Settings screen
2. Navigate to "Standalone Publish"
3. Grant camera and microphone permissions when prompted
4. The preview will start automatically after license validation
5. Tap "Start Publish" to begin streaming
6. Use the same controls as Cloud Publishing
7. Tap "Stop Publish" to end the stream

### Subscribing Examples

#### Cloud Subscribing (Stream Manager)

1. Ensure a stream is already publishing with the configured stream name
2. Configure Stream Manager settings in the Settings screen
3. Navigate to "Stream Manager Subscribe" or "Cloud Subscribe"
4. Tap "Start Subscribe" to begin playback
5. The remote stream will display once connected
6. Tap "Stop Subscribe" to end playback

#### Standalone Subscribing

1. Ensure a stream is already publishing with the configured stream name
2. Configure standalone server IP in the Settings screen
3. Navigate to "Standalone Subscribe"
4. Tap "Start Subscribe" to begin playback
5. The remote stream will display once connected
6. Tap "Stop Subscribe" to end playback

### Key Components

#### WebRTCPreviewView

A SwiftUI wrapper for the WebRTC video renderer:

```swift
struct WebRTCPreviewView: UIViewRepresentable {
    let renderer: RTCMTLVideoView
    
    func makeUIView(context: Context) -> RTCMTLVideoView {
        renderer.contentMode = .scaleAspectFill
        renderer.videoContentMode = .scaleAspectFill
        return renderer
    }
    
    func updateUIView(_ uiView: RTCMTLVideoView, context: Context) {
        // No updates needed - WebRTC handles everything
    }
}
```

#### PublishManager

Handles all publishing operations:

```swift
class PublishManager: NSObject, ObservableObject {
    private var webrtcClient: Red5WebrtcClient?
    @Published var localVideoRenderer: RTCMTLVideoView?
    @Published var isReady: Bool = false
    
    func setup() { /* ... */ }
    func startPreview() { /* ... */ }
    func startPublish() { /* ... */ }
    func stopPublish() { /* ... */ }
    func toggleCamera() { /* ... */ }
    func toggleAudio() { /* ... */ }
    func switchCamera() { /* ... */ }
}
```

#### SettingsManager

Manages persistent configuration:

```swift
class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    // Published properties for two-way binding
    @Published var streamManagerHost: String
    @Published var standaloneServerIp: String
    @Published var appName: String
    // ... more properties
    
    func saveSettings() { /* ... */ }
}
```

## Testing

### Testing Publishing

1. Configure your server settings (Cloud or Standalone)
2. Navigate to the appropriate publish screen
3. Start publishing
4. Verify the stream appears in your Red5Pro server console
5. Use another device or web browser to subscribe and verify the stream

### Testing Subscribing

1. Start a stream from another device or the Red5Pro web example
2. Configure the testbed with the same server and stream name
3. Navigate to the appropriate subscribe screen
4. Start subscribing
5. Verify the stream plays correctly

### Testing Controls

- **Camera Switch**: Verify switching between front and back cameras
- **Mute/Unmute**: Verify audio muting and unmuting
- **Camera Toggle**: Verify enabling and disabling video
- **Connection States**: Verify proper handling of connection, disconnection, and errors

## Troubleshooting

### Camera/Microphone Permissions

**Issue**: Camera or microphone not working

**Solution**:
1. Check that permissions are granted in Settings > Privacy > Camera/Microphone
2. Verify Info.plist contains the usage descriptions
3. Restart the app after granting permissions

### Connection Issues

**Issue**: Unable to connect to server

**Solution**:
1. Verify Stream Manager host or server IP is correct
2. Check that port 443 (HTTPS) or 5080 (HTTP) is accessible
3. Ensure firewall settings allow WebRTC connections
4. Verify authentication credentials if auth is enabled
5. Check server logs for connection attempts

### License Validation Failed

**Issue**: License check failed message

**Solution**:
1. Verify you have a valid Red5Pro SDK license key
2. Ensure the license key is properly configured in the SDK
3. Check that your license is not expired
4. Contact Red5Pro support for license issues

### Preview Not Starting

**Issue**: Camera preview doesn't appear

**Solution**:
1. Verify camera permissions are granted
2. Check that another app isn't using the camera
3. Ensure the video renderer is properly initialized
4. Check the console logs for error messages

### Stream Not Found

**Issue**: Subscriber can't find the stream

**Solution**:
1. Verify the stream name matches exactly
2. Ensure the publisher is actively streaming
3. Check that both publisher and subscriber use the same server/app name
4. Verify the stream appears in the server console

### Poor Video Quality

**Issue**: Low quality or choppy video

**Solution**:
1. Check network connectivity and bandwidth
2. Adjust video bitrate in the configuration
3. Lower video resolution if needed
4. Ensure the device has sufficient processing power

## Advanced Features

### Custom Video Configuration

Modify video settings in the PublishManager setup:

```swift
config.videoWidth = 1280  // Default: 640
config.videoHeight = 720  // Default: 480
config.videoFps = 30      // Default: 30
config.videoBitrate = 1500 // Default: 750 (kbps)
```

### DTLS Setup Options

Change DTLS setup mode in settings:

- **Actpass** (Recommended): Negotiates the role automatically
- **Active**: Forces the client to be the DTLS client
- **Passive**: Forces the client to be the DTLS server

### Debug Logging

Enable debug logging for troubleshooting:

```swift
// Enable in SettingsManager
config.enableDebug = true
```
