//
//  NDIControls+NDI.swift
//  NDISenderExample
//
//  Created by Cong Nguyen on 21/11/21.
//

import Foundation
import GCDWebServer

extension NDIControls {
  func addWebServerHandlersForNDI() {
    // MARK: - Get NDI status
    webServer.addHandler(forMethod: "GET", path: "/ndi/status", request: GCDWebServerRequest.self) { [unowned self] (request) -> GCDWebServerResponse? in
      
      let status: [String: Bool] = ["started": self.isSending]
      
      var response: GCDWebServerDataResponse
      do {
        let data = try JSONEncoder().encode(status)
        response = GCDWebServerDataResponse(data: data, contentType: "application/json")
      } catch {
        self.logger.error("Cannot serialise JSON. Error: \(error.localizedDescription, privacy: .public)")
        response = GCDWebServerDataResponse(statusCode: 500)
      }
      response.setValue("*", forAdditionalHeader: "Access-Control-Allow-Origin")
      return response
    }
    
    // MARK: - ndi control
    webServer.addHandler(forMethod: "GET", pathRegex: "/ndi/start", request: GCDWebServerRequest.self) { [unowned self] (request) -> GCDWebServerResponse? in
      if self.delegate == nil {
        return GCDWebServerDataResponse(statusCode: 501)
      }
      
      var response: GCDWebServerDataResponse
      self.delegate!.startNDI()
      response = GCDWebServerDataResponse(statusCode: 200)
      response.setValue("*", forAdditionalHeader: "Access-Control-Allow-Origin")
      return response
    }
    
    webServer.addHandler(forMethod: "GET", pathRegex: "/ndi/stop", request: GCDWebServerRequest.self) { [unowned self] (request) -> GCDWebServerResponse? in
      if self.delegate == nil {
        return GCDWebServerDataResponse(statusCode: 501)
      }
      
      var response: GCDWebServerDataResponse
      self.delegate!.stopNDI()
      response = GCDWebServerDataResponse(statusCode: 200)
      response.setValue("*", forAdditionalHeader: "Access-Control-Allow-Origin")
      return response
    }
  }
}
