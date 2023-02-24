//
//  DescriptorFunction.swift
//  SURFMetalApp
//
//  Created by Luke Van In on 2023/02/24.
//

import Foundation
import Metal


final class DescriptorsFunction {
    
    let function: MetalFunction1D
    
    init(device: MTLDevice, padding: Int) {
        var paddingValue = UInt32(padding)
        let constantValues = MTLFunctionConstantValues()
        constantValues.setConstantValue(&paddingValue, type: .uint, index: 0)
        self.function = MetalFunction1D(device: device, name: "descriptors", constantValues: constantValues)
    }
    
    func encode(
        commandBuffer: MTLCommandBuffer,
        integralImageInputTexture: MTLTexture,
        keypointsInputBuffer: DynamicBuffer<Keypoint>,
        descriptorsOutputBuffer: DynamicBuffer<Descriptor>
    ) {
        precondition(descriptorsOutputBuffer.count == keypointsInputBuffer.count)
        function.encode(
            commandBuffer: commandBuffer,
            length: keypointsInputBuffer.count,
            buffers: [
                keypointsInputBuffer.buffer,
                descriptorsOutputBuffer.buffer
            ],
            textures: [
                integralImageInputTexture
            ],
            textureArrays: []
        )
    }
}
