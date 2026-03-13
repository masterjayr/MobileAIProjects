//
//  ModelRunner.swift
//  ImageClassificationiOS
//
//  Created by Emmanuel Emmanuel on 13/03/2026.
//
import TensorFlowLite
import UIKit

class ModelRunner {
    static let shared = ModelRunner()
    
    private var interpreter: Interpreter?
    
    private let labels = [
            "airplane",
            "automobile",
            "bird",
            "cat",
            "deer",
            "dog",
            "frog",
            "horse",
            "ship",
            "truck"
    ]
    
    private init() {
        loadModel()
    }
    
    private func loadModel() {
        guard let modelPath = Bundle.main.path(forResource: "cifar10_model", ofType: "tflite") else {
            print("Model file not found in bundle.")
            return
        }
        
        do {
            interpreter = try Interpreter(modelPath: modelPath)
            try interpreter?.allocateTensors()
        } catch {
            print("Error loading model: \(error)")
        }
    }
    
    func classify(image: UIImage) -> String {
        guard let interpreter else {
            return "interpreter not loaded"
        }
        guard let resized = resizeImage(image: image) else {
            return "Failed to resize image"
        }
        
        guard let inputData = preprocess(image: resized) else {
            return "Failed to preprocess image"
        }
        
        do {
            try interpreter.copy(inputData, toInputAt: 0)
            try interpreter.invoke()
            
            let outputTensor = try interpreter.output(at: 0)
            
            let scores = outputTensor.data.toFloatArray()
            
            return argmax(scores)
            
        } catch {
            return "Inference error: \(error.localizedDescription)"
        }
    }
    
    func preprocess(image: UIImage) -> Data? {
        guard let cgImage = image.cgImage else { return nil }
        
        let width = 32
        let height = 32
        
        var data = Data(capacity: width * height * 3 * 4)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        var pixelData = [UInt8](repeating: 0, count: width * height * 4)
        
        let context = CGContext(data: &pixelData, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        
        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        for i in stride(from: 0, to: pixelData.count, by: 4) {
            let r = Float(pixelData[i]) / 255.0
            let g = Float(pixelData[i+1]) / 255.0
            let b = Float(pixelData[i+2]) / 255.0
            
            data.append(contentsOf: withUnsafeBytes(of: r) { Data($0) })
                   data.append(contentsOf: withUnsafeBytes(of: g) { Data($0) })
                   data.append(contentsOf: withUnsafeBytes(of: b) { Data($0) })
        }
        
        return data
    }
    
    func resizeImage(image: UIImage) -> UIImage? {
        let targetSize = CGSize(width: 32, height: 32)
        
        UIGraphicsBeginImageContextWithOptions(targetSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: targetSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return resizedImage
    }
    
    func argmax(_ array: [Float]) -> String {
        var maxIndex = 0
        var maxValue = array[0]
        
        for i in 1..<array.count {
            if array[i] > maxValue {
                maxValue = array[i]
                maxIndex = i
            }
        }
        return labels[maxIndex]
    }
}

extension Data {
    func toFloatArray() -> [Float] {
        let count = self.count / MemoryLayout<Float>.stride
        return self.withUnsafeBytes { bufferPointer in
            let floatPointer = bufferPointer.bindMemory(to: Float.self)
            return Array(floatPointer.prefix(count))
        }
    }
}
