//
//  Camera.swift
//  NDISenderExample
//
//  Created by Cong Nguyen on 21/2/21.
//

import AVFoundation

class Camera: Codable {
  
  var uniqueID: String
  var modelID: String
  var lensAperture: Float
  var supports1080p: Bool
  var supports720p: Bool
  var supports4K: Bool
  var exposureTargetOffset: Float
  var minExposureTargetBias_EV: Float
  var maxExposeTargetBias_EV: Float
  var currentTargetBias_EV: Float
  var exposureMode: String
  var activeMaxExposureDuration: Float
  var currentExposureDuration: Float
  var isAutoExposureSupported: Bool
  var isContinuousExposureSupported: Bool
  var isCustomExposureSupported: Bool
  var isExposurePointOfInterestSupported: Bool
  var exposurePointOfInterest: CGPoint
  var videoZoomFactor: Float
  var minAvailableZoomFactor: Float
  var maxAvailableZoomFactor: Float
  var isAutoFocusSupported: Bool
  var isContinuousAutoFocusSupported: Bool
  var focusPointOfInterest: CGPoint
  var isFocusPointOfInterestSupported: Bool
  var isSmoothAutoFocusSupported: Bool
  var isSmoothAutoFocusEnabled: Bool
  var isAutoFocusRangeRestrictionSupported: Bool
  var hasFlash: Bool
  var hasTorch: Bool
  var isLowLightBoostSupported: Bool
  var isLowLightBoostEnabled: Bool
  
  // TODO: White balance
  // TODO: ISO
  // TODO: HDR
  // TODO: Tone mapping

  init(camera: AVCaptureDevice) {
    
    // MARK: Device characteristics
    uniqueID = camera.uniqueID
    modelID = camera.modelID
    lensAperture = camera.lensAperture
    supports1080p = camera.supportsSessionPreset(.hd1920x1080)
    supports720p = camera.supportsSessionPreset(.hd1280x720)
    supports4K = camera.supportsSessionPreset(.hd4K3840x2160)
    
    // MARK: Exposure
    minExposureTargetBias_EV = camera.minExposureTargetBias
    maxExposeTargetBias_EV = camera.maxExposureTargetBias
    currentTargetBias_EV = camera.exposureTargetBias
    switch camera.exposureMode {
    case .autoExpose:
      exposureMode = "auto expose"
    case .continuousAutoExposure:
      exposureMode = "continuous auto exposure"
    case .custom:
      exposureMode = "custom, need iso and exposure duration"
    case .locked:
      exposureMode = "locked"
    default:
      exposureMode = "unknown setting"
    }
    exposureTargetOffset = camera.exposureTargetOffset
    activeMaxExposureDuration = Float(CMTimeGetSeconds(camera.activeMaxExposureDuration))
    currentExposureDuration = Float(CMTimeGetSeconds(AVCaptureDevice.currentExposureDuration))
    isAutoExposureSupported = camera.isExposureModeSupported(.autoExpose)
    isContinuousExposureSupported = camera.isExposureModeSupported(.continuousAutoExposure)
    isCustomExposureSupported = camera.isExposureModeSupported(.custom)
    isExposurePointOfInterestSupported = camera.isExposurePointOfInterestSupported
    exposurePointOfInterest = camera.exposurePointOfInterest
    
    // MARK: Zoom
    videoZoomFactor = Float(camera.videoZoomFactor)
    minAvailableZoomFactor = Float(camera.minAvailableVideoZoomFactor)
    maxAvailableZoomFactor = Float(camera.maxAvailableVideoZoomFactor)
    
    // MARK: Auto focus
    isAutoFocusSupported = camera.isFocusModeSupported(.autoFocus)
    isContinuousAutoFocusSupported = camera.isFocusModeSupported(.continuousAutoFocus)
    focusPointOfInterest = camera.focusPointOfInterest
    isFocusPointOfInterestSupported = camera.isFocusPointOfInterestSupported
    isSmoothAutoFocusSupported = camera.isSmoothAutoFocusSupported
    isSmoothAutoFocusEnabled = camera.isSmoothAutoFocusEnabled
    isAutoFocusRangeRestrictionSupported = camera.isAutoFocusRangeRestrictionSupported
    
    // MARK: Flash
    hasFlash = camera.hasFlash
    
    // MARK: Torch
    hasTorch = camera.hasTorch
    
    // MARK: Low light
    isLowLightBoostSupported = camera.isLowLightBoostSupported
    isLowLightBoostEnabled = camera.isLowLightBoostEnabled
  }
}
