//
//  NDIControls-Audio.swift
//  NDISenderExample
//
//  Created by Cong Nguyen on 21/11/21.
//

import Foundation
import GCDWebServer
import os

extension NDIControls {
  func addWebServerHandlersForAudio() {
    // MARK: - Get current audio output
    self.webServer.addHandler(forMethod: "GET", path: "/audio/outputs/current", request: GCDWebServerRequest.self) { (request) -> GCDWebServerResponse? in
      guard let out = Config.shared.currentOutput else { return GCDWebServerErrorResponse(statusCode: 500) }

      let audioPort = AudioPort(descriptor: out)

      var response: GCDWebServerDataResponse  = GCDWebServerDataResponse(statusCode: 500)
      do {
        let data = try JSONEncoder().encode(audioPort)
        response = GCDWebServerDataResponse(data: data, contentType: "application/json")
      } catch {
        self.logger.error("Cannot serialise JSON. Error: \(error.localizedDescription, privacy: .public)")
        response = GCDWebServerDataResponse(statusCode: 500)
      }
      response.setValue("*", forAdditionalHeader: "Access-Control-Allow-Origin")
      return response
    }
    
    // MARK: - Switch current audio input
    self.webServer.addHandler(forMethod: "POST", path: "/audio/inputs/current", request: GCDWebServerURLEncodedFormRequest.self) { [unowned self] (request) -> GCDWebServerResponse? in
      // GCDWebServerURLEncodedFormRequest expects the body data to be contained in a x-www-form-urlencoded
      let r = request as! GCDWebServerURLEncodedFormRequest
      guard let inputUid = r.arguments["uid"] else { return GCDWebServerDataResponse(statusCode: 400) }

      if delegate == nil {
        logger.error("Delegate is nil. Cannot switch microphones.")
        return GCDWebServerDataResponse(statusCode: 501)
      } else {
        let didSwitch = self.delegate!.switchMicrophone(uniqueID: inputUid)

        var response: GCDWebServerDataResponse
        if didSwitch {
          response = GCDWebServerDataResponse(statusCode: 201)
       } else {
        response = GCDWebServerDataResponse(statusCode: 500)
        }
        response.setValue("*", forAdditionalHeader: "Access-Control-Allow-Origin")
        return response
      }
    }
    
    // MARK: - Get current microphone
    self.webServer.addHandler(forMethod: "GET", path: "/audio/inputs/current", request: GCDWebServerRequest.self) { (request) -> GCDWebServerResponse? in
      guard let mic = Config.shared.currentMicrophone else { return GCDWebServerErrorResponse(statusCode: 500) }

      let audioPort = AudioPort(descriptor: mic)

      var response: GCDWebServerDataResponse  = GCDWebServerDataResponse(statusCode: 500)
      do {
        let data = try JSONEncoder().encode(audioPort)
        response = GCDWebServerDataResponse(data: data, contentType: "application/json")
      } catch {
        self.logger.error("Cannot serialise JSON. Error: \(error.localizedDescription, privacy: .public)")
        response = GCDWebServerDataResponse(statusCode: 500)
      }
      response.setValue("*", forAdditionalHeader: "Access-Control-Allow-Origin")
      return response
    }
    
    // MARK: - Get list of microphones
    self.webServer.addHandler(forMethod: "GET", path: "/audio/inputs", request: GCDWebServerRequest.self) { (request) -> GCDWebServerResponse? in
      
      guard let mics = Config.shared.microphones else { return GCDWebServerErrorResponse(statusCode: 500) }

      var audioPorts: [AudioPort] = []
      for mic in mics {
        audioPorts.append(AudioPort(descriptor: mic))
      }

      var response: GCDWebServerDataResponse  = GCDWebServerDataResponse(statusCode: 500)
      do {
        let data = try JSONEncoder().encode(audioPorts)
        response = GCDWebServerDataResponse(data: data, contentType: "application/json")
      } catch {
        self.logger.error("Cannot serialise JSON. Error: \(error.localizedDescription, privacy: .public)")
        response = GCDWebServerDataResponse(statusCode: 500)
      }
      response.setValue("*", forAdditionalHeader: "Access-Control-Allow-Origin")
      return response
    }
    
    // MARK: - Get list of audio outputs
    self.webServer.addHandler(forMethod: "GET", path: "/audio/outputs", request: GCDWebServerRequest.self) { (request) -> GCDWebServerResponse? in
      guard let outs = Config.shared.audioOutputs else { return GCDWebServerErrorResponse(statusCode: 500) }
      
      var audioPorts: [AudioPort] = []
      for o in outs {
        audioPorts.append(AudioPort(descriptor: o))
      }
      
      var response: GCDWebServerDataResponse  = GCDWebServerDataResponse(statusCode: 500)
      do {
        let data = try JSONEncoder().encode(audioPorts)
        response = GCDWebServerDataResponse(data: data, contentType: "application/json")
      } catch {
        self.logger.error("Cannot serialise JSON. Error: \(error.localizedDescription, privacy: .public)")
        response = GCDWebServerDataResponse(statusCode: 500)
      }
      response.setValue("*", forAdditionalHeader: "Access-Control-Allow-Origin")
      return response
    }
  }
}
