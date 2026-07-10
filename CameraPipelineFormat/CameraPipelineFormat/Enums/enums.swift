//
//  enums.swift
//  CameraPipeline
//
//  Created by Emmanuel Emmanuel on 09/07/2026.
//
import Foundation

enum LoadingState<T> {
    case idle, loading, success(T), failure(String)
}

enum CameraError: Error, LocalizedError {
    case noCameraAccess, inputError, outputError
    
    var errorDescription: String? {
        switch self {
            
        case .noCameraAccess:
            return "No camera access"
        case .inputError:
            return "Camera Input Error"
        case .outputError:
            return "Camera Output Error"
        }
    }
}
