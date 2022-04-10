//
//  NDIControls+Recorder.swift
//  NDISenderExample
//
//  Created by Cong Nguyen on 10/4/2022.
//

import Foundation
import GCDWebServer

extension NDIControls {
  struct RecordingUrl: Codable {
    var absoluteUrl: String
  }
  
  func addWebServerHandlersForRecorder() {
    // MARK: - Start recording
    self.webServer.addHandler(forMethod: "GET", path: "/recording/start", request: GCDWebServerRequest.self) { (request) -> GCDWebServerResponse? in
      var response: GCDWebServerDataResponse  = GCDWebServerDataResponse(statusCode: 500)
      do {
        try Recorder.instance.startRecording()
        response = GCDWebServerDataResponse(statusCode: 200)
      } catch {
        self.logger.error("Cannot start recording \(error.localizedDescription, privacy: .public)")
        response = GCDWebServerDataResponse(statusCode: 500)
      }
      response.setValue("*", forAdditionalHeader: "Access-Control-Allow-Origin")
      return response
    }
    
    // MARK: - Stop recording
    self.webServer.addHandler(forMethod: "GET", path: "/recording/stop", request: GCDWebServerRequest.self) { (request) -> GCDWebServerResponse? in
      var response: GCDWebServerDataResponse = GCDWebServerDataResponse(statusCode: 500)
      
      Recorder.instance.stopRecording { result in
        switch result {
        case .success(let url):
          print("SUCCESS")
          print(url.absoluteString)
          
          let recordingUrl = RecordingUrl(absoluteUrl: url.absoluteString)
          print(recordingUrl)
          do {
            let data = try JSONEncoder().encode(recordingUrl)
            response = GCDWebServerDataResponse(data: data, contentType: "application/json")
          } catch {
            self.logger.error("Cannot convert URL to JSON. Error: \(error.localizedDescription)")
            response = GCDWebServerDataResponse(statusCode: 500)
          }
        case .failure(let error):
          self.logger.error("Cannot stop recording: \(error.localizedDescription)")
          response = GCDWebServerDataResponse(statusCode: 500)
        }
      }
      
      response.setValue("*", forAdditionalHeader: "Access-Control-Allow-Origin")
      return response
    }
  }
}
