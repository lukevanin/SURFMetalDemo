//
//  CoreGraphicsExtensions.swift
//  SURFMetalApp
//
//  Created by Luke Van In on 2023/02/21.
//

import Foundation
import CoreGraphics


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
