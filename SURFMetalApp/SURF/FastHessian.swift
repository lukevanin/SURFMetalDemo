//
//  FastHessian.swift
//  SURFMetalApp
//
//  Created by Luke Van In on 2023/02/14.
//

import Foundation


#if false
final class FastHessian {
    
    struct Configuration {
        
        let blobResponseThreshold: Float = 4.0
        
        let initLobe: Int = 3
        
        let initMaskSize: Int = 3 * 3
        
        let samplingStep: Int = 2
        
//        let octaves: Int = 4
        let octaves: Int = 1
    }
    
    private let maxScales: Int
    private let sampling: Int
    private let width: Int
    private let height: Int
    private let threshold: Float
    
    private var interestPoints: [Keypoint] = []
    private var scaleLevels: [PixelImage]
    private var offset: [Float] = Array(repeating: 0, count: 3)
    private var vas: [Int] = Array(repeating: 0, count: 9)
    
    private let integralImage: IntegralImage
    private let configuration: Configuration
    
    init(integralImage: IntegralImage, configuration: Configuration) {
        self.integralImage = integralImage
        self.configuration = configuration
        self.maxScales = configuration.initLobe + 2
        self.width = integralImage.width
        self.height = integralImage.height
        self.sampling = configuration.samplingStep
        self.threshold = configuration.blobResponseThreshold
        
        var scaleLevels: [PixelImage] = []
        let scaleWidth = (width - 1) / configuration.samplingStep
        let scaleHeight = (height - 1) / configuration.samplingStep
        for _ in 0 ..< maxScales {
            let scaleImage = PixelImage(width: scaleWidth, height: scaleHeight)
            scaleLevels.append(scaleImage)
        }
        self.scaleLevels = scaleLevels
    }
    
    func getInterestPoints() -> [InterestPoint] {
        // Intensity values of the integral image and the determinant
        var maskSize = configuration.initLobe - 2
        // Indices
        var octave = 1
        var s = 0
        var k = 0
        var l = 0
        
        // border for non-maximum suppression
        var borders: [Int] = Array(repeating: 0, count: maxScales)
        
        for o in 0 ..< configuration.octaves {
            
            var border1 = 0
            
            if (o == 0) {
                // Save borders for non-maximum suppression
                border1 = ((3 * (maskSize + 6 * octave)) / 2) / (sampling * octave) + 1
            }
            else {
                // divide the last and the third last image in order to save the
                // blob response computation for those two levels
                let temp0 = scaleLevels[0]
                let temp1 = scaleLevels[1]
                scaleLevels[0] = scaleLevels[maxScales - 3].halfImage()
                scaleLevels[1] = scaleLevels[maxScales - 1].halfImage()
                scaleLevels[maxScales - 3] = temp0
                scaleLevels[maxScales - 1] = temp1
                
                // Calculate border and store in vector
                border1 = ((3 * (maskSize + 4 * octave)) / 2) / (sampling * octave) + 1
                borders[0] = border1
                borders[1] = border1
                s = 2
            }
            
            // Calculate blob response map for all scales in the octave
            while s < maxScales {
                borders[s] = border1
                
                maskSize += 2 * octave
                
                if (s > 2) {
                    border1 = ((3 * (maskSize)) / 2) / (sampling * octave) + 1
                }
                
                let scaleLevel0 = scaleLevels[0]
                let scaleLevel = PixelImage(width: scaleLevel0.width, height: scaleLevel0.height)
                scaleLevels[s] = scaleLevel
                
                vas[2] = Int(0.5 * Float(maskSize)) // kernel radius?
                vas[3] = 2 * vas[2] // kernel diameter?
                vas[4] = vas[3] + vas[2] // kernel diameter + radius?
                var norm = 9.0 / Float(maskSize * maskSize)
                norm *= norm;
                
                // Calculate border size
                let border2 = sampling * octave * border1
                let detrows = scaleLevel.height - border1
                let detcols = scaleLevel.width - border1
                let delt = sampling * octave
                
                vas[7] = border2 + maskSize // bottom of kernel?
                vas[8] = border2 - maskSize // top of kernel?
                
                k = border1
                vas[1] = border2 // center y of kernel?
                while k < detrows {
                    vas[5] = border2 + maskSize // right edge of kernel?
                    vas[6] = border2 - maskSize // left edge of kernel?
                    
                    l = border1
                    vas[0] = border2 // center x of kernel?
                    while l < detcols {
                        let h = integralImage.getHessian(vas)
                        scaleLevel[l, k] = norm * h
                        vas[5] += delt
                        vas[6] += delt
                        vas[0] += delt
                        l += 1
                    }
                    vas[7] += delt
                    vas[8] += delt
                    vas[1] += delt
                    k += 1
                }
                s += 1
            }
            findMaximum(borders, o, octave)
            octave *= 2
        }
        
        return interestPoints
    }
    
