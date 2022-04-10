//
//  PixelBufferBackedCGImageGenerator.swift
//  MetalPetalDemo
//
//  Created by YuAo on 2021/4/6.
//

import Foundation
import MetalPetal
import VideoToolbox

// Source: https://github.com/MetalPetal/MetalPetal/blob/master/MetalPetalExamples/Shared/PixelBufferPoolBackedImageRenderer.swift
class PixelBufferPoolBackedImageRenderer {
    private var pixelBufferPool: MTICVPixelBufferPool?
    private let renderSemaphore: DispatchSemaphore

    init(renderTaskQueueCapacity: Int = 3) {
        self.renderSemaphore = DispatchSemaphore(value: renderTaskQueueCapacity)
    }
    
  func render(_ image: MTIImage, using context: MTIContext) throws -> (CVPixelBuffer) {
        let pixelBufferPool: MTICVPixelBufferPool
        if let pool = self.pixelBufferPool, pool.pixelBufferWidth == image.dimensions.width, pool.pixelBufferHeight == image.dimensions.height {
            pixelBufferPool = pool
        } else {
            pixelBufferPool = try MTICVPixelBufferPool(pixelBufferWidth: Int(image.dimensions.width), pixelBufferHeight: Int(image.dimensions.height), pixelFormatType: kCVPixelFormatType_32BGRA, minimumBufferCount: 30)
            self.pixelBufferPool = pixelBufferPool
        }
        let pixelBuffer = try pixelBufferPool.makePixelBuffer(allocationThreshold: 30)
        
        self.renderSemaphore.wait()
        do {
            try context.startTask(toRender: image, to: pixelBuffer, sRGB: false, completion: { task in
                self.renderSemaphore.signal()
            })
        } catch {
            self.renderSemaphore.signal()
            throw error
        }

        return pixelBuffer
    }
}
