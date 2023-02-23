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


// MARK: - Types



#endif /* Shared_h */
