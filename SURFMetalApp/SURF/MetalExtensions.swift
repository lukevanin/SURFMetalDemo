//
//  MetalExtensions.swift
//  SURFMetalApp
//
//  Created by Luke Van In on 2023/02/22.
//

import Foundation
import Metal

func capture(_ name: String, commandQueue: MTLCommandQueue, capture: Bool = true, worker: (MTLCommandBuffer) -> Void) {
    var captureManager: MTLCaptureManager?
    if capture {
//        let captureManager = MTLCaptureManager.shared()
        captureManager = .shared()
        let captureDescriptor = MTLCaptureDescriptor()
        captureDescriptor.captureObject = commandQueue
        captureDescriptor.destination = .developerTools
        try! captureManager?.startCapture(with: captureDescriptor)
    }

    let descriptor = MTLCommandBufferDescriptor()
    descriptor.errorOptions = .encoderExecutionStatus
    let commandBuffer = commandQueue.makeCommandBuffer(descriptor: descriptor)!
    commandBuffer.label = name
    worker(commandBuffer)
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()

    if capture {
        captureManager?.stopCapture()
    }
    if let error = commandBuffer.error as NSError? {
        let infos = error.userInfo[MTLCommandBufferEncoderInfoErrorKey] as? [MTLCommandBufferEncoderInfo]
        if let infos {
            for info in infos {
                print (info.label + info.debugSignposts.joined())
                switch info.errorState {
                case .unknown:
                    NSLog("%@", error)
                    print(info.label + " unknown!")
                case .affected:
                    NSLog("%@", error)
                    print(info.label + " affected!")
                case .faulted:
                    NSLog("%@", error)
                    print(info.label + " faulted!")
                case .pending:
                    NSLog("%@", error)
                    print(info.label + " pending!")
                case .completed:
                    break
                }
            }
        }
    }
}

