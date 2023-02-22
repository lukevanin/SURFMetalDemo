//
//  ContentView.swift
//  SURFMetalApp
//
//  Created by Luke Van In on 2023/02/14.
//

import SwiftUI
import CoreGraphics
import simd

struct KeypointViewModel {
    var x: Float
    var y: Float
    var scale: Float
    var orientation: Float
}


struct SURFFeaturesView: View {
    
    @State var features: [KeypointViewModel]
    @State var zoom: CGFloat
    @State var color: Color
    
    var body: some View {
        Path { path in
            for feature in features {
                
                let m = makeScaleMatrix(scale: Float(zoom)) * makeTranslationMatrix(x: feature.x, y: feature.y) * makeRotationMatrix(angle: feature.orientation)

                let vMin = m * SIMD3(0, -feature.scale, 1)
                let vMax = m * SIMD3(0, +feature.scale, 1)
                
                let hMin = m * SIMD3(-feature.scale, 0, 1)
                let hMax = m * SIMD3(+feature.scale, 0, 1)
                
                path.move(to: CGPoint(vMin))
                path.addLine(to: CGPoint(vMax))

                path.move(to: CGPoint(vMin))
                path.addLine(to: CGPoint(hMin))
                
                path.move(to: CGPoint(vMin))
                path.addLine(to: CGPoint(hMax))

//                path.move(to: CGPoint(hMin))
//                path.addLine(to: CGPoint(hMax))
            }
        }
        .stroke(color, lineWidth: 1)
        .drawingGroup()
    }
}


struct SURFCompareView: View {
    
    let image: CGImage
    let sourceFeatures: [KeypointViewModel]
    let targetFeatures: [KeypointViewModel]
    let zoom: CGFloat
    
    var body: some View {
        ScrollView([.horizontal, .vertical], showsIndicators: true) {
            ZStack {
                Image(image, scale: 1, label: Text("Sample"))
                    .resizable()
                    .frame(width: CGFloat(image.width) * zoom, height: CGFloat(image.height) * zoom)
                    .brightness(-0.2)
                
//                Rectangle()
//                    .fill(.black.opacity(0.5))
//                    .frame(width: CGFloat(image.width) * zoom, height: CGFloat(image.height) * zoom)
                
                SURFFeaturesView(features: targetFeatures, zoom: zoom, color: .cyan)
                    .frame(width: CGFloat(image.width) * zoom, height: CGFloat(image.height) * zoom)
                    .blendMode(.plusLighter)
                
                SURFFeaturesView(features: sourceFeatures, zoom: zoom, color: .red)
                    .frame(width: CGFloat(image.width) * zoom, height: CGFloat(image.height) * zoom)
                    .blendMode(.plusLighter)
            }
            .frame(width: CGFloat(image.width) * zoom, height: CGFloat(image.height) * zoom)
            .padding()
        }
    }
}

private let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .indigo, .purple]

struct SURFCorrespondenceView: View {
    
    @State var sourceRect: CGRect
    @State var targetRect: CGRect
    @State var matches: [Match]
    @State var zoom: CGFloat
    @State var sourceColor: Color
    @State var targetColor: Color
    
    var body: some View {
        ForEach(matches) { match in
            Path { path in
                let sourcePoint = CGPoint(
                    x: sourceRect.origin.x + (CGFloat(match.a.keypoint.x) * zoom),
                    y: sourceRect.origin.y + (CGFloat(match.a.keypoint.y) * zoom)
                )
                let targetPoint = CGPoint(
                    x: targetRect.origin.x + (CGFloat(match.b.keypoint.x) * zoom),
                    y: targetRect.origin.y + (CGFloat(match.b.keypoint.y) * zoom)
                )
                
                path.move(to: sourcePoint)
                path.addLine(to: targetPoint)
            }
//            .stroke(LinearGradient(colors: [sourceColor, targetColor], startPoint: .leading, endPoint: .trailing), lineWidth: 2)
            .stroke(colors[match.id % colors.count], lineWidth: 1)
        }
        .drawingGroup()
        .blendMode(.plusLighter)
    }
}


struct SURFMatchView: View {
    
    let sourceImage: CGImage
    let targetImage: CGImage
    let matches: [Match]
    let zoom: CGFloat
    
    var sourceRect: CGRect {
        CGRect(
            x: 0,
            y: 0,
            width: CGFloat(sourceImage.width) * zoom,
            height: CGFloat(sourceImage.height) * zoom
        )
    }
    
    var targetRect: CGRect {
        CGRect(
            x: sourceRect.origin.x + sourceRect.width,
            y: 0,
            width: CGFloat(targetImage.width) * zoom,
            height: CGFloat(targetImage.height) * zoom
        )
    }

    var body: some View {
        ScrollView([.horizontal, .vertical], showsIndicators: true) {
            ZStack {
                HStack(alignment: .top, spacing: 0) {
                    Image(sourceImage, scale: 1, label: Text("Source"))
                        .resizable()
                        .frame(width: sourceRect.width, height: sourceRect.height)
                        .brightness(-0.2)
                    
                    Image(targetImage, scale: 1, label: Text("Target"))
                        .resizable()
                        .frame(width: targetRect.width, height: targetRect.height)
                        .brightness(-0.2)
                }

                SURFCorrespondenceView(
                    sourceRect: sourceRect,
                    targetRect: targetRect,
                    matches: matches,
                    zoom: zoom,
                    sourceColor: .yellow,
                    targetColor: .cyan
                )
            }
            .padding()
        }
    }
}


struct SURFDebugView: View {
    
    let hessianImages: [(index: Int, image: CGImage)]
    
    var body: some View {
        
        ScrollView {
            VStack {
                
                ForEach(hessianImages, id: \.index) { index, image in
                    Image(image, scale: 1, label: Text("Hessian \(index)"))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: CGFloat(image.width), height: CGFloat(image.height))
                        .backgroundStyle(.green)
                }
            }
        }
    }
}

