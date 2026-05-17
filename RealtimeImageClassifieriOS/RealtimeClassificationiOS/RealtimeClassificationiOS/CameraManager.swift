//
//  CameraManager.swift
//  RealtimeClassificationiOS
//
//  Created by Emmanuel Emmanuel on 23/03/2026.
//
import Foundation
import AVFoundation
import SwiftUI
import Combine

final class CameraManager: NSObject, ObservableObject {
    let session = AVCaptureSession()
    
    @Published var prediction: String = "Detecting..."
    
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let inferenceQueue = DispatchQueue(label: "camera.inference.queue")
    
    private var isProcessing = false
    private var lastLabel: String = ""
    private var sameCount: Int = 0
    private let requiredConsistency = 3
    private var lastTime : CFTimeInterval = 0
    
    func configureSession() {
        sessionQueue.async {
            self.session.beginConfiguration()
            self.session.sessionPreset = .vga640x480
            
            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                print("No back camera found")
                self.session.commitConfiguration()
                return
            }
            
            do {
                let input = try AVCaptureDeviceInput(device: camera)
                
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                }
                
                let output = AVCaptureVideoDataOutput()
                output.videoSettings = [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
                ]
                output.setSampleBufferDelegate(self, queue: self.inferenceQueue)
                output.alwaysDiscardsLateVideoFrames = true
                
                if self.session.canAddOutput(output) {
                    self.session.addOutput(output)
                }
                self.session.commitConfiguration()
                self.session.startRunning()
            } catch {
                print("Failed to configure camera: \(error)")
                self.session.commitConfiguration()
            }
        }
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let currentTime = CACurrentMediaTime()
        if currentTime - lastTime < 0.1 { return }
        lastTime = currentTime
        if isProcessing { return }
        isProcessing = true
        
        defer { isProcessing = false }
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        let (label, confidence) = ModelRunner.shared.classify(pixelBuffer: pixelBuffer)
        
        if label == lastLabel {
            sameCount += 1
            
        }else {
            lastLabel = label
            sameCount = 1
        }
        
        if sameCount >= requiredConsistency && confidence > 0.5 {
            DispatchQueue.main.async {
                self.prediction = "\(label) (\(String(format: "%.2f", confidence))"
            }
        }
    }
}
