//
//  SURFIPOL.swift
//  SURFMetalApp
//
//  Created by Luke Van In on 2023/02/16.
//

import Foundation
import OSLog


private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "SURF")


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

// Gaussian - should be computed as an array to be faster.
private func gaussian(x: Float, y: Float, sig: Float) -> Float {
    return 1 / (2 * pi * sig * sig) * exp( -(x * x + y * y) / (2 * sig * sig))
}


func match(_ l1: [Descriptor], _ l2: [Descriptor]) -> [Match] {
    // The match uses a ratio between a selected descriptor of l1 and the two closest descriptors
    // of l2.
    let thrm = RATE * RATE

    var matches: [Match] = []
    
    // Matching is not symmetric.
    for i in 0 ..< l1.count {
        
        let p1 = l1[i]
        var position = -1
        var d1: Float = 3
        var d2: Float = 3
        
        for j in 0 ..< l2.count {
            let p2 = l2[j]
            let d = p1.euclideanDistance(to: p2)
            
            // We select the two closes descriptors
            if p1.keypoint.laplacian == p2.keypoint.laplacian {
                d2 = (d2 > d) ? d : d2
                if d1 > d {
                    position = j
                    d2 = d1
                    d1 = d
                }
            }
        }
        
        // Try to match it
        if position >= 0 && (thrm * d2) > d1 {
            let match = Match(
                id: matches.count, 
                a: p1,
                b: l2[position]
            )
            matches.append(match)
        }
    }
    return matches
}



final class Octave {
    
    let width: Int
    let height: Int
    
    let hessian: [Field]
    let signLaplacian: [Bitmap]
    
    init(width: Int, height: Int) {
        // Initialize memory
        #warning("TODO: Pre-allocate hessian and laplacian for given size")
        var hessian: [Field] = []
        var signLaplacian: [Bitmap] = []

        for _ in 0 ..< INTERVAL {
            hessian.append(Field(width: width, height: height))
            signLaplacian.append(Bitmap(width: width, height: height))
        }

        self.width = width
        self.height = height
        self.hessian = hessian
        self.signLaplacian = signLaplacian
    }
}


final class SURFIPOL {
    
    let width: Int
    let height: Int
    
    let octaves: [Octave]
    
    init(width: Int, height: Int) {
        
        var octaves: [Octave] = []
        for octaveCounter in 0 ..< OCTAVE {
            
            let sample = Int(pow(Float(SAMPLE_IMAGE), Float(octaveCounter))) // Sampling step

//            img->getSampledImage(w, h, sample) // Build a sampled images filled in with 0
            let octaveWidth = width / sample
            let octaveHeight = height / sample
            
            let octave = Octave(width: octaveWidth, height: octaveHeight)
            octaves.append(octave)
        }

        self.width = width
        self.height = height
        self.octaves = octaves
    }
        
    func getKeypoints(image: Bitmap, threshold: Float = 1000) -> [Descriptor] {
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let endTIme = CFAbsoluteTimeGetCurrent()
            let elapsedTime = endTIme - startTime
            let framesPerSecond = 1 / elapsedTime
            print("Time: ", elapsedTime, "seconds", "/", framesPerSecond, "frames per second")
        }
        
        var keypoints: [Keypoint] = []
        
        // Compute the integral image
        let padding = 312 // size descriptor * max size L = 4*0.4*195;
        logger.info("getKeypoints: Creating integral image: width=\(image.width) height=\(image.height) padding=\(padding)")
        let integralImage = IntegralImage(image: image, padding: padding)
        logger.info("getKeypoints: Integral image: width=\(integralImage.paddedWidth) height=\(integralImage.paddedHeight) padding=\(integralImage.padding)")

        // Array of each Hessians and of each sign of the Laplacian

        // Auxiliary variables
        var Dxx: Float
        var Dxy: Float
        var Dyy: Float
        var w: Int
        var h: Int
        var xcoo: Int
        var ycoo: Int
        var lp1: Int
        var l3: Int
        var mlp1p2: Int
        var lp1d2: Int
        var l2p1: Int
        var pow2: Int
        var sample: Int
        var l: Int
        var nxy: Float
        var nxx: Float
        
