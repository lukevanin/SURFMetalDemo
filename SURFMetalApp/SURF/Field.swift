//
//  Field.swift
//  SURFMetalApp
//
//  Created by Luke Van In on 2023/02/20.
//

import Foundation
import CoreGraphics


final class Field {
    
    typealias Element = Float
    
    let width: Int
    let height: Int

    private let bytesPerRow: Int
    private let bytesPerComponent = MemoryLayout<Element>.stride
    private let buffer: UnsafeMutableBufferPointer<Element>
    
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
    
    subscript(x: Int, y: Int) -> Element {
        get {
            buffer[offset(x: x, y: y)]
        }
        set {
            buffer[offset(x: x, y: y)] = newValue
        }
    }
    
    func clear(with value: Element = 0) {
        buffer.initialize(repeating: value)
    }
    
    private func offset(x: Int, y: Int) -> Int {
        precondition(x >= 0)
        precondition(x < width)
        precondition(y >= 0)
        precondition(y < height)
        return (y * width) + x
    }
    
    func normalized() -> Field {
        let output = Field(width: width, height: height)
        
        var minimum: Float = +.greatestFiniteMagnitude
        var maximum: Float = -.greatestFiniteMagnitude

        for i in 0 ..< buffer.count {
            let value = buffer[i]
            minimum = min(minimum, value)
            maximum = max(maximum, value)
        }
        
        for i in 0 ..< buffer.count {
            let value = buffer[i]
            let normalizedValue = (value - minimum) / (maximum - minimum)
            output.buffer[i] = normalizedValue
        }
        
        return output
    }
}

extension Field {
    
    private static let colorSpace = CGColorSpace(name: CGColorSpace.linearGray)!
    private static let bitmapInfo: CGBitmapInfo = [.byteOrder32Little, .floatComponents]
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
