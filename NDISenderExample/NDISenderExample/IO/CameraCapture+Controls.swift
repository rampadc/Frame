//
//  CameraCapture-Controls.swift
//  NDISenderExample
//
//  Created by Cong Nguyen on 6/4/2022.
//

import Foundation


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
      self.logger.error("Cannot change cameras")
      self.logger.error("\(error.localizedDescription, privacy: .public)")
      return false
    }
  }
  
  func getCurrentCamera() -> CameraInformation? {
    guard let device = self.currentDevice else { return nil }
    return CameraInformation(camera: device)
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
      self.logger.error("Cannot zoom. Error: \(error.localizedDescription, privacy: .public)")
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
      self.logger.error("Cannot set custom exposure time and iso. Error: \(error.localizedDescription, privacy: .public)")
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
        self.logger.error("White balance mode \(mode.description, privacy: .public) is not supported. White balance mode is \(device.whiteBalanceMode.description, privacy: .public).")
        device.unlockForConfiguration()
        return false
      }
    } catch let error {
      self.logger.error("Cannot set white balance mode. Error: \(error.localizedDescription, privacy: .public)")
      return false
    }
  }
  
  func setTemperatureAndTint(temperature: Float, tint: Float) -> Bool {
    guard let device = self.currentDevice else { return false }
    if device.whiteBalanceMode != .locked {
      return false
    }
    
    if !device.isLockingWhiteBalanceWithCustomDeviceGainsSupported {
      self.logger.error("Device does not support white balance locking with custom gains")
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
    
    if device.isLockingWhiteBalanceWithCustomDeviceGainsSupported {
      self.logger.info("White balance with grey locking is supported. Setting to grey white-balance mode.")
      self.setWhiteBalanceGains(device.grayWorldDeviceWhiteBalanceGains)
      return true
    } else {
      self.logger.error("White balance with grey locking is not supported")
      return false
    }
  }
  
  func highlightPointOfInterest(pointOfInterest: CGPoint) -> Bool {
    guard let device = self.currentDevice else { return false }
    
    if device.isFocusPointOfInterestSupported || device.isExposurePointOfInterestSupported {
      self.logger.info("Point of interest focus/exposure is supported.")
      do {
        try device.lockForConfiguration()
        if device.isFocusPointOfInterestSupported {
          device.focusPointOfInterest = pointOfInterest
          device.focusMode = .continuousAutoFocus
          self.logger.info("Point-of-interest focus mode is enabled with continuous auto-focus.")
        }
        if device.isExposurePointOfInterestSupported {
          device.exposurePointOfInterest = pointOfInterest
          device.exposureMode = .continuousAutoExposure
          self.logger.info("Point-of-interest exposure mode is enabled with continuous auto-exposure.")
        }
        device.unlockForConfiguration()
        return true
      } catch let error {
        self.logger.error("Cannot activate point of interest with auto-focus and auto-exposure. Error: \(error.localizedDescription, privacy: .public)")
        return false
      }
    } else {
      self.logger.info("Point of interest focus/exposure is not supported.")
      return false
    }
  }
  
  func getTemperature() -> Float {
    guard let device = self.currentDevice else { return -1 }
    return CameraInformation.getTemperature(device: device)
  }
  
  func getTint() -> Float {
    guard let device = self.currentDevice else { return -1 }
    return CameraInformation.getTint(device: device)
  }
  
  func setActiveDepthDataFormat(format: String) -> Bool {
    guard let device = self.currentDevice else { return false }
    
    let depthFormats = device.activeFormat.supportedDepthDataFormats
    
    var supportedFormat: [AVCaptureDevice.Format] = []
    if format == "kCVPixelFormatType_DepthFloat16" {
      supportedFormat = depthFormats.filter({
        CMFormatDescriptionGetMediaSubType($0.formatDescription) == kCVPixelFormatType_DepthFloat16
      })
    } else if format == "kCVPixelFormatType_DepthFloat32" {
      supportedFormat = depthFormats.filter({
        CMFormatDescriptionGetMediaSubType($0.formatDescription) == kCVPixelFormatType_DepthFloat32
      })
    }
    
    if supportedFormat.isEmpty {
      self.logger.info("Device does not support the chosen depth data format: \(format, privacy: .public)")
      return false
    }
    
    let selectedFormat = supportedFormat.max(
      by: { first, second in
        CMVideoFormatDescriptionGetDimensions(first.formatDescription).width <
          CMVideoFormatDescriptionGetDimensions(second.formatDescription).width })
    do {
      try device.lockForConfiguration()
      device.activeDepthDataFormat = selectedFormat
      device.unlockForConfiguration()
      self.logger.info("Enabled depth data format")
      return true
    } catch {
      self.logger.error("Cannot enable depth data format. Error: \(error.localizedDescription, privacy: .public)")
      return false
    }
  }
  
  func setPreset(preset: AVCaptureSession.Preset) -> Bool {
    if session.canSetSessionPreset(preset) {
      session.sessionPreset = preset
      return true
    } else {
      return false
    }
  }
  
  // MARK: Private functions
  private func setWhiteBalanceGains(_ gains: AVCaptureDevice.WhiteBalanceGains) {
    guard let device = self.currentDevice else { return }
    do {
      try device.lockForConfiguration()
      let normalizedGains = self.normalizedGains(gains) // Conversion can yield out-of-bound values, cap to limits
      device.setWhiteBalanceModeLocked(with: normalizedGains, completionHandler: nil)
      device.unlockForConfiguration()
    } catch let error {
      self.logger.error("Cannot set white balance gains. Error: \(error.localizedDescription, privacy: .public)")
    }
  }
  
  private func normalizedGains(_ gains: AVCaptureDevice.WhiteBalanceGains) -> AVCaptureDevice.WhiteBalanceGains {
    if self.currentDevice == nil {
      self.logger.error("No camera active. Cannot normalise gains")
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
