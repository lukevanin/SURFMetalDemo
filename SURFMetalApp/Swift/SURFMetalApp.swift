//
//  SURFMetalAppApp.swift
//  SURFMetalApp
//
//  Created by Luke Van In on 2023/02/14.
//

import SwiftUI
import Metal

@main
struct SURFMetalApp: App {
    
//    private let surf = SURFIPOL(width: 1464, height: 968)
//    private let sourceImage = loadImage(named: "waterfall")
    private let surf = SURFIPOL(width: 1024, height: 1024)
    private let sourceImage = Bitmap(cgImage: loadImage(named: "lena")).normalized()
    private let surfFile = try! IPOLSURFFile(contentsOf: Bundle.main.url(forResource: "lena", withExtension: "surf")!)

    var body: some Scene {
        WindowGroup {
//            SURFDebugView(
//                hessianImages: {
//                    let _ = surf.getCandidatKeypoints(image: PixelImage(cgImage: sourceImage))
//                    return surf.octaves
//                        .lazy
//                        .map { octave in
//                            octave.hessian
//                        }
//                        .joined()
//                        .enumerated()
//                        .map { index, hessian in
//                            (index: index, image: hessian.normalizedImage().cgImage())
//                        }
//                }()
//            )
            SURFCompareView(
                image: sourceImage.cgImage(),
                sourceFeatures: surf.getCandidatKeypoints(image: sourceImage),
//                sourceFeatures: [],
                targetFeatures: surfFile.contents.map {
                    Keypoint(x: $0.x, y: $0.y, scale: $0.scale, strength: 0, orientation: 0, laplacian: 0, ivec: [])
                },
//                targetFeatures: [],
                zoom: 2.0
            )
        }
        .defaultSize(width: 600, height: 400)
    }
}
