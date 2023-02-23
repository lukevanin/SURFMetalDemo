//
//  IntegralImageFunction.swift
//  SURFMetalApp
//
//  Created by Luke Van In on 2023/02/22.
//

import Foundation
import Metal


final class IntegralImageSumXFunction {
    
    private let function: MetalFunction1D

    init(device: MTLDevice) {
        self.function = MetalFunction1D(device: device, name: "integralImageSumX")
    }
    
    func encode(
        commandBuffer: MTLCommandBuffer,
        sourceTexture: MTLTexture,
        targetTexture: MTLTexture
    ) {
        precondition(sourceTexture.pixelFormat == .r8Uint)
        precondition(targetTexture.pixelFormat == .r32Uint)
        precondition(sourceTexture.width == targetTexture.width)
        precondition(sourceTexture.height == targetTexture.height)
        function.encode(
            commandBuffer: commandBuffer,
            length: targetTexture.height,
            resources: [sourceTexture, targetTexture]
        )
    }
}


final class IntegralImageSumYFunction {
    
    private let function: MetalFunction1D

    init(device: MTLDevice) {
        self.function = MetalFunction1D(device: device, name: "integralImageSumY")
    }
    
    func encode(
        commandBuffer: MTLCommandBuffer,
        sourceTexture: MTLTexture,
        targetTexture: MTLTexture
    ) {
        precondition(sourceTexture.pixelFormat == .r32Uint)
        precondition(targetTexture.pixelFormat == .r32Uint)
        precondition(sourceTexture.width == targetTexture.width)
        precondition(sourceTexture.height == targetTexture.height)
        function.encode(
            commandBuffer: commandBuffer,
            length: targetTexture.width,
            resources: [sourceTexture, targetTexture]
        )
    }
}


final class IntegralImageFunction {
    
    private let workingTexture: MTLTexture
    private let xFunction: IntegralImageSumXFunction
    private let yFunction: IntegralImageSumYFunction

    init(device: MTLDevice, width: Int, height: Int) {
        self.workingTexture = {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .r32Uint,
                width: width,
                height: height,
                mipmapped: false
            )
            descriptor.usage = [.shaderRead, .shaderWrite]
            descriptor.storageMode = .private
            let texture = device.makeTexture(descriptor: descriptor)!
            texture.label = "IntegralImage(Workspace)"
            return texture
        }()
        self.xFunction = IntegralImageSumXFunction(device: device)
        self.yFunction = IntegralImageSumYFunction(device: device)
    }
    
    func encode(
        commandBuffer: MTLCommandBuffer,
        sourceTexture: MTLTexture,
        targetTexture: MTLTexture
    ) {
        precondition(sourceTexture.pixelFormat == .r8Uint)
        precondition(sourceTexture.width == targetTexture.width)
        precondition(sourceTexture.height == targetTexture.height)

        precondition(targetTexture.pixelFormat == .r32Uint)
        precondition(targetTexture.width == workingTexture.width)
        precondition(targetTexture.height == workingTexture.height)

        xFunction.encode(
            commandBuffer: commandBuffer,
            sourceTexture: sourceTexture,
            targetTexture: workingTexture
        )
        yFunction.encode(
            commandBuffer: commandBuffer,
            sourceTexture: workingTexture,
            targetTexture: targetTexture
        )
    }
}
