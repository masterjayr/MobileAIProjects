//
//  CameraManager.swift
//  CameraPipeline
//
//  Created by Emmanuel Emmanuel on 09/07/2026.
//
import AVFoundation
import Combine
import Foundation

final class CameraManager: NSObject, ObservableObject {
    @Published var state: LoadingState<String> = .idle
    @Published var isAuthorized: Bool = false
    
    // Dispatch Queues
    let sessionQueue = DispatchQueue(label: "camera.session.queue")
    let frameQueue = DispatchQueue(label: "camera.frame.queue")
    
    
    let session: AVCaptureSession = AVCaptureSession()
    var device: AVCaptureDevice? = nil
    var videoOutput: AVCaptureVideoDataOutput = AVCaptureVideoDataOutput()
    
    func checkPermission() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            isAuthorized = granted
        default:
            isAuthorized = false
        }
    }
    
    func setZoom(_ factor: CGFloat) {
        sessionQueue.async {
            do {
                try self.device?.lockForConfiguration()
                defer { self.device?.unlockForConfiguration()}
                let clamped = min(max(factor, 1.0), self.device?.activeFormat.videoMaxZoomFactor ?? 1.0)
                self.device?.videoZoomFactor = clamped
            } catch {
                print(error.localizedDescription)
            }
        }
    }
    
    func setFPS(_ fps: Int) {
        sessionQueue.async {
            do {
                try self.device?.lockForConfiguration()
                defer { self.device?.unlockForConfiguration()}
                self.device?.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: Int32(fps))
                self.device?.activeVideoMinFrameDuration = CMTime(value: 1, timescale: Int32(fps))
            } catch {
                print(error.localizedDescription)
            }
        }
    }
    
    func toggleTorch() {
        sessionQueue.async {
            do {
                try self.device?.lockForConfiguration()
                defer { self.device?.unlockForConfiguration()}
                guard self.device?.hasTorch ?? false else { return }
                if self.device?.torchMode == .on {
                    self.device?.torchMode = .off
                } else {
                    self.device?.torchMode = .on
                }
            } catch {
                print(error.localizedDescription)
            }
        }
    }
    func startRunning() {
        guard self.isAuthorized else { return }
        sessionQueue.async {
            self.session.beginConfiguration()
            
            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                self.session.commitConfiguration()
                DispatchQueue.main.async {
                    self.state = .failure(CameraError.noCameraAccess.localizedDescription)
                }
                return
            }
            self.device = camera
            
            do {
                let input = try AVCaptureDeviceInput(device: camera)
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                }else {
                    self.session.commitConfiguration()
                    DispatchQueue.main.async {
                        self.state = .failure(CameraError.inputError.localizedDescription)
                    }
                    
                }
            } catch {
                self.session.commitConfiguration()
                self.state = .failure(CameraError.inputError.localizedDescription)
            }
            
            self.videoOutput.alwaysDiscardsLateVideoFrames = true
            self.videoOutput.setSampleBufferDelegate(self, queue: self.frameQueue)
            self.videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            
            if self.session.canAddOutput(self.videoOutput) {
                self.session.addOutput(self.videoOutput)
            } else {
                self.session.commitConfiguration()
                DispatchQueue.main.async {
                    self.state = .failure(CameraError.outputError.localizedDescription)
                }
                return
            }
            self.session.commitConfiguration()
            self.session.startRunning()
            DispatchQueue.main.async {
                self.state = .success("Session running")
            }
        }
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)
        let calculatedBytesPerRow = width * 4
        print("Frame: \(width) x \(height)")
        print("BytesPerRow: \(bytesPerRow)")
        print("CalculatedBytesPerRow: \(calculatedBytesPerRow)")
    }
}
