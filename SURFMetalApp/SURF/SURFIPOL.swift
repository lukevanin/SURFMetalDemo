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
//                        let w: Float = 0.9129
                        let w: Float = 0.8317
                        octave.hessian[intervalCounter][x, y] = (Dxx * Dyy - w * (Dxy * Dxy))
                        octave.signLaplacian[intervalCounter][x, y] = (Dxx + Dyy) > 0 ? 1 : 0
                    }
                }
            }
            
            #warning("TODO: Separate hessian computation from keypoint detection")
            
            // Find keypoints
            logger.info("getCandidatKeypoints: octave=\(octaveCounter): Finding keypoints")
//            var x_: Float
//            var y_: Float
//            var s_: Float
            
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
    private func interpolationScaleSpace(octave o: Int, interval i: Int, x: Int, y: Int, sample: Int, pow2 octaveValue: Int) -> Keypoint? {
        
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
//                let di = (img[i + 1][x, y] - img[i - 1][x, y]) / 2 // Proposed by ChatGPT
        
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
        let signLaplacian = octaves[o].signLaplacian[i][x, y]
        
        return Keypoint(
            x: x_,
            y: y_,
            scale: s_,
            strength: 0,
            orientation: 0,
            laplacian: Int(signLaplacian),
            ivec: []
        )
    }
}
