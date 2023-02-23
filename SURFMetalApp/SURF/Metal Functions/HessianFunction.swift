//
//  HessianFunction.swift
//  SURFMetalApp
//
//  Created by Luke Van In on 2023/02/22.
//

import Foundation
import Metal


final class HessianFunction {
    
    struct Configuration {
        var padding: Int
        var sampleImage: Int
        var octaveCounter: Int
        var intervalCounter: Int
        var sampleWidth: Int
        var sampleHeight: Int
    }
    
    private let configuration: Configuration
    private let function: MetalFunction2D
    
    init(device: MTLDevice, configuration: Configuration) {
        var padding = UInt32(configuration.padding)
        var sampleImage = UInt32(configuration.sampleImage)
        var octaveCounter = UInt32(configuration.octaveCounter)
        var intervalCounter = UInt32(configuration.intervalCounter)
        let constantValues = MTLFunctionConstantValues()
        constantValues.setConstantValue(&padding, type: .uint, index: 0)
        constantValues.setConstantValue(&sampleImage, type: .uint, index: 1)
        constantValues.setConstantValue(&octaveCounter, type: .uint, index: 2)
        constantValues.setConstantValue(&intervalCounter, type: .uint, index: 3)
        self.function = MetalFunction2D(device: device, name: "hessian", constantValues: constantValues)
        self.configuration = configuration
    }
    
    func encode(
        commandBuffer: MTLCommandBuffer,
        integralImageInputTexture: MTLTexture,
        hessianOutputTexture: MTLTexture,
        laplacianOutputTexture: MTLTexture
    ) {
        let sample = Int(pow(Float(configuration.sampleImage), Float(configuration.octaveCounter))) // Sampling step
        let padding = configuration.padding * 2
        let paddedWidth = (configuration.sampleWidth * sample) + padding
        let paddedHeight = (configuration.sampleHeight * sample) + padding

        precondition(integralImageInputTexture.pixelFormat == .r32Uint)
        precondition(integralImageInputTexture.width == paddedWidth)
        precondition(integralImageInputTexture.height == paddedHeight)

        precondition(hessianOutputTexture.pixelFormat == .r32Float)
        precondition(hessianOutputTexture.width == configuration.sampleWidth)
        precondition(hessianOutputTexture.height == configuration.sampleHeight)
        
        precondition(laplacianOutputTexture.pixelFormat == .r8Uint)
        precondition(laplacianOutputTexture.width == configuration.sampleWidth)
        precondition(laplacianOutputTexture.height == configuration.sampleHeight)
        
        function.encode(
            commandBuffer: commandBuffer,
            width: configuration.sampleWidth,
            height: configuration.sampleHeight,
            resources: [
                integralImageInputTexture,
                hessianOutputTexture,
                laplacianOutputTexture
            ]
        )
    }
}
