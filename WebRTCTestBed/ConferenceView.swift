//
//  ConferenceView.swift
//  WebRTCTestBed
//
//  Created by Red5Pro on 12.12.2025.
//

import SwiftUI
import Red5WebRTCKit
import WebRTC

struct ConferenceView: View {
    @StateObject private var viewModel = ConferenceViewModel()
    
    @State private var roomId: String = "room1"
    @State private var userName: String = "user1"
    @State private var role: String = "publisher" // publisher or subscriber
    
    // UI States
    @State private var micEnabled = true
    @State private var cameraEnabled = true
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if !viewModel.isJoined {
                // MARK: - Join Screen
                joinScreen
            } else {
                // MARK: - Conference Screen
                conferenceScreen
            }
        }
        .onAppear {
            // Optional: Auto-fill distinct username
            userName = "user_\(Int.random(in: 100...999))"
        }
        .onDisappear {
            viewModel.cleanup()
        }
    }
    
    var joinScreen: some View {
        VStack(spacing: 20) {
            Text("Red5 Conference")
                .font(.title)
                .foregroundColor(.white)
            
            VStack(alignment: .leading) {
                Text("Room ID")
                    .foregroundColor(.gray)
                TextField("Enter Room ID", text: $roomId)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
            }
            .padding(.horizontal)
            
            VStack(alignment: .leading) {
                Text("User Name")
                    .foregroundColor(.gray)
                TextField("Enter User Name", text: $userName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
            }
            .padding(.horizontal)
            
            Picker("Role", selection: $role) {
                Text("Publisher").tag("publisher")
                Text("Subscriber").tag("subscriber")
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            Button(action: {
                viewModel.setupClient(role: role)
                viewModel.joinRoom(roomId: roomId, userId: userName, role: role)
            }) {
                Text("Join Room")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(10)
            }
            .padding()
            
            Text(viewModel.statusMessage)
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
    
    var conferenceScreen: some View {
        VStack {
            // Header
            HStack {
                Text("Room: \(viewModel.roomName)")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Button("Leave") {
                    viewModel.leaveRoom()
                }
                .foregroundColor(.red)
            }
            .padding()
            .background(Color.black.opacity(0.8))
            
            // Grid
            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    
                    // 1. Local Preview (if publisher)
                    if role == "publisher", let localRenderer = viewModel.localVideoRenderer {
                        ZStack {
                            WebRTCPreviewView(renderer: localRenderer)
                                .aspectRatio(3/4, contentMode: .fill)
                                .frame(height: 200)
                                .cornerRadius(8)
                                .clipped()
                            
                            VStack {
                                Spacer()
                                HStack {
                                    Text("Me (\(userName))")
                                        .font(.caption)
                                        .padding(4)
                                        .background(Color.black.opacity(0.5))
                                        .foregroundColor(.white)
                                        .cornerRadius(4)
                                    Spacer()
                                }
                            }
                            .padding(4)
                        }
                    }
                    
                    // 2. Remote Participants
                    ForEach(viewModel.participantRenderers.sorted(by: { $0.key < $1.key }), id: \.key) { streamId, renderer in
                        ZStack {
                            WebRTCPreviewView(renderer: renderer)
                                .aspectRatio(3/4, contentMode: .fill)
                                .frame(height: 200)
                                .cornerRadius(8)
                                .clipped()
                            
                            VStack {
                                Spacer()
                                HStack {
                                    Text(streamId)
                                        .font(.caption)
                                        .padding(4)
                                        .background(Color.black.opacity(0.5))
                                        .foregroundColor(.white)
                                        .cornerRadius(4)
                                    Spacer()
                                }
                            }
                            .padding(4)
                        }
                    }
                }
                .padding()
            }
            
            // Footer Controls
            if role == "publisher" {
                HStack(spacing: 30) {
                    Button(action: {
                        micEnabled.toggle()
                        viewModel.toggleMic()
                    }) {
                        Image(systemName: micEnabled ? "mic.fill" : "mic.slash.fill")
                            .font(.title)
                            .foregroundColor(micEnabled ? .white : .red)
                            .frame(width: 50, height: 50)
                            .background(Color.gray.opacity(0.5))
                            .clipShape(Circle())
                    }
                    
                    Button(action: {
                        cameraEnabled.toggle()
                        viewModel.toggleCamera()
                    }) {
                        Image(systemName: cameraEnabled ? "video.fill" : "video.slash.fill")
                            .font(.title)
                            .foregroundColor(cameraEnabled ? .white : .red)
                            .frame(width: 50, height: 50)
                            .background(Color.gray.opacity(0.5))
                            .clipShape(Circle())
                    }
                    
                    Button(action: {
                        viewModel.switchCamera()
                    }) {
                        Image(systemName: "camera.rotate.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(Color.gray.opacity(0.5))
                            .clipShape(Circle())
                    }
                }
                .padding()
                .background(Color.black.opacity(0.8))
            }
        }
    }
}
