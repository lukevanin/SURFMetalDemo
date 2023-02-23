//
//  SURFMetalAppApp.swift
//  SURFMetalApp
//
//  Created by Luke Van In on 2023/02/14.
//

import SwiftUI
import Metal

private struct TestImageSet: Identifiable {
    let id: String
    let imageA: Bitmap
    let imageB: Bitmap
}

private let device = MTLCreateSystemDefaultDevice()!

@main
struct SURFMetalApp: App {
    
//    private let surf = SURFIPOL(width: 1464, height: 968)
//    private let sourceImage = Bitmap(cgImage: loadImage(named: "waterfall")).normalized()
//    private let surfFile = try! IPOLSURFFile(contentsOf: Bundle.main.url(forResource: "waterfall", withExtension: "surf")!)

//    private let arch0Surf = SURFIPOL(width: 650, height: 488)
//    private let arch0SourceImage = Bitmap(cgImage: loadImage(named: "arch_0")).normalized()
//    private let arch0SurfFile = try! IPOLSURFFile(contentsOf: Bundle.main.url(forResource: "arch_0", withExtension: "surf")!)

//    private let arch1Surf = SURFIPOL(width: 488, height: 650)
//    private let arch1SourceImage = Bitmap(cgImage: loadImage(named: "arch_1")).normalized()
//    private let arch1SurfFile = try! IPOLSURFFile(contentsOf: Bundle.main.url(forResource: "arch_1", withExtension: "surf")!)

    private let lenaMetalSurf = SURFMetal(device: device, width: 1024, height: 1024)
    private let lenaMetalBitmap = MetalBitmap(device: device, name: "Lena", cgImage: loadImage(named: "lena")).normalized()
    private let lenaSurf = SURFIPOL(width: 1024, height: 1024)
    private let lenaBitmap = Bitmap(cgImage: loadImage(named: "lena")).normalized()
    private let lenaSurfFile = try! IPOLSURFFile(contentsOf: Bundle.main.url(forResource: "lena", withExtension: "surf")!)

//    private let testSurfMetal = SURFMetal(width: 480, height: 640)
//    private let testSurfIpol = SURFIPOL(width: 480, height: 640)
//    private let testImages = [
//        TestImageSet(
//            id: "test0-0",
//            imageA: Bitmap(cgImage: loadImage(named: "test-0-0")).normalized(),
//            imageB: Bitmap(cgImage: loadImage(named: "test-0-1")).normalized()
//        ),
//        TestImageSet(
//            id: "test0-1",
//            imageA: Bitmap(cgImage: loadImage(named: "test-0-1")).normalized(),
//            imageB: Bitmap(cgImage: loadImage(named: "test-0-2")).normalized()
//        ),
        
//        TestImageSet(
//            id: "test1-0",
//            imageA: Bitmap(cgImage: loadImage(named: "test-1-0")).normalized(),
//            imageB: Bitmap(cgImage: loadImage(named: "test-1-1")).normalized()
//        ),
//        TestImageSet(
//            id: "test1-1",
//            imageA: Bitmap(cgImage: loadImage(named: "test-1-1")).normalized(),
//            imageB: Bitmap(cgImage: loadImage(named: "test-1-2")).normalized()
//        ),
//        TestImageSet(
//            id: "test1-2",
//            imageA: Bitmap(cgImage: loadImage(named: "test-1-0")).normalized(),
//            imageB: Bitmap(cgImage: loadImage(named: "test-1-2")).normalized()
//        ),
//    ]

