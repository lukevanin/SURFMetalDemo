//
//  IPoint.swift
//  SURFMetalApp
//
//  Created by Luke Van In on 2023/02/14.
//

import Foundation

struct Keypoint {
    
    // x, y value of the interest point
    var x: Float
    var y: Float
    
    // detected scale
    var scale: Float
    
    // strength of the interest point
    var strength: Float
    
    // orientation
    var orientation: Float
    
    // sign of Laplacian
    var laplacian: Int
    
    // descriptor
    var ivec: [Float]
}
