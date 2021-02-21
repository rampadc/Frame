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
  
  var formatDescription: CMFormatDescription?
  
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
      let pixelBuffer: CVPixelBuffer? = createPixelBufferFrom(image: image)
      Config.shared.ciContext?.render(image, to: pixelBuffer!)
      
      let sampleBuffer: CMSampleBuffer? = createSampleBufferFrom(pixelBuffer: pixelBuffer!)
      
      // test
      guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer!) else { return }
      let image = CIImage(cvImageBuffer: imageBuffer)
      
      
      ndiWrapper.send(sampleBuffer)
    }
    
  }
  
  func createSampleBufferFrom(pixelBuffer: CVPixelBuffer) -> CMSampleBuffer? {
    var sampleBuffer: CMSampleBuffer?
    var timimgInfo  = CMSampleTimingInfo()
    CMSampleBufferCreateReadyWithImageBuffer(
      allocator: kCFAllocatorDefault,
      imageBuffer: pixelBuffer,
      formatDescription: self.formatDescription!,
      sampleTiming: &timimgInfo,
      sampleBufferOut: &sampleBuffer
    )
    
    guard let buffer = sampleBuffer else {
      print("Cannot create sample buffer")
      return nil
    }
    
    
    return buffer
  }
  
  func createPixelBufferFrom(image: CIImage) -> CVPixelBuffer? {
    // from https://stackoverflow.com/questions/54354138/how-can-you-make-a-cvpixelbuffer-directly-from-a-ciimage-instead-of-a-uiimage-in
    let attrs = [
      kCVPixelBufferCGImageCompatibilityKey: false,
      kCVPixelBufferCGBitmapContextCompatibilityKey: false,
      kCVPixelBufferWidthKey: Int(image.extent.width),
      kCVPixelBufferHeightKey: Int(image.extent.height)
    ] as CFDictionary
    var pixelBuffer : CVPixelBuffer?
    let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(image.extent.width), Int(image.extent.height), kCVPixelFormatType_32BGRA, attrs, &pixelBuffer)
    
    if status == kCVReturnInvalidPixelFormat {
      print("status == kCVReturnInvalidPixelFormat")
    }
    if status == kCVReturnInvalidSize {
      print("status == kCVReturnInvalidSize")
    }
    if status == kCVReturnPixelBufferNotMetalCompatible {
      print("status == kCVReturnPixelBufferNotMetalCompatible")
    }
    if status == kCVReturnPixelBufferNotOpenGLCompatible {
      print("status == kCVReturnPixelBufferNotOpenGLCompatible")
    }
    
    guard (status == kCVReturnSuccess) else {
      return nil
    }
    
    return pixelBuffer
  }
  
  private init() {
    ndiWrapper = NDIWrapper()
  }
}
