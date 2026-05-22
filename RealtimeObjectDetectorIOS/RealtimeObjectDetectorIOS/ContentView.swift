//
//  ContentView.swift
//  RealtimeObjectDetectorIOS
//
//  Created by Emmanuel Emmanuel on 18/05/2026.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()
    
    var body: some View {
        ZStack {
            CameraPreview(session: cameraManager.session)
                .ignoresSafeArea()
            DetectionOverlay(detections: cameraManager.detections, imageSize: CGSize(width: 480, height: 640))
                .ignoresSafeArea()
        }
        .onAppear {
            cameraManager.configureSession()
        }
    }
}

#Preview {
    ContentView()
}
