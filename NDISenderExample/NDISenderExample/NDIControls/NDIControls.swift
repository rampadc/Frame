import Foundation
import GCDWebServer
import MetalPetal

class NDIControls: NSObject {
  
  // MARK: Properties
  static let instance = NDIControls()
  var delegate: NDIControlsDelegate?
  
  let logger = Logger(subsystem: Config.shared.subsystem, category: "NDIControls")
    
  // MARK: - NDI Properties
  private(set) var ndiWrapper: NDIWrapper
  private(set) var isSending: Bool = false {
    didSet {
      logger.info("NDI isSending: \(self.isSending, privacy: .public)")
    }
  }
  
  // MARK: - Web server properties
  let webServer = GCDWebServer()
  
  private let pbRenderer = PixelBufferPoolBackedImageRenderer()
  
  // MARK: Web server functions
  func startWebServer() {    
    addWebServerHandlers()
    webServer.delegate = self
    webServer.start(withPort: 80, bonjourName: UIDevice.current.name)
  }
  
  func addWebServerHandlers() {
    addWebServerHandlersForAudio()
    addWebServerHandlersForCamera()
    addWebServerHandlersForNDI()
    addWebServerHandlersForUI()
  }
  
  // MARK: NDI Wrapper functions
  func start() {
    isSending = true
    ndiWrapper.start(UIDevice.current.name)
  }
  
  func stop() {
    isSending = false
    ndiWrapper.stop()
  }
  
  func send(image: MTIImage) {
    if isSending {
      guard let context = Config.shared.context else {
        logger.error("Config.shared.context is nil. Will not render MTIImage to pixelBuffer")
        return
      }
      
      do {
        let renderOutput = try self.pbRenderer.render(image, using: context)
        ndiWrapper.send(renderOutput.pixelBuffer)
      } catch {
        logger.error("pixel buffer cannot render MTIImage to pass to NDI Wrapper")
        logger.error("Error: \(error.localizedDescription, privacy: .public)")
      }
    }
  }
  
  func send(audioBuffer buffer: AVAudioPCMBuffer) {
    if isSending {
      ndiWrapper.sendAudioBuffer(buffer)
    }
  }
  
  // MARK: Init
  private override init() {
    ndiWrapper = NDIWrapper()
    super.init()
  }
  
  func didPresetChanged_resetNdiPixelBuffer(widthOfFrame: Int, heightOfFrame: Int) {
    if isSending {
      stop()
    }
    
    start()
  }
}

// MARK: GCDWebServerDelegate
extension NDIControls: GCDWebServerDelegate {
  func webServerDidStart(_ server: GCDWebServer) {
    logger.info("Web server started")
    NotificationCenter.default.post(name: .ndiWebServerDidStart, object: server.serverURL?.absoluteString ?? "Unknown")
  }
}

protocol NDIControlsDelegate {
  func switchCamera(uniqueID: String) -> Bool
  func zoom(factor: Float) -> Bool
  func setExposureCompensation(bias: Float) -> Bool
  func hideControls() -> Bool
  func showControls() -> Bool
  func startNDI()
  func stopNDI()
  func setWhiteBalanceMode(mode: AVCaptureDevice.WhiteBalanceMode) -> Bool
  func setTemperatureAndTint(temperature: Float, tint: Float) -> Bool
  func getWhiteBalanceTemp() -> Float
  func getWhiteBalanceTint() -> Float
  func lockGrey() -> Bool
  func getCurrentCamera() -> CameraInformation?
  func highlightPointOfInterest(pointOfInterest: CGPoint) -> Bool
  func setPreset4K() -> Bool
  func setPreset1080() -> Bool
  func setPreset720() -> Bool
  func switchMicrophone(uniqueID: String) -> Bool
}
