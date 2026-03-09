//
//  ModelRunner.swift
//  SimpleAIiOS
//
//  Created by Emmanuel Emmanuel on 09/03/2026.
//
import TensorFlowLite

final class ModelRunner {
    static let shared = ModelRunner()
    
    private var interpreter: Interpreter?
    
    private init() {}
    
    func load() throws {
        if interpreter != nil { return }
        
        guard let modelPath = Bundle.main.path(forResource: "simple_model", ofType: "tflite") else {
            throw NSError(domain: "ModelRunner", code: 1, userInfo: [NSLocalizedDescriptionKey: "Model not found in bundle"])
        }
        interpreter = try Interpreter(modelPath: modelPath)
        try interpreter?.allocateTensors()
    }
    
    func run(input: Float) throws -> Float {
        guard let interpreter else {
            throw NSError(domain: "ModelRunner", code: 2, userInfo: [NSLocalizedDescriptionKey: "Interpreter not loaded"])
        }
        
        var inputValue = input
        let inputData = Data(bytes: &inputValue, count: MemoryLayout<Float>.size)
        
        try interpreter.copy(inputData, toInputAt: 0)
        try interpreter.invoke()
        
        let outputTensor = try interpreter.output(at: 0)
        let outputData = outputTensor.data
        
        let result = outputData.withUnsafeBytes { ptr -> Float in
            ptr.load(as: Float.self)
        }
        
        return result
    }
    
    
}
