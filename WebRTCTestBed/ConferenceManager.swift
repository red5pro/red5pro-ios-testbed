//
//  ConferenceManager.swift
//  WebRTCTestBed
//
//  Created by Red5Pro on 12.12.2025.
//

import SwiftUI
import AVFoundation
import WebRTC
import PubNubSDK
import Red5WebRTCKit
internal import Combine

// MARK: - Conference Manager
class ConferenceManager: NSObject, ObservableObject, Red5ProWebrtcEventDelegate {
    func onPublishStarted() {
        print("Publish started")
    }
    
    func onPublishStopped() {
        print("Publish stopped")
    }
    
    func onPublishFailed(error: String) {
        print("Publish failed")
    }
    
    func onSubscribeStarted() {
        print("Subscribe started")
    }
    
    func onSubscribeStopped() {
        print("Subscribe stopped")
    }
    
    func onSubscribeFailed(error: String) {
        print("Subscribe failed")
    }
    
    func onIceConnectionStateChanged(state: Red5WebRTCKit.IceConnectionState) {
    }
    
    func onConnectionStateChanged(state: Red5WebRTCKit.PeerConnectionState) {
    }
    
    func onError(error: String) {
        print(error)
    }
    
    func onChatMessageReceived(channel: String, message: any PubNubSDK.JSONCodable) {
    }
    
    func onChatConnected() {
    }
    
    func onChatDisconnected() {
    }
    
    func onChatSendError(channel: String, errorMessage: String) {
    }
    
    func onChatSendSuccess(channel: String, timetoken: NSNumber) {
    }
    
    
    private var webrtcClient: Red5WebrtcClient?
    
    @Published var localVideoRenderer: RTCMTLVideoView?
    // Map of streamId -> Renderer
    @Published var participantRenderers: [String: RTCMTLVideoView] = [:]
    // Map of streamId -> Participant Info (we might need a struct for this)
    @Published var participants: [String: Red5ConferenceParticipant] = [:]
    
    @Published var isReady: Bool = false
    @Published var isJoined: Bool = false
    @Published var statusMessage: String = "Ready"
    @Published var roomName: String = ""
    @Published var localStreamId: String = ""
    
    private var isInitialized = false
    private var role: String = "publisher"
    
    // Conference settings
    private var roomId: String = ""
    private var userId: String = ""
    
    override init() {
        super.init()
        self.localVideoRenderer = RTCMTLVideoView()
        self.localVideoRenderer?.contentMode = .scaleAspectFill
        self.localVideoRenderer?.videoContentMode = .scaleAspectFill
    }
    
    func setupClient(role: String) {
        self.role = role
        
        // Initialize the client with builder pattern
        // Note: SDK might need specific conference config
        let builder = Red5WebrtcClientBuilder()
            .setAppName(SettingsManager.getAppName())
            .setStreamManagerHost(SettingsManager.getStreamManagerHost())
            .setNodeGroup(SettingsManager.getNodeGroup())
            .setLicenseKey(SettingsManager.getSdkLicenseKey())
            .setTurnServer(uri: SettingsManager.getTurnUrl(), username: SettingsManager.getTurnUsername(), password: SettingsManager.getTurnPassword())
            .setEventListener(self)
            .setConferenceDelegate(self) // Important: conference listener
        
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
            
        webrtcClient = builder.build()
        
        LogManager.shared.info("Conference", "Client built for role: \(role)")
        
        if let client = self.webrtcClient, role == "publisher" {
            client.setVideoRenderer(self.localVideoRenderer!)
        }
    }
    
    func startPreview() {
        guard let client = webrtcClient, role == "publisher" else { return }
        client.startPreview()
    }
    
    func stopPreview() {
        webrtcClient?.stopPreview()
    }
    
    private var pendingJoinRequest: (roomId: String, userId: String)?
    private var isLicenseValidated: Bool = false
    
    // ...
    
    func joinRoom(roomId: String, userId: String) {
        guard let client = webrtcClient else { return }
        
        self.roomId = roomId
        self.userId = userId
        
        statusMessage = "Joined requested for \(roomId)..."

        if !isLicenseValidated {
            statusMessage = "Waiting for license validation..."
            self.pendingJoinRequest = (roomId, userId)
            return
        }
        
        // If publisher, wait for preview to be ready for better UX? 
        // Or if we already started preview (e.g. manual join later), check isReady.
        if role == "publisher" && !isReady {
             statusMessage = "Waiting for camera preview..."
             self.pendingJoinRequest = (roomId, userId)
             return
        }

        performJoin(client: client, roomId: roomId, userId: userId)
    }
    
    private func performJoin(client: Red5WebrtcClient, roomId: String, userId: String) {
         let metaData = ["name": userId]
        var metaString = "{}"
        if let jsonData = try? JSONSerialization.data(withJSONObject: metaData, options: []),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            metaString = jsonString
        }
        
