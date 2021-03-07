import Foundation
import AVFoundation
import CoreImage
import UIKit

class CameraCapture: NSObject {
  typealias ProcessingCallback = (CIImage?) -> ()
  
  let cameraPosition: AVCaptureDevice.Position
  let processingCallback: ProcessingCallback
  var currentDevice: AVCaptureDevice?
  
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
    Config.shared.cameras = cameraDiscovery.devices
    
    guard let camera = cameraDiscovery.devices.first, let input = try? AVCaptureDeviceInput(device: camera) else { fatalError("Cannot use the camera") }
    
    self.currentDevice = camera
    
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
    
    
    NotificationCenter.default.post(name: .cameraSetupCompleted, object: nil)
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

extension CameraCapture {
  func switchCamera(uniqueID: String) -> Bool {
    let currentCameraInput = session.inputs[0]
    session.removeInput(currentCameraInput)
    
    let matchingCameras = Config.shared.cameras?.filter({ (c: AVCaptureDevice) -> Bool in
      return c.uniqueID == uniqueID
    })
    guard let camera = matchingCameras?.first else { return false }
    
    self.currentDevice = camera
    
    do {
      try session.addInput(AVCaptureDeviceInput(device: camera))
      return true
    } catch {
      print("Cannot change camera. Error: \(error.localizedDescription)")
      return false
    }
  }
  
  func zoom(factor: Float) -> Bool {
    guard let device = self.currentDevice else { return false }
    let cgFactor = CGFloat(factor)
    if device.minAvailableVideoZoomFactor > cgFactor || device.maxAvailableVideoZoomFactor < cgFactor {
      return false
    }
    
    do {
      try device.lockForConfiguration()
      device.videoZoomFactor = CGFloat(factor)
      device.unlockForConfiguration()
      return true
    } catch {
      print("Cannot zoom. Error: \(error.localizedDescription)")
      return false
    }
  }
  
  func setExposureCompensation(bias: Float) -> Bool {
    guard let device = self.currentDevice else { return false }
    
    if device.maxExposureTargetBias < bias || device.minExposureTargetBias > bias {
      return false
    }
    
    do {
      try device.lockForConfiguration()
      device.setExposureTargetBias(bias, completionHandler: nil)
      device.unlockForConfiguration()
    } catch {
      print("Cannot set custom exposure time and iso. Error: \(error.localizedDescription)")
      return false
    }
    
    return true
  }
  
  func setWhiteBalanceMode(mode: AVCaptureDevice.WhiteBalanceMode) -> Bool {
    guard let device = self.currentDevice else { return false }
    do {
      try device.lockForConfiguration()
      if device.isWhiteBalanceModeSupported(mode) {
        device.whiteBalanceMode = mode
        device.unlockForConfiguration()
        return true
      } else {
        print("White balance mode \(mode.description) is not supported. White balance mode is \(device.whiteBalanceMode.description).")
        device.unlockForConfiguration()
        return false
      }
    } catch let error {
      print("Could not lock device for configuration: \(error)")
      return false
    }
  }
  
  func setTemperatureAndTint(temperature: Float, tint: Float) -> Bool {
    guard let device = self.currentDevice else { return false }
    if device.whiteBalanceMode != .locked {
      return false
    }
    
    let temperatureAndTint = AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(
      temperature: temperature,
      tint: tint
    )
    
    self.setWhiteBalanceGains(device.deviceWhiteBalanceGains(for: temperatureAndTint))
    return true
  }
  
  func lockGreyWorld() -> Bool {
    guard let device = self.currentDevice else { return false }
    self.setWhiteBalanceGains(device.grayWorldDeviceWhiteBalanceGains)
    return true
  }
  
  private func setWhiteBalanceGains(_ gains: AVCaptureDevice.WhiteBalanceGains) {
    guard let device = self.currentDevice else { return }
    do {
      try device.lockForConfiguration()
      let normalizedGains = self.normalizedGains(gains) // Conversion can yield out-of-bound values, cap to limits
      device.setWhiteBalanceModeLocked(with: normalizedGains, completionHandler: nil)
      device.unlockForConfiguration()
    } catch let error {
      print("Could not lock device for configuration: \(error)")
    }
  }
  
  func getTemperature() -> Float {
    guard let device = self.currentDevice else { return -1 }
    return Camera.getTemperature(device: device)
  }
  
  func getTint() -> Float {
    guard let device = self.currentDevice else { return -1 }
    return Camera.getTint(device: device)
  }
  
  private func normalizedGains(_ gains: AVCaptureDevice.WhiteBalanceGains) -> AVCaptureDevice.WhiteBalanceGains {
    if self.currentDevice == nil {
      fatalError("No camera active, cannot normalize gains")
    }
    
    var g = gains
    
    g.redGain = max(1.0, g.redGain)
    g.greenGain = max(1.0, g.greenGain)
    g.blueGain = max(1.0, g.blueGain)
    
    g.redGain = min(self.currentDevice!.maxWhiteBalanceGain, g.redGain)
    g.greenGain = min(self.currentDevice!.maxWhiteBalanceGain, g.greenGain)
    g.blueGain = min(self.currentDevice!.maxWhiteBalanceGain, g.blueGain)
    
    return g
  }
}
