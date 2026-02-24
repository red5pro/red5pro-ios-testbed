//
//  StandalonePublishView.swift
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

// MARK: - Publish Manager (Screen-specific)
class StandalonePublishManager: NSObject, ObservableObject {
    private var webrtcClient: Red5WebrtcClient?
    private var statusCallback: ((String) -> Void)?

    @Published var localVideoRenderer: RTCMTLVideoView?
    @Published var isReady: Bool = false

    private var isInitialized = false

    func setupDelegate(statusCallback: @escaping (String) -> Void) {
        self.statusCallback = statusCallback

        self.localVideoRenderer = RTCMTLVideoView()
        self.localVideoRenderer?.contentMode = .scaleAspectFill
        self.localVideoRenderer?.videoContentMode = .scaleAspectFill

        // Initialize the client with builder pattern
        webrtcClient = Red5WebrtcClientBuilder()
            .setServerIp(SettingsManager.getStandaloneServerIp())
            .setPort(SettingsManager.getStandaloneServerPort())
            .setAppName(SettingsManager.getAppName())
            .setStreamName(SettingsManager.getStreamName())
            .setLicenseKey(SettingsManager.getSdkLicenseKey())
            .setVideoEnabled(true)
            .setAudioEnabled(true)
            .setVideoWidth(640)
            .setVideoHeight(480)
            .setVideoFps(30)
            .setVideoBitrate(750)
            .setTurnServer(uri: SettingsManager.getTurnUrl(), username: SettingsManager.getTurnUsername(), password: SettingsManager.getTurnPassword())
            .setEventListener(self)
            .build()

        LogManager.shared.info("Publish", "Client built")

        if let client = self.webrtcClient {
            client.setVideoRenderer(self.localVideoRenderer!)
        }

        self.statusCallback?("Validating license...")
    }

    // Call this ONCE when view appears to start camera preview
    func startPreview() {
        guard let client = webrtcClient, !isInitialized else {
            if isInitialized {
                LogManager.shared.warning("Publish", "Preview already initialized")
            }
            return
        }

        // Check if license is validated
        if !client.isLicenseValidated() {
            statusCallback?("Waiting for license validation...")
            LogManager.shared.warning("Publish", "Cannot start preview - license not validated yet")
            return
        }

        statusCallback?("Starting preview...")

        // Start the camera capture for preview
        client.startPreview()

        isInitialized = true
    }

    // Call this to start publishing (camera is already running)
    func startPublish() {
        guard let client = webrtcClient else {
            statusCallback?("Client not initialized")
            return
        }

        guard isInitialized else {
            statusCallback?("Preview not started. Call startPreview() first.")
            return
        }

        statusCallback?("Connecting...")

        // Just start publishing - camera is already running
        client.publish()
    }

    func stopPublish() {
        guard let client = webrtcClient else { return }

        // Stop publishing but keep preview running
        client.stopPublish()

        statusCallback?("Stopped publishing")
    }

    func stopPreview() {
        guard let client = webrtcClient else { return }

        // Stop the camera preview
        client.stopPreview()

        isInitialized = false
        statusCallback?("Preview stopped")
    }

    func toggleVideo(enabled: Bool) {
        webrtcClient?.setVideoEnabled(enabled)
    }

    func toggleAudio(enabled: Bool) {
        webrtcClient?.setAudioEnabled(enabled)
    }

    func switchCamera() {
        webrtcClient?.switchCamera()
    }
    
    func setResolutionScale(_ scale: Double) {
        let scaleFactor = scale > 0.0 ? NSNumber(value: scale) : nil
        webrtcClient?.setVideoTransmissionParameters(scaleResolutionDownBy: scaleFactor, maxFramerate: nil)
        statusCallback?("Resolution scaling set to \(scale > 0.0 ? String(scale) : "None")x")
    }
    
    func setLocalResolution(width: Int, height: Int, fps: Int) {
        webrtcClient?.changeCaptureFormat(width: width, height: height, framerate: fps)
        statusCallback?("Camera format changed to \(width)x\(height)")
    }

    func release() {
        // Stop everything
        webrtcClient?.stopPublish()
        webrtcClient?.stopPreview()

        // Clean up
        webrtcClient = nil
        localVideoRenderer = nil
        isInitialized = false
    }

    // Get the video renderer for SwiftUI view
    func getVideoRenderer() -> RTCMTLVideoView? {
        return localVideoRenderer
    }
}

