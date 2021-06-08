//
//  AudioCapture.swift
//  NDISenderExample
//
//  Created by Cong Nguyen on 30/5/21.
//

import AVFAudio

class AudioCapture: NSObject {
  typealias AudioBufferProcessingCallback = (AVAudioPCMBuffer, AVAudioTime) -> ()
  
  private(set) var session = AVAudioSession.sharedInstance()
  private var audioEngine: AVAudioEngine?
  private var mic: AVAudioInputNode?
  private var micTapped = false
  
  let processingCallback: AudioBufferProcessingCallback
  
  init(processingCallback: @escaping AudioBufferProcessingCallback) {
    self.processingCallback = processingCallback
    
    super.init()
    prepareSession()
  }
  
  private func prepareSession() {
    session.requestRecordPermission { granted in
      if granted {
        print("Granted")
        // The user granted access
        do {
          try self.session.setCategory(.record, mode: .measurement, policy: .default, options: .allowBluetooth)
          try self.session.setActive(true)
          
          self.audioEngine = AVAudioEngine()
          self.mic = self.audioEngine!.inputNode
          
          guard let inputs = self.session.availableInputs else { fatalError() }
          NotificationCenter.default.post(name: .microphoneDiscoveryCompleted, object: inputs)
          
          let defaultInput = self.session.currentRoute.inputs.first
          self.switchMic(to: defaultInput!)
          let _ = self.tapMic()
        } catch {
          print(error)
        }
        
        
      } else {
        print("Not Granted")
        // Present message to user indicating that recording
        // cannot be performed until they change their
        // preferences in Settings > Privacy > Microphone
      }
    }
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
}
