//
//  StandaloneSubscribeView.swift
//  WebRTCTestBed
//
//  Created by Mustafa BOLEKEN on 21.10.2025.
//

import SwiftUI
import AVFoundation
import WebRTC
import Red5WebRTCKit
import PubNubSDK
internal import Combine

// MARK: - Subscribe Manager (Screen-specific)
class StandaloneSubscribeManager: NSObject, ObservableObject {
    private var webrtcClient: Red5WebrtcClient?
    private var statusCallback: ((String) -> Void)?

    @Published var remoteVideoRenderer: RTCMTLVideoView?
    @Published var isReady: Bool = false
    @Published var isSubscribing: Bool = false
    @Published var shouldClearView: Bool = false

    private var isInitialized = false

    func setupDelegate(statusCallback: @escaping (String) -> Void) {
        self.statusCallback = statusCallback

        self.remoteVideoRenderer = RTCMTLVideoView()
        self.remoteVideoRenderer?.contentMode = .scaleAspectFill
        self.remoteVideoRenderer?.videoContentMode = .scaleAspectFill
        
        DispatchQueue.main.async {
            self.remoteVideoRenderer?.layoutIfNeeded()
        }

        // Initialize the client with builder pattern
        webrtcClient = Red5WebrtcClientBuilder()
            .setServerIp(SettingsManager.getStandaloneServerIp())
            .setPort(SettingsManager.getStandaloneServerPort())
            .setAppName(SettingsManager.getAppName())
            .setStreamName(SettingsManager.getStreamName())
            .setVideoEnabled(true)
            .setAudioEnabled(true)
            .setVideoWidth(640)
            .setVideoHeight(480)
            .setVideoFps(30)
            .setVideoBitrate(750)
            .setLicenseKey(SettingsManager.getSdkLicenseKey())
            .setTurnServer(uri: SettingsManager.getTurnUrl(), username: SettingsManager.getTurnUsername(), password: SettingsManager.getTurnPassword())
            .setEventListener(self)
            .build()

        LogManager.shared.info("Subscribe", "Subscribe Client built")

        // Set the video renderer on the client
        if let client = self.webrtcClient, let renderer = self.remoteVideoRenderer {
            client.setVideoRenderer(renderer)
            LogManager.shared.info("Subscribe", "Video renderer attached to client")
        } else {
            LogManager.shared.error("Subscribe", "Failed to attach video renderer")
        }

        self.statusCallback?("Ready to subscribe")
        isReady = true
    }

    // Call this to start subscribing
    func startSubscribe() {
        guard let client = webrtcClient else {
            statusCallback?("Client not initialized")
            return
        }

        statusCallback?("Connecting to stream...")
        LogManager.shared.info("Subscribe", "Starting subscription...")

        // Start subscribing
        client.subscribe()
    }

    func stopSubscribe() {
        guard let client = webrtcClient else { return }

        // Stop subscribing
        client.stopSubscribe()
        isSubscribing = false
        shouldClearView = true

        statusCallback?("Stopped subscribing")
    }

    func release() {
        // Stop everything
        webrtcClient?.stopSubscribe()

        // Clean up
        webrtcClient = nil
        remoteVideoRenderer = nil
        isInitialized = false
        isSubscribing = false
    }

    // Get the video renderer for SwiftUI view
    func getVideoRenderer() -> RTCMTLVideoView? {
        return remoteVideoRenderer
    }
}

// MARK: - Red5ProWebrtcEventDelegate Implementation
extension StandaloneSubscribeManager: Red5ProWebrtcEventDelegate {
    func onChatMessageReceived(channel: String, message: Any) {
        DispatchQueue.main.async {
            LogManager.shared.info("Chat", "Message received on channel: \(channel)")
        }
    }

    func onChatConnected() {
        DispatchQueue.main.async {
            LogManager.shared.info("Chat", "Connected")
        }
    }

    func onChatDisconnected() {
        DispatchQueue.main.async {
            LogManager.shared.info("Chat", "Disconnected")
        }
    }

    func onChatSendError(channel: String, errorMessage: String) {
        DispatchQueue.main.async {
            LogManager.shared.error("Chat", "Send error on channel \(channel): \(errorMessage)")
        }
    }

    func onChatSendSuccess(channel: String, timetoken: NSNumber) {
        DispatchQueue.main.async {
            LogManager.shared.info("Chat", "Send success on channel \(channel) with timetoken: \(timetoken)")
        }
    }

    func onPublishStarted() {
        DispatchQueue.main.async {
            self.statusCallback?("Publish started")
        }
    }

    func onPublishStopped() {
        DispatchQueue.main.async {
            self.statusCallback?("Publish stopped")
        }
    }

    func onPublishFailed(error: String) {
        DispatchQueue.main.async {
            self.statusCallback?("Publish error: \(error)")
        }
    }

    func onSubscribeStarted() {
        DispatchQueue.main.async {
            self.statusCallback?("Receiving stream...")
            self.isSubscribing = true
            self.shouldClearView = false
            LogManager.shared.event("Subscribe", "Subscribe started")
        }
    }

    func onSubscribeStopped() {
        DispatchQueue.main.async {
            self.statusCallback?("Stopped")
            self.isSubscribing = false
            self.shouldClearView = true
            LogManager.shared.event("Subscribe", "Subscribe stopped")
        }
    }

    func onSubscribeFailed(error: String) {
        DispatchQueue.main.async {
            self.statusCallback?("Error: \(error)")
            self.isSubscribing = false
            LogManager.shared.error("Subscribe", "Subscribe failed: \(error)")
        }
    }

