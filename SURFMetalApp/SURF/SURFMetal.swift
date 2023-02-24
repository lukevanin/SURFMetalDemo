//
//  SURFMetal.swift
//  SURFMetalApp
//
//  Created by Luke Van In on 2023/02/16.
//

import Foundation
import OSLog
import Metal
import MetalKit


private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "SURFMetal")


private let pi: Float = 3.14159265358979323846

// Amount of considered angular regions
private let NUMBER_SECTOR = 20

// Ratio between two matches
private let RATE: Float = 0.6

// Maximum octave
private let OCTAVE = 4

// Maximum scale
private let INTERVAL = 4

// Sampling of the image at each step
private let SAMPLE_IMAGE = 2

// Size of the descriptor along x or y dimension
private let DESCRIPTOR_SIZE_1D = 4

// Padding applied to image when computing the integral image = size descriptor * max size L = 4*0.4*195;
private let PADDING = 312

// Gaussian - should be computed as an array to be faster.
private func gaussian(x: Float, y: Float, sig: Float) -> Float {
    return 1 / (2 * pi * sig * sig) * exp( -(x * x + y * y) / (2 * sig * sig))
}


final class SURFMetalOctave {
    
    let octaveCounter: Int
    let width: Int
    let height: Int
    
    let hessians: [MetalField]
    let signLaplacians: [MetalBitmap]
    
    let hessianFunctions: [HessianFunction]
    let extremaFunction: ExtremaFunction
    let interpolateFunction: InterpolateFunction
    let descriptorsFunction: DescriptorsFunction

    let extremaResultBuffer: DynamicBuffer<Coordinate>
    let keypointResultsBuffer: DynamicBuffer<Keypoint>
    let descriptorResultsBuffer: DynamicBuffer<Descriptor>

    let hessianTextures: [MTLTexture]
    let laplacianTextures: [MTLTexture]

    init(device: MTLDevice, octaveCounter: Int, width: Int, height: Int, padding: Int, threshold: Int) {
        
        var hessians: [MetalField] = []
        var signLaplacians: [MetalBitmap] = []
        
        var hessianTextures: [MTLTexture] = []
        var laplacianTextures: [MTLTexture] = []
        
        var hessianFunctions: [HessianFunction] = []

        for intervalCounter in 0 ..< INTERVAL {
            
            let hessianConfiguration = HessianFunction.Configuration(
                padding: padding,
                sampleImage: SAMPLE_IMAGE,
                octaveCounter: octaveCounter,
                intervalCounter: intervalCounter,
                sampleWidth: width,
                sampleHeight: height
            )
            let hessianFunction = HessianFunction(
                device: device,
                configuration: hessianConfiguration
            )
            
            let hessianTexture: MTLTexture = {
                let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                    pixelFormat: .r32Float,
                    width: width,
                    height: height,
                    mipmapped: false
                )
                descriptor.usage = [.shaderRead, .shaderWrite]
                descriptor.storageMode = .private
                let texture = device.makeTexture(descriptor: descriptor)!
                texture.label = "Hessian.\(octaveCounter).\(intervalCounter)"
                return texture
            }()
            
            let laplacianTexture: MTLTexture = {
                let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                    pixelFormat: .r8Uint,
                    width: width,
                    height: height,
                    mipmapped: false
                )
                descriptor.usage = [.shaderRead, .shaderWrite]
                descriptor.storageMode = .private
                let texture = device.makeTexture(descriptor: descriptor)!
                texture.label = "Laplacian.\(octaveCounter).\(intervalCounter)"
                return texture
            }()

            let hessian = MetalField(
                device: device,
                name: "Hessian.\(octaveCounter).\(intervalCounter)",
                width: width,
                height: height
            )
            let signLaplacian = MetalBitmap(
                device: device,
                name: "Laplacian.\(octaveCounter).\(intervalCounter)",
                width: width,
                height: height
            )
            
