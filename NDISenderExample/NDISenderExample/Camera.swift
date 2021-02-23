//
//  Camera.swift
//  NDISenderExample
//
//  Created by Cong Nguyen on 21/2/21.
//

import AVFoundation

class DeviceProperties: Codable {
  var uniqueID: String = ""
  var modelID: String = ""
  var localizedName: String = ""
  var lensAperture: Float = 0
  var supports1080p: Bool = false
  var supports720p: Bool = false
  var supports4K: Bool = false
}

class Exposure: Codable {
  var exposureTargetOffset: Float = 0
  var minExposureTargetBias_EV: Float = 0
  var maxExposeTargetBias_EV: Float = 0
  var currentTargetBias_EV: Float = 0
  var exposureMode: String = ""
  var activeMaxExposureDuration: Float = 0
//  var currentExposureDuration: Float = 0
  var isAutoExposureSupported: Bool = false
  var isContinuousExposureSupported: Bool = false
  var isCustomExposureSupported: Bool = false
  var isExposurePointOfInterestSupported: Bool = false
  var exposurePointOfInterest: CGPoint = CGPoint()
}

class Zoom: Codable {
  var videoZoomFactor: Float = 0
  var minAvailableZoomFactor: Float = 0
  var maxAvailableZoomFactor: Float = 0
}

class AutoFocus: Codable {
  var isAutoFocusSupported: Bool = false
  var isContinuousAutoFocusSupported: Bool = false
  var focusPointOfInterest: CGPoint = CGPoint()
  var isFocusPointOfInterestSupported: Bool = false
  var isSmoothAutoFocusSupported: Bool = false
  var isSmoothAutoFocusEnabled: Bool = false
  var isAutoFocusRangeRestrictionSupported: Bool = false
}

class Flash: Codable {
  var hasFlash: Bool = false
}

class Torch: Codable {
  var hasTorch: Bool = false
}

class LowLight: Codable {
  var isLowLightBoostSupported: Bool = false
  var isLowLightBoostEnabled: Bool = false
}

class ISO: Codable {
  var minISO: Float = 0
  var maxISO: Float = 0
  var currentISO: Float = 0
}

class Camera: Codable {
  var properties = DeviceProperties()
  var exposure = Exposure()
  var zoom = Zoom()
  var autoFocus = AutoFocus()
  var flash = Flash()
  var torch = Torch()
  var lowLight = LowLight()
  
  var iso = ISO()
  //   TODO: White balance
//   TODO: HDR
//   TODO: Tone mapping

  init(camera: AVCaptureDevice) {
    
    // MARK: Device characteristics
    self.properties.uniqueID = camera.uniqueID
    self.properties.modelID = camera.modelID
    self.properties.localizedName = camera.localizedName
    self.properties.lensAperture = camera.lensAperture
    self.properties.supports1080p = camera.supportsSessionPreset(.hd1920x1080)
    self.properties.supports720p = camera.supportsSessionPreset(.hd1280x720)
    self.properties.supports4K = camera.supportsSessionPreset(.hd4K3840x2160)
    
    // MARK: Exposure
    self.exposure.minExposureTargetBias_EV = camera.minExposureTargetBias
    self.exposure.maxExposeTargetBias_EV = camera.maxExposureTargetBias
    self.exposure.currentTargetBias_EV = camera.exposureTargetBias
    switch camera.exposureMode {
    case .autoExpose:
      self.exposure.exposureMode = "auto expose"
    case .continuousAutoExposure:
      self.exposure.exposureMode = "continuous auto exposure"
    case .custom:
      self.exposure.exposureMode = "custom, need iso and exposure duration"
    case .locked:
      self.exposure.exposureMode = "locked"
    default:
      self.exposure.exposureMode = "unknown setting"
    }
    self.exposure.exposureTargetOffset = camera.exposureTargetOffset
    self.exposure.activeMaxExposureDuration = Float(CMTimeGetSeconds(camera.activeMaxExposureDuration))
//    self.exposure.currentExposureDuration = Float(CMTimeGetSeconds(AVCaptureDevice.currentExposureDuration))
    self.exposure.isAutoExposureSupported = camera.isExposureModeSupported(.autoExpose)
    self.exposure.isContinuousExposureSupported = camera.isExposureModeSupported(.continuousAutoExposure)
    self.exposure.isCustomExposureSupported = camera.isExposureModeSupported(.custom)
    self.exposure.isExposurePointOfInterestSupported = camera.isExposurePointOfInterestSupported
    self.exposure.exposurePointOfInterest = camera.exposurePointOfInterest
    
    // MARK: Zoom
    self.zoom.videoZoomFactor = Float(camera.videoZoomFactor)
    self.zoom.minAvailableZoomFactor = Float(camera.minAvailableVideoZoomFactor)
    self.zoom.maxAvailableZoomFactor = Float(camera.maxAvailableVideoZoomFactor)
    
    // MARK: Auto focus
    self.autoFocus.isAutoFocusSupported = camera.isFocusModeSupported(.autoFocus)
    self.autoFocus.isContinuousAutoFocusSupported = camera.isFocusModeSupported(.continuousAutoFocus)
    self.autoFocus.focusPointOfInterest = camera.focusPointOfInterest
    self.autoFocus.isFocusPointOfInterestSupported = camera.isFocusPointOfInterestSupported
    self.autoFocus.isSmoothAutoFocusSupported = camera.isSmoothAutoFocusSupported
    self.autoFocus.isSmoothAutoFocusEnabled = camera.isSmoothAutoFocusEnabled
    self.autoFocus.isAutoFocusRangeRestrictionSupported = camera.isAutoFocusRangeRestrictionSupported
    
    // MARK: Flash
    self.flash.hasFlash = camera.hasFlash
    
    // MARK: Torch
    self.torch.hasTorch = camera.hasTorch
    
    // MARK: Low light
    self.lowLight.isLowLightBoostSupported = camera.isLowLightBoostSupported
    self.lowLight.isLowLightBoostEnabled = camera.isLowLightBoostEnabled
    
    // MARK: ISO
    self.iso.minISO = camera.activeFormat.minISO
    self.iso.maxISO = camera.activeFormat.maxISO
    self.iso.currentISO = AVCaptureDevice.currentISO
  }
}
