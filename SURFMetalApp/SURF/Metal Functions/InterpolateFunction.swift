//
//  ExtremaFunction.swift
//  SURFMetalApp
//
//  Created by Luke Van In on 2023/02/23.
//

import Foundation
import Metal
import MetalKit


final class InterpolateFunction {
    
    let function: MetalFunction1D
    
    init(device: MTLDevice, octave: Int, sampleImage: Int, padding: Int) {
        var octaveValue = UInt32(octave)
        var sampleImageValue = UInt32(sampleImage)
        var padingValue = UInt32(padding)
        let constantValues = MTLFunctionConstantValues()
        constantValues.setConstantValue(&octaveValue, type: .uint, index: 0)
        constantValues.setConstantValue(&sampleImageValue, type: .uint, index: 1)
        constantValues.setConstantValue(&padingValue, type: .uint, index: 2)
        self.function = MetalFunction1D(
            device: device,
            name: "interpolate",
            constantValues: constantValues
        )
    }
    
    func encode(
        commandBuffer: MTLCommandBuffer,
        integralImageInputTexture: MTLTexture,
        hessianInputTextures: [MTLTexture],
        extremaInputBuffer: DynamicBuffer<Coordinate>,
        keypointsOutputBuffer: DynamicBuffer<Keypoint>
    ) {
        function.encode(
            commandBuffer: commandBuffer,
            length: extremaInputBuffer.count,
            buffers: [
                extremaInputBuffer.buffer,
                keypointsOutputBuffer.buffer,
                keypointsOutputBuffer.sizeBuffer
            ],
            textures: [
                integralImageInputTexture,
            ],
            textureArrays: [
                hessianInputTextures
            ]
        )
    }
}