// MARK: - Red5ProWebrtcEventDelegate Implementation
extension StandalonePublishManager: Red5ProWebrtcEventDelegate {
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
            self.statusCallback?("Publishing...")
            LogManager.shared.event("Publish", "Publish started")
        }
    }

    func onPublishStopped() {
        DispatchQueue.main.async {
            self.statusCallback?("Stopped")
            LogManager.shared.event("Publish", "Publish stopped")
        }
    }

    func onPublishFailed(error: String) {
        DispatchQueue.main.async {
            self.statusCallback?("Error: \(error)")
            LogManager.shared.error("Publish", "Publish failed: \(error)")
        }
    }

    func onSubscribeStarted() {
        DispatchQueue.main.async {
            self.statusCallback?("Subscribe started")
        }
    }

    func onSubscribeStopped() {
        DispatchQueue.main.async {
            self.statusCallback?("Subscribe stopped")
        }
    }

    func onSubscribeFailed(error: String) {
        DispatchQueue.main.async {
            self.statusCallback?("Subscribe error: \(error)")
        }
    }

    func onIceConnectionStateChanged(state: IceConnectionState) {
        DispatchQueue.main.async {
            self.statusCallback?("ICE: \(state)")
            LogManager.shared.info("WebRTC", "ICE connection state: \(state)")
        }
    }

    func onConnectionStateChanged(state: PeerConnectionState) {
        DispatchQueue.main.async {
            LogManager.shared.info("WebRTC", "Connection state: \(state)")
        }
    }

    func onError(error: String) {
        DispatchQueue.main.async {
            self.statusCallback?("Error: \(error)")
            LogManager.shared.error("WebRTC", "Error: \(error)")
        }
    }

    func onPreviewStarted() {
        DispatchQueue.main.async {
            LogManager.shared.event("Publish", "Preview started!")
            self.isReady = true  // Set ready state
            self.statusCallback?("Preview ready")
            self.objectWillChange.send()  // Force UI update
        }
    }

    func onPreviewStopped() {
        DispatchQueue.main.async {
            self.statusCallback?("Preview stopped")
            LogManager.shared.event("Publish", "Preview stopped")
        }
    }

    func onLicenseValidated(validated: Bool, message: String) {
        DispatchQueue.main.async {
            if validated {
                LogManager.shared.info("License", "License validated - ready to start")
                self.statusCallback?("Ready to start")
                
                // Auto-start preview after license validation
                if !self.isInitialized {
                    self.startPreview()
                }
            } else {
                self.statusCallback?("License error: \(message)")
                LogManager.shared.error("License", "License validation failed: \(message)")
            }
        }
    }

    func onIceCandidate(candidate: RTCIceCandidate) {
        DispatchQueue.main.async {
            LogManager.shared.info("WebRTC", "ICE Candidate: \(candidate.sdp) sdpMid: \(candidate.sdpMid ?? "nil") sdpMLineIndex: \(candidate.sdpMLineIndex)")
        }
    }
}

// MARK: - Standalone Publish Screen
struct StandalonePublishScreen: View {
    @StateObject private var publishManager = StandalonePublishManager()
    @State private var isVideoMuted = false
    @State private var isAudioMuted = false
    @State private var isFrontCamera = true
    @State private var iceConnectionState = "Not Connected"
    @State private var connectionState = "Disconnected"
    @State private var previewStarted = false
    @State private var cameraPermissionGranted = false
    @State private var showingLogs = false
    @State private var isPublishing = false
    @State private var resolutionScaleFactor: Double = 1.0
    @State private var localResolution: String = "VGA"

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            // Full-size WebRTC preview
            if publishManager.isReady, let renderer = publishManager.localVideoRenderer {
                WebRTCPreviewView(renderer: renderer)
                    .ignoresSafeArea()
            } else {
                Color.black
                    .ignoresSafeArea()
                    .overlay(
                        VStack(spacing: 20) {
                            Image(systemName: "camera.fill")
                                .resizable()
                                .frame(width: 80, height: 60)
                                .foregroundColor(.white.opacity(0.5))

                            if !cameraPermissionGranted {
                                Text("Camera Access Required")
                                    .foregroundColor(.white)
                                    .font(.headline)

                                Button("Open Settings") {
                                    if let url = URL(string: UIApplication.openSettingsURLString) {
                                        UIApplication.shared.open(url)
                                    }
                                }
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            } else {
                                ProgressView("Initializing camera...")
                                    .foregroundColor(.white)
                            }
                        }
                    )
            }