        // For loop on octave
        for octaveCounter in 0 ..< OCTAVE {
            
            let octave = octaves[octaveCounter]

            sample = Int(pow(Float(SAMPLE_IMAGE), Float(octaveCounter))) // Sampling step

    //            img->getSampledImage(w, h, sample) // Build a sampled images filled in with 0
            w = width / sample
            h = height / sample

            #warning("TODO: Use 1 << (octaveCounter + 1)")
            pow2 = Int(pow(2, Float(octaveCounter + 1)))

            logger.debug("getKeypoints: Octave=\(octaveCounter) Width=\(w) Height=\(h)")

            // Compute Hessian and sign of Laplacian
            // For loop on intervals
            logger.info("getKeypoints: Octave=\(octaveCounter) Computing Hessian")
            for intervalCounter in 0 ..< INTERVAL {
                l = pow2 * (intervalCounter + 1) + 1 // the "L" in the article.

                // These variables are precomputed to allow fast computations.
                // They correspond exactly to the Gamma of the formula given in the article for
                // the second order filters.
                lp1 = -l + 1
                l3 = 3 * l
                lp1d2 = (-l + 1) / 2
                mlp1p2 = (-l + 1) / 2 - l
                l2p1 = 2 * l - 1
                
                nxx = sqrt(Float(6 * l * (2 * l - 1))) // frobenius norm of the xx and yy filters
                nxy = sqrt(Float(4 * l * l)) // frobenius of the xy filter.
                
                // These are the time consuming loops that compute the Hessian at each points.
                for y in 0 ..< h {
                    for x in 0 ..< w {
                        // Sampling
                        xcoo = x * sample
                        ycoo = y * sample
                        
                        // Second order filters
                        Dxx = Float(integralImage.squareConvolutionXY(a: lp1, b: mlp1p2, c: l2p1, d: l3, x: xcoo, y: ycoo) - 3 * integralImage.squareConvolutionXY(a: lp1, b: lp1d2, c: l2p1, d: l, x: xcoo, y: ycoo))
                        Dxx /= nxx
                        
                        Dyy = Float(integralImage.squareConvolutionXY(a: mlp1p2, b: lp1, c: l3, d: l2p1, x: xcoo, y: ycoo) - 3 * integralImage.squareConvolutionXY(a: lp1d2, b: lp1, c: l, d: l2p1, x: xcoo, y: ycoo))
                        Dyy /= nxx
                        
                        Dxy = Float(integralImage.squareConvolutionXY(a: 1, b: 1, c: l, d: l, x: xcoo, y: ycoo) + integralImage.squareConvolutionXY(a: 0, b: 0, c: -l, d: -l, x: xcoo, y: ycoo) + integralImage.squareConvolutionXY(a: 1, b: 0, c: l, d: -l, x: xcoo, y: ycoo) + integralImage.squareConvolutionXY(a: 0, b: 1, c: -l, d: l, x: xcoo, y: ycoo))
                        Dxy /= nxy
                        
                        // Computation of the Hessian and Laplacian
//                        let w: Float = 0.9129
                        let w: Float = 0.8317
                        octave.hessian[intervalCounter][x, y] = (Dxx * Dyy - w * (Dxy * Dxy))
                        octave.signLaplacian[intervalCounter][x, y] = (Dxx + Dyy) > 0 ? 1 : 0
                    }
                }
            }
            
            #warning("TODO: Separate hessian computation from keypoint detection")
            
            // Find keypoints
            logger.info("getKeypoints: octave=\(octaveCounter): Finding keypoints")
//            var x_: Float
//            var y_: Float
//            var s_: Float
            
            // Detect keypoints
            var octaveKeypointCount = 0
            
            for intervalCounter in 1 ..< INTERVAL - 1 {
                var intervalKeypointCount = 0
                logger.info("getKeypoints: octave=\(octaveCounter): interval=\(intervalCounter): Finding keypoints")

                l = (pow2 * (intervalCounter + 1) + 1)
                // border points are removed
                for y in 1 ..< h - 1 {
                    for x in 1 ..< w - 1 {
                        guard isMaximum(imageStamp: octave.hessian, x: x, y: y, scale: intervalCounter, threshold: threshold) else {
                            continue
                        }
                        
//                        let keypoint = Keypoint(
//                            x: Float(x * sample),
//                            y: Float(y * sample),
//                            scale: 0.4 * Float(pow2 * (intervalCounter + 1) + 2), // box size or scale,
//                            strength: 0,
//                            orientation: 0,
//                            laplacian: Int(octave.signLaplacian[intervalCounter][x, y]),
//                            ivec: []
//                        )

                        // Affine refinement is performed for a given octave and sampling
                        let keypoint = interpolationScaleSpace(
                            integralImage: integralImage,
                            octave: octaveCounter,
                            interval: intervalCounter,
                            x: x,
                            y: y,
                            sample: sample,
                            pow2: pow2
                        )
                        
                        guard let keypoint else {
                            continue
                        }

                        keypoints.append(keypoint)
                        intervalKeypointCount += 1
                    }
                }
                
                octaveKeypointCount += intervalKeypointCount
                logger.info("getKeypoints: octave=\(octaveCounter): interval=\(intervalCounter): Found \(intervalKeypointCount) keypoints for interval")
            }
        
            logger.info("getKeypoints: octave=\(octaveCounter): Found \(octaveKeypointCount) keypoints for octave")
        }
        
