//
//  CameraCapture+Depth.swift
//  Frame
//
//  Created by Cong Nguyen on 11/4/2022.
//

import Foundation

extension CameraCapture: AVCaptureDepthDataOutputDelegate {
  func addDepthDataOutput() throws {
    // Add a depth data output
    let session = self.camera.captureSession
    session.beginConfiguration()
    
    if session.canAddOutput(depthDataOutput) {
      session.addOutput(depthDataOutput)
      depthDataOutput.setDelegate(self, callbackQueue: self.sampleBufferQueue)
      depthDataOutput.isFilteringEnabled = false
      
    } else {
      print("Could not add depth data output to the session")
      session.commitConfiguration()
      return
    }
  }
  
  func depthDataOutput(_ depthDataOutput: AVCaptureDepthDataOutput, didOutput depthData: AVDepthData, timestamp: CMTime, connection: AVCaptureConnection) {
    processDepth(depthData: depthData)
  }
  
  func processDepth(depthData: AVDepthData) {
    self.currentDepthPixelBuffer = depthData.depthDataMap
  }
}
