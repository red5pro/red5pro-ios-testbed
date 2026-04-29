//
//  MinimalPublishExample.swift
//  01-MinimalPublish
//
//  The fewest lines needed to publish a live stream with Red5 Pro.
//
//  Steps:
//    1. Build Red5WebrtcClient via the builder.
//    2. Attach a video renderer for the local camera preview.
//    3. Wait for onLicenseValidated → call startPreview().
//    4. Wait for onPreviewStarted → enable the Publish button.
//    5. Call publish() / stopPublish().
//

import SwiftUI
import WebRTC
import Red5WebRTCKit

// MARK: - Manager

final class MinimalPublishManager: NSObject, ObservableObject {
    @Published var isReady = false
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

    func publish()  { client?.publish();      status = "Publishing…" }
    func stop()     { client?.stopPublish();   status = "Stopped" }

    func release() {
        client?.stopPublish()
        client?.stopPreview()
        client = nil
    }
}

extension MinimalPublishManager: Red5ProWebrtcEventDelegate {
    func onLicenseValidated(validated: Bool, message: String) {
        DispatchQueue.main.async {
            validated ? self.client?.startPreview() : (self.status = "License error: \(message)")
        }
    }
    func onPreviewStarted() {
        DispatchQueue.main.async { self.isReady = true; self.status = "Ready" }
    }
    func onPublishStarted()             { DispatchQueue.main.async { self.status = "Live" } }
    func onPublishStopped()             { DispatchQueue.main.async { self.status = "Stopped" } }
    func onPublishFailed(error: String) { DispatchQueue.main.async { self.status = "Error: \(error)" } }
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

struct MinimalPublishView: View {
    @StateObject private var mgr = MinimalPublishManager()
    @State private var isLive = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            WebRTCPreviewView(renderer: mgr.renderer)
                .ignoresSafeArea()
                .opacity(mgr.isReady ? 1 : 0)

            if !mgr.isReady {
                ProgressView(mgr.status).foregroundColor(.white)
            }

            VStack {
                statusBadge
                Spacer()
                publishButton
                    .padding([.horizontal, .bottom], 24)
            }
        }
        .onAppear  { mgr.setup() }
        .onDisappear { mgr.release() }
    }

    private var statusBadge: some View {
        HStack {
            Text(mgr.status)
                .font(.caption)
                .padding(8)
                .background(Color.black.opacity(0.6))
                .foregroundColor(.white)
                .cornerRadius(8)
                .padding([.top, .leading], 16)
            Spacer()
        }
    }

    private var publishButton: some View {
        Button(isLive ? "Stop" : "Publish") {
            isLive ? mgr.stop() : mgr.publish()
            isLive.toggle()
        }
        .disabled(!mgr.isReady)
        .font(.headline)
        .frame(maxWidth: .infinity)
        .padding()
        .background(mgr.isReady ? (isLive ? Color.red : Color.blue) : Color.gray)
        .foregroundColor(.white)
        .cornerRadius(12)
    }
}

// MARK: - App Entry Point

@main
struct MinimalPublishApp: App {
    var body: some Scene {
        WindowGroup { MinimalPublishView() }
    }
}
