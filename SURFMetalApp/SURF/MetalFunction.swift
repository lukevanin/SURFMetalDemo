//
//  MetalFunction.swift
//  SURFMetalApp
//
//  Created by Luke Van In on 2023/02/22.
//

import Foundation
import Metal


final class MetalFunction1D {
    
    let device: MTLDevice
    let computePipelineState: MTLComputePipelineState
    
    init(device: MTLDevice, name: String) {
        self.device = device
        let library = device.makeDefaultLibrary()!
        let function = library.makeFunction(name: name)!
        self.computePipelineState = try! device.makeComputePipelineState(function: function)
    }
    
    func encode(
        commandBuffer: MTLCommandBuffer,
        length: Int,
        resources: [MTLResource]
    ) {
        let computeEncoder = commandBuffer.makeComputeCommandEncoder()!
        computeEncoder.setComputePipelineState(computePipelineState)
        for i in 0 ..< resources.count {
            let resource = resources[i]
            switch resource {
            case let texture as MTLTexture:
                computeEncoder.setTexture(texture, index: i)
            case let buffer as MTLBuffer:
                computeEncoder.setBuffer(buffer, offset: 0, index: i)
            default:
                fatalError("Unsupported MTLResource type \(resource)")
            }
        }
        let grid = MTLSize(width: length, height: 1, depth: 1)
        let threads = MTLSize(width: min(length, computePipelineState.maxTotalThreadsPerThreadgroup), height: 1, depth: 1)
        computeEncoder.dispatchThreads(grid, threadsPerThreadgroup: threads)
        computeEncoder.endEncoding()
    }
}


final class MetalFunction2D {
    
    let device: MTLDevice
    let computePipelineState: MTLComputePipelineState
    
    init(device: MTLDevice, name: String, constantValues: MTLFunctionConstantValues) {
        self.device = device
        let library = device.makeDefaultLibrary()!
        let function = try! library.makeFunction(name: name, constantValues: constantValues)
        self.computePipelineState = try! device.makeComputePipelineState(function: function)
    }
    
    func encode(
        commandBuffer: MTLCommandBuffer,
        width: Int,
        height: Int,
        resources: [MTLResource]
    ) {
        let computeEncoder = commandBuffer.makeComputeCommandEncoder()!
        computeEncoder.setComputePipelineState(computePipelineState)
        for i in 0 ..< resources.count {
            let resource = resources[i]
            switch resource {
            case let texture as MTLTexture:
                computeEncoder.setTexture(texture, index: i)
            case let buffer as MTLBuffer:
                computeEncoder.setBuffer(buffer, offset: 0, index: i)
            default:
                fatalError("Unsupported MTLResource type \(resource)")
            }
        }
        let grid = MTLSize(width: width, height: height, depth: 1)
        let w = computePipelineState.threadExecutionWidth
        let h = computePipelineState.maxTotalThreadsPerThreadgroup / w
        let threads = MTLSize(width: w, height: h, depth: 1)
        computeEncoder.dispatchThreads(grid, threadsPerThreadgroup: threads)
        computeEncoder.endEncoding()
    }
}


//final class MetalFunction2DParams<Params> {
//
//    let function: MetalFunction2D
//    let parametersBuffer: MTLBuffer
//
//    init(device: MTLDevice, name: String, constants: MTLConst) {
//        self.function = MetalFunction2D(device: device, name: name)
//        self.parametersBuffer = device.makeBuffer(length: MemoryLayout<Params>.stride, options: [.hazardTrackingModeTracked])!
//    }
//
//    func encode(
//        commandBuffer: MTLCommandBuffer,
//        width: Int,
//        height: Int,
//        parameters: Params,
//        resources: [MTLResource]
//    ) {
//        let parametersPointer = parametersBuffer.contents().assumingMemoryBound(to: Params.self)
//        parametersPointer[0] = parameters
//
//        let combinedResources = [parameters] + resources
//        function.encode(
//            commandBuffer: commandBuffer,
//            width: width,
//            height: height,
//            resources: resources
//        )
//    }
//}
