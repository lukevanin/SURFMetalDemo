//
//  ContentView.swift
//  SURFMetalApp
//
//  Created by Luke Van In on 2023/02/14.
//

import SwiftUI
import CoreGraphics

func loadImage(named name: String) -> CGImage {
    let fileURL = Bundle.main.urlForImageResource(name)!
    let dataProvider = CGDataProvider(url: fileURL as CFURL)!
    let image = CGImage(pngDataProviderSource: dataProvider, decode: nil, shouldInterpolate: true, intent: .perceptual)!
    return image
}


struct ContentView: View {
    
    let sourceImage: CGImage
    let features: [SURFDescriptor]
    
    var body: some View {
        VStack {
            Image(sourceImage, scale: 1, label: Text("Sample"))
                .resizable()
                .aspectRatio(contentMode: .fit)
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(
            sourceImage: loadImage(named: "image1"),
            features: []
        )
    }
}
