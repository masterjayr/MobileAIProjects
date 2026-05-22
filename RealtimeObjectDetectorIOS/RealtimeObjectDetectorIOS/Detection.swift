//
//  Detection.swift
//  RealtimeObjectDetectorIOS
//
//  Created by Emmanuel Emmanuel on 18/05/2026.
//
import Foundation
import CoreGraphics

struct Detection: Identifiable {
    let id = UUID()
    let label: String
    let confidence: Float
    
    // Box in image pixel coordinates after letterbox reversal
    let rect: CGRect
}
