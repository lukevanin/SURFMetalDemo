//
//  MetalIntegralImage.swift
//  SURFMetalApp
//
//  Created by Luke Van In on 2023/02/14.
//

import Foundation
import Metal


final class MetalIntegralImage {
    
    typealias Element = UInt32
    
    let name: String
    
    let imageWidth: Int
    let imageHeight: Int

    let padding: Int
    let paddedWidth: Int
    let paddedHeight: Int

    let buffer: MTLBuffer
    let bytesPerComponent = MemoryLayout<Element>.stride
    let bytesPerRow: Int
    let bytes: Int
    let contents: UnsafeMutablePointer<Element>
    
//    convenience init(device: MTLDevice, image: MetalBitmap, padding: Int) {
//        self.init(device: device, width: image.width, height: image.height, padding: padding)
//        update(image: image)
//    }
    
    init(device: MTLDevice, name: String, width: Int, height: Int, padding: Int) {
        let paddedWidth = width + (padding * 2)
        let paddedHeight = height + (padding * 2)
        let bytesPerRow = paddedWidth * bytesPerComponent
        let bytes = bytesPerRow * paddedHeight
        let buffer = device.makeBuffer(length: bytes, options: [.storageModeShared, .hazardTrackingModeTracked])!
        buffer.label = name
        let contents = buffer.contents().assumingMemoryBound(to: Element.self)
        self.name = name
        self.imageWidth = width
        self.imageHeight = height
        self.paddedWidth = paddedWidth
        self.paddedHeight = paddedHeight
        self.padding = padding
        self.buffer = buffer
        self.contents = contents
        self.bytesPerRow = bytesPerRow
        self.bytes = bytes
    }
    
    deinit {
        // buffer.setPurgeableState(.empty)
    }
    
//    func update(image: MetalBitmap) {
//        precondition(image.width == imageWidth)
//        precondition(image.height == imageHeight)
//
//        let symmetrizedImage = image.symmetrized(padding: padding)
//
//        // Set first row and column to zero.
//        for x in 0 ..< paddedWidth {
//            contents[offset(x: x, y: 0)] = 0
//        }
//        for y in 0 ..< paddedHeight {
//            contents[offset(x: 0, y: y)] = 0
//        }
//
//        // Compute sum of pixels
//        for y in 1 ..< paddedHeight {
//            var s: Element = 0
//            for x in 1 ..< paddedWidth {
//                s += Element(symmetrizedImage[x, y])
//                contents[offset(x: x, y: y)] = s + contents[offset(x: x, y: y - 1)]
//            }
//        }
//    }
    
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
        return Int(self[b1, b2]) + Int(self[a1, a2]) - Int(self[b1, a2]) - Int(self[a1, b2]) // Note: No L2-normalization is performed here.
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
            contents[paddedOffset(x: x, y: y)]
        }
        set {
            contents[paddedOffset(x: x, y: y)] = newValue
        }
    }
    
    @inlinable func paddedOffset(x: Int, y: Int) -> Int {
        return offset(x: x + padding, y: y + padding)
    }
    
    @inlinable func offset(x: Int, y: Int) -> Int {
        return (y * paddedWidth) + x
    }
}

extension MetalIntegralImage {
    
    func copyToTexture(commandBuffer: MTLCommandBuffer, targetTexture: MTLTexture) {
        precondition(paddedWidth == targetTexture.width)
        precondition(paddedHeight == targetTexture.height)
        precondition(targetTexture.pixelFormat == .r32Uint)
        
        let blitEncoder = commandBuffer.makeBlitCommandEncoder()!
        blitEncoder.copy(
            from: buffer,
            sourceOffset: 0,
            sourceBytesPerRow: bytesPerRow,
            sourceBytesPerImage: bytes,
            sourceSize: MTLSize(width: paddedWidth, height: paddedHeight, depth: 1),
            to: targetTexture,
            destinationSlice: 0,
            destinationLevel: 0,
            destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0)
        )
        blitEncoder.endEncoding()
    }

    func copyFromTexture(commandBuffer: MTLCommandBuffer, sourceTexture: MTLTexture) {
        precondition(sourceTexture.width == paddedWidth)
        precondition(sourceTexture.height == paddedHeight)
        precondition(sourceTexture.pixelFormat == .r32Uint)
        
        let blitEncoder = commandBuffer.makeBlitCommandEncoder()!
        blitEncoder.copy(
            from: sourceTexture,
            sourceSlice: 0,
            sourceLevel: 0,
            sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
            sourceSize: MTLSize(width: sourceTexture.width, height: sourceTexture.height, depth: 1),
            to: buffer,
            destinationOffset: 0,
            destinationBytesPerRow: bytesPerRow,
            destinationBytesPerImage: bytes
        )
        blitEncoder.endEncoding()
    }
}
