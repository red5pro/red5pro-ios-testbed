//
//  AudioOnlyExample.swift
//  03-AudioOnly
//
//  Publish or subscribe with video disabled — audio only.
//  Key difference from the other examples: .setVideoEnabled(false)
//  No camera renderer is needed; no camera permission is required.
//

import SwiftUI
import WebRTC
import Red5WebRTCKit

// MARK: - Manager

final class AudioOnlyManager: NSObject, ObservableObject {
    @Published var status = "Idle"
    @Published var activeMode: Mode = .idle

    enum Mode { case idle, publishing, subscribing }

    private var client: Red5WebrtcClient?

    private func makeClient() -> Red5WebrtcClient {
        Red5WebrtcClientBuilder()
            .setServerIp(Config.serverIP)
            .setPort(Config.port)
            .setAppName(Config.appName)
            .setStreamName(Config.streamName)
            .setLicenseKey(Config.licenseKey)
            .setVideoEnabled(false)   // ← audio only
            .setAudioEnabled(true)
            .setEventListener(self)
            .build()
    }

    func startPublish() {
        client = makeClient()
        client?.publish()
        activeMode = .publishing
        status = "Connecting…"
    }

    func startSubscribe() {
        client = makeClient()
        client?.subscribe()
        activeMode = .subscribing
        status = "Connecting…"
    }

    func stop() {
        switch activeMode {
        case .publishing:  client?.stopPublish()
        case .subscribing: client?.stopSubscribe()
        case .idle: break
        }
        client = nil
        activeMode = .idle
        status = "Idle"
    }
}

extension AudioOnlyManager: Red5ProWebrtcEventDelegate {
    func onPublishStarted()             { DispatchQueue.main.async { self.status = "Publishing audio" } }
    func onPublishStopped()             { DispatchQueue.main.async { self.status = "Stopped" } }
    func onPublishFailed(error: String) { DispatchQueue.main.async { self.status = "Error: \(error)" } }

    func onSubscribeStarted()             { DispatchQueue.main.async { self.status = "Receiving audio" } }
    func onSubscribeStopped()             { DispatchQueue.main.async { self.status = "Stopped" } }
    func onSubscribeFailed(error: String) { DispatchQueue.main.async { self.status = "Error: \(error)" } }

    func onError(error: String) { DispatchQueue.main.async { self.status = "Error: \(error)" } }

    // Unused callbacks required by the protocol
    func onLicenseValidated(validated: Bool, message: String) {}
    func onPreviewStarted() {}
    func onPreviewStopped() {}
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

struct AudioOnlyView: View {
    @StateObject private var mgr = AudioOnlyManager()

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            Image(systemName: iconName)
                .resizable()
                .scaledToFit()
                .frame(width: 100)
                .foregroundColor(accentColor)
                .animation(.easeInOut, value: mgr.activeMode)

            Text(mgr.status)
                .font(.title3)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)

            Spacer()

            if mgr.activeMode == .idle {
                VStack(spacing: 16) {
                    actionButton("Publish Audio", color: .blue)  { mgr.startPublish() }
                    actionButton("Subscribe Audio", color: .green) { mgr.startSubscribe() }
                }
            } else {
                actionButton("Stop", color: .red) { mgr.stop() }
            }
        }
        .padding(24)
        .onDisappear { mgr.stop() }
    }

    private var iconName: String {
        switch mgr.activeMode {
        case .idle:        return "waveform.circle"
        case .publishing:  return "mic.circle.fill"
        case .subscribing: return "speaker.wave.3.fill"
        }
    }

    private var accentColor: Color {
        switch mgr.activeMode {
        case .idle:        return .gray
        case .publishing:  return .red
        case .subscribing: return .green
        }
    }

    private func actionButton(_ label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(label, action: action)
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(color)
            .foregroundColor(.white)
            .cornerRadius(12)
    }
}

// MARK: - App Entry Point

@main
struct AudioOnlyApp: App {
    var body: some Scene {
        WindowGroup { AudioOnlyView() }
    }
}