            hessians.append(hessian)
            signLaplacians.append(signLaplacian)
            hessianFunctions.append(hessianFunction)
            hessianTextures.append(hessianTexture)
            laplacianTextures.append(laplacianTexture)
        }
        
        let extremaFunction = ExtremaFunction(
            device: device,
            threshold: threshold
        )

        let interpolateFunction = InterpolateFunction(
            device: device,
            octave: octaveCounter,
            sampleImage: SAMPLE_IMAGE,
            padding: padding
        )
        
        let descriptorsFunction = DescriptorsFunction(
            device: device,
            padding: padding
        )

        let extremaResultBuffer: DynamicBuffer<Coordinate> = DynamicBuffer(
            device: device,
            name: "Extrema",
            capacity: 1024 * 4
        )

        let keypointResultsBuffer: DynamicBuffer<Keypoint> = DynamicBuffer(
            device: device,
            name: "Keypoints",
            capacity: 1024 * 8
        )

        let descriptorResultsBuffer: DynamicBuffer<Descriptor> = DynamicBuffer(
            device: device,
            name: "Descriptors",
            capacity: 1024 * 8
        )

        self.octaveCounter = octaveCounter
        self.width = width
        self.height = height
        self.hessians = hessians
        self.signLaplacians = signLaplacians
        self.hessianTextures = hessianTextures
        self.laplacianTextures = laplacianTextures
        self.hessianFunctions = hessianFunctions
        self.extremaFunction = extremaFunction
        self.interpolateFunction = interpolateFunction
        self.descriptorsFunction = descriptorsFunction
        self.extremaResultBuffer = extremaResultBuffer
        self.keypointResultsBuffer = keypointResultsBuffer
        self.descriptorResultsBuffer = descriptorResultsBuffer
    }
    
    func findKeypoints(commandBuffer: MTLCommandBuffer, integralImageTexture: MTLTexture) {
        
        for intervalCounter in 0 ..< INTERVAL {
            
            let hessianTexture = hessianTextures[intervalCounter]
            let laplacianTexture = laplacianTextures[intervalCounter]
            let hessianFunction = hessianFunctions[intervalCounter]
            
            hessianFunction.encode(
                commandBuffer: commandBuffer,
                integralImageInputTexture: integralImageTexture,
                hessianOutputTexture: hessianTexture,
                laplacianOutputTexture: laplacianTexture
            )
            
            hessians[intervalCounter].copyFromTexture(
                commandBuffer: commandBuffer,
                sourceTexture: hessianTexture
            )
            
            signLaplacians[intervalCounter].copyFromTexture(
                commandBuffer: commandBuffer,
                sourceTexture: laplacianTexture
            )
        }
        
        extremaResultBuffer.allocate(0)
        extremaFunction.encode(
            commandBuffer: commandBuffer,
            width: width,
            height: height,
            hessianInputTextures: hessianTextures,
            resultsOutputBuffer: extremaResultBuffer
        )
    }
    
    func interpolateKeypoints(commandBuffer: MTLCommandBuffer, integralImageTexture: MTLTexture) {
        keypointResultsBuffer.allocate(0)
        interpolateFunction.encode(
            commandBuffer: commandBuffer,
            integralImageInputTexture: integralImageTexture,
            hessianInputTextures: hessianTextures,
            laplacianInputTextures: laplacianTextures,
            extremaInputBuffer: extremaResultBuffer,
            keypointsOutputBuffer: keypointResultsBuffer
        )
    }
    
    func getDescriptors(commandBuffer: MTLCommandBuffer, integralImageTexture: MTLTexture) {
        logger.info("Getting \(self.keypointResultsBuffer.count) descriptors")
        descriptorResultsBuffer.allocate(keypointResultsBuffer.count)
        descriptorsFunction.encode(
            commandBuffer: commandBuffer,
            integralImageInputTexture: integralImageTexture,
            keypointsInputBuffer: keypointResultsBuffer,
            descriptorsOutputBuffer: descriptorResultsBuffer
        )
    }
}


final class SURFMetal {
    
    let width: Int
    let height: Int
    
    let padding: Int
    
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    
    private let symmetrizedImageTexture: MTLTexture
    private let integralImageTexture: MTLTexture
    
    private let integralImageFunction: IntegralImageFunction
    
    private let integralImage: MetalIntegralImage
    
    let octaves: [SURFMetalOctave]
    
    init(
        device: MTLDevice = MTLCreateSystemDefaultDevice()!,
        width: Int,
        height: Int,
        threshold: Int = 1000
    ) {
        
        let padding = PADDING
        
        let integralImage = MetalIntegralImage(
            device: device,
            name: "IntegralImage",
            width: width,
            height: height,
            padding: padding
        )

        let commandQueue = device.makeCommandQueue()!
        
        let symmetrizedImageTexture: MTLTexture = {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .r8Uint,
                width: integralImage.paddedWidth,
                height: integralImage.paddedHeight,
                mipmapped: false
            )
            descriptor.usage = [.shaderRead, .shaderWrite]
            descriptor.storageMode = .private
            descriptor.hazardTrackingMode = .tracked
            descriptor.storageMode = .private
            let texture = device.makeTexture(descriptor: descriptor)!
            texture.label = "SymmetrizedImage"
            return texture
        }()
        