    func onIceConnectionStateChanged(state: IceConnectionState) {
        DispatchQueue.main.async {
            self.statusCallback?("ICE: \(state)")
            LogManager.shared.info("WebRTC", "ICE connection state: \(state)")

            // Update connection status based on ICE state
            switch state {
            case .connected, .completed:
                self.statusCallback?("Connected")
            case .checking:
                self.statusCallback?("Connecting...")
            case .failed:
                self.statusCallback?("Connection failed")
                self.isSubscribing = false
            case .disconnected:
                self.statusCallback?("Disconnected")
                self.isSubscribing = false
            default:
                break
            }
        }
    }

    func onConnectionStateChanged(state: PeerConnectionState) {
        DispatchQueue.main.async {
            LogManager.shared.info("WebRTC", "Connection state: \(state)")

            // Update status based on peer connection state
            switch state {
            case .connected:
                self.statusCallback?("Streaming")
            case .connecting:
                self.statusCallback?("Connecting...")
            case .failed:
                self.statusCallback?("Connection failed")
                self.isSubscribing = false
            case .disconnected:
                self.statusCallback?("Disconnected")
                self.isSubscribing = false
            default:
                break
            }
        }
    }

    func onError(error: String) {
        DispatchQueue.main.async {
            self.statusCallback?("Error: \(error)")
            self.isSubscribing = false
            LogManager.shared.error("WebRTC", "Error: \(error)")
        }
    }

    func onPreviewStarted() {
        DispatchQueue.main.async {
            self.statusCallback?("Preview started")
        }
    }

    func onPreviewStopped() {
        DispatchQueue.main.async {
            self.statusCallback?("Preview stopped")
        }
    }

    func onLicenseValidated(validated: Bool, message: String) {
        DispatchQueue.main.async {
            self.statusCallback?(validated ? "License valid" : "License invalid: \(message)")
        }
    }

    func onIceCandidate(candidate: RTCIceCandidate) {
        DispatchQueue.main.async {
            LogManager.shared.info("WebRTC", "ICE Candidate: \(candidate.sdp) sdpMid: \(candidate.sdpMid ?? "nil") sdpMLineIndex: \(candidate.sdpMLineIndex)")
        }
    }
}

// MARK: - Standalone Subscribe Screen
struct StandaloneSubscribeScreen: View {
    @StateObject private var subscribeManager = StandaloneSubscribeManager()
    @State private var statusMessage = "Ready"
    @State private var isFullscreen = false
    @State private var showingLogs = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Full-size WebRTC subscribe view
            if subscribeManager.isReady, let renderer = subscribeManager.remoteVideoRenderer {
                WebRTCPreviewView(renderer: renderer, shouldClear: subscribeManager.shouldClearView)
                    .ignoresSafeArea()
            } else {
                Color.black
                    .ignoresSafeArea()
                    .overlay(
                        VStack(spacing: 20) {
                            Image(systemName: "play.rectangle.fill")
                                .resizable()
                                .frame(width: 120, height: 80)
                                .foregroundColor(.white.opacity(0.3))

                            Text("No Stream")
                                .foregroundColor(.white.opacity(0.5))
                                .font(.title2)

                            ProgressView("Loading...")
                                .foregroundColor(.white)
                        }
                    )
            }

            // Status indicator at top left
            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(subscribeManager.isSubscribing ? Color.red : Color.gray)
                                .frame(width: 8, height: 8)
                            Text(subscribeManager.isSubscribing ? "LIVE" : "OFFLINE")
                                .font(.caption)
                                .fontWeight(.bold)
                        }
                        Text(statusMessage)
                            .font(.caption2)
                            .lineLimit(1)
                    }
                    .padding(10)
                    .background(Color.black.opacity(0.6))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding(.top, 10)
                    .padding(.leading, 15)

                    Spacer()
                }

                Spacer()
            }

            // Subscribe button at the bottom
            VStack {
                Spacer()

                HStack(spacing: 20) {
                    // Main Subscribe/Stop Button
                    Button(action: {
                        if subscribeManager.isSubscribing {
                            subscribeManager.stopSubscribe()
                        } else {
                            subscribeManager.startSubscribe()
                        }
                    }) {
                        HStack {
                            Image(systemName: subscribeManager.isSubscribing ? "stop.circle.fill" : "play.circle.fill")
                                .font(.system(size: 20))
                            Text(subscribeManager.isSubscribing ? "Stop" : "Subscribe")
                                .font(.headline)
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(subscribeManager.isSubscribing ? Color.red : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!subscribeManager.isReady)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            
            // Floating Logs Button
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        showingLogs = true
                    }) {
                        Image(systemName: "list.bullet.rectangle")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(Color.blue.opacity(0.8))
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 80)
                }
                Spacer()
            }
        }
        .navigationTitle("Subscribe")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingLogs) {
            LogsView()
        }
        .onAppear {
            setupSubscription()
        }
        .onDisappear {
            cleanup()
        }
    }

    private func setupSubscription() {
        // Setup the subscribe manager
        subscribeManager.setupDelegate { message in
            DispatchQueue.main.async {
                statusMessage = message
            }
        }
    }

    private func cleanup() {
        subscribeManager.stopSubscribe()
        subscribeManager.release()
    }
}

#Preview {
    NavigationView {
        StandaloneSubscribeScreen()
    }
}
