import Foundation
import AVFoundation
import CoreImage
import UIKit
import os
import VideoIO

class CameraCapture: NSObject {
  typealias ProcessingCallback = (CMSampleBuffer, CVPixelBuffer?) -> ()
  
  var cameraPosition: AVCaptureDevice.Position
  var currentDevice: AVCaptureDevice?
  let processingCallback: ProcessingCallback
  
  private(set) var session = AVCaptureSession()
  let sampleBufferQueue = DispatchQueue(label: "camera.sampleBufferQueue", qos: .userInitiated)

  private let output = AVCaptureVideoDataOutput()
  
  private var isUsingFilters = true
  
  var delegate: AVCaptureVideoDataOutputSampleBufferDelegate!
  
  let logger = Logger(subsystem: Config.shared.subsystem, category: "CameraCapture")

  var camera: Camera
  
  let depthDataOutput = AVCaptureDepthDataOutput()
  var currentDepthPixelBuffer: CVPixelBuffer?
  
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

    if !self.switchCamera(deviceType: .builtInDualCamera) {
      self.logger.error("Cannot change camera to built in dual")
    }
    
    do {
      try self.addDepthDataOutput()
      self.logger.info("Added depth data output")
    } catch {
      self.logger.error("Cannot add depth data output")
    }
    if !self.configureFrameRate(30) {
      self.logger.error("Cannot set frame rate to 30")
    }
    
    prepareSession()
  }
  
  func stopCapture() {
    sampleBufferQueue.async {
      self.camera.stopRunningCaptureSession()
      NotificationCenter.default.post(name: .cameraDidStopRunning, object: nil)
    }
  }
  
  func discoverCameras() {
    let backCamerasDiscovery = AVCaptureDevice.DiscoverySession(
      deviceTypes: [
        .builtInDualCamera,
        .builtInTrueDepthCamera
      ],
      mediaType: .video,
      position: .back)
    let frontCamerasDiscovery = AVCaptureDevice.DiscoverySession(
      deviceTypes: [
        .builtInTrueDepthCamera
      ],
      mediaType: .video,
      position: .front)
    
    let allCameras = frontCamerasDiscovery.devices + backCamerasDiscovery.devices
    NotificationCenter.default.post(name: .cameraDiscoveryCompleted, object: allCameras)
    Config.shared.cameras = allCameras
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
      // Need to use audioCapture instead
      break
    case .video:
      processingCallback(sampleBuffer, self.currentDepthPixelBuffer)
    default:
      break
    }
  }
}

extension CameraCapture {
  func configureFrameRate(_ frameRate: Int) -> Bool {
    guard let videoDevice = camera.videoDevice else {
      self.logger.error("Camera is not yet initialised. Try again later")
      return false
    }
    do {
      try videoDevice.configureDesiredFrameRateForDepth(30)
      return true
    } catch {
      Config.shared.defaultLogger.error("Cannot set desired frame rate. Error: \(error.localizedDescription, privacy: .public)")
      return false
    }
  }
}
