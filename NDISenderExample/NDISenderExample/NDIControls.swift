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
  
  private init() {
    ndiWrapper = NDIWrapper()
  }
}
