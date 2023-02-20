//
//  SURF.swift
//  SURFMetalApp
//
//  Created by Luke Van In on 2023/02/14.
//

import Foundation
import CoreGraphics

#if false

///
/// Port of the SURF method by Herbert Bay et al.
///
/// See: https://github.com/herbertbay/SURF
///
final class SURFBay {
    
    init() {
    }
    
    func getFeatures(_ inputImage: CGImage) -> [SURFDescriptor] {
        
        // 1. Make the integral image from the input image.
        // 2. Extract interest points.
        // 3. Compute orientations for each interest points.
        // 4. Extract the descriptor for each interest point.
        
        let pixelImage = PixelImage(inputImage)
        let integralImage = IntegralImage(pixelImage)
        
        let hessian = FastHessian(
            integralImage: integralImage,
            configuration: FastHessian.Configuration()
        )
        let points = hessian.getInterestPoints()
        print("found points", points.count)
        print(points)
        
        var descriptors: [SURFDescriptor] = []
        
        for point in points {
            let descriptor = SURFDescriptor(
                x: point.x,
                y: point.y,
                scale: point.scale,
                descriptor: []
            )
            descriptors.append(descriptor)
        }
        
        return descriptors
    }
}

#endif 
