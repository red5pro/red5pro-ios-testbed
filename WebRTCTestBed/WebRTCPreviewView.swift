//
//  WebRTCPreviewView.swift
//  WebRTCTestBed
//
//  Created by Mustafa BOLEKEN on 28.10.2025.
//

import SwiftUI
import WebRTC

// MARK: - WebRTC Preview View
struct WebRTCPreviewView: UIViewRepresentable {
    let renderer: RTCMTLVideoView

    func makeUIView(context: Context) -> RTCMTLVideoView {
        // Ensure the renderer is properly configured
        renderer.contentMode = .scaleAspectFill
        renderer.videoContentMode = .scaleAspectFill
        
        // Make sure the view is visible and not hidden
        renderer.isHidden = false
        renderer.alpha = 1.0
        renderer.backgroundColor = .clear
        
        return renderer
    }

    func updateUIView(_ uiView: RTCMTLVideoView, context: Context) {
        // Ensure the view remains visible
        uiView.isHidden = false
        uiView.alpha = 1.0
    }
}

#Preview {
    NavigationView {
        StandalonePublishScreen()
    }
}
