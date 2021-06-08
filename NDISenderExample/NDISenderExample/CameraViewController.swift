import UIKit
import AVFoundation
import GCDWebServer
import CoreImage
import CoreImage.CIFilterBuiltins

class CameraViewController: UIViewController {
  // MARK: Properties
  @IBOutlet weak var remoteControlsLabel: UILabel!
  @IBOutlet weak var sendStreamButton: UIButton!
  @IBOutlet weak var metalView: MetalView!
  
  private var cameraCapture: CameraCapture?
  private var audioCapture: AudioCapture?
  
  private var isUsingFilters = false
  
  private var currentOrientation: UIDeviceOrientation = .landscapeLeft
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    NDIControls.instance.delegate = self
    
    NotificationCenter.default.addObserver(self, selector: #selector(onNdiWebSeverDidStart(_:)), name: .ndiWebServerDidStart, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(onCameraDiscoveryCompleted(_:)), name: .cameraDiscoveryCompleted, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(onCameraSetupCompleted(_:)), name: .cameraSetupCompleted, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(onMicrophoneDiscoveryCompleted(_:)), name: .microphoneDiscoveryCompleted, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(onMicrophoneDidSwitch(_:)), name: .microphoneDidSwitch, object: nil)
    
    NotificationCenter.default.addObserver(self, selector: #selector(deviceDidRotated(_:)), name: UIDevice.orientationDidChangeNotification, object: nil)
    
    cameraCapture = CameraCapture(cameraPosition: .back, processingCallback: { [unowned self] (image) in
      guard var image = image else { return }
      
      switch currentOrientation {
      case .landscapeLeft:
        image = image.oriented(forExifOrientation: 1)
      case .landscapeRight:
        image = image.oriented(forExifOrientation: 3)
      default:
        break
      }
      
      if self.isUsingFilters {
        let filter = CIFilter.colorMonochrome()
        filter.intensity = 1
        filter.color = CIColor(red: 0.5, green: 0.5, blue: 0.5)
        filter.inputImage = image
        guard let output = filter.outputImage else { return }
        self.metalView.image = output
        NDIControls.instance.send(image: output)
      } else {
        self.metalView.image = image
        NDIControls.instance.send(image: image)
      }
      
      if !NDIControls.instance.isSending && Config.shared.bufferPool == nil {
        switch (cameraCapture?.session.sessionPreset) {
        case AVCaptureSession.Preset.hd1920x1080:
          NDIControls.instance.preparePixelBufferPool(widthOfFrame: 1920, heightOfFrame: 1080)
        case AVCaptureSession.Preset.hd1280x720:
          NDIControls.instance.preparePixelBufferPool(widthOfFrame: 1280, heightOfFrame: 720)
        default:
          break
        }
      }
    })
    
    audioCapture = AudioCapture(processingCallback: { buffer, time in
      // print out VU
    })
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    cameraCapture?.startCapture()
    
    // stop screen from going to sleep
    UIApplication.shared.isIdleTimerDisabled = true
    
    // get device orientation nofications
    UIDevice.current.beginGeneratingDeviceOrientationNotifications()
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    cameraCapture?.stopCapture()
  }
  
  @objc private func onNdiWebSeverDidStart(_ notification: Notification) {
    guard let serverUrl = notification.object as? String else { return }
    remoteControlsLabel.text = "Controls: \(serverUrl)"
    
    startNDI()
  }
  
  @objc private func onCameraDiscoveryCompleted(_ notification: Notification) {
    // Start web server
    print("Starting web server...")
    NDIControls.instance.startWebServer()
  }
  
  @objc private func onCameraSetupCompleted(_ notification: Notification) {
    print("Camera setup completed")
  }
  
  @objc private func onMicrophoneDiscoveryCompleted(_ notification: Notification) {
    guard let microphones = notification.object as? [AVAudioSessionPortDescription] else {
      print("Microphones list does not conform to type [AVAudioSessionPortDescription]")
      return }
    print(microphones)
  }
  
  @objc private func onMicrophoneDidSwitch(_ notification: Notification) {
    guard let microphone = notification.object as? AVAudioSessionPortDescription else {
      print("Microphone does not conform to type AVAudioSessionPortDescription")
      return }
    print("Switched to \(microphone.portName)")
  }
  
  @IBAction func onSendButtonTapped(_ sender: UIButton) {
    let isSending = NDIControls.instance.isSending
    
    if !isSending {
      startNDI()
    } else {
      stopNDI()
    }
  }
  
  @objc private func deviceDidRotated(_ notification: Notification) {
    currentOrientation = UIDevice.current.orientation
  }
}

extension CameraViewController: NDIControlsDelegate {
  func switchCamera(uniqueID: String) -> Bool {
    guard let cc = cameraCapture else { return false }
    return cc.switchCamera(uniqueID: uniqueID)
  }
  
