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


constant uint OCTAVE [[ function_constant(0) ]];
constant uint SAMPLE_IMAGE [[ function_constant(1) ]];


kernel void interpolate(device Coordinate * coordinatesBuffer [[ buffer(0) ]],
                        device Keypoint * resultsBuffer [[ buffer(1) ]],
                        device atomic_uint * resultsCount [[ buffer(2) ]],
                        texture2d<float, access::read> integralImageTexture [[ texture(3) ]],
                        array<texture2d<float, access::read>, 4> hessianTextures [[ texture(4) ]],
                        uint gid [[ thread_position_in_grid ]]) {

//        let img = octaves[o].hessians

        //If we are outside the image...
//        if x <= 0 || y <= 0 || x >= (img[i].width - 2) || y >= (img[i].height - 2) {
//            return nil
//        }
    const Coordinate coordinate = coordinatesBuffer[gid];
    const int3 origin(coordinate.x, coordinate.y, coordinate.interval);
    Patch patch(hessianTextures, origin);
        
    // Nabla X
    const float dx = (patch.getPixel(+1, 0, 0) - patch.getPixel(-1, 0, 0)) / 2;
    const float dy = (patch.getPixel(0, +1, 0) - patch.getPixel(0, -1, 0)) / 2;
    const float di = (patch.getPixel(0, 0, 0) - patch.getPixel(0, 0, 0)) / 2;
    #warning("FIXME: Compute gradient in i")
    // let di = (img[i + 1][x, y] - img[i - 1][x, y]) / 2
    
    //Hessian X
    const float a = patch.getPixel(0, 0, 0);
    const float dxx = (patch.getPixel(+1, 0, 0) + patch.getPixel(-1, 0, 0)) - 2 * a;
    #warning("FIXME: Compute dyy gradient using (y + 1) + (y - 1)")
    const float dyy = (patch.getPixel(0, +1, 0) + patch.getPixel(0, +1, 0)) - 2 * a;
    const float dii = (patch.getPixel(0, 0, -1) + patch.getPixel(0, 0, +1)) - 2 * a;
    
    const float dxy = (patch.getPixel(+1, +1, 0) - patch.getPixel(+1, -1, 0) - patch.getPixel(-1, +1, 0) + patch.getPixel(-1, -1, 0)) / 4;
    const float dxi = (patch.getPixel(+1, 0, +1) - patch.getPixel(-1, 0, +1) - patch.getPixel(+1, 0, -1) + patch.getPixel(-1, 0, -1)) / 4;
    const float dyi = (patch.getPixel(0, +1, +1) - patch.getPixel(0, -1, +1) - patch.getPixel(0, +1, -1) + patch.getPixel(0, -1, -1)) / 4;
    
    // Det
    const float det = dxx * dyy * dii - dxx * dyi * dyi - dyy * dxi * dxi + 2 * dxi * dyi * dxy - dii * dxy * dxy;

    if (det == 0) {
        // Matrix must be inversible - maybe useless.
        return;
    }
    
    const float mx = -1.0 / det * (dx * (dyy * dii - dyi * dyi) + dy * (dxi * dyi - dii * dxy) + di * (dxy * dyi - dyy * dxi));
    const float my = -1.0 / det * (dx * (dxi * dyi - dii * dxy) + dy * (dxx * dii - dxi * dxi) + di * (dxy * dxi - dxx * dyi));
    const float mi = -1.0 / det * (dx * (dxy * dyi - dyy * dxi) + dy * (dxy * dxi - dxx * dyi) + di * (dxx * dyy - dxy * dxy));

    // If the point is stable
    if ((abs(mx) >= 1) || (abs(my) >= 1) || (abs(mi) >= 1)) {
        return;
    }
    
    const float sample = pow((float)SAMPLE_IMAGE, (float)OCTAVE); // Sampling step
    const float octaveValue = pow(2.0, (float)OCTAVE + 1);
    const float x_ = (float)sample * ((float)coordinate.x + mx) + 0.5; // Center the pixels value
    const float y_ = (float)sample * ((float)coordinate.y + my) + 0.5;
    const float s_ = 0.4 * (1 + (float)octaveValue * ((float)coordinate.interval + mi + 1));
    const float orientation = 0; // getOrientation(integralImage: integralImage, x: x_, y: y_, scale: s_)
    const int signLaplacian = 0; // octaves[o].signLaplacians[i][x, y]
    
    threadgroup_barrier(metal::mem_flags::mem_threadgroup);
    const auto index = atomic_fetch_add_explicit(resultsCount, 1, memory_order_relaxed);
    
    Keypoint keypoint;
    keypoint.x = x_;
    keypoint.y = y_;
    keypoint.scale = s_;
    keypoint.orientation = orientation;
    keypoint.laplacian = signLaplacian;

    resultsBuffer[index] = keypoint;
}
