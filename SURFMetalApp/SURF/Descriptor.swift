//
//  SURFDescriptor.swift
//  SURFMetalApp
//
//  Created by Luke Van In on 2023/02/16.
//

import Foundation


extension Descriptor {
    func euclideanDistance(to other: Descriptor) -> Float {
        var sum: Float = 0
        
        var u = vector
        var v = other.vector
        withUnsafePointer(to: &u.0) { u in
            withUnsafePointer(to: &v.0) { v in
                #warning("TODO: Use BLAS to compute distance")
                for i in 0 ..< Int(DESCRIPTOR_LENGTH) {
                    let a = u[i]
                    let b = v[i]
                    let t0 = a.sumDx - b.sumDx
                    let t1 = a.sumDy - b.sumDy
                    let t2 = a.sumAbsDx - b.sumAbsDx
                    let t3 = a.sumAbsDy - b.sumAbsDy
                    sum += (t0 * t0) + (t1 * t1) + (t2 * t2) + (t3 * t3)
                }
            }
        }
        return sum
    }
}


struct Match: Identifiable {
    var id: Int
    var a: Descriptor
    var b: Descriptor
}
