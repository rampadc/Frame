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
    
    let cameraDiscovery = AVCaptureDevice.DiscoverySession(
      deviceTypes: [
        .builtInDualCamera,
        .builtInTripleCamera,
        .builtInWideAngleCamera,
        .builtInTelephotoCamera,
        .builtInDualWideCamera,
        .builtInUltraWideCamera,
        .builtInDualWideCamera
      ],
      mediaType: .video,
      position: cameraPosition)

    NotificationCenter.default.post(name: .cameraDiscoveryCompleted, object: cameraDiscovery.devices)
    
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
    
    NotificationCenter.default.post(name: .cameraSetupCompleted, object: cameraDiscovery.devices)
  }
}

extension CameraCapture: AVCaptureVideoDataOutputSampleBufferDelegate {
  func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
    
    DispatchQueue.main.async {
      let image = CIImage(cvImageBuffer: imageBuffer)
      self.processingCallback(image)      
    }
  }
}
