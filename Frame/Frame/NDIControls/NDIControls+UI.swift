//
//  NDIControls+UI.swift
//  NDISenderExample
//
//  Created by Cong Nguyen on 21/11/21.
//

import Foundation
import GCDWebServer

extension NDIControls {
  func addWebServerHandlersForUI() {
    // MARK: - on-screen controls
    self.webServer.addHandler(forMethod: "GET", pathRegex: "/controls/hide", request: GCDWebServerRequest.self) { [unowned self] (request) -> GCDWebServerResponse? in
      if self.delegate == nil {
        return GCDWebServerDataResponse(statusCode: 501)
      }
      
      var response: GCDWebServerDataResponse
      if self.delegate!.hideControls() {
        response = GCDWebServerDataResponse(statusCode: 200)
      } else {
        response = GCDWebServerDataResponse(statusCode: 500)
      }
      response.setValue("*", forAdditionalHeader: "Access-Control-Allow-Origin")
      return response
    }
    
    self.webServer.addHandler(forMethod: "GET", pathRegex: "/controls/show", request: GCDWebServerRequest.self) { [unowned self] (request) -> GCDWebServerResponse? in
      if self.delegate == nil {
        return GCDWebServerDataResponse(statusCode: 501)
      }
      
      var response: GCDWebServerDataResponse
      if self.delegate!.showControls() {
        response = GCDWebServerDataResponse(statusCode: 200)
      } else {
        response = GCDWebServerDataResponse(statusCode: 500)
      }
      response.setValue("*", forAdditionalHeader: "Access-Control-Allow-Origin")
      return response
    }
  }
}
