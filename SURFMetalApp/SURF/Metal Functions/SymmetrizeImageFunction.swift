//
//  SymmetrizeImageFunction.swift
//  SURFMetalApp
//
//  Created by Luke Van In on 2023/02/24.
//

import Foundation
import Metal


final class SymmetrizeImageFunction {
    
    let padding: Int
    let function: MetalFunction2D
    
    init(device: MTLDevice, padding: Int) {
        var paddingValue = UInt32(padding)
        let constantValues = MTLFunctionConstantValues()
        constantValues.setConstantValue(&paddingValue, type: .uint, index: 0)
        self.function = MetalFunction2D(
            device: device,
            name: "symmetrize",
            constantValues: constantValues
        )
        self.padding = padding
    }
    
    func encode(
        commandBuffer: MTLCommandBuffer,
        sourceTexture: MTLTexture,
        targetTexture: MTLTexture
    ) {
        precondition(targetTexture.width == sourceTexture.width + (padding * 2))
        precondition(targetTexture.height == sourceTexture.height + (padding * 2))
        function.encode(
            commandBuffer: commandBuffer,
            width: targetTexture.width,
            height: targetTexture.height,
            buffers: [],
            textures: [
                sourceTexture,
                targetTexture
            ],
            textureArrays: []
        )
    }
}
