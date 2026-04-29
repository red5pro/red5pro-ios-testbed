//
//  MinimalSubscribeExample.swift
//  02-MinimalSubscribe
//
//  The fewest lines needed to subscribe to a live stream with Red5 Pro.
//
//  Steps:
//    1. Build Red5WebrtcClient via the builder.
//    2. Attach a video renderer for the incoming stream.
//    3. License validates automatically — no preview step needed for subscribe.
//    4. Call subscribe() / stopSubscribe().
//

import SwiftUI
import WebRTC
import Red5WebRTCKit

// MARK: - Manager

final class MinimalSubscribeManager: NSObject, ObservableObject {
    @Published var isSubscribed = false
    @Published var status = "Ready to subscribe"

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

    func subscribe()  { client?.subscribe();       status = "Connecting…" }
    func stop()       { client?.stopSubscribe();    status = "Stopped" }

    func release() {
        client?.stopSubscribe()
        client = nil
    }
}

extension MinimalSubscribeManager: Red5ProWebrtcEventDelegate {
    func onSubscribeStarted() {
        DispatchQueue.main.async { self.isSubscribed = true; self.status = "Subscribed" }
    }
    func onSubscribeStopped() {
        DispatchQueue.main.async { self.isSubscribed = false; self.status = "Stopped" }
    }
    func onSubscribeFailed(error: String) {
        DispatchQueue.main.async { self.status = "Error: \(error)" }
    }
    func onError(error: String) { DispatchQueue.main.async { self.status = "Error: \(error)" } }

    // Unused callbacks required by the protocol
    func onLicenseValidated(validated: Bool, message: String) {}
    func onPreviewStarted() {}
    func onPreviewStopped() {}
    func onPublishStarted() {}
    func onPublishStopped() {}
    func onPublishFailed(error: String) {}
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

struct MinimalSubscribeView: View {
    @StateObject private var mgr = MinimalSubscribeManager()
    @State private var isActive = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if mgr.isSubscribed {
                WebRTCPreviewView(renderer: mgr.renderer).ignoresSafeArea()
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "play.tv")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80)
                        .foregroundColor(.white.opacity(0.35))
                    Text(mgr.status)
                        .foregroundColor(.white.opacity(0.7))
                        .font(.caption)
                }
            }

            VStack {
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
                Spacer()
                Button(isActive ? "Stop" : "Subscribe") {
                    isActive ? mgr.stop() : mgr.subscribe()
                    isActive.toggle()
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(isActive ? Color.red : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
                .padding([.horizontal, .bottom], 24)
            }
        }
        .onAppear   { mgr.setup() }
        .onDisappear { mgr.release() }
    }
}

// MARK: - App Entry Point

@main
struct MinimalSubscribeApp: App {
    var body: some Scene {
        WindowGroup { MinimalSubscribeView() }
    }
}
