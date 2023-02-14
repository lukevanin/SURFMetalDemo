//
//  SURFMetalAppApp.swift
//  SURFMetalApp
//
//  Created by Luke Van In on 2023/02/14.
//

import SwiftUI
import Metal

@main
struct SURFMetalApp: App {
    
    private let surf = SURFCPU()
    private let sourceImage = loadImage(named: "image1")
    
    var body: some Scene {
        WindowGroup {
            ContentView(
                sourceImage: sourceImage,
                features: surf.getFeatures(sourceImage)
            )
        }
    }
}