    private func findMaximum(_ borders: [Int], _ o: Int, _ octave: Int) {
        
        let rows = scaleLevels[0].height
        let cols = scaleLevels[0].width
        let thres = 0.8 * configuration.blobResponseThreshold
        
        var best: Float = 0
        var r = 0
        var c = 0
        var s = 0
        var ss = 0
        
        var dr = 0
        var dc = 0
        var ds = 0
        
        var cas = 0
        
        for k in stride(from: 1, to: maxScales, by: 2) {
            
            for i in stride(from: borders[k + 1] + 1, to: rows - (borders[k + 1] + 1), by: 2) {
                
                for j in stride(from: borders[k + 1] + 1, to: cols - (borders[k + 1] + 1), by: 2) {
                    
                    best = scaleLevels[k][j, i];
                    cas = 0;
                    
                    if scaleLevels[k][j + 1, i] > best {
                        best = scaleLevels[k][j + 1, i]
                        cas = 1
                    }
                    if scaleLevels[k][j, i + 1] > best {
                        best = scaleLevels[k][j, i + 1]
                        cas = 2
                    }
                    if scaleLevels[k][j + 1, i + 1] > best {
                        best = scaleLevels[k][j + 1, i + 1]
                        cas = 3
                    }
                    if scaleLevels[k + 1][j, i] > best {
                        best = scaleLevels[k + 1][j, i]
                        cas = 4
                    }
                    if scaleLevels[k + 1][j + 1, i] > best {
                        best = scaleLevels[k + 1][j + 1, i]
                        cas = 5
                    }
                    if scaleLevels[k + 1][j, i + 1] > best {
                        best = scaleLevels[k + 1][j, i + 1]
                        cas = 6
                    }
                    if scaleLevels[k + 1][j + 1, i + 1] > best {
                        best = scaleLevels[k + 1][j + 1, i + 1]
                        cas = 7
                    }
                    
                    if (best < thres) {
                        continue
                    }
                    
                    if k + 1 == maxScales - 1 && cas > 3 {
                        continue
                    }
                    
                    c = j;
                    r = i;
                    s = k;
                    dc = -1;
                    dr = -1;
                    ds = -1;
                    if cas != 0 {
                        if cas == 1 {
                            c = j+1
                            dc = 1
                        }
                        else if cas == 2 {
                            r = i + 1
                            dr = 1
                        }
                        else if cas == 3 {
                            c = j + 1
                            r = i + 1
                            dc = 1
                            dr = 1
                            
                        }
                        else {
                            s += 1
                            ds = 1
                            if cas == 5 {
                                c = j + 1
                                dc = 1
                            }
                            else if cas == 6 {
                                r = i + 1
                                dr = 1
                            }
                            else if cas == 7 {
                                c = j + 1
                                r = i + 1
                                dc = 1
                                dr = 1
                            }
                        }
                    }
                    
                    ss = s + ds
                    
                    if best < scaleLevels[ss][c - 1, r - dr] {
                        continue
                    }
                    if best < scaleLevels[ss][c, r - dr] {
                        continue
                    }
                    if best < scaleLevels[ss][c + 1, r - dr] {
                        continue
                    }
                    if best < scaleLevels[ss][c - 1, r] {
                        continue
                    }
                    if best < scaleLevels[ss][c, r] {
                        continue
                    }
                    if best < scaleLevels[ss][c + 1, r] {
                        continue
                    }
                    if best < scaleLevels[ss][c - 1, r + dr] {
                        continue
                    }
                    if best < scaleLevels[ss][c, r + dr] {
                        continue
                    }
                    if best < scaleLevels[ss][c + 1, r + dr] {
                        continue
                    }
                    if best < scaleLevels[s][c - 1, r + dr] {
                        continue
                    }
                    if best < scaleLevels[s][c, r + dr] {
                        continue
                    }
                    if best < scaleLevels[s][c + 1, r + dr] {
                        continue
                    }
                    if best < scaleLevels[s][c + dc, r] {
                        continue
                    }
                    if best < scaleLevels[s][c + dc, r - dr] {
                        continue
                    }
                    
                    ss = s - ds
                    
                    if best < scaleLevels[ss][c - 1, r + dr] {
                        continue
                    }
                    if best < scaleLevels[ss][c, r + dr] {
                        continue
                    }
                    if best < scaleLevels[ss][c + 1, r + dr] {
                        continue
                    }
                    if best < scaleLevels[ss][c + dc, r] {
                        continue
                    }
                    if best < scaleLevels[ss][c + dc, r - dr] {
                        continue
                    }
                    
                    interpFeature(s, r, c, o, octave, 5, borders)
                }
            }
        }
    }
    
