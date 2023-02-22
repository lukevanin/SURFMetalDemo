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

    func euclideanDistance(to other: Descriptor) -> Float {
        var sum: Float = 0
        for i in 0 ..< 16 {
            let a = vector[i]
            let b = other.vector[i]
            let t0 = a.sumDx - b.sumDx
            let t1 = a.sumDy - b.sumDy
            let t2 = a.sumAbsDx - b.sumAbsDx
            let t3 = a.sumAbsDy - b.sumAbsDy
            sum += (t0 * t0) + (t1 * t1) + (t2 * t2) + (t3 * t3)
        }
        #warning("TODO: USe square root for absolute distance")
        return sum
    }
}


struct Match: Identifiable {
    var id: Int
    var a: Descriptor
    var b: Descriptor
}
