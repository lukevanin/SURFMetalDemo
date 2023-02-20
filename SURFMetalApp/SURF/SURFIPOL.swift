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
private let RATE = 0.6

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
        
    func getCandidatKeypoints(image: Bitmap, threshold: Float = 1000) -> [Keypoint] {
        var keypoints: [Keypoint] = []
        
        // Compute the integral image
        let padding = 312 // size descriptor * max size L = 4*0.4*195;
        logger.info("getCandidatKeypoints: Creating integral image: width=\(image.width) height=\(image.height) padding=\(padding)")
        let integralImage = IntegralImage(image: image, padding: padding)
        logger.info("getCandidatKeypoints: Integral image: width=\(integralImage.paddedWidth) height=\(integralImage.paddedHeight) padding=\(integralImage.padding)")

        // Array of each Hessians and of each sign of the Laplacian

        // Auxiliary variables
        var Dxx: Float
        var Dxy: Float
        var Dyy: Float
        var intervalCounter: Int
        var octaveCounter: Int
        var x: Int
        var y: Int
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
        
        var octaveKeypointCount: Int
        var intervalKeypointCount: Int
        
        // For loop on octave
        for octaveCounter in 0 ..< OCTAVE {
            
            let octave = octaves[octaveCounter]

            sample = Int(pow(Float(SAMPLE_IMAGE), Float(octaveCounter))) // Sampling step

    //            img->getSampledImage(w, h, sample) // Build a sampled images filled in with 0
            w = width / sample
            h = height / sample

            #warning("TODO: Use 1 << (octaveCounter + 1)")
            pow2 = Int(pow(2, Float(octaveCounter + 1)))
            

            logger.debug("getCandidatKeypoints: Octave=\(octaveCounter) Width=\(w) Height=\(h)")

            // Compute Hessian and sign of Laplacian
            // For loop on intervals
            logger.info("getCandidatKeypoints: Octave=\(octaveCounter) Computing Hessian")
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
                        octave.hessian[intervalCounter][x, y] = (Dxx * Dyy - 0.8317 * (Dxy * Dxy))
                        octave.signLaplacian[intervalCounter][x, y] = Dxx + Dyy > 0 ? 1 : 0
                    }
                }
            }
            
            // Find keypoints
            logger.info("getCandidatKeypoints: octave=\(octaveCounter): Finding keypoints")
            var x_: Float
            var y_: Float
            var s_: Float
            
            // Detect keypoints
            var octaveKeypointCount = 0
            
            for intervalCounter in 1 ..< INTERVAL - 1 {
                var intervalKeypointCount = 0
                logger.info("getCandidatKeypoints: octave=\(octaveCounter): interval=\(intervalCounter): Finding keypoints")

                l = (pow2 * (intervalCounter + 1) + 1)
                // border points are removed
                for y in 1 ..< h - 1 {
                    for x in 1 ..< w - 1 {
                        guard isMaximum(imageStamp: octave.hessian, x: x, y: y, scale: intervalCounter, threshold: threshold) else {
                            continue
                        }
                        
                        x_ = Float(x * sample)
                        y_ = Float(y * sample)
                        s_ = 0.4 * Float(pow2 * (intervalCounter + 1) + 2) // box size or scale
                        let laplacian = octave.signLaplacian[intervalCounter][x, y] >= 0 ? 1 : -1
                        
                        let keypoint = Keypoint(
                            x: x_,
                            y: y_,
                            scale: s_,
                            strength: 0,
                            orientation: 0,
                            laplacian: laplacian,
                            ivec: []
                        )
                        keypoints.append(keypoint)
                        intervalKeypointCount += 1
                            // Affine refinement is performed for a given octave and sampling
//                            if (interpolationScaleSpace(hessian, x, y, intervalCounter, x_, y_, s_, sample,pow2)) {
//                                addKeypoint(imgInt, x_, y_, (*(signLaplacian[intervalCounter]))(x,y),s_, lKP);
//                            }
                    }
                }
                
                octaveKeypointCount += intervalKeypointCount
                logger.info("getCandidatKeypoints: octave=\(octaveCounter): interval=\(intervalCounter): Found \(intervalKeypointCount) keypoints for interval")
            }
        
            logger.info("getCandidatKeypoints: octave=\(octaveCounter): Found \(octaveKeypointCount) keypoints for octave")
        }
        
        // Compute the descriptors
        logger.info("getCandidatKeypoints: Found \(keypoints.count) total keypoints")
        return keypoints
    }
    
    
    // Check if a point is a local maximum or not, and more than a given threshold.
    private func isMaximum(imageStamp: [Field], x: Int, y: Int, scale: Int, threshold: Float) -> Bool {
        let tmp = imageStamp[scale][x, y]
        
        guard (tmp > threshold) else {
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

//    func refineInterestPoints(_ points: [InterestPoint]) -> [InterestPoint] {
//
//    }
}