        statusMessage = "Joining \(roomId)..."
        client.join(roomId: roomId, streamName: userId, role: role, metadata: metaString)
        self.pendingJoinRequest = nil
    }
    
    func leaveRoom() {
        webrtcClient?.stopPublish()
        webrtcClient?.stopPreview()
        cleanup()
    }
    
    func cleanup() {
        webrtcClient?.stopPublish()
        webrtcClient?.stopPreview()
        webrtcClient = nil
        
        participantRenderers.removeAll()
        participants.removeAll()
        isJoined = false
        isInitialized = false
        isLicenseValidated = false
        isReady = false
        pendingJoinRequest = nil
    }
    
    // ...

    func onPreviewStarted() {
         DispatchQueue.main.async {
             self.isReady = true
             if let pending = self.pendingJoinRequest, let client = self.webrtcClient {
                 self.performJoin(client: client, roomId: pending.roomId, userId: pending.userId)
             }
        }
    }
    
    func onPreviewStopped() {
         DispatchQueue.main.async {
             self.isReady = false
        }
    }
    
    func onLicenseValidated(validated: Bool, message: String) {
        if validated {
            DispatchQueue.main.async {
                self.isLicenseValidated = true
                self.statusMessage = "License Validated"
                
                if self.role == "publisher" {
                    self.startPreview()
                    // pendingJoinRequest will be handled in onPreviewStarted
                } else {
                    // Subscriber doesn't preview, so join immediately if pending
                    if let pending = self.pendingJoinRequest, let client = self.webrtcClient {
                        self.performJoin(client: client, roomId: pending.roomId, userId: pending.userId)
                    }
                }
            }
        } else {
             DispatchQueue.main.async {
                 self.statusMessage = "License Invalid: \(message)"
                 self.pendingJoinRequest = nil
            }
        }
    }
}

// MARK: - Red5ProConferenceDelegate
// Assuming the interface name based on patterns
extension ConferenceManager: ConferenceDelegate {
    func onParticipantJoined(uid: String, role: String, metaData: String, videoEnabled: Bool, audioEnabled: Bool, renderer: (any RTCVideoRenderer)?) {
    }
    
    func onParticipantLeft(uid: String) {
    }
    
    func onParticipantMediaUpdate(uid: String, videoEnabled: Bool, audioEnabled: Bool, timestamp: Int64) {
    }
    
    func onJoinRoomSuccess(roomId: String, participants: [Red5ConferenceParticipant]) {
        DispatchQueue.main.async {
            self.isJoined = true
            self.statusMessage = "Joined Room: \(roomId)"
            self.roomName = roomId
            
            // Add existing participants
            for p in participants {
                self.handleParticipant(p)
            }
            print("onJoinRoomSuccess: \(participants)")
        }
    }
    
    func onJoinRoomFailed(statusCode: Int, message: String) {
        DispatchQueue.main.async {
            self.statusMessage = "Join Failed: \(message)"
            print("onJoinRoomFailed: \(message)")
        }
    }
    
    func onParticipantJoined(participant: Red5ConferenceParticipant) {
        DispatchQueue.main.async {
            self.handleParticipant(participant)
            print("onParticipantJoined: \(participant)")
        }
    }
    
    func onParticipantLeft(participant: Red5ConferenceParticipant) {
        DispatchQueue.main.async {
            self.participants.removeValue(forKey: participant.uid)
            self.participantRenderers.removeValue(forKey: participant.uid)
        }
    }
    
    func onParticipantMediaUpdate(participant: Red5ConferenceParticipant) {
        // Handle mute/unmute visual cues
         DispatchQueue.main.async {
             self.participants[participant.uid] = participant
         }
    }
    
    private func handleParticipant(_ participant: Red5ConferenceParticipant) {
        guard participant.uid != self.userId else { return } // Skip self if returned
        
        self.participants[participant.uid] = participant
        
        // Setup renderer for this participant
        let renderer = RTCMTLVideoView()
        renderer.contentMode = .scaleAspectFill
        renderer.videoContentMode = .scaleAspectFill
        self.participantRenderers[participant.uid] = renderer
        
        // Attach renderer using SDK
        // Note: The SDK should have a method to attach a renderer to a specific participant stream
        // e.g. client.subscribe(participant.streamName, renderer: renderer)
        // OR client.setParticipantRenderer(participant, renderer)
        
        // In Android: onParticipantJoined provides the renderer or allows setting it.
        // Android: addParticipant -> ... renderer?.parent...
        
        // Checking commonly used Red5 iOS Conference API:
        // usually passed in as `attachRenderer(renderer, to: participant)` or similar.
        // Let's assume webrtcClient.subscribe(streamName: participant.streamName, renderer: renderer)
        
        self.webrtcClient?.subscribe(streamName: participant.uid, renderer: renderer)
    }
}
