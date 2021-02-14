//
//  WebServer.swift
//  NDISenderExample
//
//  Created by Cong Nguyen on 11/2/21.
//

import Foundation
import GCDWebServer

class NDIControls {
  static let webServer = GCDWebServer()
  static func startWebServer() {
    webServer.addDefaultHandler(forMethod: "GET", request: GCDWebServerRequest.self, processBlock: {request in
      return GCDWebServerDataResponse(html:"<html><body><p>Hello World</p></body></html>")
    })
    webServer.start(withPort: 8080, bonjourName: UIDevice.current.name)
  }
}
