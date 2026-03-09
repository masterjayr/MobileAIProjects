//
//  ContentView.swift
//  SimpleAIiOS
//
//  Created by Emmanuel Emmanuel on 04/03/2026.
//

import SwiftUI

struct ContentView: View {
    @State private var inputText: String = ""
    @State private var outputText: String = "Output: -"
    @State private var latencyText: String = "Latency: -"
    
    var body: some View {
        VStack(spacing: 16) {
            TextField("Enter number", text: $inputText)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
            
            Button("Run Inference") {
                runInference()
            }
            .buttonStyle(.borderedProminent)
            
            Text(outputText).font(.title3)
            Text(latencyText).font(.body).foregroundStyle(.secondary)
        }
        .padding(24)
        .onAppear {
            do {
                try ModelRunner.shared.load()
            } catch {
                outputText = "Load error: \(error.localizedDescription)"
            }
        }
    }
    
    private func runInference() {
        let value = Float(inputText) ?? 0.0
        
        let start = CFAbsoluteTimeGetCurrent()
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let result = try ModelRunner.shared.run(input: value)
                let end = CFAbsoluteTimeGetCurrent()
                
                DispatchQueue.main.async {
                    outputText = "Output: \(result)"
                    latencyText = String(format: "Latency: %.2f ms", (end - start) * 1000)
                }
            } catch {
                DispatchQueue.main.async {
                    outputText = "Run error: \(error.localizedDescription)"
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
