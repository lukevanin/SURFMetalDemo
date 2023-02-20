//
//  SURFFile.swift
//  SURFMetalApp
//
//  Created by Luke Van In on 2023/02/15.
//

import Foundation
import OSLog


private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "SURFFile")


///
/// Save interest point with descriptor in the format of Krystian Mikolajczyk
/// for reasons of comparison with other descriptors. As our interest points
/// are circular in any case, we use the second component of the ellipse to
/// provide some information about the strength of the interest point. This is
/// important for 3D reconstruction as only the strongest interest points are
/// considered. Replace the strength with 0.0 in order to perform Krystian's
/// comparisons.
///
/// Fields delimited by newline (\n).
/// Int: Length of the vector data, including the optional laplacian. 64 without laplacian, or 65 with laplacian.
/// Int: Number of entries
///
/// Followed by interest points, separated by spaces:
///     Float: X
///     Float: Y
///     Float: 1 / r^2
///     Float: Strength. Always 0.
///     Float: 1 / r^2
///     Int: Laplacian (optional)
///     Float[64]: Descriptor
///
final class BaySURFFile {
    
    struct PointOfInterest {
        let x: Float
        let y: Float
        let scale: Float
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
        assert(vectorLength == 65)
        i += 1
        
        let numberOfPoints = Int(lines[i])!
        logger.debug("Line \(i): Number of points = \(numberOfPoints)")
        assert(numberOfPoints == lines.count - 3)
        i += 1
        
        for _ in 0 ..< numberOfPoints {
            let components = lines[i].split(separator: " ")
            logger.debug("Line \(i): Components = \(components)")

            var j = 0
            
            let x = Float(components[j])!
            logger.debug("Line \(i): Components \(j): x = \(x)")
            j += 1
            
            let y = Float(components[j])!
            logger.debug("Line \(i): Components \(j): y = \(y)")
            j += 1
            
            let a = Float(components[j])!
            logger.debug("Line \(i): Components \(j): a = \(a)")
            j += 1
            
            let b = Float(components[j])!
            logger.debug("Line \(i): Components \(j): b = \(b)")
            j += 1
            
            let c = Float(components[j])!
            logger.debug("Line \(i): Components \(j): c = \(c)")
            j += 1
            
            let laplacian = Int(components[j])!
            logger.debug("Line \(i): Components \(j): laplacian = \(laplacian)")
            j += 1
            
            var descriptor = [Float]()
            for _ in 0 ..< 64 {
                let value = Float(components[j])!
                descriptor.append(value)
                j += 1
            }
            logger.debug("Line \(i): Descriptor = \(descriptor)")

            let det = sqrt((a - c) * (a - c) + 4.0 * b * b)
            let e1 = 0.5 * (a + c + det)
            let e2 = 0.5 * (a + c - det)
            let l1 = (1.0 / sqrt(e1))
            let l2 = (1.0 / sqrt(e2))
            let sc = sqrt(l1 * l2)
            
            let pointOfInterest = PointOfInterest(
                x: x,
                y: y,
                scale: sc / 2.5,
                laplacian: laplacian,
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
    
    func write(to fileURL: URL) throws {
        var lines: [String] = []
        
        // Length of descriptior vector (64) + laplacian (1)
        lines.append("65")
        
        // Number of points of interest
        lines.append(String(contents.count))
        
        // Append points of interest
        for pointOfInterest in contents {
            var components: [String] = []
            
            let r = 2.5 * pointOfInterest.scale
            let sc = r * r

            // x-location of the interest point
            components.append(String(pointOfInterest.x))
            
            // y-location of the interest point
            components.append(String(pointOfInterest.y))
            
            // 1.0/sc (1/r^2)
            components.append(String(sc))

            // (*ipts)[n]->strength (0.0)
            components.append(String(0))

            // 1.0/sc (1/r^2)
            components.append(String(sc))
            
            // Laplacian
            components.append(String(pointOfInterest.laplacian))
            
            // Descriptor
            for value in pointOfInterest.descriptor {
                components.append(String(value))
            }

            // Combine components into line line
            let line = components.joined(separator: " ")
            lines.append(line)
        }
        
        // Write file
        let text = String(lines.joined(separator: "\n"))
        try text.write(to: fileURL, atomically: true, encoding: .ascii)
    }
}
