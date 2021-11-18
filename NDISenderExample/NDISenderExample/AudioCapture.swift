//
//  AudioCapture.swift
//  NDISenderExample
//
//  Created by Cong Nguyen on 30/5/21.
//

import AVFAudio

class AudioPort: Codable {
  var type = ""
  var name = ""
  var uid = ""
  var selectedDataSource = ""
  
  init(descriptor: AVAudioSessionPortDescription) {
    self.type = descriptor.portType.rawValue
    self.name = descriptor.portName
    self.uid = descriptor.uid
    self.selectedDataSource = descriptor.selectedDataSource?.dataSourceName ?? ""
  }
}

class AudioCapture: NSObject {
  typealias AudioBufferProcessingCallback = (AVAudioPCMBuffer, AVAudioTime) -> ()
  
  private(set) var session = AVAudioSession.sharedInstance()
  private var audioEngine: AVAudioEngine?
  private var mic: AVAudioInputNode?
  private var micTapped = false
  private var connectedAudioOutput: AVAudioSessionPortDescription?
  let processingCallback: AudioBufferProcessingCallback
  
  init(processingCallback: @escaping AudioBufferProcessingCallback) {
    self.processingCallback = processingCallback
    
    super.init()
    prepareSession()
  }
  
  private func prepareSession() {
    session.requestRecordPermission { granted in
      if granted {
        print("Record permission is granted.")
        // The user granted access
        do {
          //          try self.session.setCategory(.record, mode: .measurement, policy: .default, options: .allowBluetooth)
          try self.session.setCategory(.playAndRecord, mode: .videoChat, policy: .default, options: .allowBluetooth)
          try self.session.setActive(true)
          
          self.audioEngine = AVAudioEngine()
          self.mic = self.audioEngine!.inputNode
          
          self.getMicrophones()
          self.getAudioOutputs()

          let defaultInput = self.session.currentRoute.inputs.first
          self.switchMic(to: defaultInput!)
          let _ = self.tapMic()
        } catch {
          print(error)
        }
        
        // Observe route changes (headphones, microphones connected)
        NotificationCenter.default.addObserver(self, selector: #selector(self.onRouteChanged(_:)), name: AVAudioSession.routeChangeNotification, object: nil)
        
        
      } else {
        print("Record permission is granted.")
        // TODO: Present message to user indicating that recording cannot be performed until they change their preferences in Settings > Privacy > Microphone
      }
    }
  }
  
  private func getMicrophones() {
    guard let inputs = self.session.availableInputs else { fatalError() }
    Config.shared.microphones = inputs
    NotificationCenter.default.post(name: .microphoneDiscoveryCompleted, object: inputs)
  }
  
  private func getAudioOutputs() {
    let outputs = self.session.currentRoute.outputs
    Config.shared.audioOutputs = outputs
    NotificationCenter.default.post(name: .audioOutputsDiscoveryCompleted, object: outputs)
  }
  
  private func switchMic(to mic: AVAudioSessionPortDescription) {
    do {
      try self.session.setPreferredInput(mic)
      NotificationCenter.default.post(name: .microphoneDidSwitch, object: mic)
    } catch {
      print("Cannot set preferred input")
      print(error)
    }
  }
  
  func tapMic() -> Bool {
    if micTapped {
      print("Mic is already tapped")
      return false
    }
    
    print("Tapping mic...")
    let format = mic?.inputFormat(forBus: 0)
    mic?.installTap(onBus: 0, bufferSize: 2048, format: format, block: { buffer, audioTime in
      self.processingCallback(buffer, audioTime)
    })
    micTapped = true
    start()
    print("Mic tapped")
    return true
  }
  
  func untapMic() -> Bool {
    if micTapped {
      mic?.removeTap(onBus: 0)
      micTapped = false
      stop()
      
      return true
    }
    
    return false
  }
  
  private func start() {
    guard let audioEngine = self.audioEngine else {
      return
    }
    
    do {
      try audioEngine.start()
    } catch {
      print(error)
    }
  }
  
  private func stop() {
    guard let ae = self.audioEngine else {
      return
    }
    
    ae.stop()
  }
  
  @objc func onRouteChanged(_ notification: Notification) {
    guard let userInfo = notification.userInfo,
          let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
          let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
          }
    switch reason {
    case .newDeviceAvailable: // New device found.
      print("New devices found")
    case .oldDeviceUnavailable: // Old device removed.
      print("Old devices removed")
//      if let previousRoute =
//          userInfo[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription {
//        // switch to new inputs/outputs
//      }
    case .wakeFromSleep:
      print("Awaken from sleep")
    default: ()
    }
    
    self.getMicrophones()
    self.getAudioOutputs()
  }
  
  func hasHeadphones(in routeDescription: AVAudioSessionRouteDescription) -> Bool {
      // Filter the outputs to only those with a port type of headphones.
      return !routeDescription.outputs.filter({$0.portType == .headphones}).isEmpty
  }
}