        let integralImageTexture: MTLTexture = {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .r32Uint,
                width: integralImage.paddedWidth,
                height: integralImage.paddedHeight,
                mipmapped: false
            )
            descriptor.usage = [.shaderRead, .shaderWrite]
            descriptor.storageMode = .private
            descriptor.hazardTrackingMode = .tracked
            let texture = device.makeTexture(descriptor: descriptor)!
            texture.label = "IntegralImage"
            return texture
        }()
        
        let integralImageFunction = IntegralImageFunction(
            device: device,
            width: integralImage.paddedWidth,
            height: integralImage.paddedHeight
        )

        var octaves: [SURFMetalOctave] = []
        for octaveCounter in 0 ..< OCTAVE {
            
            let sample = Int(pow(Float(SAMPLE_IMAGE), Float(octaveCounter))) // Sampling step

            let octaveWidth = width / sample
            let octaveHeight = height / sample
            
            let octave = SURFMetalOctave(
                device: device,
                octaveCounter: octaveCounter,
                width: octaveWidth,
                height: octaveHeight,
                padding: padding,
                threshold: threshold
            )
            octaves.append(octave)
        }
        
        self.device = device
        self.commandQueue = commandQueue
        self.integralImageTexture = integralImageTexture
        self.symmetrizedImageTexture = symmetrizedImageTexture
        self.integralImageFunction = integralImageFunction
        self.width = width
        self.height = height
        self.padding = padding
        self.integralImage = integralImage
        self.octaves = octaves
    }
        
    func getKeypoints(image: MetalBitmap) -> [Descriptor] {
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let endTIme = CFAbsoluteTimeGetCurrent()
            let elapsedTime = endTIme - startTime
            let framesPerSecond = 1 / elapsedTime
            print("Time: ", elapsedTime, "seconds", "/", framesPerSecond, "frames per second")
        }
        
        let symmetrizedBitmap = image.symmetrized(padding: padding)

        capture("findKeypoints", commandQueue: commandQueue, capture: false) { commandBuffer in
            
            // Compute the integral image
            makeIntegralImage(
                commandBuffer: commandBuffer,
                symmetrizedBitmap: symmetrizedBitmap
            )
            
            // Compute Hessians and of each sign of the Laplacian for each interval
            // in each octave.
            for octaveCounter in 0 ..< OCTAVE {
                let octave = octaves[octaveCounter]
                octave.findKeypoints(
                    commandBuffer: commandBuffer,
                    integralImageTexture: integralImageTexture
                )
            }
        }
        
        capture("interpolateKeypoints", commandQueue: commandQueue, capture: false) { commandBuffer in
            for octaveCounter in 0 ..< OCTAVE {
                let octave = octaves[octaveCounter]
                octave.interpolateKeypoints(
                    commandBuffer: commandBuffer,
                    integralImageTexture: integralImageTexture
                )
            }
        }
        
        capture("descriptors", commandQueue: commandQueue, capture: false) { commandBuffer in
            for octaveCounter in 0 ..< OCTAVE {
                let octave = octaves[octaveCounter]
                octave.getDescriptors(
                    commandBuffer: commandBuffer,
                    integralImageTexture: integralImageTexture
                )
            }
        }

        let output = getDescriptors()
        return output
    }

    private func makeIntegralImage(commandBuffer: MTLCommandBuffer, symmetrizedBitmap: MetalBitmap) {
        logger.info("getKeypoints: Creating integral image: width=\(self.integralImage.paddedWidth) height=\(self.integralImage.paddedHeight) padding=\(self.integralImage.padding)")
        
        symmetrizedBitmap.copyToTexture(
            commandBuffer: commandBuffer,
            targetTexture: symmetrizedImageTexture
        )
        
        integralImageFunction.encode(
            commandBuffer: commandBuffer,
            sourceTexture: symmetrizedImageTexture,
            targetTexture: integralImageTexture
        )
        
        integralImage.copyFromTexture(
            commandBuffer: commandBuffer,
            sourceTexture: integralImageTexture
        )
    }
    
    private func getDescriptors() -> [Descriptor] {
        // Aggregate keypoints
        var output: [Descriptor] = []
        
        for octaveCounter in 0 ..< OCTAVE {
            var octaveKeypointCount = 0
            let octave = octaves[octaveCounter]
            let descriptors = octave.descriptorResultsBuffer
            for i in 0 ..< descriptors.count {
                output.append(descriptors[i])
                octaveKeypointCount += 1
            }
            logger.info("getKeypoints: octave=\(octaveCounter): Found \(octaveKeypointCount) keypoints for octave")
        }
        
        // Compute the descriptors
        logger.info("getKeypoints: Found \(output.count) total keypoints")
//        let descriptors = getDescriptors(integralImage: integralImage, keypoints: keypoints)
        return output
    }
    
