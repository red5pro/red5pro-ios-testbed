//
//  CameraControlsExample.swift
//  05-CameraControls
//
//  Flip camera and mute/unmute video & audio while live.
//  Demonstrates: switchCamera(), setVideoEnabled(), setAudioEnabled()
//

import SwiftUI
import WebRTC
import Red5WebRTCKit

// MARK: - Manager

final class CameraControlsManager: NSObject, ObservableObject {
    @Published var isReady = false
    @Published var isLive  = false
    @Published var status  = "Initializing…"

    private var client: Red5WebrtcClient?
    private(set) var renderer = RTCMTLVideoView()

    func setup() {
        renderer.videoContentMode = .scaleAspectFill

        client = Red5WebrtcClientBuilder()
            .setServerIp(Config.serverIP)
            .setPort(Config.port)
            .setAppName(Config.appName)
            .setStreamName(Config.streamName)
            .setLicenseKey(Config.licenseKey)
            .setVideoEnabled(true)
            .setAudioEnabled(true)
            .setEventListener(self)
            .build()

        client?.setVideoRenderer(renderer)
    }

    // Camera controls — available once preview is running
    func flipCamera()            { client?.switchCamera() }
    func setVideo(on: Bool)      { client?.setVideoEnabled(on) }
    func setAudio(on: Bool)      { client?.setAudioEnabled(on) }

    func publish()  { client?.publish() }
    func stop()     { client?.stopPublish() }

    func release() {
        client?.stopPublish()
        client?.stopPreview()
        client = nil
    }
}

extension CameraControlsManager: Red5ProWebrtcEventDelegate {
    func onLicenseValidated(validated: Bool, message: String) {
        DispatchQueue.main.async {
            validated ? self.client?.startPreview() : (self.status = "License error: \(message)")
        }
    }
    func onPreviewStarted() {
        DispatchQueue.main.async { self.isReady = true; self.status = "Preview ready" }
    }
    func onPublishStarted()             { DispatchQueue.main.async { self.isLive = true;  self.status = "Live" } }
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

struct CameraControlsView: View {
    @StateObject private var mgr = CameraControlsManager()
    @State private var videoMuted = false
    @State private var audioMuted = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if mgr.isReady {
                WebRTCPreviewView(renderer: mgr.renderer).ignoresSafeArea()
            } else {
                ProgressView(mgr.status).foregroundColor(.white)
            }

            VStack {
                liveIndicator
                Spacer()
                controlsStack
                    .padding([.horizontal, .bottom], 24)
            }
        }
        .onAppear   { mgr.setup() }
        .onDisappear { mgr.release() }
    }

    // MARK: Subviews

    private var liveIndicator: some View {
        HStack {
            HStack(spacing: 6) {
                Circle()
                    .fill(mgr.isLive ? Color.red : Color.gray)
                    .frame(width: 8, height: 8)
                Text(mgr.status)
                    .font(.caption)
                    .foregroundColor(.white)
            }
            .padding(8)
            .background(Color.black.opacity(0.6))
            .cornerRadius(8)
            .padding([.top, .leading], 16)
            Spacer()
        }
    }

    private var controlsStack: some View {
        VStack(spacing: 14) {
            HStack(spacing: 16) {
                iconButton(
                    icon: "arrow.triangle.2.circlepath.camera",
                    label: "Flip",
                    tint: .white,
                    enabled: mgr.isReady
                ) { mgr.flipCamera() }

                iconButton(
                    icon: videoMuted ? "video.slash.fill" : "video.fill",
                    label: videoMuted ? "Video Off" : "Video On",
                    tint: videoMuted ? .orange : .white,
                    enabled: mgr.isReady
                ) {
                    videoMuted.toggle()
                    mgr.setVideo(on: !videoMuted)
                }

                iconButton(
                    icon: audioMuted ? "mic.slash.fill" : "mic.fill",
                    label: audioMuted ? "Mic Off" : "Mic On",
                    tint: audioMuted ? .orange : .white,
                    enabled: mgr.isReady
                ) {
                    audioMuted.toggle()
                    mgr.setAudio(on: !audioMuted)
                }
            }

            Button(mgr.isLive ? "Stop Publish" : "Start Publish") {
                mgr.isLive ? mgr.stop() : mgr.publish()
            }
            .disabled(!mgr.isReady)
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(mgr.isReady ? (mgr.isLive ? Color.red : Color.blue) : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
    }

    private func iconButton(icon: String, label: String, tint: Color, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 22))
                Text(label).font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.white.opacity(enabled ? 0.2 : 0.08))
            .foregroundColor(enabled ? tint : .gray)
            .cornerRadius(12)
        }
        .disabled(!enabled)
    }
}

// MARK: - App Entry Point

@main
struct CameraControlsApp: App {
    var body: some Scene {
        WindowGroup { CameraControlsView() }
    }
}
