//
//  DescriptorsFunction.metal
//  SURFMetalApp
//
//  Created by Luke Van In on 2023/02/24.
//

#include <metal_stdlib>

#include "Shared.h"
#include "Common.h"

using namespace metal;


constant uint PADDING [[ function_constant(0) ]];


kernel void descriptors(device Keypoint * keypointsBuffer [[ buffer(0) ]],
                        device Descriptor * descriptorsBuffer [[ buffer(1) ]],
                        texture2d<uint, access::read> integralImageTexture [[ texture(2) ]],
                        uint gid [[ thread_position_in_grid ]]) {
    
    Keypoint keypoint = keypointsBuffer[gid];
    IntegralImage integralImage(integralImageTexture, (int)PADDING);
    
    const float scale = keypoint.scale;

    // Divide in a 4x4 zone the space around the interest point

    // First compute the orientation.
    const float cosP = cos(keypoint.orientation);
    const float sinP = sin(keypoint.orientation);
    float norm = 0;

    Descriptor descriptor;
    descriptor.keypoint = keypoint;
    
    // Divide in 16 sectors the space around the interest point.
    for (int i = 0; i < DESCRIPTOR_SIZE_1D; i++) {
        for (int j = 0; j < DESCRIPTOR_SIZE_1D; j++) {
            
            float sumDx = 0;
            float sumAbsDx = 0;
            float sumDy = 0;
            float sumAbsDy = 0;

            // Then each 4x4 is subsampled into a 5x5 zone
            for (int k = 0; k < 5; k++) {
                for (int l = 0; l < 5; l++)  {
                    
                    // We pre compute Haar answers
                    #warning("TODO: Use simd matrix multiplication")
                    float u = (keypoint.x + scale * (cosP * (((float)i - 2) * 5 + (float)k + 0.5) - sinP * (((float)j - 2) * 5 + (float)l + 0.5)));
                    float v = (keypoint.y + scale * (sinP * (((float)i - 2) * 5 + (float)k + 0.5) + cosP * (((float)j - 2) * 5 + (float)l + 0.5)));
                    
                    // (u,v) are already translated of 0.5, which means
                    // that there is no round-off to perform: one takes
                    // the integer part of the coordinates.
                    float responseX = integralImage.haarX((int)u, (int)v, fround(scale));
                    float responseY = integralImage.haarY((int)u, (int)v, fround(scale));
                    
                    // Gaussian weight
                    float gauss = gaussian(
                        ((float)i - 2) * 5 + (float)k + 0.5,
                        ((float)j - 2) * 5 + (float)l + 0.5,
                        3.3
                    );
                    
                    // Rotation of the axis
                    #warning("TODO: Use simd matrix multiplication")
                    //responseU = gauss*( -responseX*sinP + responseY*cosP);
                    //responseV = gauss*(responseX*cosP + responseY*sinP);
                    float responseU = gauss * (+(float)responseX * cosP + (float)responseY * sinP);
                    float responseV = gauss * (-(float)responseX * sinP + (float)responseY * cosP);
                    
                    // The descriptors.
                    sumDx += responseU;
                    sumAbsDx += abs(responseU);
                    sumDy += responseV;
                    sumAbsDy += abs(responseV);
                }
            }
            
            int index = DESCRIPTOR_SIZE_1D * i + j;
            VectorDescriptor vector = { sumDx, sumDy, sumAbsDx, sumAbsDy };
            descriptor.vector[index] = vector;
            
            // Compute the norm of the vector
            norm += sumAbsDx * sumAbsDx + sumAbsDy * sumAbsDy + sumDx * sumDx + sumDy * sumDy;
        }
    }
    
    // Normalization of the descriptors in order to improve invariance to contrast change
    // and whitening the descriptors.
    norm = sqrt(norm);
    if (norm != 0) {
        for (int i = 0; i < DESCRIPTOR_LENGTH; i++) {
            descriptor.vector[i].sumDx /= norm;
            descriptor.vector[i].sumAbsDx /= norm;
            descriptor.vector[i].sumDy /= norm;
            descriptor.vector[i].sumAbsDy /= norm;
        }
    }
    
    descriptorsBuffer[gid] = descriptor;
}

