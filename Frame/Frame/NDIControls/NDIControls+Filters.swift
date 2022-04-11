//
//  NDIControls+Recorder.swift
//  NDISenderExample
//
//  Created by Cong Nguyen on 12/4/2022.
//

import Foundation
import GCDWebServer

extension NDIControls {
  func addWebServerHandlersForFilters() {
    // MARK: - Configure bokeh
    self.webServer.addHandler(forMethod: "POST", pathRegex: "/filters/bokeh", request: GCDWebServerURLEncodedFormRequest.self) { [unowned self] (request) -> GCDWebServerResponse? in
      let r = request as! GCDWebServerURLEncodedFormRequest
      
      guard let radius = Float(r.arguments["radius"] ?? "invalidNumber") else { return GCDWebServerDataResponse(statusCode: 400) }
      guard let brightness = Float(r.arguments["brightness"] ?? "invalidNumber") else { return GCDWebServerDataResponse(statusCode: 400) }
      
      if self.delegate == nil {
        self.logger.error("Delegate is nil. Cannot update bokeh")
        return GCDWebServerDataResponse(statusCode: 501)
      } else {
        self.delegate!.configureBokeh(radius: radius, brightness: brightness)
        
        let response = GCDWebServerDataResponse(statusCode: 201)
        response.setValue("*", forAdditionalHeader: "Access-Control-Allow-Origin")
        
        return response
      }
    }
  }
}
