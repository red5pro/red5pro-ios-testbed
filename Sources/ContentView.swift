//
//  ContentView.swift
//  TestBed
//
//  Created by Mustafa BOLEKEN on 21.10.2025.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack {
                GridView()
                    .navigationTitle("")
            }
        } else {
            // Fallback on earlier versions
        }
    }
}

struct GridView: View {
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

// Screen 1: Profile
struct ProfileScreen: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.circle.fill")
                .resizable()
                .frame(width: 100, height: 100)
                .foregroundColor(.blue)
            
            Text("Profile Screen")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("View and edit your profile")
                .font(.body)
                .foregroundColor(.gray)
            
            Spacer()
        }
        .padding()
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// Screen 3: Notifications
struct NotificationsScreen: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "bell.fill")
                .resizable()
                .frame(width: 100, height: 100)
                .foregroundColor(.orange)
            
            Text("Notifications Screen")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Check your notifications")
                .font(.body)
                .foregroundColor(.gray)
            
            Spacer()
        }
        .padding()
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// Screen 4: Messages
struct MessagesScreen: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "message.fill")
                .resizable()
                .frame(width: 100, height: 100)
                .foregroundColor(.green)
            
            Text("Messages Screen")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Read your messages")
                .font(.body)
                .foregroundColor(.gray)
            
            Spacer()
        }
        .padding()
        .navigationTitle("Messages")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// Screen 5: Favorites
struct FavoritesScreen: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "star.fill")
                .resizable()
                .frame(width: 100, height: 100)
                .foregroundColor(.yellow)
            
            Text("Favorites Screen")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Your favorite items")
                .font(.body)
                .foregroundColor(.gray)
            
            Spacer()
        }
        .padding()
        .navigationTitle("Favorites")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// Default screen for other items
struct DefaultDetailScreen: View {
    let item: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.fill")
                .resizable()
                .frame(width: 100, height: 100)
                .foregroundColor(.purple)
            
            Text("Detail Screen")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("You selected: \(item)")
                .font(.title2)
            
            Spacer()
        }
        .padding()
        .navigationTitle(item)
        .navigationBarTitleDisplayMode(.inline)
    }
}
