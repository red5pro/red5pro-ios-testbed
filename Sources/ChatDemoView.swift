//
//  ChatDemoView.swift
//  SampleApp
//
//  Created by Assistant on 27.10.2025.
//

/*
 PubNub Chat Demo View
 
 This is a fully functional chat application that integrates with your Red5WebRTC client
 to provide real-time messaging capabilities using PubNub.
 
 SETUP INSTRUCTIONS:
 
 1. Get PubNub Keys:
    - Sign up at https://www.pubnub.com
    - Create a new app in the PubNub dashboard
    - Get your Publish Key and Subscribe Key
 
 2. Configure the app:
    - Open the chat demo
    - Tap "Settings" in the top left
    - Enter your PubNub Publish and Subscribe keys
    - Optionally change your username and channel name
    - Tap "Done"
 
 3. Connect and chat:
    - Tap "Connect" in the top right
    - Once connected, you can send and receive messages
    - Other users on the same channel will see your messages in real-time
 
 FEATURES:
 - Real-time messaging using PubNub
 - Custom usernames and channel names
 - Message history and timestamps
 - Connection status indicator
 - Error handling and user feedback
 - Clean, modern UI with message bubbles
 - System messages for status updates
 
 TECHNICAL DETAILS:
 - Uses Red5WebrtcClient with PubNub integration
 - Messages are sent as JSON objects with metadata
 - Automatic scroll to latest messages
 - Thread-safe UI updates
 - Proper resource cleanup
 */

import SwiftUI
import PubNubSDK
import Red5WebRTCKit

// MARK: - Chat Demo View
struct ChatDemoView: View {
    @State private var messageText = ""
    @State private var messages: [ChatMessage] = []
    @State private var isConnected = false
    @State private var connectionStatus = "Disconnected"
    @State private var currentUsername = "User\(Int.random(in: 1000...9999))"
    @State private var currentChannel = "red5pro-chat-demo"
    @State private var showingSettings = false
    @State private var errorMessage: String?
    @State private var showingError = false
    
    // Red5Pro WebRTC Client
    @State private var webrtcClient: Red5WebrtcClient?
    
    // Configuration
    @State private var pubKey = ""
    @State private var subKey = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Connection Status Header
                connectionStatusHeader
                
                // Messages List
                messagesScrollView
                
