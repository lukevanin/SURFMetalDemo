//
//  MetalFunction.swift
//  SURFMetalApp
//
//  Created by Luke Van In on 2023/02/22.
//

import Foundation
import OSLog
import Metal


private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "MetalFunction")


final class MetalFunction {
    
    let device: MTLDevice
    let name: String
    let maxTotalThreadsPerThreadgroup: Int
    let threadExecutionWidth: Int
    let computePipelineState: MTLComputePipelineState
    
    init(device: MTLDevice, name: String, constantValues: MTLFunctionConstantValues?) {
        let library = device.makeDefaultLibrary()!
        let function: MTLFunction
        if let constantValues {
            function = try! library.makeFunction(name: name, constantValues: constantValues)
        }
        else {
            function = library.makeFunction(name: name)!
        }
        let computePipelineState = try! device.makeComputePipelineState(function: function)
        self.device = device
        self.name = name
        self.computePipelineState = computePipelineState
        self.maxTotalThreadsPerThreadgroup = computePipelineState.maxTotalThreadsPerThreadgroup
        self.threadExecutionWidth = computePipelineState.threadExecutionWidth
    }

    func encode(
        commandBuffer: MTLCommandBuffer,
        grid: MTLSize,
        threads: MTLSize,
        buffers: [MTLBuffer],
        textures: [MTLTexture],
        textureArrays: [[MTLTexture]]
    ) {
        let computeEncoder = commandBuffer.makeComputeCommandEncoder()!
        computeEncoder.setComputePipelineState(computePipelineState)
        var index = 0
        for buffer in buffers {
            logger.debug("Function \(self.name): Binding buffer \(buffer.label ?? "-anonymous-") at index #\(index)")
            computeEncoder.setBuffer(buffer, offset: 0, index: index)
            index += 1
        }
        for texture in textures {
            logger.debug("Function \(self.name): Binding texture \(texture.label ?? "-anonymous-") at index #\(index)")
            computeEncoder.setTexture(texture, index: index)
            index += 1
        }
        for textureArray in textureArrays {
            let labels = textureArray.map {
                $0.label ?? "-anonymous-"
            }
            logger.debug("Function \(self.name): Binding textureArray[\(labels)] at index #\(index)")
            let lastIndex = index + textureArray.count
            computeEncoder.setTextures(textureArray, range: index ..< lastIndex)
            index = lastIndex
        }
        logger.debug("Function \(self.name): Dispatch threads: Grid=\(grid.width)x\(grid.height)x\(grid.depth), Threads=\(threads.width)x\(threads.height)x\(threads.depth)")
        computeEncoder.dispatchThreads(grid, threadsPerThreadgroup: threads)
        computeEncoder.endEncoding()
    }
}


final class MetalFunction1D {
    
    let function: MetalFunction
    
    init(device: MTLDevice, name: String, constantValues: MTLFunctionConstantValues?) {
        self.function = MetalFunction(device: device, name: name, constantValues: constantValues)
    }
    
    func encode(
        commandBuffer: MTLCommandBuffer,
        length: Int,
        buffers: [MTLBuffer],
        textures: [MTLTexture],
        textureArrays: [[MTLTexture]]
    ) {
        let threads = min(length, function.maxTotalThreadsPerThreadgroup)
        function.encode(
            commandBuffer: commandBuffer,
            grid: MTLSize(width: length, height: 1, depth: 1),
            threads: MTLSize(width: threads, height: 1, depth: 1),
            buffers: buffers,
            textures: textures,
            textureArrays: textureArrays
        )
    }
}


final class MetalFunction2D {

    let function: MetalFunction
    
    init(device: MTLDevice, name: String, constantValues: MTLFunctionConstantValues?) {
        self.function = MetalFunction(device: device, name: name, constantValues: constantValues)
    }

    func encode(
        commandBuffer: MTLCommandBuffer,
        width: Int,
        height: Int,
        buffers: [MTLBuffer],
        textures: [MTLTexture],
        textureArrays: [[MTLTexture]]
    ) {
        let w = function.threadExecutionWidth
        let h = function.maxTotalThreadsPerThreadgroup / w
        function.encode(
            commandBuffer: commandBuffer,
            grid: MTLSize(width: width, height: height, depth: 1),
            threads: MTLSize(width: w, height: h, depth: 1),
            buffers: buffers,
            textures: textures,
            textureArrays: textureArrays
        )
    }
}


final class MetalFunction3D {
    
    let function: MetalFunction
    
    init(device: MTLDevice, name: String, constantValues: MTLFunctionConstantValues?) {
        self.function = MetalFunction(device: device, name: name, constantValues: constantValues)
    }

    func encode(
        commandBuffer: MTLCommandBuffer,
        width: Int,
        height: Int,
        depth: Int,
        buffers: [MTLBuffer],
        textures: [MTLTexture],
        textureArrays: [[MTLTexture]]
    ) {
        // Assume threadExecutionWidth is a square number, and
        // maxTotalThreadsPerThreadgroup is divisible by threadExecutionWidth,
        // otherwise we end up wasting threads.
        let k = Int(sqrt(Float(function.threadExecutionWidth)))
        let w = k
        let h = k
        let d = function.maxTotalThreadsPerThreadgroup / function.threadExecutionWidth;
        function.encode(
            commandBuffer: commandBuffer,
            grid: MTLSize(width: width, height: height, depth: 1),
            threads: MTLSize(width: w, height: h, depth: d),
            buffers: buffers,
            textures: textures,
            textureArrays: textureArrays
        )
    }
}