            // Status indicator at top left
            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(isPublishing ? Color.red : Color.gray)
                                .frame(width: 8, height: 8)
                            Text(isPublishing ? "LIVE" : "READY")
                                .font(.caption)
                                .fontWeight(.bold)
                        }
                        // ICE Connection State
                                                HStack(spacing: 5) {
                                                    Text("ICE:")
                                                        .font(.caption2)
                                                        .fontWeight(.semibold)
                                                    Text(iceConnectionState)
                                                        .font(.caption2)
                                                }
                                                
                                                // Peer Connection State
                                                HStack(spacing: 5) {
                                                    Text("Connection State:")
                                                        .font(.caption2)
                                                        .fontWeight(.semibold)
                                                    Text(connectionState)
                                                        .font(.caption2)
                                                    .lineLimit(1)
                                                }
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

            // Buttons at the bottom
            VStack {
                Spacer()

                VStack(spacing: 15) {
                    // First row: 3 buttons
                    HStack(spacing: 20) {
                        // Video Mute/Unmute Button
                        Button(action: {
                            isVideoMuted.toggle()
                            publishManager.toggleVideo(enabled: !isVideoMuted)
                        }) {
                            VStack(spacing: 5) {
                                Image(systemName: isVideoMuted ? "video.slash.fill" : "video.fill")
                                    .font(.system(size: 24))
                                Text(isVideoMuted ? "Video Off" : "Video On")
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white.opacity(previewStarted ? 0.2 : 0.1))
                            .foregroundColor(previewStarted ? .white : .gray)
                            .cornerRadius(12)
                        }
                        .disabled(!previewStarted)

                        // Audio Mute/Unmute Button
                        Button(action: {
                            isAudioMuted.toggle()
                            publishManager.toggleAudio(enabled: !isAudioMuted)
                        }) {
                            VStack(spacing: 5) {
                                Image(systemName: isAudioMuted ? "mic.slash.fill" : "mic.fill")
                                    .font(.system(size: 24))
                                Text(isAudioMuted ? "Mic Off" : "Mic On")
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white.opacity(previewStarted ? 0.2 : 0.1))
                            .foregroundColor(previewStarted ? .white : .gray)
                            .cornerRadius(12)
                        }
                        .disabled(!previewStarted)

                        // Camera Switch Button
                        Button(action: {
                            isFrontCamera.toggle()
                            publishManager.switchCamera()
                        }) {
                            VStack(spacing: 5) {
                                Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                                    .font(.system(size: 24))
                                Text("Flip")
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white.opacity(previewStarted ? 0.2 : 0.1))
                            .foregroundColor(previewStarted ? .white : .gray)
                            .cornerRadius(12)
                        }
                        .disabled(!previewStarted)
                    }

                    // Second row: Full-width Publish Button
                    Button(action: {
                        if isPublishing {
                            publishManager.stopPublish()
                            isPublishing = false
                        } else {
                            publishManager.startPublish()
                            isPublishing = true
                        }
                    }) {
                        Text(isPublishing ? "Stop Publish" : "Start Publish")
                            .font(.headline)
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(previewStarted ? (isPublishing ? Color.red : Color.blue) : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .disabled(!previewStarted)
                }
                .padding(.horizontal, 20)
                
                // Third row: Resolution Scaling Picker
                if isPublishing {
                    VStack {
                        Text("Transmission Scale")
                            .font(.caption)
                            .foregroundColor(.white)
                        Picker("Resolution Scale", selection: $resolutionScaleFactor) {
                            Text("Full").tag(1.0)
                            Text("Half").tag(2.0)
                            Text("Quarter").tag(4.0)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .background(Color.white.opacity(0.8))
                        .cornerRadius(8)
                        .onChange(of: resolutionScaleFactor) { newValue in
                            publishManager.setResolutionScale(newValue)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                // Fourth row: Local Preview Resolution Picker
                VStack {
                    Text("Camera Resolution")
                        .font(.caption)
                        .foregroundColor(.white)
                    Picker("Camera Resolution", selection: $localResolution) {
                        Text("VGA").tag("VGA")
                        Text("qHD").tag("qHD")
                        Text("HD").tag("HD")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(8)
                    .onChange(of: localResolution) { newValue in
                        switch newValue {
                        case "VGA": publishManager.setLocalResolution(width: 640, height: 480, fps: 30)
                        case "qHD": publishManager.setLocalResolution(width: 960, height: 540, fps: 30)
                        case "HD": publishManager.setLocalResolution(width: 1280, height: 720, fps: 30)
                        default: break
                        }
                    }
                }
                .padding(.horizontal, 20)
                .disabled(!previewStarted)
                
                Spacer().frame(height: 40)
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
        .navigationTitle("Publish")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingLogs) {
            LogsView()
        }
        .onAppear {
            setupPublishing()
        }
        .onDisappear {
            cleanup()
        }
    }

    private func setupPublishing() {
        // Check camera permission first
        checkCameraPermission { granted in
            cameraPermissionGranted = granted

            if granted {
                // Setup the publish manager
                publishManager.setupDelegate { message in
                    DispatchQueue.main.async {
                        // Parse the message to detect state changes
                        if message.hasPrefix("ICE:") {
                            // Extract ICE state
                            let state = message.replacingOccurrences(of: "ICE: ", with: "")
                            iceConnectionState = state
                        } else if message.contains("Preview") {
                            previewStarted = true
                            iceConnectionState = "Ready"
                            connectionState = "Ready"
                        } else if message.contains("Publishing") || message.contains("Stopped") {
                            connectionState = message
                        } else if message.contains("Connecting") {
                            iceConnectionState = message
                            connectionState = message
                        } else if message.contains("Error:") {
                            connectionState = message
                        }
                    }
                }

                // Start preview - camera will start and stay running
                publishManager.startPreview()
            }
        }
    }

    private func cleanup() {
        if isPublishing {
            publishManager.stopPublish()
        }
        publishManager.stopPreview()
        publishManager.release()
    }

    private func checkCameraPermission(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        case .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }
}
