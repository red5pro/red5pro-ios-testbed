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
    var shouldClear: Bool = false

    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .black
        
        renderer.contentMode = .scaleAspectFit
        renderer.videoContentMode = .scaleAspectFit
        renderer.backgroundColor = .black
        renderer.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(renderer)
        
        NSLayoutConstraint.activate([
            renderer.topAnchor.constraint(equalTo: containerView.topAnchor),
            renderer.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            renderer.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            renderer.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)
        ])
        
        return containerView
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if shouldClear {
            // Hide the renderer to show black background
            renderer.isHidden = true
            renderer.alpha = 0
        } else {
            // Show the renderer
            renderer.isHidden = false
            renderer.alpha = 1.0
        }
    }
}

#Preview {
    NavigationView {
        StandalonePublishScreen()
    }
}
