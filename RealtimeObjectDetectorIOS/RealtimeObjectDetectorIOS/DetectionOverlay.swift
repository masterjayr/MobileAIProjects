//
//  DetectionOverlay.swift
//  RealtimeObjectDetectorIOS
//
//  Created by Emmanuel Emmanuel on 21/05/2026.
//

import SwiftUI

struct DetectionOverlay: View {
    let detections: [Detection]
    let imageSize: CGSize
    
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                    let canvasSize = size
                let imageAspect = imageSize.width / imageSize.height
                let canvasAspect = canvasSize.width / canvasSize.height
                
                var scale: CGFloat
                var offsetX: CGFloat = 0
                var offsetY: CGFloat = 0
                
                if imageAspect > canvasAspect {
                    scale = canvasSize.width / imageSize.width
                    let scaledHeight = imageSize.height * scale
                    offsetY = (canvasSize.height - scaledHeight) / 2
                } else {
                    scale = canvasSize.height / imageSize.height
                    let scaledWidth = imageSize.width * scale
                    offsetX = (canvasSize.width - scaledWidth) / 2
                }
                
                for detection in detections {
                    let rect = detection.rect
                    let left = rect.minX * scale + offsetX
                    let top = rect.minY * scale + offsetY
                    let right =  rect.maxX * scale + offsetX
                    let bottom = rect.maxY * scale + offsetY
                    
                    
                    let boxWidth = right - left
                    let boxHeight = bottom - top
                    
                    let paddingX = boxWidth * 0.08
                    let paddingY = boxHeight * 0.12
                    
                    
                    let drawRect = CGRect(
                        x: left - paddingX,
                        y: top - paddingY,
                        width: boxWidth + paddingX * 2,
                        height: boxHeight + paddingY * 2
                    )
                    
                    context.stroke(
                        Path(drawRect),
                        with: .color(.red),
                        lineWidth: 3
                    )
                    
                    let text = Text("\(detection.label) \(Int(detection.confidence * 100))%")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.red)
                    
                    context.draw(
                        text,
                        at: CGPoint(x: left+4, y: max(top-10, 10)),
                        anchor: .leading
                    )
                }
            }
        }
    }
}

