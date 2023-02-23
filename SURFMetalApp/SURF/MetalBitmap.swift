//
//  Image.swift
//  SURFMetalApp
//
//  Created by Luke Van In on 2023/02/14.
//

import Foundation
import OSLog
import Metal
import CoreGraphics


private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "MetalBitmap")


final class MetalBitmap {
    
    typealias Pixel = UInt8
    
    let device: MTLDevice
    let name: String
    let width: Int
    let height: Int

    let bytesPerRow: Int
    let bytesPerComponent = MemoryLayout<Pixel>.stride
    let bytes: Int
    let buffer: MTLBuffer
    
    let contents: UnsafeMutablePointer<Pixel>
    
    convenience init(device: MTLDevice, name: String, cgImage image: CGImage) {
        self.init(device: device, name: name, width: image.width, height: image.height)
        draw(cgImage: image)
    }
    
    init(device: MTLDevice, name: String, width: Int, height: Int) {
        let bytesPerRow = width * bytesPerComponent
        let bytes = bytesPerRow * height
        let buffer = device.makeBuffer(length: bytes, options: [.storageModeShared, .hazardTrackingModeTracked])!
        buffer.label = name
        let contents = buffer.contents().assumingMemoryBound(to: Pixel.self)
        self.device = device
        self.name = name
        self.width = width
        self.height = height
        self.bytesPerRow = bytesPerRow
        self.bytes = bytes
        self.buffer = buffer
        self.contents = contents
        logger.debug("Allocated \(name) \(width)x\(height) \(bytes) Bytes")
    }
    
    deinit {
        logger.debug("Deallocated \(self.name)")
        // buffer.setPurgeableState(.empty)
    }
    
    subscript(x: Int, y: Int) -> Pixel {
        get {
            contents[offset(x: x, y: y)]
        }
        set {
            contents[offset(x: x, y: y)] = newValue
        }
    }
    
    private func offset(x: Int, y: Int) -> Int {
        precondition(x >= 0)
        precondition(x < width)
        precondition(y >= 0)
        precondition(y < height)
        return (y * width) + x
    }
    
    func clear(with value: Pixel = 0) {
        contents.initialize(repeating: value, count: width * height)
    }
    
    func halfImage() -> MetalBitmap {
        let halfWidth = width / 2
        let halfHeight = height / 2
        let output = MetalBitmap(
            device: device,
            name: "\(name)-HalfImage",
            width: halfWidth,
            height: halfHeight
        )
        for y in 0 ..< halfHeight {
            for x in 0 ..< halfWidth {
                output[x, y] = self[x * 2, y * 2]
            }
        }
        return output
    }
    
    func normalized() -> MetalBitmap {
        let output = MetalBitmap(
            device: device,
            name: "\(name)-Normalized",
            width: width,
            height: height
        )
        
        let count = width * height
        var minimum: UInt8 = .min
        var maximum: UInt8 = .max

        for i in 0 ..< count {
            let value = contents[i]
            minimum = min(minimum, value)
            maximum = max(maximum, value)
        }
        
        for i in 0 ..< count {
            let value = contents[i]
            let t = Float(value - minimum) / Float(maximum - minimum)
            #warning("TODO: Round value")
            let normalizedValue = UInt8(t * 255)
            output.contents[i] = normalizedValue
        }
        
        return output
    }
    
    func symmetrized(padding: Int) -> MetalBitmap {
        let output = MetalBitmap(
            device: device,
            name: "\(name)-Symmetrized",
            width: width + (padding * 2),
            height: height + (padding * 2)
        )
        
        for i in -padding ..< width + padding {
            for j in -padding ..< height + padding {
                var i0 = i
                var j0 = j
                
                if i0 < 0 {
                    i0 = -i0
                }
                if j0 < 0 {
                    j0 = -j0
                }
                
                i0 = i0 % (2 * width)
                j0 = j0 % (2 * height)
                
                if i0 >= width {
                    i0 = 2 * width - i0 - 1
                }
                if j0 >= height {
                    j0 = 2 * height - j0 - 1
                }
                
                output[i + padding, j + padding] = self[i0, j0]
            }
        }
        return output
    }
}

extension MetalBitmap {
    func copyToTexture(commandBuffer: MTLCommandBuffer, targetTexture: MTLTexture) {
        precondition(width == targetTexture.width)
        precondition(height == targetTexture.height)
        precondition(targetTexture.pixelFormat == .r8Uint)
        
        let blitEncoder = commandBuffer.makeBlitCommandEncoder()!
        blitEncoder.copy(
            from: buffer,
            sourceOffset: 0,
            sourceBytesPerRow: bytesPerRow,
            sourceBytesPerImage: bytes,
            sourceSize: MTLSize(width: width, height: height, depth: 1),
            to: targetTexture,
            destinationSlice: 0,
            destinationLevel: 0,
            destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0)
        )
        blitEncoder.endEncoding()
    }

    func copyFromTexture(commandBuffer: MTLCommandBuffer, sourceTexture: MTLTexture) {
        precondition(sourceTexture.width == width)
        precondition(sourceTexture.height == height)
        precondition(sourceTexture.pixelFormat == .r8Uint)
        
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

extension MetalBitmap {
    
    private static let colorSpace = CGColorSpace(name: CGColorSpace.genericGrayGamma2_2)!
    private static let bitmapInfo: CGBitmapInfo = []
    private static let alphaInfo: CGImageAlphaInfo = .none
    
    func draw(cgImage image: CGImage) {
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        let pointer = UnsafeMutableRawPointer(contents)
        let context = CGContext(
            data: pointer,
            width: image.width,
            height: image.height,
            bitsPerComponent: bytesPerComponent * 8,
            bytesPerRow: bytesPerRow,
            space: Self.colorSpace,
            bitmapInfo: Self.bitmapInfo.rawValue | Self.alphaInfo.rawValue
        )!
        context.draw(image, in: rect)
    }
    
    func cgImage() -> CGImage {
        let pointer = UnsafeMutableRawPointer(contents)
        let context = CGContext(
            data: pointer,
            width: width,
            height: height,
            bitsPerComponent: bytesPerComponent * 8,
            bytesPerRow: bytesPerRow,
            space: Self.colorSpace,
            bitmapInfo: Self.bitmapInfo.rawValue | Self.alphaInfo.rawValue
        )!
        return context.makeImage()!
    }
}
