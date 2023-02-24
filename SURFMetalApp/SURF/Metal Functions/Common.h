//
//  Common.metal
//  SURFMetalApp
//
//  Created by Luke Van In on 2023/02/24.
//

#ifndef Common_h
#define Common_h

#include <metal_stdlib>

#include "Shared.h"

using namespace metal;


// IntegralImage
class IntegralImage {
    texture2d<uint, access::read> texture;
    int2 padding;
    
public:
    IntegralImage(
                  texture2d<uint, access::read> texture,
                  int2 padding
                  ) : texture(texture), padding(padding)
    {
    }
    
    inline int getPixel(const int2 coordinate) {
        return (int)texture.read(uint2(padding + coordinate)).r;
    }
    
    inline int squareConvolutionXY(
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
    
    // Convolution by a box [-1,+1]
    inline int haarX(int x,int y,int lambda) {
        return -(squareConvolutionXY(1,-lambda-1,-lambda-1,lambda*2+1, x, y)+
                squareConvolutionXY(0,-lambda-1, lambda+1,lambda*2+1, x, y));
        
        
    }

    // Convolution by a box [-1;+1]
    inline int haarY(int x,int y,int lambda) {
        return -(squareConvolutionXY(-lambda-1,1, 2*lambda+1,-lambda-1, x, y)+
             squareConvolutionXY(-lambda-1,0, 2*lambda+1,lambda+1, x, y));
    }

};


// Patch
class Patch {
    
    array<texture2d<float, access::read>, 4> textures;
    int3 origin;
    
public:
    Patch(array<texture2d<float, access::read>, 4> textures,
          int3 origin) : textures(textures), origin(origin) {
    }

    inline int getPixel(const int x, const int y, const int z) {
        return getPixel(int3(x, y, z));
    }

    inline int getPixel(const int3 offset) {
        const uint3 coordinate = uint3(origin + offset);
        return textures[coordinate.z].read(coordinate.xy).r;
    }
};

#endif /* Common.h */
