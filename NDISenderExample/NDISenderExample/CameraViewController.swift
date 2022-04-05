import UIKit
import AVFoundation
import GCDWebServer
import CoreImage
import CoreImage.CIFilterBuiltins
import MetalPetal

class CameraViewController: UIViewController {
  // MARK: Properties
  @IBOutlet weak var remoteControlsLabel: UILabel!
  @IBOutlet weak var sendStreamButton: UIButton!
  @IBOutlet weak var metalView: MTIImageView!
  
  private var cameraCapture: CameraCapture?
  private var audioCapture: AudioCapture?

  private var currentOrientation: UIDeviceOrientation = .landscapeLeft
  
  private var isCameraReady = false {
    didSet {
      if isCameraReady && isWebServerReady {
        self.startNDI()
      }
    }
  }
  
  private var isWebServerReady = false {
    didSet {
      print("[INFO] Web server is ready")
      if isCameraReady && isWebServerReady {
        self.startNDI()
      }
    }
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // Initialise MetalPetal's context
    let options = MTIContextOptions()
    guard
      let device = MTLCreateSystemDefaultDevice(),
      let context = try? MTIContext(device: device, options: options)
    else {
      fatalError()
    }
    Config.shared.context = context
    self.metalView.context = context
    
    // Instantiate NDI
    NDIControls.instance.delegate = self
    
    NotificationCenter.default.addObserver(self, selector: #selector(onNdiWebSeverDidStart(_:)), name: .ndiWebServerDidStart, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(onCameraDiscoveryCompleted(_:)), name: .cameraDiscoveryCompleted, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(onCameraSetupCompleted(_:)), name: .cameraSetupCompleted, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(onMicrophoneDiscoveryCompleted(_:)), name: .microphoneDiscoveryCompleted, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(onMicrophoneDidSwitch(_:)), name: .microphoneDidSwitch, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(onAudioOutputsDiscoveryCompleted(_:)), name: .audioOutputsDiscoveryCompleted, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(onCameraDidStartRunning(_:)), name: .cameraDidStartRunning, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(onCameraDidStopRunning(_:)), name: .cameraDidStopRunning, object: nil)
    
    NotificationCenter.default.addObserver(self, selector: #selector(deviceDidRotated(_:)), name: UIDevice.orientationDidChangeNotification, object: nil)
    
    // Filter example: Chroma key background image
    let backgroundImage = MTIImage(
      ciImage: CIImage(contentsOf: Bundle.main.url(forResource: "IMG_2021", withExtension: "jpg")!)!,
      isOpaque: true)
    let filter = MTIChromaKeyBlendFilter()
    filter.inputBackgroundImage = backgroundImage
    
    
    cameraCapture = CameraCapture(cameraPosition: .back, delegate: self)
    
    audioCapture = AudioCapture(processingCallback: { buffer, time in
      NDIControls.instance.send(audioBuffer: buffer)
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
    
    self.isWebServerReady = true
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
    print("\nMicrophones found:")
    for mic in microphones {
      print(mic)
    }
    print("\n")
  }
  
  @objc private func onMicrophoneDidSwitch(_ notification: Notification) {
    guard let microphone = notification.object as? AVAudioSessionPortDescription else {
      print("Microphone does not conform to type AVAudioSessionPortDescription")
      return }
    print("Switched to \(microphone.portName)")
  }
  
  @objc private func onAudioOutputsDiscoveryCompleted(_ notification: Notification) {
    guard let audioOutputs = notification.object as? [AVAudioSessionPortDescription] else {
      print("Audio outputs list does not conform to type [AVAudioSessionPortDescription]")
      return }
    print("\nAudio outputs found:")
    for output in audioOutputs {
      print(output)
    }
    print("\n")
  }
  
  @objc private func onCameraDidStartRunning(_ notification: Notification) {
    print("[INFO] Camera is ready")
    self.isCameraReady = true
  }
  
  @objc private func onCameraDidStopRunning(_ notification: Notification) {
    print("[INFO] Camera is not ready")
    self.isCameraReady = false
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
        print("[INFO] Starting NDI")
        self.sendStreamButton.setTitle("Sending...", for: .normal)
        self.sendStreamButton.backgroundColor = .blue
        NDIControls.instance.start()
        print("[INFO] NDI Started")
      }
    }
  }
  
  func stopNDI() {
    DispatchQueue.main.async {
      if NDIControls.instance.isSending {
        self.sendStreamButton.setTitle("Send", for: .normal)
        self.sendStreamButton.backgroundColor = .gray
      }
    }
    cameraCapture?.stopCapture()
    NDIControls.instance.stop()
    cameraCapture?.startCapture()
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
  
  func switchMicrophone(uniqueID: String) -> Bool {
    guard let ac = audioCapture else { return false }
    return ac.switchMic(toUid: uniqueID)
  }
}

extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
  func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
      return
    }
    var outputImage: MTIImage? = nil
    
    outputImage = MTIImage(cvPixelBuffer: pixelBuffer, alphaType: .alphaIsOne)
    // Render to screen and output
    guard let outputImage = outputImage else {
      print("No video")
      return
    }
    DispatchQueue.main.async {
      self.metalView.image = outputImage
    }
    
    NDIControls.instance.send(image: outputImage)
  }
}
