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
    
    let extremaResultBuffer: DynamicBuffer<ExtremaResult>
    
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
            let hessianFunction = HessianFunction(device: device, configuration: hessianConfiguration)
            
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
        
        let extremaResultBuffer: DynamicBuffer<ExtremaResult> = DynamicBuffer(
            device: device,
            name: "Extrema",
            count: 4096
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
        self.extremaResultBuffer = extremaResultBuffer
    }
    
    func computeHessian(commandBuffer: MTLCommandBuffer, integralImageTexture: MTLTexture) {
        
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
    }
    
    func computeExtrema(commandBuffer: MTLCommandBuffer) {
        extremaFunction.encode(
            commandBuffer: commandBuffer,
            width: width,
            height: height,
            hessianInputTextures: hessianTextures,
            resultsOutputBuffer: extremaResultBuffer
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

        capture("SURF", commandQueue: commandQueue, capture: false) { commandBuffer in
            
            // Compute the integral image
            makeIntegralImage(
                commandBuffer: commandBuffer,
                symmetrizedBitmap: symmetrizedBitmap
            )
            
            // Compute Hessians and of each sign of the Laplacian for each interval
            // in each octave.
            for octaveCounter in 0 ..< OCTAVE {
                let octave = octaves[octaveCounter]
                octave.computeHessian(
                    commandBuffer: commandBuffer,
                    integralImageTexture: integralImageTexture
                )
                
                octave.computeExtrema(
                    commandBuffer: commandBuffer
                )
            }
        }
        
        // Find keypoints
        var keypoints: [Keypoint] = []

        for octaveCounter in 0 ..< OCTAVE {
            let octave = octaves[octaveCounter]
            let pow2 = Int(pow(2.0, Float(octaveCounter + 1)))
//            let w = octave.width
//            let h = octave.height
            let sample = Int(pow(Float(SAMPLE_IMAGE), Float(octaveCounter))) // Sampling step

            #warning("TODO: Separate hessian computation from keypoint detection")
            
            // Interpolate keypoints
            var octaveKeypointCount = 0
            
            let extrema = octave.extremaResultBuffer
            logger.info("getKeypoints: octave=\(octaveCounter): Interpolating keypoints \(extrema.allocatedCount)")

            for i in 0 ..< extrema.allocatedCount {
                let extremum = extrema[i]
                
                let x_ = Float(Int(extremum.x) * sample);
                let y_ = Float(Int(extremum.y) * sample);
                let s_ = 0.4 * Float(pow2 * (Int(extremum.interval) + 1) + 2); // box size or scale

                let keypoint = Keypoint(
                    x: x_,
                    y: y_,
                    scale: s_,
                    orientation: 0,
                    laplacian: 0
                )
                
//                let keypoint = interpolationScaleSpace(
//                    integralImage: integralImage,
//                    octave: octaveCounter,
//                    interval: Int(extremum.interval),
//                    x: Int(extremum.x) * sample,
//                    y: Int(extremum.y) * sample,
//                    sample: sample,
//                    pow2: pow2
//                )
//
//                guard let keypoint else {
//                    continue
//                }

                keypoints.append(keypoint)
                octaveKeypointCount += 1
            }
        
            logger.info("getKeypoints: octave=\(octaveCounter): Found \(octaveKeypointCount) keypoints for octave")
        }
        
        // Compute the descriptors
        logger.info("getKeypoints: Found \(keypoints.count) total keypoints")
        let descriptors = getDescriptors(integralImage: integralImage, keypoints: keypoints)
        return descriptors
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
    
    // Check if a point is a local maximum or not, and more than a given threshold.
//    private func isMaximum(imageStamp: [MetalField], x: Int, y: Int, scale: Int, threshold: Float) -> Bool {
//        let tmp = imageStamp[scale][x, y]
//
//        guard tmp > threshold else {
//            return false
//        }
//
//        for j in y - 1 ... y + 1 {
//            for i in x - 1 ... x + 1 {
//                if imageStamp[scale - 1][i, j] >= tmp {
//                    return false
//                }
//                if imageStamp[scale + 1][i, j] >= tmp {
//                    return false
//                }
//                // TODO: Should this be && instead of ||
//                if (x != i || y != j) && (imageStamp[scale][i, j] >= tmp) {
//                    return false
//                }
//            }
//        }
//        return true
//    }
    
    // Scale space interpolation as described in Lowe
    private func interpolationScaleSpace(integralImage: MetalIntegralImage, octave o: Int, interval i: Int, x: Int, y: Int, sample: Int, pow2 octaveValue: Int) -> Keypoint? {
        
        let img = octaves[o].hessians

        //If we are outside the image...
        if x <= 0 || y <= 0 || x >= (img[i].width - 2) || y >= (img[i].height - 2) {
            return nil
        }
        
        // Nabla X
        let dx = (img[i][x + 1, y] - img[i][x - 1, y]) / 2
        let dy = (img[i][x, y + 1] - img[i][x, y - 1]) / 2
        let di = (img[i][x, y] - img[i][x, y]) / 2
        #warning("FIXME: Compute gradient in i")
        // let di = (img[i + 1][x, y] - img[i - 1][x, y]) / 2
        
        //Hessian X
        let a: Float32 = img[i][x, y]
        let dxx: Float32 = (img[i][x + 1, y] + img[i][x - 1, y]) - 2 * a
        let dyy: Float32 = (img[i][x, y + 1] + img[i][x, y + 1]) - 2 * a
        let dii: Float32 = (img[i - 1][x, y] + img[i + 1][x, y]) - 2 * a
        
        let dxy: Float32 = (img[i][x + 1, y + 1] - img[i][x + 1, y - 1] - img[i][x - 1, y + 1] + img[i][x - 1, y - 1]) / 4
        let dxi: Float32 = (img[i + 1][x + 1, y] - img[i + 1][x - 1, y] - img[i - 1][x + 1, y] + img[i - 1][x - 1, y]) / 4
        let dyi: Float32 = (img[i + 1][x, y + 1] - img[i + 1][x, y - 1] - img[i - 1][x, y + 1] + img[i - 1][x, y - 1]) / 4
        
        // Det
        let det: Float32 = dxx * dyy * dii - dxx * dyi * dyi - dyy * dxi * dxi + 2 * dxi * dyi * dxy - dii * dxy * dxy

        if det == 0 {
            // Matrix must be inversible - maybe useless.
            return nil
        }
        
        let mx = -1 / det * (dx * (dyy * dii - dyi * dyi) + dy * (dxi * dyi - dii * dxy) + di * (dxy * dyi - dyy * dxi))
        let my = -1 / det * (dx * (dxi * dyi - dii * dxy) + dy * (dxx * dii - dxi * dxi) + di * (dxy * dxi - dxx * dyi))
        let mi = -1 / det * (dx * (dxy * dyi - dyy * dxi) + dy * (dxy * dxi - dxx * dyi) + di * (dxx * dyy - dxy * dxy))

        // If the point is stable
        guard abs(mx) < 1 && abs(my) < 1 && abs(mi) < 1 else {
            return nil
        }
        
        let x_ = Float(sample) * (Float(x) + mx) + 0.5 // Center the pixels value
        let y_ = Float(sample) * (Float(y) + my) + 0.5
        let s_ = 0.4 * (1 + Float(octaveValue) * (Float(i) + mi + 1))
        let orientation = getOrientation(integralImage: integralImage, x: x_, y: y_, scale: s_)
        let signLaplacian = octaves[o].signLaplacians[i][x, y]
        
        return Keypoint(
            x: x_,
            y: y_,
            scale: s_,
            orientation: orientation,
            laplacian: Int(signLaplacian)
        )
    }
    
    private func getOrientation(integralImage: MetalIntegralImage, x: Float, y: Float, scale: Float) -> Float {
        let sectors = NUMBER_SECTOR
        
        #warning("TODO: Pre-allocate and reuse arrays")
        var haarResponseX: [Float] = Array(repeating: 0, count: sectors)
        var haarResponseY: [Float] = Array(repeating: 0, count: sectors)
        var haarResponseSectorX: [Float] = Array(repeating: 0, count: sectors)
        var haarResponseSectorY: [Float] = Array(repeating: 0, count: sectors)
        var answerX: Int
        var answerY: Int
        var gauss: Float
        
        var theta: Int
        
        // Computation of the contribution of each angular sectors.
        for i in -6 ... 6 {
            for j in -6 ... 6 {
                
                if (i * i + j * j) <= 36 {
                    
                    answerX = integralImage.haarX(
                        x: Int(Float(x) + scale * Float(i)),
                        y: Int(Float(y) + scale * Float(j)),
                        lambda: fround(2 * scale)
                    )
                    answerY = integralImage.haarY(
                        x: Int(Float(x) + scale * Float(i)),
                        y: Int(Float(y) + scale * Float(j)),
                        lambda: fround(2 * scale)
                    )
                    
                    // Associated angle
                    theta = Int(atan2(Float(answerY), Float(answerX)) * Float(sectors) / (2 * pi))
                    theta = ((theta >= 0) ? (theta) : (theta + sectors))
                    
                    // Gaussian weight
                    gauss = gaussian(x: Float(i), y: Float(j), sig: 2)
                    
                    // Cumulative answers
                    haarResponseSectorX[theta] += Float(answerX) * gauss
                    haarResponseSectorY[theta] += Float(answerY) * gauss
                }
            }
        }

        // Compute a windowed answer
        for i in 0 ..< sectors {
            for j in -sectors / 12 ... sectors / 12 {
                if 0 <= i + j && i + j < sectors {
                    haarResponseX[i] += haarResponseSectorX[i + j]
                    haarResponseY[i] += haarResponseSectorY[i + j]
                }
                else if i + j < 0 {
                    // The answer can be on any quadrant of the unit circle
                    haarResponseX[i] += haarResponseSectorX[sectors + i + j]
                    haarResponseY[i] += haarResponseSectorY[i + j + sectors]
                }
                else {
                    haarResponseX[i] += haarResponseSectorX[i + j - sectors]
                    haarResponseY[i] += haarResponseSectorY[i + j - sectors]
                }
            }
        }
                
        // Find out the maximum answer
        var max = haarResponseX[0] * haarResponseX[0] + haarResponseY[0] * haarResponseY[0]
        
        var t = 0
        for i in 1 ..< sectors {
            let norm = haarResponseX[i] * haarResponseX[i] + haarResponseY[i] * haarResponseY[i]
            t = (max < norm) ? i : t
            max = (max < norm) ? norm : max
        }

        // Return the angle ; better than atan which is not defined in pi/2
        return atan2(haarResponseY[t], haarResponseX[t])
    }
    
    private func getDescriptors(integralImage: MetalIntegralImage, keypoints: [Keypoint]) -> [Descriptor] {
        var descriptors: [Descriptor] = []
        for keypoint in keypoints {
            let descriptor = makeDescriptor(integralImage: integralImage, keypoint: keypoint)
            descriptors.append(descriptor)
        }
        return descriptors
    }
    
    private func makeDescriptor(integralImage: MetalIntegralImage, keypoint: Keypoint) -> Descriptor {
        let scale: Float = keypoint.scale

        // Divide in a 4x4 zone the space around the interest point

        // First compute the orientation.
        let cosP = cos(keypoint.orientation)
        let sinP = sin(keypoint.orientation)
        var norm: Float = 0
        var u: Float
        var v: Float
        var gauss: Float
        var responseU: Float
        var responseV: Float
        var responseX: Int
        var responseY: Int
        
        let zeroVector = VectorDescriptor(sumDx: 0, sumDy: 0, sumAbsDx: 0, sumAbsDy: 0)
        let vectorCount = DESCRIPTOR_SIZE_1D * DESCRIPTOR_SIZE_1D
        var vectors: [VectorDescriptor] = Array(repeating: zeroVector, count: vectorCount)
        
        // Divide in 16 sectors the space around the interest point.
        for i in 0 ..< DESCRIPTOR_SIZE_1D {
            for j in 0 ..< DESCRIPTOR_SIZE_1D {
                
                var sumDx: Float = 0
                var sumAbsDx: Float = 0
                var sumDy: Float = 0
                var sumAbsDy: Float = 0

                // Then each 4x4 is subsampled into a 5x5 zone
                for k in 0 ..< 5 {
                    for l in 0 ..< 5  {
                        // We pre compute Haar answers
                        #warning("TODO: Use simd matrix multiplication")
                        u = (keypoint.x + scale * (cosP * ((Float(i) - 2) * 5 + Float(k) + 0.5) - sinP * ((Float(j) - 2) * 5 + Float(l) + 0.5)))
                        v = (keypoint.y + scale * (sinP * ((Float(i) - 2) * 5 + Float(k) + 0.5) + cosP * ((Float(j) - 2) * 5 + Float(l) + 0.5)))
                        responseX = integralImage.haarX(
                            x: Int(u),
                            y: Int(v),
                            lambda: fround(scale)
                        ) // (u,v) are already translated of 0.5, which means
                                                                   // that there is no round-off to perform: one takes
                                                                   // the integer part of the coordinates.
                        responseY = integralImage.haarY(
                            x: Int(u),
                            y: Int(v),
                            lambda: fround(scale)
                        )
                        
                        // Gaussian weight
                        gauss = gaussian(
                            x: ((Float(i) - 2) * 5 + Float(k) + 0.5),
                            y: ((Float(j) - 2) * 5 + Float(l) + 0.5),
                            sig: 3.3
                        )
                        
                        // Rotation of the axis
                        #warning("TODO: Use simd matrix multiplication")
                        //responseU = gauss*( -responseX*sinP + responseY*cosP);
                        //responseV = gauss*(responseX*cosP + responseY*sinP);
                        responseU = gauss * (+Float(responseX) * cosP + Float(responseY) * sinP)
                        responseV = gauss * (-Float(responseX) * sinP + Float(responseY) * cosP)
                        
                        // The descriptors.
                        sumDx += responseU
                        sumAbsDx += abs(responseU)
                        sumDy += responseV
                        sumAbsDy += abs(responseV)
                    }
                }
                
                let index = DESCRIPTOR_SIZE_1D * i + j
                let vector = VectorDescriptor(sumDx: sumDx, sumDy: sumDy, sumAbsDx: sumAbsDx, sumAbsDy: sumAbsDy)
                vectors[index] = vector
                
                // Compute the norm of the vector
                norm += sumAbsDx * sumAbsDx + sumAbsDy * sumAbsDy + sumDx * sumDx + sumDy * sumDy
            }
        }
        // Normalization of the descriptors in order to improve invariance to contrast change
        // and whitening the descriptors.
        norm = sqrtf(norm)
        
        if norm != 0 {
            for i in 0 ..< vectorCount {
                var vector = vectors[i]
                vector.sumDx /= norm
                vector.sumAbsDx /= norm
                vector.sumDy /= norm
                vector.sumAbsDy /= norm
                vectors[i] = vector
            }
        }
        
        return Descriptor(keypoint: keypoint, vector: vectors)
    }
}
