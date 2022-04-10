//
//  Config.swift
//  NDISenderExample
//
//  Created by Cong Nguyen on 21/2/21.
//

import Foundation
import CoreImage
import MetalPetal

class Config {
  static var shared = Config()
  var context: MTIContext?
  var cameras: [AVCaptureDevice]?
  var microphones: [AVAudioSessionPortDescription]?
  var audioOutputs: [AVAudioSessionPortDescription]?
  var currentMicrophone: AVAudioSessionPortDescription?
  var currentOutput: AVAudioSessionPortDescription?
  var amplitude: Float?
  
  var chromaKeyEnabled = false
  
  let subsystem = "rampadc.ndisender"
  let recordingDirectory = FileManager.default.temporaryDirectory
  private init() {}
}

extension Notification.Name {
  static let ndiWebServerDidStart = Notification.Name("ndiWebServerDidStart")
  static let cameraDiscoveryCompleted = Notification.Name("cameraDiscoveryCompleted")
  static let cameraSetupCompleted = Notification.Name("cameraSetupCompleted")
  static let microphoneDiscoveryCompleted = Notification.Name("microphoneDiscoveryCompleted")
  static let microphoneDidSwitch = Notification.Name("microphoneDidSwitch")
  static let audioOutputsDiscoveryCompleted = Notification.Name("audioOutputsDiscoveryCompleted")
  static let cameraDidStartRunning = Notification.Name("cameraDidStartRunning")
  static let cameraDidStopRunning = Notification.Name("cameraDidStopRunning")
}
