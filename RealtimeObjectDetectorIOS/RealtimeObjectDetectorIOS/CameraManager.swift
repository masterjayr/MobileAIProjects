//
//  CameraManager.swift
//  RealtimeObjectDetectorIOS
//
//  Created by Emmanuel Emmanuel on 20/05/2026.
//
import Foundation
import AVFoundation
import SwiftUI
import Combine

final class CameraManager: NSObject, ObservableObject {
    let session = AVCaptureSession()
    
    @Published var detections: [Detection] = Array<Detection>()
    
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let inferenceQueue = DispatchQueue(label: "camera.inference.queue")
    
    private let modelRunner = ModelRunner()
    
    private var isProcessing = false
    private let videoOutput = AVCaptureVideoDataOutput()
    
    
    func configureSession() {
        sessionQueue.async {
            self.session.beginConfiguration()
            self.session.sessionPreset = .vga640x480
            
            guard let camera = AVCaptureDevice.default(
                .builtInWideAngleCamera,
                for: .video,
                position: .back
            ) else {
                print("No back camera found")
                self.session.commitConfiguration()
                return
            }
            
            do {
                let input = try AVCaptureDeviceInput(device: camera)
                
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                } else {
                    print("Could not add camera input")
                }
                
                
                
                self.videoOutput.videoSettings = [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
                ]
                
                self.videoOutput.alwaysDiscardsLateVideoFrames = true
                
                self.videoOutput.setSampleBufferDelegate(self, queue: self.inferenceQueue)
                
                if self.session.canAddOutput(self.videoOutput) {
                    self.session.addOutput(self.videoOutput)
                    print("Video output added")
                } else {
                    print("Could not add video output")
                }
                
//                self.videoOutput.setSampleBufferDelegate(self, queue: self.inferenceQueue)
                
                
                if let connection = self.videoOutput.connection(with: .video) {
                    print("Video output connection exists: \(connection.isActive)")
                }else {
                    print("No video output connection")
                }
                self.session.commitConfiguration()
                self.session.startRunning()
                print("Session running: \(self.session.isRunning)")
            } catch {
                print("Camera configuration failed: \(error)")
                self.session.commitConfiguration()
            }
        }
    }
    
    
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
            _ output: AVCaptureOutput,
            didOutput sampleBuffer: CMSampleBuffer,
            from connection: AVCaptureConnection
        ) {
        print("FRAME RECEIVED")
        if isProcessing {
            return
        }
        
        isProcessing = true
        
        defer {
             isProcessing = false
        }
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("No pixel buffer")
            return
        }
        let width = CVPixelBufferGetWidth(pixelBuffer)

        let height = CVPixelBufferGetHeight(pixelBuffer)

        print("PixelBuffer size: \(width)x\(height)")
        
        let results = modelRunner.detect(pixelBuffer: pixelBuffer)

        print("Detections count: \(results.count)")
        DispatchQueue.main.async {
            self.detections=results
        }
    }
}
