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
  var maxExposureTargetBias_EV: Float = 0
  var currentTargetBias_EV: Float = 0
  var exposureMode: String = ""
  var activeMaxExposureDuration: Float = 0
  var currentExposureDuration: Float = 0
  var isAutoExposureSupported: Bool = false
  var isContinuousExposureSupported: Bool = false
  var isCustomExposureSupported: Bool = false
  var isExposurePointOfInterestSupported: Bool = false
  var exposurePointOfInterest: CGPoint = CGPoint()
}

class Depth: Codable {
  var supportsDepthDataOutput: Bool = false
  var kCVPixelFormatType_DepthFloat16: Bool = false
  var kCVPixelFormatType_DepthFloat32: Bool = false
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

class WhiteBalance: Codable {
  var isAutoWhiteBalanceSupported: Bool = false
  var isLockedWhiteBalanceSupported: Bool = false
  var isContinuousWhiteBalanceSupported: Bool = false
  var currentWhiteBalanceMode: String = ""
  var gain: Float = 0
  var temperature: Float = 0
  var tint: Float = 0
  var minTemp = 3000
  var maxTemp = 8000
  var minTint = -150
  var maxTint = 150
  var currentTemperature: Float = 0
  var currentTint: Float = 0
  var isGreyWhiteBalanceSupported: Bool = false
  var isCustomGainsSupportedInLockedMode: Bool = false
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
  var whiteBalance = WhiteBalance()
  var depth = Depth()
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
    self.exposure.maxExposureTargetBias_EV = camera.maxExposureTargetBias
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
    let currentExposureDuration = Float(CMTimeGetSeconds(AVCaptureDevice.currentExposureDuration))
    self.exposure.currentExposureDuration = currentExposureDuration.isNaN ? -1 : currentExposureDuration
    
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
    
    // MARK: Depth data format
    let depthDataFormats = camera.activeFormat.supportedDepthDataFormats
    if depthDataFormats.count > 0 {
      self.depth.supportsDepthDataOutput = true
      for format in depthDataFormats {
        let desc = CMFormatDescriptionGetMediaSubType(format.formatDescription)
        if desc == kCVPixelFormatType_DepthFloat16 {
          self.depth.kCVPixelFormatType_DepthFloat16 = true
        }
        if desc == kCVPixelFormatType_DepthFloat32 {
          self.depth.kCVPixelFormatType_DepthFloat32 = true
        }
      }
    }
    
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
    
    // MARK: White balance
    self.whiteBalance.currentWhiteBalanceMode = camera.whiteBalanceMode.description
    self.whiteBalance.isAutoWhiteBalanceSupported = camera.isWhiteBalanceModeSupported(.autoWhiteBalance)
    self.whiteBalance.isLockedWhiteBalanceSupported = camera.isWhiteBalanceModeSupported(.locked)
    self.whiteBalance.isContinuousWhiteBalanceSupported = camera.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance)
    self.whiteBalance.isGreyWhiteBalanceSupported = camera.isLockingWhiteBalanceWithCustomDeviceGainsSupported
    self.whiteBalance.isCustomGainsSupportedInLockedMode = camera.isLockingWhiteBalanceWithCustomDeviceGainsSupported
    
    let whiteBalanceGains = camera.deviceWhiteBalanceGains
    let whiteBalanceTemperatureAndTint = camera.temperatureAndTintValues(for: whiteBalanceGains)
    self.whiteBalance.currentTemperature = whiteBalanceTemperatureAndTint.temperature
    self.whiteBalance.currentTint = whiteBalanceTemperatureAndTint.tint
  }
  
  static func getTemperature(device: AVCaptureDevice) -> Float {
    let whiteBalanceGains = device.deviceWhiteBalanceGains
    let whiteBalanceTemperatureAndTint = device.temperatureAndTintValues(for: whiteBalanceGains)
    return whiteBalanceTemperatureAndTint.temperature
  }
  
  static func getTint(device: AVCaptureDevice) -> Float {
    let whiteBalanceGains = device.deviceWhiteBalanceGains
    let whiteBalanceTemperatureAndTint = device.temperatureAndTintValues(for: whiteBalanceGains)
    return whiteBalanceTemperatureAndTint.tint
  }
}

extension AVCaptureDevice.WhiteBalanceMode: CustomStringConvertible {
  public var description: String {
    var string: String
    
    switch self {
    case .locked:
      string = "Locked"
    case .autoWhiteBalance:
      string = "Auto"
    case .continuousAutoWhiteBalance:
      string = "ContinuousAuto"
    @unknown default:
      string = "unknown value"
    }
    
    return string
  }
}