    private func interpFeature(
        _ s: Int,
        _ row: Int,
        _ col: Int,
        _ o: Int,
        _ octave: Int,
        _ movesRemain: Int,
        _ borders: [Int]
    ) {
        var newr = row
        var newc = col

        // Interpolate the detected maximum in order to
        // get a more accurate location
        let strength = fitQuadrat(s, row, col)
        
        if offset[1] > 0.6 && row < scaleLevels[0].height - borders[s] {
            newr += 1
        }
        if offset[1] < -0.6 && row > borders[s] {
            newr -= 1
        }
        if offset[2] > 0.6 && col < scaleLevels[0].width - borders[s] {
            newc += 1
        }
        if offset[2] < -0.6 && col > borders[s] {
            newc -= 1
        }
        
        if movesRemain > 0  && (newr != row || newc != col) {
            return interpFeature(s, newr, newc, o, octave, movesRemain - 1, borders)
        }
        
        // Do not create a keypoint if interpolation still remains far
        // outside expected limits, or if magnitude of peak value is below
        // threshold (i.e., contrast is too low)
        if offset[0].isNaN || offset[1].isNaN || offset[2].isNaN {
            return
        }
        
        if abs(offset[0]) > 1.5 || abs(offset[1]) > 1.5 || abs(offset[2]) > 1.5 {
            return
        }
        
        if strength < threshold {
            return
        }
        
        let newScale = (Float(configuration.initLobe) + Float(octave - 1) * Float(maxScales) + (Float(s) + offset[0]) * 2.0 * Float(octave)) / 3.0
        
        makeIpoint(
            Float(octave) * (Float(col) + offset[2]),
            Float(octave) * (Float(row) + offset[1]),
            newScale,
            strength
        )
    }
    
    private func fitQuadrat(_ s: Int, _ r: Int, _ c: Int) -> Float {
        // variables to fit quadratic
        var g: [Float] = Array(repeating: 0, count: 3)
        var H: [[Float]] = Array(repeating: Array(repeating: 0, count: 3), count: 3)

        // Fill in the values of the gradient from pixel differences
        g[0] = (scaleLevels[s + 1][c, r] - scaleLevels[s - 1][c, r]) / 2.0
        
        g[1] = (scaleLevels[s][c, r + 1] - scaleLevels[s][c, r - 1]) / 2.0
        
        g[2] = (scaleLevels[s][c + 1, r] - scaleLevels[s][c - 1, r]) / 2.0

        // Fill in the values of the Hessian from pixel differences
        H[0][0] = scaleLevels[s - 1][c, r] -
            2.0 * scaleLevels[s][c, r] +
                  scaleLevels[s + 1][c, r]
                               
        H[1][1] = scaleLevels[s][c, r - 1] -
            2.0 * scaleLevels[s][c, r] +
                  scaleLevels[s][c, r + 1]
                               
        H[2][2] = scaleLevels[s][c - 1, r] -
            2.0 * scaleLevels[s][c, r] +
                  scaleLevels[s][c + 1, r]
                               
        H[0][1] = ((scaleLevels[s + 1][c, r + 1] -
                              scaleLevels[s + 1][c, r - 1]) -
           (scaleLevels[s - 1][c, r + 1] - scaleLevels[s - 1][c, r - 1])) / 4.0
        H[1][0] = H[0][1]
                               
        H[0][2] = ((scaleLevels[s + 1][c + 1, r] -
                              scaleLevels[s + 1][c - 1, r]) -
           (scaleLevels[s - 1][c + 1, r] - scaleLevels[s - 1][c - 1, r])) / 4.0
        H[2][0] = H[0][2]
                               
        H[1][2] = ((scaleLevels[s][c + 1, r + 1] -
                              scaleLevels[s][c - 1, r + 1]) -
           (scaleLevels[s][c + 1, r - 1] - scaleLevels[s][c - 1, r - 1])) / 4.0
        H[2][1] = H[1][2]

        // Solve the 3x3 linear sytem, Hx = -g.  Result gives peak _offset.
        // Note that SolveLinearSystem destroys contents of H
        offset[0] = -g[0]
        offset[1] = -g[1]
        offset[2] = -g[2]

        solveLinearSystem(&offset, &H, 3)

        // Also return value of the determinant at peak location using initial
        // value plus 0.5 times linear interpolation with gradient to peak
        // position (this is correct for a quadratic approximation).
        return scaleLevels[s][c, r] + 0.5 * dotProduct(offset, g)
    }
                                             
    // Create a new ipoint and return list of ipoints with new one added
    private func makeIpoint(_ x: Float, _ y: Float, _ scale: Float, _ strength: Float) {
        vas[0] = Int(x * Float(sampling) + 0.5)
        vas[1] = Int(y * Float(sampling) + 0.5)
        vas[2] = Int(3 * scale + 0.5) / 2
        vas[3] = 2 * vas[2];
        vas[4] = vas[3] + vas[2]
        vas[5] = vas[0] + Int(3 * scale + 0.5)
        vas[6] = vas[0] - Int(3 * scale + 0.5)
        vas[7] = vas[1] + Int(3 * scale + 0.5)
        vas[8] = vas[1] - Int(3 * scale + 0.5)

        let interestPoint = InterestPoint(
            x: x * Float(sampling),
            y: y * Float(sampling),
            scale: 1.2 * scale,
            strength: strength,
            ori: 0.0,
            laplace: integralImage.getTrace(vas),
            ivec: []
        )
        
        interestPoints.append(interestPoint)
    }
    
}

#endif
