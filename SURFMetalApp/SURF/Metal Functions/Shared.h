//
//  Shared.h
//  SURFMetalApp
//
//  Created by Luke Van In on 2023/02/22.
//

#ifndef Shared_h
#define Shared_h


#ifdef __METAL_VERSION__
// MARK: - Metal

#include <metal_stdlib>
#include <simd/simd.h>

#define METAL_ATTRIBUTE(_index) [[attribute(_index)]]

typedef metal::int32_t EnumBackingType;


#else
// MARK: - Swift

#import <Foundation/Foundation.h>
#import <simd/simd.h>

#define METAL_ATTRIBUTE(_index)

#endif


#define DESCRIPTOR_SIZE_1D 4

#define DESCRIPTOR_LENGTH 16


// MARK: - Types


struct Coordinate {
    uint32_t x;
    uint32_t y;
    uint32_t interval;
};


struct Keypoint {
    float x;
    float y;
    float scale;
    float orientation;
    int32_t laplacian;
};


struct VectorDescriptor {
    float sumDx;
    float sumDy;
    float sumAbsDx;
    float sumAbsDy;
};


struct Descriptor {
    struct Keypoint keypoint;
    struct VectorDescriptor vector[DESCRIPTOR_LENGTH];
};


#endif /* Shared_h */
