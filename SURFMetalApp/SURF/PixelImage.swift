//
//  Image.swift
//  SURFMetalApp
//
//  Created by Luke Van In on 2023/02/14.
//

import Foundation
import CoreGraphics


final class PixelImage {
    
    typealias Pixel = Float16

    let width: Int
    let height: Int

    private let bytesPerComponent = MemoryLayout<Pixel>.size
    private let buffer: UnsafeMutableBufferPointer<Float16>
    
    convenience init(_ image: CGImage) {
        self.init(width: image.width, height: image.height, initialize: false)
        draw(image)
    }
    
    init(width: Int, height: Int, initialize: Bool = true) {
        self.width = width
        self.height = height
        self.buffer = UnsafeMutableBufferPointer<Pixel>.allocate(capacity: width * height)
        if initialize {
            buffer.initialize(repeating: 0)
        }
    }
    
    deinit {
        buffer.deallocate()
    }
    
    subscript(x: Int, y: Int) -> Float16 {
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
    
    func draw(_ image: CGImage) {
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        let pointer = UnsafeMutableRawPointer(buffer.baseAddress!)
        let colorSpace = CGColorSpace(name: CGColorSpace.extendedGray)!
        let bitmapInfo: CGBitmapInfo = [.byteOrder16Little, .floatComponents]
        let context = CGContext(
            data: pointer,
            width: image.width,
            height: image.height,
            bitsPerComponent: bytesPerComponent * 8,
            bytesPerRow: width * bytesPerComponent,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        )!
        context.draw(image, in: rect)
    }
}
