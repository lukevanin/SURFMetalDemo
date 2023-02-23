//
//  IntegralImage.metal
//  SURFMetalApp
//
//  Created by Luke Van In on 2023/02/22.
//

#include <metal_stdlib>

#include "Shared.h"

using namespace metal;


kernel void integralImageSumX(
                              texture2d<uint, access::read> sourceTexture [[texture(0)]],
                              texture2d<uint, access::write> targetTexture [[texture(1)]],
                              uint y [[thread_position_in_grid]]
                              )
{
    const uint width = targetTexture.get_width();
    uint sum = 0;
    
    for (uint x = 0; x < width; x++) {
        uint value = sourceTexture.read(uint2(x, y)).r;
        sum += value;
        targetTexture.write(sum, uint2(x, y));
    }
}


kernel void integralImageSumY(
                              texture2d<uint, access::read> sourceTexture [[texture(0)]],
                              texture2d<uint, access::write> targetTexture [[texture(1)]],
                              uint x [[thread_position_in_grid]]
                              )
{
    const uint height = targetTexture.get_height();
    uint sum = 0;
    
    for (uint y = 0; y < height; y++) {
        uint value = sourceTexture.read(uint2(x, y)).r;
        sum += value;
        targetTexture.write((uint)sum, uint2(x, y));
    }
}


