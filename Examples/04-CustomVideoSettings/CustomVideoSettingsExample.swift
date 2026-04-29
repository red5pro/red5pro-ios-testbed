//
//  CustomVideoSettingsExample.swift
//  04-CustomVideoSettings
//
//  Choose resolution, frame rate, and bitrate before starting a publish session.
//  Demonstrates: setVideoWidth/Height(), setVideoFps(), setVideoBitrate()
//

import SwiftUI
import WebRTC
import Red5WebRTCKit

// MARK: - Presets

struct VideoPreset: Identifiable, Hashable {
    let id = UUID()
    let label: String
    let width, height, fps, bitrate: Int
}

let videoPresets: [VideoPreset] = [
    VideoPreset(label: "360p · 30fps · 400 kbps",  width: 640,  height: 360,  fps: 30, bitrate: 400),
    VideoPreset(label: "480p · 30fps · 750 kbps",  width: 854,  height: 480,  fps: 30, bitrate: 750),
    VideoPreset(label: "720p · 30fps · 1.5 Mbps",  width: 1280, height: 720,  fps: 30, bitrate: 1500),
    VideoPreset(label: "720p · 60fps · 2.5 Mbps",  width: 1280, height: 720,  fps: 60, bitrate: 2500),
    VideoPreset(label: "1080p · 30fps · 3 Mbps",   width: 1920, height: 1080, fps: 30, bitrate: 3000),
]

// MARK: - Manager

final class CustomVideoManager: NSObject, ObservableObject {
    @Published var isReady = false
    @Published var isLive  = false
    @Published var status  = "Select a preset"

    private var client: Red5WebrtcClient?
    private(set) var renderer = RTCMTLVideoView()

    func setup(preset: VideoPreset) {
        renderer.videoContentMode = .scaleAspectFill

        client = Red5WebrtcClientBuilder()
            .setServerIp(Config.serverIP)
            .setPort(Config.port)
            .setAppName(Config.appName)
            .setStreamName(Config.streamName)
            .setLicenseKey(Config.licenseKey)
            .setVideoEnabled(true)
            .setAudioEnabled(true)
            .setVideoWidth(preset.width)
            .setVideoHeight(preset.height)
            .setVideoFps(preset.fps)
            .setVideoBitrate(preset.bitrate)
            .setEventListener(self)
            .build()

        client?.setVideoRenderer(renderer)
        status = "Waiting for license…"
    }

    func publish() { client?.publish();      isLive = true;  status = "Publishing…" }
    func stop()    { client?.stopPublish();   isLive = false; status = "Stopped" }

    func release() {
        client?.stopPublish()
        client?.stopPreview()
        client = nil
        isReady = false
        isLive  = false
    }
}

extension CustomVideoManager: Red5ProWebrtcEventDelegate {
    func onLicenseValidated(validated: Bool, message: String) {
        DispatchQueue.main.async {
            validated ? self.client?.startPreview() : (self.status = "License error: \(message)")
        }
    }
    func onPreviewStarted() {
        DispatchQueue.main.async { self.isReady = true; self.status = "Ready — tap Publish" }
    }
    func onPublishStarted()             { DispatchQueue.main.async { self.status = "Live" } }
    func onPublishStopped()             { DispatchQueue.main.async { self.isLive = false; self.status = "Stopped" } }
    func onPublishFailed(error: String) { DispatchQueue.main.async { self.isLive = false; self.status = "Error: \(error)" } }
    func onError(error: String)         { DispatchQueue.main.async { self.status = "Error: \(error)" } }

    // Unused callbacks required by the protocol
    func onPreviewStopped() {}
    func onSubscribeStarted() {}
    func onSubscribeStopped() {}
    func onSubscribeFailed(error: String) {}
    func onIceConnectionStateChanged(state: IceConnectionState) {}
    func onConnectionStateChanged(state: PeerConnectionState) {}
    func onIceCandidate(candidate: RTCIceCandidate) {}
    func onChatMessageReceived(channel: String, message: Any) {}
    func onChatConnected() {}
    func onChatDisconnected() {}
    func onChatSendError(channel: String, errorMessage: String) {}
    func onChatSendSuccess(channel: String, timetoken: NSNumber) {}
}

// MARK: - View

struct CustomVideoSettingsView: View {
    @StateObject private var mgr = CustomVideoManager()
    @State private var selected  = videoPresets[1]   // default: 480p
    @State private var sessionStarted = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if sessionStarted {
                WebRTCPreviewView(renderer: mgr.renderer).ignoresSafeArea()
            }

            VStack {
                if !sessionStarted {
                    presetPicker
                } else {
                    activePresetLabel
                }

                statusBadge

                Spacer()

                controlButton
                    .padding([.horizontal, .bottom], 24)
            }
        }
        .onDisappear { mgr.release() }
    }

    private var presetPicker: some View {
        VStack(spacing: 12) {
            Text("Choose Quality Preset")
                .font(.headline)
                .foregroundColor(.white)

            Picker("Preset", selection: $selected) {
                ForEach(videoPresets) { p in Text(p.label).tag(p) }
            }
            .pickerStyle(.wheel)
            .frame(height: 140)
            .clipped()
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
            .colorScheme(.dark)
        }
        .padding()
        .background(Color.black.opacity(0.85))
        .cornerRadius(16)
        .padding()
    }

    private var activePresetLabel: some View {
        HStack {
            Text(selected.label)
                .font(.caption)
                .padding(8)
                .background(Color.black.opacity(0.6))
                .foregroundColor(.white)
                .cornerRadius(8)
                .padding([.top, .leading], 16)
            Spacer()
        }
    }

    private var statusBadge: some View {
        Text(mgr.status)
            .font(.caption)
            .padding(8)
            .background(Color.black.opacity(0.6))
            .foregroundColor(.white)
            .cornerRadius(8)
    }

    private var controlButton: some View {
        Group {
            if !sessionStarted {
                Button("Start Preview") {
                    mgr.setup(preset: selected)
                    sessionStarted = true
                }
                .buttonStyle(FilledButton(color: .blue))
            } else {
                Button(mgr.isLive ? "Stop" : "Publish") {
                    mgr.isLive ? mgr.stop() : mgr.publish()
                }
                .disabled(!mgr.isReady)
                .buttonStyle(FilledButton(color: mgr.isReady ? (mgr.isLive ? .red : .blue) : .gray))
            }
        }
    }
}

struct FilledButton: ButtonStyle {
    let color: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(color.opacity(configuration.isPressed ? 0.7 : 1))
            .foregroundColor(.white)
            .cornerRadius(12)
    }
}

// MARK: - App Entry Point

@main
struct CustomVideoSettingsApp: App {
    var body: some Scene {
        WindowGroup { CustomVideoSettingsView() }
    }
}
