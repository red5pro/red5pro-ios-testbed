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
        renderer.contentMode = .scaleAspectFill
        renderer.videoContentMode = .scaleAspectFill
        
        renderer.isHidden = false
        renderer.alpha = 1.0
        renderer.backgroundColor = .clear
        
        return renderer
    }

    func updateUIView(_ uiView: RTCMTLVideoView, context: Context) {
        uiView.isHidden = false
        uiView.alpha = 1.0
    }
}

#Preview {
    NavigationView {
        StandalonePublishScreen()
    }
}
