//
//  WebRTCPreviewView.swift
//  SampleApp
//
//  Created by Mustafa BOLEKEN on 23.10.2025.
//

import SwiftUI
import WebRTC

// MARK: - WebRTC Preview View
struct WebRTCPreviewView: UIViewRepresentable {
    let renderer: RTCMTLVideoView
    
    func makeUIView(context: Context) -> RTCMTLVideoView {
        renderer.contentMode = .scaleAspectFill
        renderer.videoContentMode = .scaleAspectFill
        return renderer
    }
    
    func updateUIView(_ uiView: RTCMTLVideoView, context: Context) {
        // No updates needed - WebRTC handles everything
    }
}

#Preview {
    NavigationView {
        StandalonePublishScreen()
    }
}
