import AVFAudio
import Accelerate

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

public enum AnalysisMode {
    case rms
    case peak
}

/// How to deal with stereo signals
public enum StereoMode {
    /// Use left channel
    case left
    /// Use right channel
    case right
    /// Use combined left and right channels
    case center
}


class AudioCapture: NSObject {
  typealias AudioBufferProcessingCallback = (AVAudioPCMBuffer, AVAudioTime) -> ()
  
  private(set) var session = AVAudioSession.sharedInstance()
  private var audioEngine: AVAudioEngine?
  private var mic: AVAudioInputNode?
  private var micTapped = false
  private var connectedAudioOutput: AVAudioSessionPortDescription?
  let processingCallback: AudioBufferProcessingCallback
  
  let analysisMode: AnalysisMode = .rms
  let stereoMode: StereoMode = .left
  private var amp: [Float] = Array(repeating: 0, count: 2)

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
          // AudioKit: buffer length = 128, samplerate = 44100
          try AVAudioSession.sharedInstance().setPreferredIOBufferDuration(128/44100)
          try AVAudioSession.sharedInstance().setCategory(.playAndRecord, options: [.defaultToSpeaker, .mixWithOthers, .allowBluetooth, .allowBluetoothA2DP])
          try AVAudioSession.sharedInstance().setActive(true)
          print("AVAudioSession setup completed")
          
          self.audioEngine = AVAudioEngine()
          self.mic = self.audioEngine!.inputNode
          
          self.getMicrophones()
          self.getAudioOutputs()

          // Assign current input
          guard let defaultInput = self.session.currentRoute.inputs.first else { fatalError("No microphones available") }
          Config.shared.currentMicrophone = defaultInput
          self.switchMic(to: defaultInput)
          
          // Get current output
          Config.shared.currentOutput = AVAudioSession.sharedInstance().currentRoute.outputs.first
          
          // Start audio processing
          let _ = self.tapMic()
        } catch {
          print(error)
          print("AVAudioSession setup failed")
        }
        
        // Observe route changes (headphones, microphones connected)
        NotificationCenter.default.addObserver(self, selector: #selector(self.onRouteChanged(_:)), name: AVAudioSession.routeChangeNotification, object: nil)
        
        
      } else {
        print("Record permission is granted.")
        // TODO: Present message to user indicating that recording cannot be performed until they change their preferences in Settings > Privacy > Microphone
      }
    }
  }
  
  func switchMic(toUid uid: String) -> Bool {
    guard let inputs = self.session.availableInputs else { return false }
    for mic in inputs {
      if mic.uid == uid {
        do {
          try self.session.setPreferredInput(mic)
          NotificationCenter.default.post(name: .microphoneDidSwitch, object: mic)
          Config.shared.currentMicrophone = mic
          return true
        } catch {
          print("Cannot set preferred input")
          print(error)
          return false
        }
      }
    }
    
    return false
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
  
  /// Detected amplitude (average of left and right channels)
  public var amplitude: Float {
      return amp.reduce(0, +) / 2
  }

  /// Detected left channel amplitude
  public var leftAmplitude: Float {
      return amp[0]
  }

  /// Detected right channel amplitude
  public var rightAmplitude: Float {
      return amp[1]
  }
  
  func tapMic() -> Bool {
    if micTapped {
      print("Mic is already tapped")
      return false
    }
    
    print("Tapping mic...")
    let format = mic?.inputFormat(forBus: 0)
    mic?.installTap(onBus: 0, bufferSize: 128, format: format, block: { buffer, audioTime in
      guard let floatData = buffer.floatChannelData else { return }

      let channelCount = Int(buffer.format.channelCount)
      let length = UInt(buffer.frameLength)

      // n is the channel
      for n in 0 ..< channelCount {
          let data = floatData[n]

        if self.analysisMode == .rms {
            var rms: Float = 0
            vDSP_rmsqv(data, 1, &rms, UInt(length))
            self.amp[n] = rms
          } else {
            var peak: Float = 0
            var index: vDSP_Length = 0
            vDSP_maxvi(data, 1, &peak, &index, UInt(length))
            self.amp[n] = peak
          }
      }

      switch self.stereoMode {
      case .left:
        Config.shared.amplitude = self.leftAmplitude
//        print(self.leftAmplitude)
      case .right:
        Config.shared.amplitude = self.rightAmplitude
//        print(self.rightAmplitude)
      case .center:
        Config.shared.amplitude = self.amplitude
//        print(self.amplitude)
      }
      
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
