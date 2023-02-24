//
//  IPOLSURFFile.swift
//  SURFMetalApp
//
//  Created by Luke Van In on 2023/02/20.
//

import Foundation
import OSLog


private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "SURFFile")

extension Descriptor {
    
    init(_ keypoint: IPOLSURFFile.PointOfInterest) {
        var vectors: [VectorDescriptor] = []
        for i in stride(from: 0, to: keypoint.descriptor.count, by: 4) {
            var vector = VectorDescriptor(
                sumDx: keypoint.descriptor[i + 0],
                sumDy: keypoint.descriptor[i + 1],
                sumAbsDx: keypoint.descriptor[i + 2],
                sumAbsDy: keypoint.descriptor[i + 3]
            )
            vectors.append(vector)
        }
        self.init(
            keypoint: Keypoint(
                x: keypoint.x,
                y: keypoint.y,
                scale: keypoint.scale,
                orientation: keypoint.orientation,
                laplacian: Int32(keypoint.laplacian)
            ),
            vector: vectors
        )
    }
}


final class IPOLSURFFile {
    
    struct PointOfInterest {
        let x: Float
        let y: Float
        let scale: Float
        let orientation: Float
        let laplacian: Int
        let descriptor: [Float]
    }
    
    let contents: [PointOfInterest]
    
    convenience init(contentsOf fileURL: URL) throws {
        logger.debug("Reading file \(fileURL.absoluteString)")
        var pointsOfInterest: [PointOfInterest] = []
        let text = try! String(contentsOf: fileURL, encoding: .ascii)
        let lines = text.components(separatedBy: "\n")
        
        var i = 0
        
        let vectorLength = Int(lines[i])!
        logger.debug("Line \(i): Vector length = \(vectorLength)")
        assert(vectorLength == 64)
        i += 1
        
        let numberOfPoints = Int(lines[i])!
        logger.debug("Line \(i): Number of points = \(numberOfPoints)")
        assert(numberOfPoints == lines.count - 3)
        i += 1
        
        for _ in 0 ..< numberOfPoints {
            let components = lines[i].split(separator: " ")
//            logger.debug("Line \(i): Components = \(components)")
            
            var j = 0
            
            let x = Float(components[j])!
//            logger.debug("Line \(i): Components \(j): x = \(x)")
            j += 1
            
            let y = Float(components[j])!
//            logger.debug("Line \(i): Components \(j): y = \(y)")
            j += 1
            
            let scale = Float(components[j])!
//            logger.debug("Line \(i): Components \(j): a = \(scale)")
            j += 1
            
            let orientation = Float(components[j])!
//            logger.debug("Line \(i): Components \(j): b = \(orientation)")
            j += 1
            
            var descriptor = [Float]()
            for _ in 0 ..< 64 {
                let value = Float(components[j])!
                descriptor.append(value)
                j += 1
            }
//            logger.debug("Line \(i): Descriptor = \(descriptor)")
            
            let laplacian = Int(components[j])!
//            logger.debug("Line \(i): Components \(j): laplacian = \(laplacian)")
            j += 1
            
            let pointOfInterest = PointOfInterest(
                x: x,
                y: y,
                scale: scale,
                orientation: orientation,
                laplacian: laplacian != 0 ? +1 : -1,
                descriptor: descriptor
            )
            pointsOfInterest.append(pointOfInterest)
            
            i += 1
        }
        
        self.init(contents: pointsOfInterest)
    }
    
    init(contents: [PointOfInterest]) {
        self.contents = contents
    }
}
