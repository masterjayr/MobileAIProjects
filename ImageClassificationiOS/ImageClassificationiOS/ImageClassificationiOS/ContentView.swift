//
//  ContentView.swift
//  ImageClassificationiOS
//
//  Created by Emmanuel Emmanuel on 13/03/2026.
//

import SwiftUI
import UIKit

struct ContentView: View {
    @State private var selectedImage: UIImage?
    @State private var isShowingPicker = false
    @State private var prediction = "No prediction yet"
    @State private var isRunning = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let selectedImage {
                    Image(uiImage: selectedImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 250, height: 250)
                        .cornerRadius(12)
                    
                    
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 250, height: 250)
                        .overlay {
                            Text("No image selected")
                                .foregroundStyle(.gray)
                        }
                }
                Text("Prediction: \(prediction)")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                
                Button("Pick Image") {
                    isShowingPicker = true
                }
                .buttonStyle(.borderedProminent)
                
                Button(isRunning ? "Running..." : "Classify Image") {
                    runClassification()
                }
                .buttonStyle(.bordered)
                .disabled(selectedImage == nil || isRunning)
                
                Spacer()
            }
            .padding()
            .navigationTitle("iOS Image Classifier")
            .sheet(isPresented: $isShowingPicker) {
                PhotoPickerView(selectedImage: $selectedImage)
            }
        }
    }
    
    private func runClassification() {
        guard let selectedImage else { return }
        
        isRunning = true
        
        prediction = "Running..."
        
        DispatchQueue.global(qos: .userInitiated).async {
            let result = ModelRunner.shared.classify(image: selectedImage)
            
            DispatchQueue.main.async {
                prediction = result
                isRunning = false 
            }
        }
    }
}

#Preview {
    ContentView()
}
