//
//  ContentView.swift
//  SURFMetalApp
//
//  Created by Luke Van In on 2023/02/14.
//

import SwiftUI
import CoreGraphics
import simd

func loadImage(named name: String) -> CGImage {
    let fileURL = Bundle.main.urlForImageResource(name)!
    let dataProvider = CGDataProvider(url: fileURL as CFURL)!
    let image = CGImage(pngDataProviderSource: dataProvider, decode: nil, shouldInterpolate: true, intent: .perceptual)!
    return image
}


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

