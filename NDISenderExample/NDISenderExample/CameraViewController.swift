import UIKit
import AVFoundation
import GCDWebServer
import CoreImage
import CoreImage.CIFilterBuiltins
import MetalPetal
import os

class CameraViewController: UIViewController {
  // MARK: Properties
  @IBOutlet weak var remoteControlsLabel: UILabel!
  @IBOutlet weak var sendStreamButton: UIButton!
  @IBOutlet weak var metalView: MTIImageView!
  
  private var cameraCapture: CameraCapture?
  private var audioCapture: AudioCapture?
  
  private let logger = Logger(subsystem: Config.shared.subsystem, category: "CameraViewController")

  private var currentOrientation: UIDeviceOrientation = .landscapeLeft
  private var userDidStopNDI = false {
    didSet {
      logger.debug("User stopped NDI")
    }
  }
  
  private var isCameraReady = false {
    didSet {
      if isCameraReady && isWebServerReady && !userDidStopNDI {
        self.startNDI()
      }
    }
  }
  
  private var isWebServerReady = false {
    didSet {
      if isCameraReady && isWebServerReady && !userDidStopNDI {
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
    logger.debug("Web server is ready.")

    guard let serverUrl = notification.object as? String else {
      logger.error("Web server does not have a valid URL.")
      return
    }
    remoteControlsLabel.text = "Controls: \(serverUrl)"
    
    self.isWebServerReady = true
  }
  
  @objc private func onCameraDiscoveryCompleted(_ notification: Notification) {
    // Start web server
    logger.info("Starting web server...")
    NDIControls.instance.startWebServer()
  }
  
  @objc private func onCameraSetupCompleted(_ notification: Notification) {
    logger.info("Camera setup completed")
  }
  
  @objc private func onMicrophoneDiscoveryCompleted(_ notification: Notification) {
    logger.info("Microphone discovery completed")
    guard let microphones = notification.object as? [AVAudioSessionPortDescription] else {
      logger.debug("Microphones list does not conform to type [AVAudioSessionPortDescription]")
      return }
    logger.info("Microphones found")
    for mic in microphones {
      logger.debug("  > Name: \(mic.portName, privacy: .public)")
      logger.debug("    > UID: \(mic.uid, privacy: .public)")
      logger.debug("    > Type: \(mic.portType.rawValue, privacy: .public)")
    }
  }
  
  @objc private func onMicrophoneDidSwitch(_ notification: Notification) {
    logger.info("Microphone switched")
    guard let microphone = notification.object as? AVAudioSessionPortDescription else {
      logger.error("Microphone does not conform to type AVAudioSessionPortDescription")
      return }
    logger.info("Switched to \(microphone.portName, privacy: .public)")
  }
  
  @objc private func onAudioOutputsDiscoveryCompleted(_ notification: Notification) {
    logger.info("Audio output discovery completed")
    guard let audioOutputs = notification.object as? [AVAudioSessionPortDescription] else {
      logger.error("Audio outputs list does not conform to type [AVAudioSessionPortDescription]")
      return }
    logger.info("Audio outputs found")
    for output in audioOutputs {
      logger.debug("  > Name: \(output.portName, privacy: .public)")
      logger.debug("    > UID: \(output.uid, privacy: .public)")
      logger.debug("    > Type: \(output.portType.rawValue, privacy: .public)")
    }
  }
  
  @objc private func onCameraDidStartRunning(_ notification: Notification) {
    logger.info("Camera is ready")
    self.isCameraReady = true
  }
  
  @objc private func onCameraDidStopRunning(_ notification: Notification) {
    logger.info("Camera is not ready")
    self.isCameraReady = false
  }
  
  @IBAction func onSendButtonTapped(_ sender: UIButton) {
    let isSending = NDIControls.instance.isSending
    logger.info("NDI isSending: \(isSending, privacy: .public)")
    if !isSending {
      self.userDidStopNDI = false
      startNDI()
    } else {
      self.userDidStopNDI = true
      stopNDI()
    }
  }
  
  @objc private func deviceDidRotated(_ notification: Notification) {
    currentOrientation = UIDevice.current.orientation
    switch (currentOrientation) {
    case .portrait: logger.info("Device did rotate: portrait")
    case .portraitUpsideDown: logger.info("Device did rotate: portrait upside down")
    case .landscapeLeft: logger.info("Device did rotate: landscape left")
    case .landscapeRight: logger.info("Device did rotate: landscape right")
    case .faceUp: logger.info("Device did rotate: face up")
    case .faceDown: logger.info("Device did rotate: face down")
    case .unknown:
      logger.error("Device did rotate: UNKNOWN orientation")
    @unknown default:
      logger.error("Device did rotate: UNKNOWN default orientation")
    }
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
        self.logger.info("Starting NDI")
        self.sendStreamButton.setTitle("Sending...", for: .normal)
        self.sendStreamButton.backgroundColor = .blue
        NDIControls.instance.start()
        self.logger.info("NDI started")
      }
    }
  }
  
  func stopNDI() {
    DispatchQueue.main.async {
      self.sendStreamButton.setTitle("Send", for: .normal)
      self.sendStreamButton.backgroundColor = .gray
    }
    
    cameraCapture?.sampleBufferAsync {
      NDIControls.instance.stop()
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
      logger.error("Cannot create MTIImage")
      return
    }
    DispatchQueue.main.async {
      self.metalView.image = outputImage
    }
    
    NDIControls.instance.send(image: outputImage)
  }
}
