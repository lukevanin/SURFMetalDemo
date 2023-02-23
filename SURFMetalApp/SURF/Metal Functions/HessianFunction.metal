//
//  HessianFunction.metal
//  SURFMetalApp
//
//  Created by Luke Van In on 2023/02/23.
//

#include <metal_stdlib>

#include "Shared.h"

using namespace metal;


constant uint PADDING [[ function_constant(0) ]];
constant uint SAMPLE_IMAGE [[ function_constant(1) ]];
constant uint OCTAVE [[ function_constant(2) ]];
constant uint INTERVAL [[ function_constant(3) ]];



class IntegralImage {
    texture2d<uint, access::read> texture [[texture(1)]];
    int2 padding;
    
public:
    IntegralImage(
                  texture2d<uint, access::read> texture [[texture(1)]],
                  int2 padding
                  ) : texture(texture), padding(padding)
    {
    }
    
    int getPixel(const int2 coordinate) {
        return (int)texture.read(uint2(padding + coordinate)).r;
    }
    
    int squareConvolutionXY(
                                     const int a,
                                     const int b,
                                     const int c,
                                     const int d,
                                     const int x,
                                     const int y
                                     )
    {
        const int a1 = x - a;
        const int a2 = y - b;
        const int b1 = a1 - c;
        const int b2 = a2 - d;
        return getPixel(int2(b1, b2)) + getPixel(int2(a1, a2)) - getPixel(int2(b1, a2)) - getPixel(int2(a1, b2)); // Note: No L2-normalization is performed here.
    }
};


kernel void hessian(texture2d<uint, access::read> integralSourceTexture [[ texture(0) ]],
                    texture2d<float, access::write> hessianTargetTexture [[ texture(1) ]],
                    texture2d<ushort, access::write> laplacianTargetTexture [[ texture(2) ]],
                    uint2 gid [[ thread_position_in_grid ]])
{

    IntegralImage img(integralSourceTexture, int2(PADDING));

    #warning("TODO: Use 1 << (octaveCounter + 1)")
    const int pow2 = pow(2.0, (float)(OCTAVE + 1));
    const int sample = pow((float)SAMPLE_IMAGE, (float)OCTAVE); // Sampling step

    const int l = pow2 * (INTERVAL + 1) + 1; // the "L" in the article.
    
    // These variables are precomputed to allow fast computations.
    // They correspond exactly to the Gamma of the formula given in the article for
    // the second order filters.
    const int lp1 = -l + 1;
    const int l3 = 3 * l;
    const int lp1d2 = (-l + 1) / 2;
    const int mlp1p2 = (-l + 1) / 2 - l;
    const int l2p1 = 2 * l - 1;
    
    const float nxx = sqrt((float)(6 * l * (2 * l - 1))); // frobenius norm of the xx and yy filters
    const float nxy = sqrt((float)(4 * l * l)); // frobenius of the xy filter.
    
    // These are the time consuming loops that compute the Hessian at each points.
    
    // Sampling
    int xcoo = (int)gid.x * sample;
    int ycoo = (int)gid.y * sample;
    
    // Second order filters
    float Dxx = img.squareConvolutionXY(lp1, mlp1p2, l2p1, l3, xcoo, ycoo) - 3 * img.squareConvolutionXY(lp1, lp1d2, l2p1, l, xcoo, ycoo);
    Dxx /= nxx;
    
    float Dyy = img.squareConvolutionXY(mlp1p2, lp1, l3, l2p1, xcoo, ycoo) - 3 * img.squareConvolutionXY(lp1d2, lp1, l, l2p1, xcoo, ycoo);
    Dyy /= nxx;
    
    float Dxy = img.squareConvolutionXY(1, 1, l, l, xcoo, ycoo) + img.squareConvolutionXY(0, 0, -l, -l, xcoo, ycoo) + img.squareConvolutionXY(1, 0, l, -l, xcoo, ycoo) + img.squareConvolutionXY(0, 1, -l, l, xcoo, ycoo);
    Dxy /= nxy;
    
    // Computation of the Hessian and Laplacian
    //                        let w: Float = 0.9129
    const float hessian = (Dxx * Dyy) - (0.8317 * (Dxy * Dxy));
    const ushort laplacian = (Dxx + Dyy) > 0 ? 1 : 0;
//    if (hessian > 0) {
//        hessianTargetTexture.write(float4(1), gid);
//    }
//    else {
//        hessianTargetTexture.write(float4(0), gid);
//    }
    hessianTargetTexture.write(float4(hessian), gid);
    laplacianTargetTexture.write(ushort4(laplacian), gid);
}
