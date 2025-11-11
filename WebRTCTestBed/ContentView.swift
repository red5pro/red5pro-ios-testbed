//
//  ContentView.swift
//  WebRTCTestBed
//
//  Created by Mustafa BOLEKEN on 21.10.2025.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack {
                GridView()
                    .navigationTitle("WebRTC Test Bed")
            }
        } else {
            // Fallback on earlier versions
        }
    }
}

struct GridView: View {
    @State private var showingLogs = false
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    let items = ["Standalone Publish Screen", "Standalone Subscribe Screen", "Stream Manager Publish Screen", "Stream Manager Subscribe Screen", "Chat Screen", "Settings"]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(items, id: \.self) { item in
                    NavigationLink(destination: destinationView(for: item)) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.blue)
                            .frame(height: 120)
                            .overlay(
                                Text(item)
                                    .foregroundColor(.white)
                                    .font(.headline)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 8)
                            )
                    }
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingLogs = true
                }) {
                    Image(systemName: "list.bullet.rectangle")
                }
            }
        }
        .sheet(isPresented: $showingLogs) {
            LogsView()
        }
    }

    // Route to different screens based on item
    @ViewBuilder
    func destinationView(for item: String) -> some View {
        switch item {
        case "Standalone Publish Screen":
            StandalonePublishScreen()
        case "Standalone Subscribe Screen":
            StandaloneSubscribeScreen()
        case "Stream Manager Publish Screen":
            StreamManagerPublishScreen()
        case "Stream Manager Subscribe Screen":
            StreamManagerSubscribeScreen()
        case "Chat Screen":
            ChatDemoView()
        case "Settings":
            SettingsScreen()
        default:
            SettingsScreen()
        }
    }
}
