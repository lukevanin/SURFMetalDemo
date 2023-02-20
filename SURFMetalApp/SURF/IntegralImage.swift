//
//  IntegralImage.swift
//  SURFMetalApp
//
//  Created by Luke Van In on 2023/02/14.
//

import Foundation


final class IntegralImage {
    
    typealias Element = Int
    
    let imageWidth: Int
    let imageHeight: Int

    let padding: Int
    let paddedWidth: Int
    let paddedHeight: Int

    let buffer: UnsafeMutableBufferPointer<Element>
    
    init(image: Bitmap, padding: Int) {
        self.imageWidth = image.width
        self.imageHeight = image.height
        self.paddedWidth = image.width + (padding * 2)
        self.paddedHeight = image.height + (padding * 2)
        self.padding = padding
        self.buffer = UnsafeMutableBufferPointer.allocate(capacity: paddedWidth * paddedHeight)
        update(image: image)
    }
    
    deinit {
        buffer.deallocate()
    }
    
    func update(image: Bitmap) {
        precondition(image.width == imageWidth)
        precondition(image.height == imageHeight)
        
        let symmetrizedImage = image.symmetrized(padding: padding)

        // Set first row and column to zero.
        for x in 0 ..< paddedWidth {
            buffer[offset(x: x, y: 0)] = 0
        }
        for y in 0 ..< paddedHeight {
            buffer[offset(x: 0, y: y)] = 0
        }

        // Compute sum of pixels
        for y in 1 ..< paddedHeight {
            var s: Element = 0
            for x in 1 ..< paddedWidth {
                s += Element(symmetrizedImage[x, y])
                buffer[offset(x: x, y: y)] = s + buffer[offset(x: x, y: y - 1)]
            }
        }
    }
    
//    @inlinable func getSum(_ x1: Int, _ y1: Int, _ x2: Int, _ y2: Int) -> Element {
//        return self[x1 + 1, y1 + 1] + self[x2, y2] - self[x1 + 1, y2] - self[x2, y1 + 1]
//    }

//    @inlinable func getHessian(_ x: [Int]) -> Float {
//        /* Get second order derivatives */
//        let Lxx = Float(
//            getSum(x[5] + x[2], x[1] + x[3], x[6] - x[2], x[1] - x[3]) -
//            getSum(x[0] + x[2], x[1] + x[3], x[0] - x[2], x[1] - x[3]) * 3
//        )
//
//        let Lyy = Float(
//            getSum(x[0] + x[3], x[7] + x[2], x[0] - x[3], x[8] - x[2]) -
//            getSum(x[0] + x[3], x[1] + x[2], x[0] - x[3], x[1] - x[2]) * 3
//        )
//
//        let Lxy = Float(
//            getSum(x[0] + x[4], x[1], x[0], x[1] - x[4]) +
//            getSum(x[0], x[1] + x[4], x[0] - x[4], x[1]) -
//            getSum(x[0] + x[4], x[1] + x[4], x[0], x[1]) -
//            getSum(x[0], x[1], x[0] - x[4], x[1] - x[4])
//        ) * 0.6
//
//        return Lxx * Lyy - Lxy * Lxy;
//    }
    
    // Get the Hessian trace response
//    @inlinable func getTrace(_ x: [Int]) -> Int {
//        /* Get second order derivatives */
//        let Lxx = (
//            getSum(x[5] + x[2], x[1] + x[3], x[6] - x[2], x[1] - x[3]) -
//            getSum(x[0] + x[2], x[1] + x[3], x[0] - x[2], x[1] - x[3]) * 3
//        )
//        let Lyy = (
//            getSum(x[0] + x[3], x[7] + x[2], x[0] - x[3], x[8] - x[2]) -
//            getSum(x[0] + x[3], x[1] + x[2], x[0] - x[3], x[1] - x[2]) * 3
//        )
//        return (Lxx + Lyy > 0 ? 1 : -1)
//    }
    
    // Convolution by a square defined by the bottom-left (a,b) and top-right (c,d)
    @inlinable func squareConvolutionXY(a: Int, b: Int, c: Int, d: Int, x: Int, y: Int) -> Int {
        let a1 = x - a
        let a2 = y - b
        let b1 = a1 - c
        let b2 = a2 - d
        return self[b1, b2] + self[a1, a2] - self[b1, a2] - self[a1, b2] // Note: No L2-normalization is performed here.
    }

    // Convolution by a box [-1,+1]
    @inlinable func haarX(x: Int, y: Int, lambda: Int) -> Int {
        return -(squareConvolutionXY(a: 1, b: -lambda - 1, c: -lambda - 1, d: lambda * 2 + 1, x: x, y: y) + squareConvolutionXY(a: 0, b: -lambda - 1, c: lambda + 1, d: lambda * 2 + 1, x: x, y: y))
    }

    // Convolution by a box [-1;+1]
    @inlinable func haarY(x: Int, y: Int, lambda: Int) -> Int {
        return -(squareConvolutionXY(a: -lambda - 1, b: 1, c: 2 * lambda + 1, d: -lambda - 1, x: x, y: y) + squareConvolutionXY(a: -lambda - 1, b: 0, c: 2 * lambda + 1, d: lambda + 1, x: x, y: y))
    }

    @inlinable subscript(x: Int, y: Int) -> Element {
        get {
            buffer[paddedOffset(x: x, y: y)]
        }
        set {
            buffer[paddedOffset(x: x, y: y)] = newValue
        }
    }
    
    @inlinable func paddedOffset(x: Int, y: Int) -> Int {
        return offset(x: x + padding, y: y + padding)
    }
    
    @inlinable func offset(x: Int, y: Int) -> Int {
        return (y * paddedWidth) + x
    }
}
