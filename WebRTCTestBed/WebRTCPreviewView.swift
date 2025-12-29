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
    let renderer: RTCVideoRenderer
    var shouldClear: Bool = false

    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .black
        
        if let videoView = renderer as? UIView {
            
            if let mtlView = videoView as? RTCMTLVideoView {
                mtlView.videoContentMode = .scaleAspectFit
            }
            
            videoView.contentMode = .scaleAspectFit
            videoView.backgroundColor = .black
            videoView.translatesAutoresizingMaskIntoConstraints = false
            
            containerView.addSubview(videoView)
            
            NSLayoutConstraint.activate([
                videoView.topAnchor.constraint(equalTo: containerView.topAnchor),
                videoView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
                videoView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                videoView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)
            ])
        }
        
        return containerView
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let videoView = renderer as? UIView {
            if shouldClear {
                videoView.isHidden = true
                videoView.alpha = 0
            } else {
                videoView.isHidden = false
                videoView.alpha = 1.0
            }
        }
    }
}

#Preview {
    NavigationView {
        StandalonePublishScreen()
    }
}
