//
//  WebServer.swift
//  NDISenderExample
//
//  Created by Cong Nguyen on 11/2/21.
//

import Foundation
import GCDWebServer

class NDIControls {
  private var ndiWrapper: NDIWrapper
  private(set) var isSending: Bool = false
  private let webServer = GCDWebServer()
  
  static let instance = NDIControls()
  
  func startWebServer() {
    webServer.addDefaultHandler(forMethod: "GET", request: GCDWebServerRequest.self, processBlock: {request in
      return GCDWebServerDataResponse(html:"<html><body><p>Hello World</p></body></html>")
    })
    webServer.start(withPort: 8080, bonjourName: UIDevice.current.name)
  }
  
  func start() {
    isSending = true
    ndiWrapper.start(UIDevice.current.name)
  }
  
  func stop() {
    isSending = false
    ndiWrapper.stop()
  }
  
  func send(sampleBuffer: CMSampleBuffer) {
    if isSending {
      ndiWrapper.send(sampleBuffer)
    }
  }
  
  func send(imageBuffer: CVImageBuffer, formatDescription: CMFormatDescription) {
    var timing = CMSampleTimingInfo()
    var copiedSampleBuffer: CMSampleBuffer?
    CMSampleBufferCreateReadyWithImageBuffer(
      allocator: kCFAllocatorDefault,
      imageBuffer: imageBuffer,
      formatDescription: formatDescription,
      sampleTiming: &timing,
      sampleBufferOut: &copiedSampleBuffer)
    
    if isSending {
      ndiWrapper.send(copiedSampleBuffer)
    }
  }
  
  func send(image: CIImage) {
    if isSending {
      // Based on https://gist.github.com/levantAJ/4e3e40ba2fa190fd88e329ede8f27f3f
      // Create a CVPixelBuffer
      var pixelBuffer: CVPixelBuffer? = nil
          let options: [NSObject: Any] = [
              kCVPixelBufferCGImageCompatibilityKey: false,
              kCVPixelBufferCGBitmapContextCompatibilityKey: false,
              ]
      let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(image.extent.width), Int(image.extent.height), kCVPixelFormatType_32BGRA, options as CFDictionary, &pixelBuffer)
          CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
      let destination = CIRenderDestination(pixelBuffer: pixelBuffer!)
      
      let ciContext = CIContext()
      try! ciContext.startTask(toRender: image, to: destination)
      
      
//
      // Create a CMSampleBuffer
      var newSampleBuffer: CMSampleBuffer? = nil
      var timimgInfo  = CMSampleTimingInfo()
      var videoInfo: CMVideoFormatDescription? = nil
      CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixelBuffer!, formatDescriptionOut: &videoInfo)
      CMSampleBufferCreateReadyWithImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixelBuffer!, formatDescription: videoInfo!, sampleTiming: &timimgInfo, sampleBufferOut: &newSampleBuffer)

      ndiWrapper.send(newSampleBuffer)
    }
    
  }
  
  private init() {
    ndiWrapper = NDIWrapper()
  }
}
