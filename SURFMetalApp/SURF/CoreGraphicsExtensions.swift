//
//  CoreGraphicsExtensions.swift
//  SURFMetalApp
//
//  Created by Luke Van In on 2023/02/21.
//

import Foundation
import CoreGraphics


func loadImage(named name: String) -> CGImage {
    let fileURL = Bundle.main.urlForImageResource(name)!
    let resourceValues = try! fileURL.resourceValues(forKeys: [.contentTypeKey])
    let contentType = resourceValues.contentType
    let dataProvider = CGDataProvider(url: fileURL as CFURL)!
    let image: CGImage
    switch contentType {
    case .some(.png):
        image = CGImage(pngDataProviderSource: dataProvider, decode: nil, shouldInterpolate: true, intent: .perceptual)!
    case .some(.jpeg):
        image = CGImage(jpegDataProviderSource: dataProvider, decode: nil, shouldInterpolate: true, intent: .perceptual)!
    default:
        fatalError("Unsupported content type \(contentType)")
    }
    return image
}


extension CGPoint {
    
    ///
    /// Initialize a CGPoint from a 3D SIMD Float vector representing a 2D homogeneous coordinate.
    ///
    init(_ vector: SIMD3<Float>) {
        self.init(
            x: CGFloat(vector.x / vector.z),
            y: CGFloat(vector.y / vector.z)
        )
    }
}
