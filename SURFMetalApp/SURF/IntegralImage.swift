//
//  IntegralImage.swift
//  SURFMetalApp
//
//  Created by Luke Van In on 2023/02/14.
//

import Foundation


final class IntegralImage {
    
    typealias Element = Float16
    
    let width: Int
    let height: Int
    
    private let buffer: UnsafeMutableBufferPointer<Element>
    
    init(_ image: PixelImage) {
        self.width = image.width
        self.height = image.height
        self.buffer = UnsafeMutableBufferPointer.allocate(capacity: image.width * image.height)
        update(image)
    }
    
    deinit {
        buffer.deallocate()
    }
    
    func update(_ image: PixelImage) {
        precondition(image.width == width)
        precondition(image.height == height)
        
        // Set first row and column to zero.
        for x in 0 ..< width {
            self[x, 0] = 0
        }
        for y in 0 ..< height {
            self[0, y] = 0
        }
        
        // Compute sum of pixels
        for y in 1 ..< height {
            var s: Element = 0
            for x in 1 ..< width {
                s += image[x, y]
                self[x, y] = s + self[x, y - 1]
            }
        }
    }
    
    private subscript(x: Int, y: Int) -> Float16 {
        get {
            buffer[offset(x: x, y: y)]
        }
        set {
            buffer[offset(x: x, y: y)] = newValue
        }
    }
    
    private func offset(x: Int, y: Int) -> Int {
        precondition(x >= 0)
        precondition(x < width)
        precondition(y >= 0)
        precondition(y < height)
        return (y * height) + x
    }

}