        // Compute the descriptors
        logger.info("getKeypoints: Found \(keypoints.count) total keypoints")
        let descriptors = getDescriptors(integralImage: integralImage, keypoints: keypoints)
        return descriptors
    }
    
    
    // Check if a point is a local maximum or not, and more than a given threshold.
    private func isMaximum(imageStamp: [Field], x: Int, y: Int, scale: Int, threshold: Float) -> Bool {
        let tmp = imageStamp[scale][x, y]
        
        guard tmp > threshold else {
            return false
        }
        
        for j in y - 1 ... y + 1 {
            for i in x - 1 ... x + 1 {
                if imageStamp[scale - 1][i, j] >= tmp {
                    return false
                }
                if imageStamp[scale + 1][i, j] >= tmp {
                    return false
                }
                // TODO: Should this be && instead of ||
                if (x != i || y != j) && (imageStamp[scale][i, j] >= tmp) {
                    return false
                }
            }
        }
        return true
    }
    
    // Scale space interpolation as described in Lowe
    private func interpolationScaleSpace(integralImage: IntegralImage, octave o: Int, interval i: Int, x: Int, y: Int, sample: Int, pow2 octaveValue: Int) -> Keypoint? {
        
//        let sample = Int(pow(Float(SAMPLE_IMAGE), Float(keypoint.octave))) // Sampling step
        let img = octaves[o].hessian

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
        let a = img[i][x, y]
        let dxx = (img[i][x + 1, y] + img[i][x - 1, y]) - 2 * a
        let dyy = (img[i][x, y + 1] + img[i][x, y + 1]) - 2 * a
        let dii = (img[i - 1][x, y] + img[i + 1][x, y]) - 2 * a
        
        let dxy = (img[i][x + 1, y + 1] - img[i][x + 1, y - 1] - img[i][x - 1, y + 1] + img[i][x - 1, y - 1]) / 4
        let dxi = (img[i + 1][x + 1, y] - img[i + 1][x - 1, y] - img[i - 1][x + 1, y] + img[i - 1][x - 1, y]) / 4
        let dyi = (img[i + 1][x, y + 1] - img[i + 1][x, y - 1] - img[i - 1][x, y + 1] + img[i - 1][x, y - 1]) / 4
        
        // Det
        let det = dxx * dyy * dii - dxx * dyi * dyi - dyy * dxi * dxi + 2 * dxi * dyi * dxy - dii * dxy * dxy

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
        let signLaplacian = octaves[o].signLaplacian[i][x, y]
        
        return Keypoint(
            x: x_,
            y: y_,
            scale: s_,
            orientation: orientation,
            laplacian: Int(signLaplacian)
        )
    }
    
    private func getOrientation(integralImage: IntegralImage, x: Float, y: Float, scale: Float) -> Float {
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
    
    private func getDescriptors(integralImage: IntegralImage, keypoints: [Keypoint]) -> [Descriptor] {
        var descriptors: [Descriptor] = []
        for keypoint in keypoints {
            let descriptor = makeDescriptor(integralImage: integralImage, keypoint: keypoint)
            descriptors.append(descriptor)
        }
        return descriptors
    }
    
    private func makeDescriptor(integralImage: IntegralImage, keypoint: Keypoint) -> Descriptor {
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
