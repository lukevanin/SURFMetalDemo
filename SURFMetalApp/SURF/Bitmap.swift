//
//  Image.swift
//  SURFMetalApp
//
//  Created by Luke Van In on 2023/02/14.
//

import Foundation
import CoreGraphics


final class Bitmap {
    
    typealias Pixel = UInt8
    
    let width: Int
    let height: Int

    let bytesPerRow: Int
    let bytesPerComponent = MemoryLayout<Pixel>.stride
    let buffer: UnsafeMutableBufferPointer<Pixel>
    
    convenience init(cgImage image: CGImage) {
        self.init(width: image.width, height: image.height, initialize: false)
        draw(cgImage: image)
    }
    
    init(width: Int, height: Int, initialize: Bool = true) {
        self.width = width
        self.height = height
        self.buffer = .allocate(capacity: width * height)
        self.bytesPerRow = width * bytesPerComponent
        if initialize {
            clear()
        }
    }
    
    deinit {
        buffer.deallocate()
    }
    
    subscript(x: Int, y: Int) -> Pixel {
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
        return (y * width) + x
    }
    
    func clear(with value: Pixel = 0) {
        buffer.initialize(repeating: value)
    }
    
    func halfImage() -> Bitmap {
        let halfWidth = width / 2
        let halfHeight = height / 2
        let output = Bitmap(width: halfWidth, height: halfHeight)
        for y in 0 ..< halfHeight {
            for x in 0 ..< halfWidth {
                output[x, y] = self[x * 2, y * 2]
            }
        }
        return output
    }
    
    func normalized() -> Bitmap {
        let output = Bitmap(width: width, height: height)
        
        var minimum: UInt8 = .min
        var maximum: UInt8 = .max

        for i in 0 ..< buffer.count {
            let value = buffer[i]
            minimum = min(minimum, value)
            maximum = max(maximum, value)
        }
        
        for i in 0 ..< buffer.count {
            let value = buffer[i]
            let t = Float(value - minimum) / Float(maximum - minimum)
            #warning("TODO: Round value")
            let normalizedValue = UInt8(t * 255)
            output.buffer[i] = normalizedValue
        }
        
        return output
    }
    
    func symmetrized(padding: Int) -> Bitmap {
        let output = Bitmap(
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

extension Bitmap {
    
    private static let colorSpace = CGColorSpace(name: CGColorSpace.genericGrayGamma2_2)!
    private static let bitmapInfo: CGBitmapInfo = []
    private static let alphaInfo: CGImageAlphaInfo = .none
    
    func draw(cgImage image: CGImage) {
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        let pointer = UnsafeMutableRawPointer(buffer.baseAddress!)
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
        let pointer = UnsafeMutableRawPointer(buffer.baseAddress!)
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
