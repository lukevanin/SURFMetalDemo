//
//  ExtremaFunction.swift
//  SURFMetalApp
//
//  Created by Luke Van In on 2023/02/23.
//

import Foundation
import Metal
import MetalKit


final class ExtremaFunction {
    
    let function: MetalFunction3D
    
    init(device: MTLDevice, threshold: Int) {
        var thresholdValue = UInt32(threshold)
        let constantValues = MTLFunctionConstantValues()
        constantValues.setConstantValue(&thresholdValue, type: .uint, index: 0)
        self.function = MetalFunction3D(
            device: device,
            name: "extrema",
            constantValues: constantValues
        )
    }
    
    func encode(
        commandBuffer: MTLCommandBuffer,
        width: Int,
        height: Int,
        hessianInputTextures: [MTLTexture],
        resultsOutputBuffer: DynamicBuffer<Coordinate>
    ) {
        precondition(width > 2)
        precondition(height > 2)
        precondition(hessianInputTextures.count > 2)
        function.encode(
            commandBuffer: commandBuffer,
            width: width - 2,
            height: height - 2,
            depth: hessianInputTextures.count - 2,
            buffers: [resultsOutputBuffer.buffer, resultsOutputBuffer.sizeBuffer],
            textures: [],
            textureArrays: [hessianInputTextures]
        )
    }
}
