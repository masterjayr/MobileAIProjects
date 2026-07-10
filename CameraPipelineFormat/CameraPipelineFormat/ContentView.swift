//
//  ContentView.swift
//  CameraPipelineFormat
//
//  Created by Emmanuel Emmanuel on 09/07/2026.
//

import SwiftUI

struct ContentView: View {
    @StateObject var cameraManager = CameraManager()
    
    var body: some View {
        ZStack {
            CameraPreview(session: cameraManager.session)
                .ignoresSafeArea()
            HStack {
                Button("Set Zoom") {
                    cameraManager.setZoom(2.0)
                }
                Button("Set FPS") {
                    cameraManager.setFPS(15)
                }
                Button("Toggle Torch") {
                    cameraManager.toggleTorch()
                }
            }
            .task {
                await cameraManager.checkPermission()
                cameraManager.startRunning()
            }
        }
    }
}

#Preview {
    ContentView()
}