//    private func getDescriptors(integralImage: MetalIntegralImage, keypoints: [Keypoint]) -> [Descriptor] {
//        var descriptors: [Descriptor] = []
//        for keypoint in keypoints {
//            let descriptor = makeDescriptor(integralImage: integralImage, keypoint: keypoint)
//            descriptors.append(descriptor)
//        }
//        return descriptors
//    }
    
//    private func makeDescriptor(integralImage: MetalIntegralImage, keypoint: Keypoint) -> Descriptor {
//        let scale: Float = keypoint.scale
//
//        // Divide in a 4x4 zone the space around the interest point
//
//        // First compute the orientation.
//        let cosP = cos(keypoint.orientation)
//        let sinP = sin(keypoint.orientation)
//        var norm: Float = 0
//        var u: Float
//        var v: Float
//        var gauss: Float
//        var responseU: Float
//        var responseV: Float
//        var responseX: Int
//        var responseY: Int
//
//        let zeroVector = VectorDescriptor(sumDx: 0, sumDy: 0, sumAbsDx: 0, sumAbsDy: 0)
//        let vectorCount = DESCRIPTOR_SIZE_1D * DESCRIPTOR_SIZE_1D
//        var vectors: [VectorDescriptor] = Array(repeating: zeroVector, count: vectorCount)
//
//        // Divide in 16 sectors the space around the interest point.
//        for i in 0 ..< DESCRIPTOR_SIZE_1D {
//            for j in 0 ..< DESCRIPTOR_SIZE_1D {
//
//                var sumDx: Float = 0
//                var sumAbsDx: Float = 0
//                var sumDy: Float = 0
//                var sumAbsDy: Float = 0
//
//                // Then each 4x4 is subsampled into a 5x5 zone
//                for k in 0 ..< 5 {
//                    for l in 0 ..< 5  {
//                        // We pre compute Haar answers
//                        #warning("TODO: Use simd matrix multiplication")
//                        u = (keypoint.x + scale * (cosP * ((Float(i) - 2) * 5 + Float(k) + 0.5) - sinP * ((Float(j) - 2) * 5 + Float(l) + 0.5)))
//                        v = (keypoint.y + scale * (sinP * ((Float(i) - 2) * 5 + Float(k) + 0.5) + cosP * ((Float(j) - 2) * 5 + Float(l) + 0.5)))
//                        responseX = integralImage.haarX(
//                            x: Int(u),
//                            y: Int(v),
//                            lambda: fround(scale)
//                        ) // (u,v) are already translated of 0.5, which means
//                                                                   // that there is no round-off to perform: one takes
//                                                                   // the integer part of the coordinates.
//                        responseY = integralImage.haarY(
//                            x: Int(u),
//                            y: Int(v),
//                            lambda: fround(scale)
//                        )
//
//                        // Gaussian weight
//                        gauss = gaussian(
//                            x: ((Float(i) - 2) * 5 + Float(k) + 0.5),
//                            y: ((Float(j) - 2) * 5 + Float(l) + 0.5),
//                            sig: 3.3
//                        )
//
//                        // Rotation of the axis
//                        #warning("TODO: Use simd matrix multiplication")
//                        //responseU = gauss*( -responseX*sinP + responseY*cosP);
//                        //responseV = gauss*(responseX*cosP + responseY*sinP);
//                        responseU = gauss * (+Float(responseX) * cosP + Float(responseY) * sinP)
//                        responseV = gauss * (-Float(responseX) * sinP + Float(responseY) * cosP)
//
//                        // The descriptors.
//                        sumDx += responseU
//                        sumAbsDx += abs(responseU)
//                        sumDy += responseV
//                        sumAbsDy += abs(responseV)
//                    }
//                }
//
//                let index = DESCRIPTOR_SIZE_1D * i + j
//                let vector = VectorDescriptor(sumDx: sumDx, sumDy: sumDy, sumAbsDx: sumAbsDx, sumAbsDy: sumAbsDy)
//                vectors[index] = vector
//
//                // Compute the norm of the vector
//                norm += sumAbsDx * sumAbsDx + sumAbsDy * sumAbsDy + sumDx * sumDx + sumDy * sumDy
//            }
//        }
//        // Normalization of the descriptors in order to improve invariance to contrast change
//        // and whitening the descriptors.
//        norm = sqrtf(norm)
//
//        if norm != 0 {
//            for i in 0 ..< vectorCount {
//                var vector = vectors[i]
//                vector.sumDx /= norm
//                vector.sumAbsDx /= norm
//                vector.sumDy /= norm
//                vector.sumAbsDy /= norm
//                vectors[i] = vector
//            }
//        }
//
//        return Descriptor(keypoint: keypoint, vector: vectors)
//    }
}
