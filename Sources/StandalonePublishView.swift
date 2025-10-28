import SwiftUI
import AVFoundation
import WebRTC
import Red5WebRTCKit
import PubNubSDK

// MARK: - Publish Manager (Screen-specific)
class StandalonePublishManager: NSObject, ObservableObject {
    private var webrtcClient: Red5WebrtcClient?
    private var statusCallback: ((String) -> Void)?
    
    @Published var localVideoRenderer: RTCMTLVideoView?
    @Published var isReady: Bool = false
    
    private let config = Red5WebrtcClientConfig()
    private var isInitialized = false
    
    func setupDelegate(statusCallback: @escaping (String) -> Void) {
        self.statusCallback = statusCallback
        
        self.localVideoRenderer = RTCMTLVideoView()
        self.localVideoRenderer?.contentMode = .scaleAspectFill
        self.localVideoRenderer?.videoContentMode = .scaleAspectFill
        
        // Configure the client using SettingsManager
        config.serverIp = SettingsManager.getStandaloneServerIp()
        config.port = SettingsManager.getStandaloneServerPort()
        config.appName = SettingsManager.getAppName()
        config.streamName = SettingsManager.getStreamName()
        config.userName = SettingsManager.getUserName()
        config.password = SettingsManager.getPassword()
        config.videoEnabled = true
        config.audioEnabled = true
        config.videoWidth = 640
        config.videoHeight = 480
        config.videoFps = 30
        config.videoBitrate = 750
        config.nodeGroup = SettingsManager.getNodeGroup()
        
        config.videoRenderer = self.localVideoRenderer
        
        // Initialize the client with builder pattern
        webrtcClient = Red5WebrtcClientBuilder()
            .setServerIp(SettingsManager.getStandaloneServerIp())
            .setPort(SettingsManager.getStandaloneServerPort())
            .setAppName(SettingsManager.getAppName())
            .setStreamName(SettingsManager.getStreamName())
            .setVideoEnabled(config.videoEnabled)
            .setAudioEnabled(config.audioEnabled)
            .setVideoWidth(config.videoWidth)
            .setVideoHeight(config.videoHeight)
            .setVideoFps(config.videoFps)
            .setVideoBitrate(config.videoBitrate)
            .setTurnServer(uri: SettingsManager.getTurnUrl(), username: SettingsManager.getTurnUsername(), password: SettingsManager.getTurnPassword())
            .setEventListener(self)
            .build()
        
        print("Client built")
        
        if let client = self.webrtcClient {
            client.setVideoRenderer(self.localVideoRenderer!)
        }
        
        self.statusCallback?("Ready to start")
    }
    
    // Call this ONCE when view appears to start camera preview
    func startPreview() {
        guard let client = webrtcClient, !isInitialized else { return }
        
        statusCallback?("Starting preview...")
        
        // Start the camera capture for preview
        // WebRTC will own the camera from now on
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
    func onChatMessageReceived(channel: String, message: any PubNubSDK.JSONCodable) {
        print("chat message received")
    }
    
    func onChatConnected() {
        print("chat connected")
    }
    
    func onChatDisconnected() {
        print("chat disconnected")
    }
    
    func onChatSendError(channel: String, errorMessage: String) {
        print("chat send error")
    }
    
    func onChatSendSuccess(channel: String, timetoken: NSNumber) {
        print("chat send success")
    }
    
    func onPublishStarted() {
        DispatchQueue.main.async {
            self.statusCallback?("Publishing...")
            print("Publish started")
        }
    }
    
    func onPublishStopped() {
        DispatchQueue.main.async {
            self.statusCallback?("Stopped")
            print("Publish stopped")
        }
    }
    
    func onPublishFailed(error: String) {
        DispatchQueue.main.async {
            self.statusCallback?("Error: \(error)")
            print("Publish failed: \(error)")
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
            print("ICE connection state: \(state)")
        }
    }
    
    func onConnectionStateChanged(state: PeerConnectionState) {
        DispatchQueue.main.async {
            print("Connection state: \(state)")
        }
    }
    
    func onError(error: String) {
        DispatchQueue.main.async {
            self.statusCallback?("Error: \(error)")
            print("Error: \(error)")
        }
    }
    
    func onPreviewStarted() {
        DispatchQueue.main.async {
            print("[Delegate] Preview started!")
            self.isReady = true  // Set ready state
            self.statusCallback?("Preview ready")
            self.objectWillChange.send()  // Force UI update
        }
    }
    
    func onPreviewStopped() {
        DispatchQueue.main.async {
            self.statusCallback?("Preview stopped")
            print("Preview stopped")
        }
    }
    
    func onLicenseValidated(validated: Bool, message: String) {
        DispatchQueue.main.async {
            self.statusCallback?(validated ? "License valid" : "License invalid: \(message)")
        }
    }
}

// MARK: - Standalone Publish Screen
struct StandalonePublishScreen: View {
    @StateObject private var publishManager = StandalonePublishManager()
    @State private var isVideoMuted = false
    @State private var isAudioMuted = false
    @State private var isFrontCamera = true
    @State private var isPublishing = false
    @State private var statusMessage = "Ready"
    @State private var previewStarted = false
    @State private var cameraPermissionGranted = false
    
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
                            statusMessage = "Stopped"
                        } else {
                            publishManager.startPublish()
                            isPublishing = true
                            statusMessage = "Publishing..."
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
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Publish")
        .navigationBarTitleDisplayMode(.inline)
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
                        statusMessage = message
                        
                        // Track when preview actually starts
                        if message.contains("Preview") && message.contains("ready") {
                            previewStarted = true
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
