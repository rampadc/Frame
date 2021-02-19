import Foundation
import AVFoundation
import CoreImage
import UIKit

class CameraCapture: NSObject {
  typealias ProcessingCallback = (CIImage?) -> ()
  
  let cameraPosition: AVCaptureDevice.Position
  let processingCallback: ProcessingCallback
  
  private(set) var session = AVCaptureSession()
  private let sampleBufferQueue = DispatchQueue(label: "realtime.samplebuffer", qos: .userInitiated)
  

  
  init(cameraPosition: AVCaptureDevice.Position, processingCallback: @escaping ProcessingCallback) {
    self.cameraPosition = cameraPosition
    self.processingCallback = processingCallback
    
    super.init()
    prepareSession()
  }
  
  func startCapture() {
    session.startRunning()
  }
  
  func stopCapture() {
    session.stopRunning()
  }
  
  private func prepareSession() {
    session.sessionPreset = .hd1920x1080
    
    let cameraDiscovery = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInDualCamera, .builtInWideAngleCamera], mediaType: .video, position: cameraPosition)
    guard let camera = cameraDiscovery.devices.first, let input = try? AVCaptureDeviceInput(device: camera) else { fatalError("Cannot use the camera") }
    if session.canAddInput(input) {
      session.addInput(input)
    }
    
    
    let output = AVCaptureVideoDataOutput()
    output.videoSettings = [kCVPixelBufferPixelFormatTypeKey :  kCVPixelFormatType_32BGRA] as [String : Any]
    output.alwaysDiscardsLateVideoFrames = true
    output.setSampleBufferDelegate(self, queue: sampleBufferQueue)
    if session.canAddOutput(output) {
      session.addOutput(output)
    }
  }
}

extension CameraCapture: AVCaptureVideoDataOutputSampleBufferDelegate {
  func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    guard let videoPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
          let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else {
      return
    }
    
    // use `var` when start to modify finalVideoPixelBuffer, using let` to suppress warnings for now
    let finalVideoPixelBuffer = videoPixelBuffer
    
    guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
    
    DispatchQueue.main.async {
      let image = CIImage(cvImageBuffer: imageBuffer)
      self.processingCallback(image)
      
      NDIControls.instance.send(sampleBuffer: sampleBuffer)
//      // create a sample buffer from processed finalVideoPixelBuffer
//      var timing = CMSampleTimingInfo()
//      var copiedSampleBuffer: CMSampleBuffer?
//      CMSampleBufferCreateReadyWithImageBuffer(
//        allocator: kCFAllocatorDefault,
//        imageBuffer: finalVideoPixelBuffer,
//        formatDescription: formatDescription,
//        sampleTiming: &timing,
//        sampleBufferOut: &copiedSampleBuffer)
//
//      guard let ndiWrapper = self.ndiWrapper, self.isSending else { return }
//      ndiWrapper.send(copiedSampleBuffer)
    }
  }
}
