//
//  Field.swift
//  SURFMetalApp
//
//  Created by Luke Van In on 2023/02/20.
//

import Foundation
import Metal
import CoreGraphics


final class MetalField {
    
    typealias Element = Float32
    
    let device: MTLDevice
    let name: String
    let width: Int
    let height: Int

    let bytesPerRow: Int
    let bytesPerComponent = MemoryLayout<Element>.stride
    let bytes: Int
    let buffer: MTLBuffer
    let contents: UnsafeMutablePointer<Element>
    
    convenience init(device: MTLDevice, name: String, cgImage image: CGImage) {
        self.init(device: device, name: name, width: image.width, height: image.height)
        draw(cgImage: image)
    }
    
    init(device: MTLDevice, name: String, width: Int, height: Int) {
        let bytesPerRow = width * bytesPerComponent
        let bytes = bytesPerRow * height
        let buffer = device.makeBuffer(length: bytes, options: [.storageModeShared, .hazardTrackingModeTracked])!
        buffer.label = name
        let contents = buffer.contents().assumingMemoryBound(to: Element.self)
        self.device = device
        self.name = name
        self.width = width
        self.height = height
        self.buffer = buffer
        self.bytesPerRow = bytesPerRow
        self.bytes = bytes
        self.contents = contents
    }
    
    deinit {
//        buffer.setPurgeableState(.empty)
    }
    
    subscript(x: Int, y: Int) -> Element {
        get {
            contents[offset(x: x, y: y)]
        }
        set {
            contents[offset(x: x, y: y)] = newValue
        }
    }
    
    func clear(with value: Element = 0) {
        contents.initialize(repeating: value, count: width * height)
    }
    
    private func offset(x: Int, y: Int) -> Int {
        precondition(x >= 0)
        precondition(x < width)
        precondition(y >= 0)
        precondition(y < height)
        return (y * width) + x
    }
    
    func normalized() -> MetalField {
        let output = MetalField(
            device: device,
            name: "\(name)-Normalized",
            width: width,
            height: height
        )
        
        let count = width * height
        var minimum: Float = +.greatestFiniteMagnitude
        var maximum: Float = -.greatestFiniteMagnitude

        for i in 0 ..< count {
            let value = contents[i]
            minimum = min(minimum, value)
            maximum = max(maximum, value)
        }
        
        for i in 0 ..< count {
            let value = contents[i]
            let normalizedValue = (value - minimum) / (maximum - minimum)
            output.contents[i] = normalizedValue
        }
        
        return output
    }
}

extension MetalField {
    
    func copyToTexture(commandBuffer: MTLCommandBuffer, targetTexture: MTLTexture) {
        precondition(width == targetTexture.width)
        precondition(height == targetTexture.height)
        precondition(targetTexture.pixelFormat == .r32Float)
        
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
        precondition(sourceTexture.pixelFormat == .r32Float)
        
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

extension MetalField {
    
    private static let colorSpace = CGColorSpace(name: CGColorSpace.linearGray)!
    private static let bitmapInfo: CGBitmapInfo = [.byteOrder32Little, .floatComponents]
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
