//
//  SURF.swift
//  SURFMetalApp
//
//  Created by Luke Van In on 2023/02/14.
//

import Foundation
import CoreGraphics


struct SURFDescriptor {
    var features: [Float]
}



///
/// Port of the SURF method by Herbert Bay et al.
///
/// See: https://github.com/herbertbay/SURF
///
final class SURFCPU {
    
    init() {
    }
    
    func getFeatures(_ inputImage: CGImage) -> [SURFDescriptor] {
        
        // 1. Make the integral image from the input image.
        // 2. Extract interest points.
        // 3. Compute orientations for each interest points.
        // 4. Extract the descriptor for each interest point.
        
        let pixelImage = PixelImage(inputImage)
        let integralImage = IntegralImage(pixelImage)
        
        
        
        var output: [SURFDescriptor] = []
        return output
    }
}
