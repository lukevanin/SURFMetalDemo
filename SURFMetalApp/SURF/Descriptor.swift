//
//  SURFDescriptor.swift
//  SURFMetalApp
//
//  Created by Luke Van In on 2023/02/16.
//

import Foundation


struct VectorDescriptor {
    var sumDx: Float
    var sumDy: Float
    var sumAbsDx: Float
    var sumAbsDy: Float
}


struct Descriptor {
    var keypoint: Keypoint
    var vector: [VectorDescriptor]
}
