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
        return output
    }
}
