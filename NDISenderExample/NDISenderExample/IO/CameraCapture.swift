import Foundation
import AVFoundation
import CoreImage
import UIKit
import os

class CameraCapture: NSObject {
  typealias ProcessingCallback = (CMSampleBuffer) -> ()
  
  let cameraPosition: AVCaptureDevice.Position
  var currentDevice: AVCaptureDevice?
  
  private(set) var session = AVCaptureSession()
  private let sampleBufferQueue = DispatchQueue(label: "camera.sampleBufferQueue", qos: .userInitiated, attributes: .concurrent)

  private let output = AVCaptureVideoDataOutput()
  
  private var isUsingFilters = true
  
  var delegate: AVCaptureVideoDataOutputSampleBufferDelegate!
  
  let logger = Logger(subsystem: Config.shared.subsystem, category: "CameraCapture")

  
  init(cameraPosition: AVCaptureDevice.Position, delegate: AVCaptureVideoDataOutputSampleBufferDelegate) {
    self.cameraPosition = cameraPosition
    self.delegate = delegate
    
    super.init()
    
    NotificationCenter.default.addObserver(self, selector: #selector(onCaptureSessionError(_:)), name: .AVCaptureSessionRuntimeError, object: nil)
    prepareSession()
  }
  
  func startCapture() {
    session.startRunning()
    NotificationCenter.default.post(name: .cameraDidStartRunning, object: nil)
  }
  
  func stopCapture() {
    session.stopRunning()
    NotificationCenter.default.post(name: .cameraDidStopRunning, object: nil)
  }
  
  private func prepareSession() {
//    session.sessionPreset = .hd1920x1080
    session.sessionPreset = .hd1280x720
//    session.sessionPreset = .hd4K3840x2160
    
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
    Config.shared.cameras = cameraDiscovery.devices
    
    guard let camera = cameraDiscovery.devices.first, let input = try? AVCaptureDeviceInput(device: camera) else { fatalError("Cannot use the camera") }
    
    self.currentDevice = camera
    
    if session.canAddInput(input) {
      session.addInput(input)
    }
    
    output.videoSettings = [kCVPixelBufferPixelFormatTypeKey : kCVPixelFormatType_32BGRA] as [String : Any]
    output.alwaysDiscardsLateVideoFrames = true
    output.setSampleBufferDelegate(self.delegate, queue: sampleBufferQueue)
    
    if session.canAddOutput(output) {
      session.addOutput(output)
    }
    session.commitConfiguration()
    
    NotificationCenter.default.post(name: .cameraSetupCompleted, object: nil)
  }
  
  func sampleBufferAsync(actionClosure: @escaping () -> Void) {
    sampleBufferQueue.async {
      actionClosure()
    }
  }
  
  @objc private func onCaptureSessionError(_ notification: Notification) {
    // Example: https://github.com/tensorflow/examples/blob/master/lite/examples/object_detection/ios/ObjectDetection/Camera%20Feed/CameraFeedManager.swift
    guard let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError else {
      return
    }
    
    self.logger.error("AVCaptureSessionError: \(error.localizedDescription, privacy: .public)")
  }
}
