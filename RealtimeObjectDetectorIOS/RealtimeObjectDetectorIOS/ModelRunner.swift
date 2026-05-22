//
//  ModelRunner.swift
//  RealtimeObjectDetectorIOS
//
//  Created by Emmanuel Emmanuel on 18/05/2026.
//
import TensorFlowLite
import Foundation
import CoreVideo
import CoreGraphics

struct LetterboxInfo {
    let inputData: Data
    let scale: CGFloat
    let padX: CGFloat
    let padY: CGFloat
    let originalWidth: Int
    let originalHeight: Int
}

final class ModelRunner {
    private var interpreter: Interpreter?
    private var labels: [String] = []
    
    init() {
        loadModel()
        loadLabels()
    }
    
    private func loadModel() {
        guard let modelPath = Bundle.main.path(forResource: "efficientdet_lite0", ofType: "tflite") else {
            print("Model file not found!")
            return
        }
        
        do {
            interpreter = try Interpreter(modelPath: modelPath)
            try interpreter?.allocateTensors()
            print("Model loaded successfully")
            logModelInfo()
        } catch {
            print("Failed to load model: \(error)")
        }
    }
    
    private func loadLabels() {
        guard let path = Bundle.main.path(forResource: "labels", ofType: "txt") else {
            print("Labels file not found")
            return
        }
        
        do {
            let text = try String(contentsOfFile: path, encoding: .utf8)
            labels = text
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines)}
                .filter { !$0.isEmpty }
            print("Labels loaded: \(labels.count)")
        } catch {
            print("Faile to load labels: \(error)")
        }
    }
    
    private func logModelInfo() {
        guard let interpreter else { return }
        do {
            let inputTensor = try interpreter.input(at: 0)
            
            print("Input tensor shape: \(inputTensor.shape)")
            print("Input tensor type: \(inputTensor.dataType)")
            
            let outputCount = interpreter.outputTensorCount
            print("Output tensor count: \(outputCount)")
            
            for i in 0..<outputCount {
                let outputTensor = try interpreter.output(at: i)
                print("Output \(i) shape: \(outputTensor.shape), type: \(outputTensor.dataType)")
                
            }
        } catch {
            print("Failed to log model info: \(error)")
        }
    }
    
    func detect(pixelBuffer: CVPixelBuffer) -> [Detection] {
        guard let interpreter else { return [] }
        
        guard let letterbox = pixelBufferToLetterboxInput(pixelBuffer) else {
            return []
        }
        
        do {
            try interpreter.copy(letterbox.inputData, toInputAt: 0)
            try interpreter.invoke()
            
            let boxesTensor = try interpreter.output(at: 0)
            let classesTensor = try interpreter.output(at: 1)
            let scoresTensor = try interpreter.output(at: 2)
            let countTensor = try interpreter.output(at: 3)
            
            let boxes = boxesTensor.data.toFloatArray()
            let classes = classesTensor.data.toFloatArray()
            let scores = scoresTensor.data.toFloatArray()
            let count = Int(countTensor.data.toFloatArray().first ?? 0)
            
            return parseDetections(
                boxes: boxes,
                classes: classes,
                scores: scores,
                count: count,
                letterbox: letterbox
            )
        } catch {
            print("Detection failed: \(error)")
            return []
        }
    }
    
    private func parseDetections(
    boxes: [Float],
    classes: [Float],
    scores: [Float],
    count: Int,
    letterbox: LetterboxInfo
    
    ) -> [Detection]{
     
        var detections: [Detection] = []
        
        let inputSize: CGFloat = 320.0
        let maxDetections = min(count, 25)
        
        for i in 0..<maxDetections {
            let score = scores[i]
            if score < 0.3 { continue }
            let classIndex = Int(classes[i]) + 1
            let label: String
            if classIndex >= 0 && classIndex < labels.count {
                label = labels[classIndex]
            }else {
                label = "Unknown"
            }
            let boxOffset = i * 4
            
            let ymin = CGFloat(boxes[boxOffset+0]).clamped(to: 0...1) * inputSize
            let xmin = CGFloat(boxes[boxOffset+1]).clamped(to: 0...1) * inputSize
            let ymax = CGFloat(boxes[boxOffset+2]).clamped(to: 0...1) * inputSize
            let xmax = CGFloat(boxes[boxOffset+3]).clamped(to: 0...1) * inputSize
            
            let left = (xmin - letterbox.padX) / letterbox.scale
            let top = (ymin - letterbox.padY) / letterbox.scale
            let right = (xmax - letterbox.padX) / letterbox.scale
            let bottom = (ymax - letterbox.padY) / letterbox.scale
            
            let clippedLeft = max(0, min(left, CGFloat(letterbox.originalWidth)))
            let clippedTop = max(0, min(top, CGFloat(letterbox.originalHeight)))
            let clippedRight = max(0, min(right, CGFloat(letterbox.originalWidth)))
            let clippedBottom = max(0, min(bottom, CGFloat(letterbox.originalHeight)))
            
            let rect = CGRect(x: clippedLeft, y: clippedTop, width: clippedRight - clippedLeft, height: clippedBottom - clippedTop)
            
            detections.append(
                Detection(
                    label: label ,
                    confidence: score,
                    rect: rect
                )
            )
        }
        
        return detections
    }
    
    private func pixelBufferToLetterboxInput(_ pixelBuffer: CVPixelBuffer) -> LetterboxInfo? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return nil
        }

        let rawWidth = CVPixelBufferGetWidth(pixelBuffer)      // usually 640
        let rawHeight = CVPixelBufferGetHeight(pixelBuffer)    // usually 480
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)

        // After 90-degree rotation, logical image becomes portrait-ish:
        let imageWidth = rawHeight     // 480
        let imageHeight = rawWidth     // 640

        let inputSize = 320

        let scale = min(
            CGFloat(inputSize) / CGFloat(imageWidth),
            CGFloat(inputSize) / CGFloat(imageHeight)
        )

        let scaledWidth = Int((CGFloat(imageWidth) * scale).rounded())
        let scaledHeight = Int((CGFloat(imageHeight) * scale).rounded())

        let padX = CGFloat(inputSize - scaledWidth) / 2.0
        let padY = CGFloat(inputSize - scaledHeight) / 2.0

        let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)

        var inputBytes = [UInt8]()
        inputBytes.reserveCapacity(inputSize * inputSize * 3)

        for y in 0..<inputSize {
            for x in 0..<inputSize {
                let sourceXInScaled = CGFloat(x) - padX
                let sourceYInScaled = CGFloat(y) - padY

                if sourceXInScaled < 0 ||
                    sourceYInScaled < 0 ||
                    sourceXInScaled >= CGFloat(scaledWidth) ||
                    sourceYInScaled >= CGFloat(scaledHeight) {

                    inputBytes.append(0)
                    inputBytes.append(0)
                    inputBytes.append(0)
                    continue
                }

                // Coordinates in rotated/upright image space
                let rotatedX = Int(sourceXInScaled / scale)
                let rotatedY = Int(sourceYInScaled / scale)

                let safeRotatedX = min(max(rotatedX, 0), imageWidth - 1)
                let safeRotatedY = min(max(rotatedY, 0), imageHeight - 1)

                // Map upright portrait coordinate back to raw landscape buffer.
                // 90° clockwise transform:
                let rawX = safeRotatedY
                let rawY = rawHeight - 1 - safeRotatedX

                let byteIndex = rawY * bytesPerRow + rawX * 4

                // BGRA memory
                let b = buffer[byteIndex]
                let g = buffer[byteIndex + 1]
                let r = buffer[byteIndex + 2]

                // Model wants RGB
                inputBytes.append(r)
                inputBytes.append(g)
                inputBytes.append(b)
            }
        }

        return LetterboxInfo(
            inputData: Data(inputBytes),
            scale: scale,
            padX: padX,
            padY: padY,
            originalWidth: imageWidth,
            originalHeight: imageHeight
        )
    }
}


extension Data {
    func toFloatArray() -> [Float] {
        return self.withUnsafeBytes { rawBuffer -> [Float] in
            // Bind the raw memory to Float
            let floatBuffer = rawBuffer.bindMemory(to: Float.self)
            return Array(floatBuffer)
        }
    }
}

extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
