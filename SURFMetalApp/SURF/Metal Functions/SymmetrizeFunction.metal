//
//  SymmetrizeFunction.metal
//  SURFMetalApp
//
//  Created by Luke Van In on 2023/02/24.
//

#include <metal_stdlib>

#include "Shared.h"
#include "Common.h"

using namespace metal;


constant uint PADDING [[ function_constant(0) ]];


kernel void symmetrize(texture2d<ushort, access::read> sourceTexture [[ texture(0) ]],
                       texture2d<ushort, access::write> targetTexture [[ texture(1) ]],
                       uint2 gid [[ thread_position_in_grid ]]) {
    
    const int width = sourceTexture.get_width();
    const int height = sourceTexture.get_height();
    
    int i0 = (int)gid.x - (int)PADDING;
    int j0 = (int)gid.y - (int)PADDING;
    
    if (i0 < 0) {
        i0 = -i0;
    }
    if (j0 < 0) {
        j0 = -j0;
    }
    
    i0 = i0 % (2 * width);
    j0 = j0 % (2 * height);
    
    if (i0 >= width) {
        i0 = 2 * width - i0 - 1;
    }
    if (j0 >= height) {
        j0 = 2 * height - j0 - 1;
    }
    
    const int c = sourceTexture.read(uint2(i0, j0)).r;
    targetTexture.write(ushort4(c), gid);
}