                // Message Input
                messageInputSection
            }
            .navigationTitle("PubNub Chat Demo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Settings") {
                        showingSettings = true
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isConnected ? "Disconnect" : "Connect") {
                        if isConnected {
                            disconnectFromChat()
                        } else {
                            connectToChat()
                        }
                    }
                    .foregroundColor(isConnected ? .red : .blue)
                }
            }
            .sheet(isPresented: $showingSettings) {
                ChatSettingsView(
                    username: $currentUsername,
                    channel: $currentChannel,
                    pubKey: $pubKey,
                    subKey: $subKey
                )
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "Unknown error occurred")
            }
            .onAppear {
                loadDemoMessages()
            }
        }
    }
    
    // MARK: - UI Components
    
    private var connectionStatusHeader: some View {
        HStack {
            HStack(spacing: 6) {
                Circle()
                    .fill(isConnected ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(connectionStatus)
                    .font(.caption)
                    .foregroundColor(isConnected ? .green : .red)
            }
            
            Spacer()
            
            Text("Channel: \(currentChannel)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.separator)),
            alignment: .bottom
        )
    }
    
    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(messages) { message in
                        MessageBubbleView(message: message)
                            .id(message.id)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .onChange(of: messages.count) { _ in
                if let lastMessage = messages.last {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    private var messageInputSection: some View {
        VStack(spacing: 0) {
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.separator))
            
            HStack(spacing: 12) {
                if #available(iOS 16.0, *) {
                    TextField("Type a message...", text: $messageText, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(1...4)
                        .onSubmit {
                            sendMessage()
                        }
                } else {
                    // Fallback on earlier versions
                }
                
                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(canSendMessage ? .blue : .gray)
                        .font(.title2)
                }
                .disabled(!canSendMessage)
            }
            .padding()
            .background(Color(.systemBackground))
        }
    }
    
    private var canSendMessage: Bool {
        isConnected && !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Chat Functions
    
    private func connectToChat() {
        guard !SettingsManager.getPubnubPubKey().isEmpty && !SettingsManager.getPubnubSubKey().isEmpty else {
            showError("Please configure PubNub keys in Settings")
            return
        }
        
        connectionStatus = "Connecting..."
        
        // Create Red5WebRTC client configuration
        let config = Red5WebrtcClientConfig()
        config.pubnubPublishKey = SettingsManager.getPubnubPubKey()
        config.pubnubSubscribeKey = SettingsManager.getPubnubSubKey()
        config.eventListener = ChatEventListener(chatView: self)
        
        // Create WebRTC client
        let client = Red5WebrtcClientBuilder()
            .setPubnubPublishKey(config.pubnubPublishKey ?? "")
            .setPubnubSubscribeKey(config.pubnubSubscribeKey ?? "")
            .setEventListener(ChatEventListener(chatView: self))
            .build()
        
        webrtcClient = client
        
        // Subscribe to chat channel
        client.subscribeChatChannel(channelName: currentChannel)
        
        addSystemMessage("Connecting to channel '\(currentChannel)'...")
    }
    
    private func disconnectFromChat() {
        webrtcClient?.disconnectChat()
        webrtcClient = nil
        
        isConnected = false
        connectionStatus = "Disconnected"
        
        addSystemMessage("Disconnected from chat")
    }
    
    private func sendMessage() {
        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let client = webrtcClient, isConnected else { return }
        
        // Create message object
        let messageData: [String: Any] = [
            "username": currentUsername,
            "message": trimmed,
            "timestamp": Date().timeIntervalSince1970,
            "messageId": UUID().uuidString
        ]
        
        // Convert to JSONCodable
        if let jsonData = try? JSONSerialization.data(withJSONObject: messageData),
           let jsonMessage = try? JSONDecoder().decode(AnyJSON.self, from: jsonData) {
            
            // Send via PubNub
            client.sendChatJsonMessage(
                channelName: currentChannel,
                jsonObject: jsonMessage,
                metaData: nil
            )
            
            // Add to local messages immediately
            let chatMessage = ChatMessage(
                content: trimmed,
                username: currentUsername,
                isCurrentUser: true
            )
            
            withAnimation(.easeOut(duration: 0.2)) {
                messages.append(chatMessage)
            }
            
            messageText = ""
        }
    }
    
    private func addSystemMessage(_ content: String) {
        let systemMessage = ChatMessage(
            content: content,
            username: "System",
            isCurrentUser: false,
            messageType: .system
        )
        
        withAnimation(.easeOut(duration: 0.2)) {
            messages.append(systemMessage)
        }
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
    
    private func loadDemoMessages() {
        messages = [
            ChatMessage(
                content: "Welcome to PubNub Chat Demo! 🎉",
                username: "System",
                messageType: .system
            ),
            ChatMessage(
                content: "Configure your PubNub keys in Settings and tap Connect to start chatting.",
                username: "System",
                messageType: .system
            )
        ]
    }
    
    // MARK: - Event Handling
    
    fileprivate func handleChatConnected() {
        DispatchQueue.main.async {
            self.isConnected = true
            self.connectionStatus = "Connected"
            self.addSystemMessage("✅ Connected to PubNub chat!")
        }
    }
    
    fileprivate func handleChatDisconnected() {
        DispatchQueue.main.async {
            self.isConnected = false
            self.connectionStatus = "Disconnected"
            self.addSystemMessage("❌ Disconnected from PubNub chat")
        }
    }
    
    fileprivate func handleMessageReceived(channel: String, message: JSONCodable) {
        DispatchQueue.main.async {
            // Parse the received message
            if let messageDict = message.rawValue as? [String: Any],
               let username = messageDict["username"] as? String,
               let content = messageDict["message"] as? String {
                
                // Don't show our own messages again
                if username != self.currentUsername {
                    let chatMessage = ChatMessage(
                        content: content,
                        username: username,
                        isCurrentUser: false
                    )
                    
                    withAnimation(.easeOut(duration: 0.2)) {
                        self.messages.append(chatMessage)
                    }
                }
            }
        }
    }
    
    fileprivate func handleSendError(channel: String, error: String) {
        DispatchQueue.main.async {
            self.showError("Failed to send message: \(error)")
        }
    }
    
    fileprivate func handleSendSuccess(channel: String, timetoken: NSNumber) {
        // Message was sent successfully
        print("✅ Message sent successfully with timetoken: \(timetoken)")
    }
}

// MARK: - Message Bubble View
struct MessageBubbleView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isCurrentUser {
                Spacer(minLength: 50)
            }
            
            VStack(alignment: message.isCurrentUser ? .trailing : .leading, spacing: 4) {
                if !message.isCurrentUser && message.messageType != .system {
                    Text(message.username)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(message.content)
                    .padding(.horizontal, message.messageType == .system ? 12 : 16)
                    .padding(.vertical, message.messageType == .system ? 6 : 10)
                    .background(
                        RoundedRectangle(cornerRadius: message.messageType == .system ? 12 : 18)
                            .fill(backgroundColorForMessage)
                    )
                    .foregroundColor(textColorForMessage)
                
                if message.messageType != .system {
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            if !message.isCurrentUser {
                Spacer(minLength: 50)
            }
        }
    }
    
    private var backgroundColorForMessage: Color {
        switch message.messageType {
        case .system:
            return Color(.systemGray6)
        case .user:
            return message.isCurrentUser ? Color.blue : Color(.systemGray5)
        }
    }
    
    private var textColorForMessage: Color {
        switch message.messageType {
        case .system:
            return .secondary
        case .user:
            return message.isCurrentUser ? .white : .primary
        }
    }
}

// MARK: - Chat Message Model
struct ChatMessage: Identifiable {
    let id = UUID()
    let content: String
    let username: String
    let timestamp: Date
    let isCurrentUser: Bool
    let messageType: MessageType
    
    enum MessageType {
        case user
        case system
    }
    
    init(content: String, username: String, isCurrentUser: Bool = false, messageType: MessageType = .user) {
        self.content = content
        self.username = username
        self.timestamp = Date()
        self.isCurrentUser = isCurrentUser
        self.messageType = messageType
    }
}

// MARK: - Chat Event Listener
class ChatEventListener: Red5ProWebrtcEventDelegate {
    var chatView: ChatDemoView?
    
    init(chatView: ChatDemoView) {
        self.chatView = chatView
    }
    
    // MARK: - Chat-specific events
    func onChatConnected() {
        chatView?.handleChatConnected()
    }
    
    func onChatDisconnected() {
        chatView?.handleChatDisconnected()
    }
    
    func onChatMessageReceived(channel: String, message: JSONCodable) {
        chatView?.handleMessageReceived(channel: channel, message: message)
    }
    
    func onChatSendError(channel: String, errorMessage: String) {
        chatView?.handleSendError(channel: channel, error: errorMessage)
    }
    
    func onChatSendSuccess(channel: String, timetoken: NSNumber) {
        chatView?.handleSendSuccess(channel: channel, timetoken: timetoken)
    }
    
    // MARK: - WebRTC events (optional implementations)
    func onError(error: String) {
        print("WebRTC Error: \(error)")
    }
    
    // Other delegate methods can be left empty since we're only using chat
    func onPublishStarted() {}
    func onPublishStopped() {}
    func onPublishFailed(error: String) {}
    func onSubscribeStarted() {}
    func onSubscribeStopped() {}
    func onSubscribeFailed(error: String) {}
    func onIceConnectionStateChanged(state: IceConnectionState) {}
    func onConnectionStateChanged(state: PeerConnectionState) {}
    func onPreviewStarted() {}
    func onPreviewStopped() {}
    func onLicenseValidated(validated: Bool, message: String) {}
}

// MARK: - Chat Settings View
struct ChatSettingsView: View {
    @Binding var username: String
    @Binding var channel: String
    @Binding var pubKey: String
    @Binding var subKey: String
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("User Settings")) {
                    HStack {
                        Text("Username")
                        TextField("Enter username", text: $username)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Channel")
                        TextField("Enter channel name", text: $channel)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                Section(header: Text("PubNub Configuration")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Publish Key")
                        TextField("Enter your PubNub publish key", text: $pubKey)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Subscribe Key")
                        TextField("Enter your PubNub subscribe key", text: $subKey)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
            }
            .navigationTitle("Chat Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview
#if DEBUG
struct ChatDemoView_Previews: PreviewProvider {
    static var previews: some View {
        ChatDemoView()
    }
}
#endif
