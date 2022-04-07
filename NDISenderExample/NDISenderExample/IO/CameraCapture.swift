import Foundation
import AVFoundation
import CoreImage
import UIKit
import os
import VideoIO

class CameraCapture: NSObject {
  typealias ProcessingCallback = (CMSampleBuffer) -> ()
  
  let cameraPosition: AVCaptureDevice.Position
  var currentDevice: AVCaptureDevice?
  let processingCallback: ProcessingCallback
  
  private(set) var session = AVCaptureSession()
  private let sampleBufferQueue = DispatchQueue(label: "camera.sampleBufferQueue", qos: .userInitiated)

  private let output = AVCaptureVideoDataOutput()
  
  private var isUsingFilters = true
  
  var delegate: AVCaptureVideoDataOutputSampleBufferDelegate!
  
  let logger = Logger(subsystem: Config.shared.subsystem, category: "CameraCapture")

  var camera: Camera
  
  init(cameraPosition: AVCaptureDevice.Position, processingCallback: @escaping ProcessingCallback) {
    self.cameraPosition = cameraPosition
    self.processingCallback = processingCallback
    
    // Configure VideoIO camera
    var configurator = Camera.Configurator()
    let interfaceOrientation = UIApplication.shared.windows.first(where: { $0.windowScene != nil })?.windowScene?.interfaceOrientation
    configurator.videoConnectionConfigurator = { camera, connection in
      switch interfaceOrientation {
      case .landscapeLeft:
        connection.videoOrientation = .landscapeLeft
      case .landscapeRight:
        connection.videoOrientation = .landscapeRight
      case .portraitUpsideDown:
        connection.videoOrientation = .portraitUpsideDown
      default:
        connection.videoOrientation = .portrait
      }
    }
    
    camera = Camera(captureSessionPreset: .hd1280x720, defaultCameraPosition: cameraPosition, configurator: configurator)
    self.currentDevice = camera.videoDevice
    super.init()
    
    prepareSession()
  }
  
  func stopCapture() {
    sampleBufferQueue.async {
      self.camera.stopRunningCaptureSession()
      NotificationCenter.default.post(name: .cameraDidStopRunning, object: nil)
    }
  }
  
  func discoverCameras() {
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
  }
  
  private func prepareSession() {
    discoverCameras()
    do {
      try self.camera.enableVideoDataOutput(on: sampleBufferQueue, delegate: self)
      
      sampleBufferQueue.async {
        self.camera.startRunningCaptureSession()
        NotificationCenter.default.post(name: .cameraSetupCompleted, object: nil)
        NotificationCenter.default.post(name: .cameraDidStartRunning, object: nil)
      }
    } catch {
      logger.error("Cannot enable video data output. Error: \(error.localizedDescription)")
    }
  }
  
  func sampleBufferAsync(actionClosure: @escaping () -> Void) {
    sampleBufferQueue.async {
      actionClosure()
    }
  }
}

extension CameraCapture: AVCaptureVideoDataOutputSampleBufferDelegate {
  func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    guard let formatDescription = sampleBuffer.formatDescription else {
      return
    }
    switch formatDescription.mediaType {
    case .audio:
      // Ignoring audio buffers as I'm planning to use AudioKit
      break
    case .video:
      processingCallback(sampleBuffer)
    default:
      break
    }
  }
}
