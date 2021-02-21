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
  
  private init() {
  }
}

extension Notification.Name {
  static let ndiWebServerDidStart = Notification.Name("ndiWebServerDidStart")
  static let cameraDiscoveryCompleted = Notification.Name("cameraDiscoveryCompleted")
  static let cameraSetupCompleted = Notification.Name("cameraSetupCompleted")
}
