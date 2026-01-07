import Foundation
import Red5WebRTCKit
import WebRTC
import SwiftUI
import PubNubSDK
internal import Combine

class ConferenceViewModel: ObservableObject, Red5ProWebrtcEventDelegate, ConferenceDelegate {
    
    func onPreviewStarted() {
    }
    
    func onPreviewStopped() {
    }
    
    func onLicenseValidated(validated: Bool, message: String) {
        print("ViewModel: License validated: \(validated) - \(message)")
    }
    
    func onChatMessageReceived(channel: String, message: Any) {
    }
    
    func onChatConnected() {
    }
    
    func onChatDisconnected() {
    }
    
    func onChatSendError(channel: String, errorMessage: String) {
    }
    
    func onChatSendSuccess(channel: String, timetoken: NSNumber) {
    }
    
    
    // MARK: - Published Properties
    @Published var isJoined: Bool = false
    @Published var statusMessage: String = "Ready"
    @Published var localVideoRenderer: RTCVideoRenderer?
    @Published var participantRenderers: [String: RTCVideoRenderer] = [:]
    
    // MARK: - Properties
    private var client: Red5WebrtcClient?
    public var roomName: String = ""
    
    // MARK: - Helper Methods
    
    func setupClient(role: String) {
        let builder = Red5WebrtcClientBuilder()
            .setAppName(SettingsManager.getAppName())
            .setStreamManagerHost(SettingsManager.getStreamManagerHost())
            .setNodeGroup(SettingsManager.getNodeGroup())
            .setLicenseKey(SettingsManager.getSdkLicenseKey())
            .setTurnServer(uri: SettingsManager.getTurnUrl(), username: SettingsManager.getTurnUsername(), password: SettingsManager.getTurnPassword())
            .setEventListener(self)
            .setConferenceDelegate(self)
        
        if role == "publisher" {
            builder.setVideoEnabled(true)
                .setAudioEnabled(true)
                .setVideoWidth(640)
                .setVideoHeight(480)
                .setVideoFps(30)
                .setVideoBitrate(750)
        } else {
            builder.setVideoEnabled(false)
                .setAudioEnabled(false)
        }
        
        self.client = builder.build()
        
        // Prepare local renderer if publisher
        if role == "publisher" {
            #if arch(arm64) || arch(x86_64)
            let renderer = RTCMTLVideoView(frame: .zero)
            renderer.videoContentMode = .scaleAspectFit
            self.localVideoRenderer = renderer
            self.client?.setVideoRenderer(renderer)
            #endif
        }
        
        self.statusMessage = "Client setup complete for role: \(role)"
    }
    
    func joinRoom(roomId: String, userId: String, role: String, metadata: [String: Any]) {
        self.roomName = roomId
        self.statusMessage = "Joining \(roomId) as \(userId)..."
        
        var metadataString = ""
        if let jsonData = try? JSONSerialization.data(withJSONObject: metadata, options: []),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            metadataString = jsonString
        }
        
        client?.join(roomId: roomId, streamName: userId, role: role, metadata: metadataString)
    }
    
    func leaveRoom() {
        self.statusMessage = "Leaving room..."
        client?.leave()
        
        DispatchQueue.main.async {
            self.isJoined = false
            self.participantRenderers.removeAll()
            self.localVideoRenderer = nil // Or keep it if we want to preview?
            // Usually we destroy everything on leave
        }
    }
    
    func toggleMic() {
        guard let client = client else { return }
        let isEnabled = client.isLocalAudioTrackEnabled()
        client.toggleSendAudio(!isEnabled)
        print("ViewModel: Toggled mic to \(!isEnabled)")
    }
    
    func toggleCamera() {
        guard let client = client else { return }
        let isEnabled = client.isLocalVideoTrackEnabled()
        client.toggleSendVideo(!isEnabled)
        print("ViewModel: Toggled camera to \(!isEnabled)")
    }
    
    func switchCamera() {
        client?.switchCamera()
        print("ViewModel: Switch camera")
    }
    
    func cleanup() {
        leaveRoom()
        client?.stop()
        client = nil
    }
    
    // MARK: - Red5ProWebrtcEventDelegate
    
    func onPublishStarted() {
        print("ViewModel: Publish started")
    }
    
    func onPublishStopped() {
        print("ViewModel: Publish stopped")
    }
    
    func onPublishFailed(error: String) {
        DispatchQueue.main.async {
            self.statusMessage = "Publish Error: \(error)"
        }
    }
    
    func onSubscribeStarted() {
        print("ViewModel: Subscribe started")
    }
    
    func onSubscribeStopped() {
        print("ViewModel: Subscribe stopped")
    }
    
    func onSubscribeFailed(error: String) {
        DispatchQueue.main.async {
            self.statusMessage = "Subscribe Error: \(error)"
        }
    }
    
    func onError(error: String) {
        DispatchQueue.main.async {
            self.statusMessage = "Error: \(error)"
        }
    }
    
    func onIceConnectionStateChanged(state: IceConnectionState) {
        print("ViewModel: ICE State: \(state)")
    }
    
    func onConnectionStateChanged(state: PeerConnectionState) {
         print("ViewModel: Connection State: \(state)")
    }

    func onIceCandidate(candidate: RTCIceCandidate) {
        DispatchQueue.main.async {
            LogManager.shared.info("WebRTC", "ICE Candidate: \(candidate.sdp) sdpMid: \(candidate.sdpMid ?? "nil") sdpMLineIndex: \(candidate.sdpMLineIndex)")
            print("ViewModel: ICE Candidate: \(candidate.sdp)")
        }
    }
    
    // MARK: - ConferenceDelegate
    
    func onJoinRoomSuccess(roomId: String, participants: [Red5ConferenceParticipant]) {
        DispatchQueue.main.async {
            self.isJoined = true
            self.statusMessage = "Joined room \(roomId)"
            print("ViewModel: Joined with \(participants.count) participants")
        }
    }
    
    func onJoinRoomFailed(statusCode: Int, message: String) {
        DispatchQueue.main.async {
            self.statusMessage = "Join Failed: \(statusCode) - \(message)"
        }
    }
    
    func onParticipantJoined(uid: String, role: String, metaData: String, videoEnabled: Bool, audioEnabled: Bool, renderer: RTCVideoRenderer?) {
        DispatchQueue.main.async {
            print("ViewModel: Participant joined: \(uid)")
            if let renderer = renderer {
                self.participantRenderers[uid] = renderer
            }
        }
    }
    
    func onParticipantLeft(uid: String) {
        DispatchQueue.main.async {
            print("ViewModel: Participant left: \(uid)")
            self.participantRenderers.removeValue(forKey: uid)
        }
    }
    
    func onParticipantMediaUpdate(uid: String, videoEnabled: Bool, audioEnabled: Bool, timestamp: Int64) {
        // Update UI icons if we had corresponding state
    }
    
    func onParticipantRendererUpdate(uid: String, renderer: RTCVideoRenderer) {
        DispatchQueue.main.async {
            print("ViewModel: Renderer update for \(uid)")
            self.participantRenderers[uid] = renderer
        }
    }

    func onIceCandidate(candidate: RTCIceCandidate, uid: String) {
        DispatchQueue.main.async {
            LogManager.shared.info("WebRTC", "ICE Candidate (participant \(uid)): \(candidate.sdp) sdpMid: \(candidate.sdpMid ?? "nil") sdpMLineIndex: \(candidate.sdpMLineIndex)")
            print("ViewModel: ICE Candidate for \(uid): \(candidate.sdp)")
        }
    }
}