    var body: some Scene {
        WindowGroup {
            
            HStack {
                
                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    SURFCompareView(
                        image: lenaMetalBitmap.cgImage(),
                        sourceFeatures: lenaMetalSurf.getKeypoints(image: lenaMetalBitmap).map {
                            KeypointViewModel(x: $0.keypoint.x, y: $0.keypoint.y, scale: $0.keypoint.scale, orientation: $0.keypoint.orientation)
                        },
                        targetFeatures: lenaSurfFile.contents.map {
                            KeypointViewModel(x: $0.x, y: $0.y, scale: $0.scale, orientation: $0.orientation)
                        },
                        zoom: 2.0
                    )
                }

                ScrollView {
                    SURFDebugView(
                        hessianImages: makeHessianImages()
                    )
                }
            }

//            VStack {
//                SURFCompareView(
//                    image: arch0SourceImage.cgImage(),
//                    sourceFeatures: arch0Surf.getKeypoints(image: arch0SourceImage).map {
//                        KeypointViewModel(x: $0.keypoint.x, y: $0.keypoint.y, scale: $0.keypoint.scale, orientation: $0.keypoint.orientation)
//                    },
//                    targetFeatures: arch0SurfFile.contents.map {
//                        KeypointViewModel(x: $0.x, y: $0.y, scale: $0.scale, orientation: $0.orientation)
//                    },
//                    zoom: 1.0
//                )
//
//                SURFCompareView(
//                    image: arch1SourceImage.cgImage(),
//                    sourceFeatures: arch1Surf.getKeypoints(image: arch1SourceImage).map {
//                        KeypointViewModel(x: $0.keypoint.x, y: $0.keypoint.y, scale: $0.keypoint.scale, orientation: $0.keypoint.orientation)
//                    },
//                    targetFeatures: arch1SurfFile.contents.map {
//                        KeypointViewModel(x: $0.x, y: $0.y, scale: $0.scale, orientation: $0.orientation)
//                    },
//                    zoom: 1.0
//                )
//            }
            
//            SURFMatchView(
//                sourceImage: arch0SourceImage.cgImage(),
//                targetImage: arch1SourceImage.cgImage(),
//                matches: match(
//                    arch0SurfFile.contents.map {
//                        Descriptor($0)
//                    },
//                    arch1SurfFile.contents.map {
//                        Descriptor($0)
//                    }
//                ),
//                zoom: 1.0
//            )
            
//            SURFMatchView(
//                sourceImage: arch0SourceImage.cgImage(),
//                targetImage: arch1SourceImage.cgImage(),
//                matches: match(
//                    arch0Surf.getKeypoints(image: arch0SourceImage),
//                    arch1Surf.getKeypoints(image: arch1SourceImage)
//                ),
//                zoom: 1.0
//            )

//            ScrollView() {
//                VStack {
//                    ForEach(testImages) { images in
//                        HStack {
//                            SURFMatchView(
//                                sourceImage: images.imageA.cgImage(),
//                                targetImage: images.imageB.cgImage(),
//                                matches: match(
//                                    testSurfIpol.getKeypoints(image: images.imageA),
//                                    testSurfIpol.getKeypoints(image: images.imageB)
//                                ),
//                                zoom: 0.5
//                            )
//                            .background(.teal)
//
//                            SURFMatchView(
//                                sourceImage: images.imageA.cgImage(),
//                                targetImage: images.imageB.cgImage(),
//                                matches: match(
//                                    testSurfMetal.getKeypoints(image: images.imageA),
//                                    testSurfMetal.getKeypoints(image: images.imageB)
//                                ),
//                                zoom: 0.5
//                            )
//                            .background(.orange)
//
//                        }
//                    }
//                }
//            }
            
        }
        .defaultSize(width: 800, height: 600)
    }
        
    private func makeHessianImages() -> [(index: Int, reference: CGImage, metal: CGImage)] {
        let _ = lenaMetalSurf.getKeypoints(image: lenaMetalBitmap)
        let _ = lenaSurf.getKeypoints(image: lenaBitmap)
        let metalImages = lenaMetalSurf.octaves
            .lazy
            .map { octave in
                octave.hessians
            }
            .joined()
            .map { hessian in
                hessian.normalized().cgImage()
            }
        let images = lenaSurf.octaves
            .lazy
            .map { octave in
                octave.hessian
            }
            .joined()
            .map { hessian in
                hessian.normalized().cgImage()
            }
        return zip(images, metalImages)
            .enumerated()
            .map {
                (index: $0, reference: $1.0, metal: $1.1)
            }
    }
}
