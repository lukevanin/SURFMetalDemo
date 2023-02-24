//
//  MetalBuffer.swift
//  SURFMetalApp
//
//  Created by Luke Van In on 2023/02/24.
//

import Foundation
import Metal


final class DynamicBuffer<T> {
    
    let capacity: Int

    var count: Int {
        Int(sizeContents[0])
    }

    let buffer: MTLBuffer
    let sizeBuffer: MTLBuffer
    
    private let contents: UnsafeMutablePointer<T>
    private let sizeContents: UnsafeMutablePointer<UInt32>
    
    init(device: MTLDevice, name: String, capacity: Int) {
        let bytesPerComponent = MemoryLayout<T>.stride
        let bytes = bytesPerComponent * capacity
        let buffer = device.makeBuffer(length: bytes)!
        buffer.label = name
        let sizeBuffer = device.makeBuffer(length: 4)!
        sizeBuffer.label = "\(name)(Size)"
        self.capacity = capacity
        self.buffer = buffer
        self.sizeBuffer = sizeBuffer // UInt32
        self.contents = buffer.contents().assumingMemoryBound(to: T.self)
        self.sizeContents = sizeBuffer.contents().assumingMemoryBound(to: UInt32.self)
        allocate(0)
    }
    
    #warning("TODO: Deallocate buffer")

    subscript(index: Int) -> T {
        get {
            precondition(index >= 0)
            precondition(index < count)
            return contents[index]
        }
        set {
            precondition(index >= 0)
            precondition(index < count)
            contents[index] = newValue
        }
    }

    func allocate(_ count: Int) {
        precondition(count >= 0)
        precondition(count < capacity)
        sizeContents[0] = UInt32(count)
    }
}


final class ManagedBuffer<T> {
    
    let buffer: MTLBuffer
    
    private let contents: UnsafeMutablePointer<T>
    
    init(device: MTLDevice, name: String, count: Int) {
        let bytesPerComponent = MemoryLayout<T>.stride
        let bytes = bytesPerComponent * count
        let buffer = device.makeBuffer(length: bytes)!
        buffer.label = name
        let contents = buffer.contents().assumingMemoryBound(to: T.self)
        self.buffer = buffer
        self.contents = contents
    }
    
    #warning("TODO: Deallocate buffer")
    
    subscript(index: Int) -> T {
        get {
            contents[index]
        }
        set {
            contents[index] = newValue
        }
    }
}
