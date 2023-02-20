//
//  ContentView.swift
//  SURFMetalApp
//
//  Created by Luke Van In on 2023/02/14.
//

import SwiftUI
import CoreGraphics

func loadImage(named name: String) -> CGImage {
    let fileURL = Bundle.main.urlForImageResource(name)!
    let dataProvider = CGDataProvider(url: fileURL as CFURL)!
    let image = CGImage(pngDataProviderSource: dataProvider, decode: nil, shouldInterpolate: true, intent: .perceptual)!
    return image
}


struct SURFFeaturesView: View {
    
    @State var features: [Keypoint]
    @State var zoom: CGFloat
    @State var color: Color
    
    var body: some View {
        Path { path in
            for feature in features {
                let bounds = CGRect(
                    x: CGFloat(feature.x - feature.scale) * zoom,
                    y: CGFloat(feature.y - feature.scale) * zoom,
                    width: CGFloat(feature.scale * 2) * zoom,
                    height: CGFloat(feature.scale * 2) * zoom
                )
                path.move(to: CGPoint(x: bounds.midX, y: bounds.minY))
                path.addLine(to: CGPoint(x: bounds.midX, y: bounds.maxY))
                
                path.move(to: CGPoint(x: bounds.minX, y: bounds.midY))
                path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.midY))
            }
        }
        .stroke(color.opacity(0.8), lineWidth: 2.0)
        .blendMode(.plusLighter)
    }
}


struct SURFCompareView: View {
    
    let image: CGImage
    let sourceFeatures: [Keypoint]
    let targetFeatures: [Keypoint]
    let zoom: CGFloat
    
    var body: some View {
        ScrollView([.horizontal, .vertical], showsIndicators: true) {
            ZStack {
                Image(image, scale: 1, label: Text("Sample"))
                    .resizable()
                    .frame(width: CGFloat(image.width) * zoom, height: CGFloat(image.height) * zoom)
                
                Rectangle()
                    .fill(.black.opacity(0.5))
                    .frame(width: CGFloat(image.width) * zoom, height: CGFloat(image.height) * zoom)
                
                SURFFeaturesView(features: targetFeatures, zoom: zoom, color: .green)
                    .frame(width: CGFloat(image.width) * zoom, height: CGFloat(image.height) * zoom)
                
                SURFFeaturesView(features: sourceFeatures, zoom: zoom, color: .red)
                    .frame(width: CGFloat(image.width) * zoom, height: CGFloat(image.height) * zoom)
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

