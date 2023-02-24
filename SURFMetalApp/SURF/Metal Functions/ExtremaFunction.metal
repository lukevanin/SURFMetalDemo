//
//  ExtremaFunction.metal
//  SURFMetalApp
//
//  Created by Luke Van In on 2023/02/24.
//

#include <metal_stdlib>

#include "Shared.h"
#include "Common.h"

using namespace metal;


constant uint THRESHOLD [[ function_constant(0) ]];


kernel void extrema(device Coordinate * resultsBuffer [[ buffer(0) ]],
                    device atomic_uint * resultsCount [[ buffer(1) ]],
                    array<texture2d<float, access::read>, 4> hessianTextures [[ texture(2) ]],
                    uint3 gid [[ thread_position_in_grid ]]) {

    const int3 origin = int3(gid) + 1;
    Patch patch(hessianTextures, origin);
    const float tmp = patch.getPixel(int3(0));
    
    if (tmp <= THRESHOLD) {
        return;
    }

    #warning("TODO: Use array of offsets instead of loops?")
    for (int j = -1; j <= +1; j++) {
        for (int i = -1; i <= +1; i++) {
            if (patch.getPixel(int3(i, j, -1)) >= tmp) {
                return;
            }
            if (patch.getPixel(int3(i, j, +1)) >= tmp) {
                return;
            }
            if ((i != 0 || j != 0) && (patch.getPixel(int3(i, j, 0)) >= tmp)) {
                return;
            }
        }
    }

    threadgroup_barrier(metal::mem_flags::mem_threadgroup);
    const auto index = atomic_fetch_add_explicit(resultsCount, 1, memory_order_relaxed);
    
    Coordinate result;
    result.x = origin.x;
    result.y = origin.y;
    result.interval = origin.z;
    resultsBuffer[index] = result;
}
