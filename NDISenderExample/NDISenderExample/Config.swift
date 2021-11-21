//
//  Config.swift
//  NDISenderExample
//
//  Created by Cong Nguyen on 21/2/21.
//

import Foundation
import CoreImage

class Config {
  static var shared = Config()
  var ciContext: CIContext?
  var cameras: [AVCaptureDevice]?
  var bufferPool: CVPixelBufferPool?
  var microphones: [AVAudioSessionPortDescription]?
  var audioOutputs: [AVAudioSessionPortDescription]?
  var currentMicrophone: AVAudioSessionPortDescription?
  var currentOutput: AVAudioSessionPortDescription?
  var amplitude: Float?
  
  private init() {}
}

extension Notification.Name {
  static let ndiWebServerDidStart = Notification.Name("ndiWebServerDidStart")
  static let cameraDiscoveryCompleted = Notification.Name("cameraDiscoveryCompleted")
  static let cameraSetupCompleted = Notification.Name("cameraSetupCompleted")
  static let microphoneDiscoveryCompleted = Notification.Name("microphoneDiscoveryCompleted")
  static let microphoneDidSwitch = Notification.Name("microphoneDidSwitch")
  static let audioOutputsDiscoveryCompleted = Notification.Name("audioOutputsDiscoveryCompleted")
}
