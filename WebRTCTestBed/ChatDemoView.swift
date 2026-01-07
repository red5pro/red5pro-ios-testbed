//
//  ChatDemoView.swift
//  WebRTCTestBed
//
//  Created by Mustafa BOLEKEN on 27.10.2025.
//

import SwiftUI
import PubNubSDK
import Red5WebRTCKit
import Red5PubNubClient

// MARK: - Chat Demo View
struct ChatDemoView: View {
    @State private var messageText = ""
    @State private var messages: [ChatMessage] = []
    @State private var isConnected = false
    @State private var connectionStatus = "Disconnected"
    @State private var currentUsername = "User\(Int.random(in: 1000...9999))"
    @State private var currentChannel = "room1"
    @State private var showingSettings = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var isLicenseValidated = false
    @State private var licenseCheckInProgress = false
    @State private var showingLogs = false

    // Red5Pro WebRTC Client
    @State private var webrtcClient: Red5PubNubClient?

    // Configuration
    @State private var pubKey = SettingsManager.shared.pubnubPubKey
    @State private var subKey = SettingsManager.shared.pubnubSubKey

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
                    HStack(spacing: 12) {
                        Button(action: {
                            showingLogs = true
                        }) {
                            Image(systemName: "list.bullet.rectangle")
                        }
                        
                        Button(isConnected ? "Disconnect" : "Connect") {
                            if isConnected {
                                disconnectFromChat()
                            } else {
                                connectToChat()
                            }
                        }
                        .foregroundColor(isConnected ? .red : (canConnect ? .blue : .gray))
                        .disabled(!canConnect && !isConnected)
                    }
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
            .sheet(isPresented: $showingLogs) {
                LogsView()
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "Unknown error occurred")
            }
            .onAppear {
                currentChannel = SettingsManager.getPubnubChannel()
                loadDemoMessages()
                initializeClient()
            }
            .onDisappear {
                cleanup()
            }
        }
    }

    // MARK: - UI Components

    private var connectionStatusHeader: some View {
        HStack {
            HStack(spacing: 6) {
                Circle()
                    .fill(statusIndicatorColor)
                    .frame(width: 8, height: 8)
                Text(connectionStatus)
                    .font(.caption)
                    .foregroundColor(statusTextColor)
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

    private var statusIndicatorColor: Color {
        if isConnected {
            return .green
        } else if licenseCheckInProgress {
            return .orange
        } else if isLicenseValidated {
            return .gray
        } else {
            return .red
        }
    }

    private var statusTextColor: Color {
        if isConnected {
            return .green
        } else if licenseCheckInProgress {
            return .orange
        } else if isLicenseValidated {
            return .gray
        } else {
            return .red
        }
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
                    TextField("Type a message...", text: $messageText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
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

    private var canConnect: Bool {
        isLicenseValidated && !licenseCheckInProgress
    }

    // MARK: - Initialization

    private func initializeClient() {
        guard !SettingsManager.getPubnubPubKey().isEmpty && !SettingsManager.getPubnubSubKey().isEmpty else {
            addSystemMessage("Please configure PubNub keys in Settings")
            connectionStatus = "Configuration Required"
            return
        }

        licenseCheckInProgress = true
        connectionStatus = "Validating license..."

        // Create Red5WebRTC client configuration
        let config = Red5WebrtcClientConfig()
        config.pubnubPublishKey = SettingsManager.getPubnubPubKey()
        config.pubnubSubscribeKey = SettingsManager.getPubnubSubKey()
        config.pubnubAuthKey = SettingsManager.getPubnubToken()
        config.eventListener = ChatEventListener(chatView: self)
        config.licenseKey = SettingsManager.getSdkLicenseKey()
        
        let pubNubClient = Red5PubNubClient(config: config, webrtcClientListener: ChatEventListener(chatView: self))

        webrtcClient = pubNubClient

        addSystemMessage("Initializing chat client...")
    }

    // MARK: - Chat Functions

    private func connectToChat() {
        guard let client = webrtcClient else {
            showError("Client not initialized. Please restart the app.")
            return
        }

        guard isLicenseValidated else {
            showError("License not validated. Please wait for validation to complete.")
            return
        }

        guard !SettingsManager.getPubnubPubKey().isEmpty && !SettingsManager.getPubnubSubKey().isEmpty else {
            showError("Please configure PubNub keys in Settings")
            return
        }

        connectionStatus = "Connecting..."

        // Subscribe to chat channel
        client.subscribeChannel(channelName: currentChannel)

        addSystemMessage("Connecting to channel '\(currentChannel)'...")
    }

    private func disconnectFromChat() {
        webrtcClient?.disconnect()

        isConnected = false
        connectionStatus = isLicenseValidated ? "Disconnected" : "License Validation Required"

        addSystemMessage("Disconnected from chat")
    }

    private func cleanup() {
        if isConnected {
            disconnectFromChat()
        }
        webrtcClient = nil
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        
        // Set the date format
        formatter.dateFormat = "EEE MMM dd yyyy HH:mm:ss 'GMT'Z '(GMT'XXX')'"
        
        return formatter.string(from: date)
    }

    private func sendMessage() {
        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let client = webrtcClient, isConnected else { return }
        let now = Date()

        // Create message object
        let messageData: [String: Any] = [
            "username": currentUsername,
            "name": currentUsername,
            "message": trimmed,
            "eventType": "MESSAGE_RECEIVED",
            "date": formatDate(now),
            "timestamp": Date().timeIntervalSince1970,
            "messageId": UUID().uuidString
        ]

        // Convert to JSONCodable
        if let jsonData = try? JSONSerialization.data(withJSONObject: messageData),
           let jsonMessage = try? JSONDecoder().decode(AnyJSON.self, from: jsonData) {

            // Send via PubNub
//            client.sendJsonMessage(
//                channelName: currentChannel,
//                jsonObject: jsonMessage,
//                metaData: nil
//            )

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
                content: "Welcome to Chat Demo!",
                username: "System",
                messageType: .system
            ),
            ChatMessage(
                content: "Validating license...",
                username: "System",
                messageType: .system
            )
        ]
    }

    // MARK: - Event Handling

    fileprivate func handleLicenseValidated(validated: Bool, message: String) {
        DispatchQueue.main.async {
            self.licenseCheckInProgress = false
            self.isLicenseValidated = validated

            if validated {
                self.connectionStatus = "Ready to Connect"
                self.addSystemMessage("✓ License validated successfully!")
                self.addSystemMessage("Configure your PubNub keys in Settings and tap Connect to start chatting.")
            } else {
                self.connectionStatus = "License Error"
                self.addSystemMessage("✗ License validation failed: \(message)")
                self.showError("License validation failed: \(message)")
            }
        }
    }

    fileprivate func handleChatConnected() {
        DispatchQueue.main.async {
            self.isConnected = true
            self.connectionStatus = "Connected"
            self.addSystemMessage("✓ Connected to chat!")
        }
    }

    fileprivate func handleChatDisconnected() {
        DispatchQueue.main.async {
            self.isConnected = false
            self.connectionStatus = self.isLicenseValidated ? "Disconnected" : "License Validation Required"
            self.addSystemMessage("Disconnected from chat")
        }
    }

    fileprivate func handleMessageReceived(channel: String, message: JSONCodable) {
        DispatchQueue.main.async {
            // Parse the received message
            if let messageDict = message.rawValue as? [String: Any],
               let username = messageDict["name"] as? String,
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
        LogManager.shared.info("Chat", "Message sent successfully with timetoken: \(timetoken)")
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

    // MARK: - License Validation
    func onLicenseValidated(validated: Bool, message: String) {
        chatView?.handleLicenseValidated(validated: validated, message: message)
    }

    // MARK: - Chat-specific events
    func onChatConnected() {
        chatView?.handleChatConnected()
    }

    func onChatDisconnected() {
        chatView?.handleChatDisconnected()
    }

    func onChatMessageReceived(channel: String, message: Any) {
        chatView?.handleMessageReceived(channel: channel, message: message as! JSONCodable)
    }

    func onChatSendError(channel: String, errorMessage: String) {
        chatView?.handleSendError(channel: channel, error: errorMessage)
    }

    func onChatSendSuccess(channel: String, timetoken: NSNumber) {
        chatView?.handleSendSuccess(channel: channel, timetoken: timetoken)
    }

    // MARK: - WebRTC events (optional implementations)
    func onError(error: String) {
        LogManager.shared.error("WebRTC", "WebRTC Error: \(error)")
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
