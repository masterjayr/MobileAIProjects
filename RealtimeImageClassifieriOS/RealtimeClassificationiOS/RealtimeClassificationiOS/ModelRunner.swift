//
//  ModelRunner.swift
//  RealtimeClassificationiOS
//
//  Created by Emmanuel Emmanuel on 23/03/2026.
//
import TensorFlowLite

final class ModelRunner {
    static let shared = ModelRunner()
    
    private var interpreter: Interpreter?
    private var labels: [String] = []
    
    private init() {
        loadModel()
        loadLabels()
    }
    
    private func loadModel() {
        guard let modelPath = Bundle.main.path(forResource: "mobilenet_v1_1.0_224", ofType: "tflite") else {
            print("Model file not found")
            return 
        }
        do {
            interpreter = try Interpreter(modelPath: modelPath)
            try interpreter?.allocateTensors()
            print("Interpreter loaded")
        } catch {
            print("Failed to load model: \(error)")
        }
    }
    
    private func loadLabels() {
        guard let path = Bundle.main.path(forResource: "labels", ofType: "txt") else {
            print("labels.txt not found")
            return
        }
        
        do {
            let text = try String(contentsOfFile: path, encoding: .utf8)
            labels = text
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines)}
                .filter{ !$0.isEmpty }
        } catch {
            print("Failed to load labels: \(error)")
        }
    }
    
    func classify(pixelBuffer: CVPixelBuffer) -> (String, Float) {
        guard let interpreter else {
            return ("Interpreter not loaded", 0.0)
        }
        
        guard let inputData = pixelBufferToInputData(pixelBuffer) else {
            return ("Preprocess failed", 0.0)
        }
        
        do {
            try interpreter.copy(inputData, toInputAt: 0)
            try interpreter.invoke()
            
            let outputTensor = try interpreter.output(at: 0)
            let scores = outputTensor.data.toFloatArray()
            
            guard !scores.isEmpty else {
                return ("No output", 0.0)
            }
            var maxIndex = 0
            var maxScore = scores[0]
            
            for i in 1..<scores.count {
                if scores[i] > maxScore {
                    maxScore = scores[i]
                    maxIndex = i
                }
            }
            
            let labelIndex = labels.count == 1000 ? maxIndex - 1 : maxIndex
            let label: String
            
            if labelIndex >= 0 && labelIndex < labels.count {
                label = labels[labelIndex]
            } else {
                label = "Unknown"
            }
            
            return (label, maxScore)
        } catch {
            return ("Inference error", 0.0)
        }
    }
    
    private func pixelBufferToInputData(_ pixelBuffer: CVPixelBuffer) -> Data? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)}
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return nil
        }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        
        let targetSize = 224
        var inputData = Data(capacity: targetSize * targetSize * 3 * 4)
        let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)
        for ty in 0..<targetSize {
            for tx in 0..<targetSize {
                let srcX = tx * width / targetSize
                let srcY = ty * height / targetSize
                
                let pixelOffset = srcY * bytesPerRow + srcX * 4
                
                let b = Float(buffer[pixelOffset]) / 255.0
                let g = Float(buffer[pixelOffset + 1]) / 255.0
                let r = Float(buffer[pixelOffset + 2]) / 255.0
                
                var red = r
                var green = g
                var blue = b
                
                inputData.append(UnsafeBufferPointer(start: &red, count: 1))
                inputData.append(UnsafeBufferPointer(start: &green, count: 1))
                inputData.append(UnsafeBufferPointer(start: &blue, count: 1))
            }
        }
        return inputData
    }
}

extension Data {
    func toFloatArray() -> [Float] {
        let count = self.count / MemoryLayout<Float>.stride
        return self.withUnsafeBytes { rawBufferPointer in
            let buffer = rawBufferPointer.bindMemory(to: Float.self)
            return Array(buffer.prefix(count))
        }
    }
}
