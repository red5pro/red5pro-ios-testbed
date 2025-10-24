import SwiftUI

struct StreamManagerSubscribeScreen: View {
    @State private var isSubscribed = false
    @State private var viewerCount = 1234
    
    var body: some View {
        ZStack {
            // Full-size video player (placeholder)
            Color.black
                .ignoresSafeArea()
                .overlay(
                    // Simulated video view
                    VStack {
                        Image(systemName: "play.rectangle.fill")
                            .resizable()
                            .frame(width: 120, height: 80)
                            .foregroundColor(.white.opacity(0.3))
                        Text("Video Playing")
                            .foregroundColor(.white.opacity(0.5))
                            .font(.title2)
                    }
                )
            
            // Status indicator at top right
            VStack {
                HStack {
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 5) {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                            Text("LIVE")
                                .font(.caption)
                                .fontWeight(.bold)
                        }
                        
                        HStack(spacing: 5) {
                            Image(systemName: "eye.fill")
                                .font(.caption)
                            Text("\(viewerCount)")
                                .font(.caption)
                        }
                    }
                    .padding(10)
                    .background(Color.black.opacity(0.6))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding(.top, 10)
                    .padding(.trailing, 15)
                }
                
                Spacer()
            }
            
            // Subscribe button at the bottom
            VStack {
                Spacer()
                
                Button(action: {
                    isSubscribed.toggle()
                }) {
                    HStack {
                        Image(systemName: isSubscribed ? "checkmark.circle.fill" : "plus.circle.fill")
                            .font(.system(size: 20))
                        Text(isSubscribed ? "Subscribed" : "Subscribe")
                            .font(.headline)
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isSubscribed ? Color.gray : Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Play")
        .navigationBarTitleDisplayMode(.inline)
    }
}
