//
//  NDIControls+Camera.swift
//  NDISenderExample
//
//  Created by Cong Nguyen on 21/11/21.
//

import Foundation
import GCDWebServer

extension NDIControls {
  func addWebServerHandlersForCamera() {
    // MARK: - Get cameras JSON
    self.webServer.addHandler(forMethod: "GET", path: "/cameras", request: GCDWebServerRequest.self) { (request) -> GCDWebServerResponse? in
      guard let cameras = Config.shared.cameras else { return GCDWebServerErrorResponse(statusCode: 500) }
      var cameraObjects: [CameraInformation] = []
      for camera in cameras {
        cameraObjects.append(CameraInformation(camera: camera))
      }
      
      var response: GCDWebServerDataResponse
      do {
        let data = try JSONEncoder().encode(cameraObjects)
        response = GCDWebServerDataResponse(data: data, contentType: "application/json")
      } catch {
        self.logger.error("Cannot serialise JSON. Error: \(error.localizedDescription, privacy: .public)")
        response = GCDWebServerDataResponse(statusCode: 500)
      }
      response.setValue("*", forAdditionalHeader: "Access-Control-Allow-Origin")
      return response
    }
    
    // MARK: - Get active camera
    self.webServer.addHandler(forMethod: "GET", path: "/cameras/active", request: GCDWebServerRequest.self) { [unowned self] (request) -> GCDWebServerResponse? in
      if delegate == nil {
        return GCDWebServerDataResponse(statusCode: 501)
      }
      guard let camera = self.delegate!.getCurrentCamera() else {
        return GCDWebServerDataResponse(statusCode: 501)
      }
      
      var response: GCDWebServerDataResponse
      do {
        let data = try JSONEncoder().encode(camera)
        response = GCDWebServerDataResponse(data: data, contentType: "application/json")
      } catch {
        self.logger.error("Cannot serialise JSON. Error: \(error.localizedDescription, privacy: .public)")
        response = GCDWebServerDataResponse(statusCode: 500)
      }
      response.setValue("*", forAdditionalHeader: "Access-Control-Allow-Origin")
      return response
    }
    
    // MARK: - Switch camera
    self.webServer.addHandler(forMethod: "POST", path: "/cameras/select", request: GCDWebServerURLEncodedFormRequest.self) { [unowned self] (request) -> GCDWebServerResponse? in
      // GCDWebServerURLEncodedFormRequest expects the body data to be contained in a x-www-form-urlencoded
      let r = request as! GCDWebServerURLEncodedFormRequest
      guard let cameraUniqueID = r.arguments["uniqueID"] else { return GCDWebServerDataResponse(statusCode: 400) }
      
      if delegate == nil {
        return GCDWebServerDataResponse(statusCode: 501)
      } else {
        let hasCameraSwitched = self.delegate!.switchCamera(uniqueID: cameraUniqueID)
        
        var response: GCDWebServerDataResponse
        if hasCameraSwitched {
          response = GCDWebServerDataResponse(statusCode: 200)
       } else {
        response = GCDWebServerDataResponse(statusCode: 500)
        }
        response.setValue("*", forAdditionalHeader: "Access-Control-Allow-Origin")
        return response
      }
    }
    
    // MARK: - Zoom camera
    self.webServer.addHandler(forMethod: "POST", pathRegex: "/camera/zoom", request: GCDWebServerURLEncodedFormRequest.self) { [unowned self] (request) -> GCDWebServerResponse? in
      let r = request as! GCDWebServerURLEncodedFormRequest
      guard let zoomFactor = r.arguments["zoomFactor"] else { return GCDWebServerDataResponse(statusCode: 400) }
      
      if self.delegate == nil {
        return GCDWebServerDataResponse(statusCode: 501)
      }
      
      guard let zf = Float(zoomFactor) else { return GCDWebServerDataResponse(statusCode: 400) }
      
      var response: GCDWebServerDataResponse
      if self.delegate!.zoom(factor: zf) {
        response = GCDWebServerDataResponse(statusCode: 200)
      } else {
        response = GCDWebServerDataResponse(statusCode: 500)
      }
      response.setValue("*", forAdditionalHeader: "Access-Control-Allow-Origin")
      return response
    }
    
    // MARK: - Exposure bias adjustment
    self.webServer.addHandler(forMethod: "POST", pathRegex: "/camera/exposure/bias", request: GCDWebServerURLEncodedFormRequest.self) { [unowned self] (request) -> GCDWebServerResponse? in
      let r = request as! GCDWebServerURLEncodedFormRequest
      guard let bias = Float(r.arguments["bias"] ?? "invalidNumber") else {
        return GCDWebServerDataResponse(statusCode: 400)
      }
      
      if self.delegate == nil {
        return GCDWebServerDataResponse(statusCode: 501)
      }
      
      var response: GCDWebServerDataResponse
      if self.delegate!.setExposureCompensation(bias: bias)  {
        response = GCDWebServerDataResponse(statusCode: 200)
      } else {
        response = GCDWebServerDataResponse(statusCode: 500)
      }
      response.setValue("*", forAdditionalHeader: "Access-Control-Allow-Origin")
      return response
    }
    
    // MARK: - White balance
    self.webServer.addHandler(forMethod: "GET", pathRegex: "/camera/white-balance/mode/auto", request: GCDWebServerRequest.self) { [unowned self] (request) -> GCDWebServerResponse? in
      if self.delegate == nil {
        return GCDWebServerDataResponse(statusCode: 501)
      }
      
      var response: GCDWebServerDataResponse
      if self.delegate!.setWhiteBalanceMode(mode: .continuousAutoWhiteBalance) {
        response = GCDWebServerDataResponse(statusCode: 200)
      } else {
        response = GCDWebServerDataResponse(statusCode: 500)
      }
      response.setValue("*", forAdditionalHeader: "Access-Control-Allow-Origin")
      return response
    }
    
    self.webServer.addHandler(forMethod: "GET", pathRegex: "/camera/white-balance/mode/locked", request: GCDWebServerRequest.self) { [unowned self] (request) -> GCDWebServerResponse? in
      if self.delegate == nil {
        return GCDWebServerDataResponse(statusCode: 501)
      }
      
      var response: GCDWebServerDataResponse
      if self.delegate!.setWhiteBalanceMode(mode: .locked) {
        response = GCDWebServerDataResponse(statusCode: 200)
      } else {
        response = GCDWebServerDataResponse(statusCode: 500)
      }
      response.setValue("*", forAdditionalHeader: "Access-Control-Allow-Origin")
      return response
    }
    
    self.webServer.addHandler(forMethod: "GET", pathRegex: "/camera/white-balance/temp-tint", request: GCDWebServerRequest.self) { [unowned self] (request) -> GCDWebServerResponse? in
      if self.delegate == nil {
        return GCDWebServerDataResponse(statusCode: 501)
      }
      
      let respData: [String: Float] = [
        "temperature": self.delegate!.getWhiteBalanceTemp(),
        "tint": self.delegate!.getWhiteBalanceTint()
      ]
      
      var response: GCDWebServerDataResponse
      do {
        let json = try JSONEncoder().encode(respData)
        response = GCDWebServerDataResponse(data: json, contentType: "application/json")
      } catch {
        self.logger.error("Cannot convert temp-tint to JSON")
        response = GCDWebServerDataResponse(statusCode: 500)
      }
      response.setValue("*", forAdditionalHeader: "Access-Control-Allow-Origin")
      return response
    }
    
    self.webServer.addHandler(forMethod: "POST", pathRegex: "/camera/white-balance/temp-tint", request: GCDWebServerURLEncodedFormRequest.self) { [unowned self] (request) -> GCDWebServerResponse? in
      let r = request as! GCDWebServerURLEncodedFormRequest
      guard let temp = Float(r.arguments["temperature"] ?? "invalidNumber"),
            let tint = Float(r.arguments["tint"] ?? "invalidNumber")
      else {
        return GCDWebServerDataResponse(statusCode: 400)
      }
      
      if self.delegate == nil {
        return GCDWebServerDataResponse(statusCode: 501)
      }
      
      var response: GCDWebServerDataResponse
      if self.delegate!.setTemperatureAndTint(temperature: temp, tint: tint) {
        response = GCDWebServerDataResponse(statusCode: 200)
      } else {
        response = GCDWebServerDataResponse(statusCode: 500)
      }
      response.setValue("*", forAdditionalHeader: "Access-Control-Allow-Origin")
      return response
    }
    
    self.webServer.addHandler(forMethod: "GET", pathRegex: "/camera/white-balance/grey", request: GCDWebServerRequest.self) { [unowned self] (request) -> GCDWebServerResponse? in
      if self.delegate == nil {
        return GCDWebServerDataResponse(statusCode: 501)
      }
      
      var response: GCDWebServerDataResponse
      if self.delegate!.lockGrey() {
        response = GCDWebServerDataResponse(statusCode: 200)
      } else {
        response = GCDWebServerDataResponse(statusCode: 500)
      }
      response.setValue("*", forAdditionalHeader: "Access-Control-Allow-Origin")
      return response
    }
        
    // MARK: - Focus
    self.webServer.addHandler(forMethod: "POST", pathRegex: "/camera/focus", request: GCDWebServerURLEncodedFormRequest.self) { [unowned self] (request) -> GCDWebServerResponse? in
      let r = request as! GCDWebServerURLEncodedFormRequest
      guard let x = Double(r.arguments["x"] ?? "invalidNumber"),
            let y = Double(r.arguments["y"] ?? "invalidNumber")
      else {
        return GCDWebServerDataResponse(statusCode: 400)
      }
      
      if self.delegate == nil {
        return GCDWebServerDataResponse(statusCode: 501)
      }
      
      var response: GCDWebServerDataResponse
      if self.delegate!.highlightPointOfInterest(pointOfInterest: CGPoint(x: x, y: y)) {
        response = GCDWebServerDataResponse(statusCode: 200)
      } else {
        response = GCDWebServerDataResponse(statusCode: 500)
      }
      response.setValue("*", forAdditionalHeader: "Access-Control-Allow-Origin")
      return response
    }
    
    // MARK: - swtich session preset
    self.webServer.addHandler(forMethod: "GET", pathRegex: "/preset/1080p", request: GCDWebServerRequest.self) { [unowned self] (request) -> GCDWebServerResponse? in
      if self.delegate == nil {
        return GCDWebServerDataResponse(statusCode: 501)
      }
      
      var response: GCDWebServerDataResponse
      if self.delegate!.setPreset1080() {
        response = GCDWebServerDataResponse(statusCode: 200)
      } else {
        response = GCDWebServerDataResponse(statusCode: 500)
      }
      response = GCDWebServerDataResponse(statusCode: 200)
      response.setValue("*", forAdditionalHeader: "Access-Control-Allow-Origin")
      return response
    }
    
    self.webServer.addHandler(forMethod: "GET", pathRegex: "/preset/720p", request: GCDWebServerRequest.self) { [unowned self] (request) -> GCDWebServerResponse? in
      if self.delegate == nil {
        return GCDWebServerDataResponse(statusCode: 501)
      }
      
      var response: GCDWebServerDataResponse
      if self.delegate!.setPreset720() {
        response = GCDWebServerDataResponse(statusCode: 200)
      } else {
        response = GCDWebServerDataResponse(statusCode: 500)
      }
      response = GCDWebServerDataResponse(statusCode: 200)
      response.setValue("*", forAdditionalHeader: "Access-Control-Allow-Origin")
      return response
    }
    
    self.webServer.addHandler(forMethod: "GET", pathRegex: "/preset/4K", request: GCDWebServerRequest.self) { [unowned self] (request) -> GCDWebServerResponse? in
      if self.delegate == nil {
        return GCDWebServerDataResponse(statusCode: 501)
      }
      
      var response: GCDWebServerDataResponse
      if self.delegate!.setPreset4K() {
        response = GCDWebServerDataResponse(statusCode: 200)
      } else {
        response = GCDWebServerDataResponse(statusCode: 500)
      }
      response = GCDWebServerDataResponse(statusCode: 200)
      response.setValue("*", forAdditionalHeader: "Access-Control-Allow-Origin")
      return response
    }
  }
}