  func zoom(factor: Float) -> Bool {
    guard let cc = cameraCapture else { return false }
    return cc.zoom(factor: factor)
  }
  
  func setExposureCompensation(bias: Float) -> Bool {
    guard let cc = cameraCapture else { return false }
    return cc.setExposureCompensation(bias: bias)
  }
  
  func hideControls() -> Bool {
    DispatchQueue.main.async {
      self.remoteControlsLabel.isHidden = true
      self.sendStreamButton.isHidden = true
    }
    
    return true
  }
  
  func showControls() -> Bool {
    DispatchQueue.main.async {
      self.remoteControlsLabel.isHidden = false
      self.sendStreamButton.isHidden = false
    }
    return true
  }
  
  func startNDI() {
    DispatchQueue.main.async {
      if !NDIControls.instance.isSending {
        self.sendStreamButton.setTitle("Sending...", for: .normal)
        self.sendStreamButton.backgroundColor = .blue
        NDIControls.instance.start()
      }
    }
  }
  
  func stopNDI() {
    DispatchQueue.main.async {
      if NDIControls.instance.isSending {
        self.sendStreamButton.setTitle("Send", for: .normal)
        self.sendStreamButton.backgroundColor = .gray
        NDIControls.instance.stop()
      }
    }
  }
  
  func setWhiteBalanceMode(mode: AVCaptureDevice.WhiteBalanceMode) -> Bool {
    guard let cc = cameraCapture else { return false }
    return cc.setWhiteBalanceMode(mode: mode)
  }
  
  func setTemperatureAndTint(temperature: Float, tint: Float) -> Bool {
    guard let cc = cameraCapture else { return false }
    return cc.setTemperatureAndTint(temperature: temperature, tint: tint)
  }
  
  func getWhiteBalanceTemp() -> Float {
    guard let cc = cameraCapture else { return -1 }
    return cc.getTemperature()
  }
  
  func getWhiteBalanceTint() -> Float {
    guard let cc = cameraCapture else { return -1 }
    return cc.getTint()
  }
  
  func lockGrey() -> Bool {
    guard let cc = cameraCapture else { return false }
    return cc.lockGreyWorld()
  }
  
  func getCurrentCamera() -> Camera? {
    guard let cc = cameraCapture else { return nil }
    return cc.getCurrentCamera()
  }
  
  func highlightPointOfInterest(pointOfInterest: CGPoint) -> Bool {
    guard let cc = cameraCapture else { return false }
    return cc.highlightPointOfInterest(pointOfInterest: pointOfInterest)
  }
  
  func setPreset4K() -> Bool {
    guard let cc = cameraCapture else { return false }
    if cc.setPreset(preset: .hd4K3840x2160) {
      NDIControls.instance.didPresetChanged_resetNdiPixelBuffer(widthOfFrame: 3840, heightOfFrame: 2160)
      return true
    }
    return false
    
  }
  
  func setPreset1080() -> Bool {
    guard let cc = cameraCapture else { return false }
    if cc.setPreset(preset: .hd1920x1080) {
      NDIControls.instance.didPresetChanged_resetNdiPixelBuffer(widthOfFrame: 1920, heightOfFrame: 1080)
      return true
    }
    return false
  }
  
  func setPreset720() -> Bool {
    guard let cc = cameraCapture else { return false }
    if cc.setPreset(preset: .hd1280x720) {
      NDIControls.instance.didPresetChanged_resetNdiPixelBuffer(widthOfFrame: 1280, heightOfFrame: 720)
      return true
    }
    return false
  }
}
