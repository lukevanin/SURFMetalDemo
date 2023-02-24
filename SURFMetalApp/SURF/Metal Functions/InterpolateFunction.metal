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
constant uint PADDING [[ function_constant(2) ]];

constant float PI = 3.14159265358979323846;
constant int NUMBER_SECTOR = 20;


// Gaussian - should be computed as an array to be faster.
inline float gaussian(float x, float y, float sig)
{
    return 1 / (2 * PI * sig * sig) * exp( -(x * x + y * y) / (2 * sig * sig));
}


// Round-off functions
inline int fround(float flt) { return (int) (flt+0.5f); }


// Compute the orientation to assign to a keypoint
inline float getOrientation(IntegralImage integralImage,
                            const int x,
                            const int y,
                            const float scale) {
    
    float haarResponseX[NUMBER_SECTOR];
    float haarResponseY[NUMBER_SECTOR];
    float haarResponseSectorX[NUMBER_SECTOR];
    float haarResponseSectorY[NUMBER_SECTOR];
    float answerX, answerY;
    float gauss;
    
    int theta;
    
    for (int i = 0; i < NUMBER_SECTOR; i++) {
        haarResponseX[i] = 0;
        haarResponseY[i] = 0;
        haarResponseSectorX[i] = 0;
        haarResponseSectorY[i] = 0;
    }
    
    // Computation of the contribution of each angular sectors.
    for ( int i = -6 ; i <= 6 ; i++ ) {
        for( int j = -6 ; j <= 6 ; j++ ) {
            if (i * i + j * j <= 36) {
                
                answerX = integralImage.haarX(x + scale * i, y + scale * j, fround(2 * scale));
                answerY = integralImage.haarY(x + scale * i, y + scale * j, fround(2 * scale));
                
                // Associated angle
                theta = (int)(atan2(answerY, answerX) * NUMBER_SECTOR / (2 * PI));
                theta = ((theta >= 0) ? (theta) : (theta + NUMBER_SECTOR));
                
                // Gaussian weight
                gauss = gaussian(i,j,2);
                
                // Cumulative answers
                haarResponseSectorX[theta] += answerX * gauss;
                haarResponseSectorY[theta] += answerY * gauss;
            }
        }
    }

    // Compute a windowed answer
    for(int i=0 ; i < NUMBER_SECTOR; i++) {
        for(int j = -NUMBER_SECTOR / 12; j <= NUMBER_SECTOR / 12; j++) {
            if ((0 <= i + j) && (i + j < NUMBER_SECTOR)) {
                haarResponseX[i] += haarResponseSectorX[i + j];
                haarResponseY[i] += haarResponseSectorY[i + j];
            }
            // The answer can be on any quadrant of the unit circle
            else if (i + j < 0) {
                haarResponseX[i] += haarResponseSectorX[NUMBER_SECTOR + i + j];
                haarResponseY[i] += haarResponseSectorY[i + j + NUMBER_SECTOR];
            }
            else {
                haarResponseX[i] += haarResponseSectorX[i + j - NUMBER_SECTOR];
                haarResponseY[i] += haarResponseSectorY[i + j - NUMBER_SECTOR];
            }
        }
    }
    
    // Find out the maximum answer
    float max = haarResponseX[0] * haarResponseX[0] + haarResponseY[0] * haarResponseY[0];
    
    int t = 0;
    for (int i=1 ; i < NUMBER_SECTOR ; i++ ) {
        float norm = haarResponseX[i] * haarResponseX[i] + haarResponseY[i] * haarResponseY[i];
        t = ((max < norm) ? i : t);
        max = ((max < norm) ? norm : max);
    }
        
    // Return the angle ; better than atan which is not defined in pi/2
    return atan2(haarResponseY[t], haarResponseX[t]);
}


kernel void interpolate(device Coordinate * coordinatesBuffer [[ buffer(0) ]],
                        device Keypoint * resultsBuffer [[ buffer(1) ]],
                        device atomic_uint * resultsCount [[ buffer(2) ]],
                        texture2d<uint, access::read> integralImageTexture [[ texture(3) ]],
                        array<texture2d<float, access::read>, 4> hessianTextures [[ texture(4) ]],
                        uint gid [[ thread_position_in_grid ]]) {

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
#warning("TODO: Get orientation when computing descriptor")
    IntegralImage integralImage(integralImageTexture, int2(PADDING));
    const float orientation = getOrientation(integralImage, x_, y_, s_);
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
