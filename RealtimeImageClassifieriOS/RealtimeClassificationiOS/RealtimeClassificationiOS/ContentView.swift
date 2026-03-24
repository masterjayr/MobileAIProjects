//
//  ContentView.swift
//  RealtimeClassificationiOS
//
//  Created by Emmanuel Emmanuel on 23/03/2026.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()
    var body: some View {
        ZStack(alignment: .bottom) {
            CameraPreview(session: cameraManager.session)
                .ignoresSafeArea()
            Text(cameraManager.prediction)
                .font(.title3)
                .foregroundColor(.white)
                .padding()
                .background(.black.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.bottom, 40)
        }
        .onAppear {
            cameraManager.configureSession()
        }
    }
}

#Preview {
    ContentView()
}
