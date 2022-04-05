import Foundation
import GCDWebServer
import MetalPetal

class NDIControls: NSObject {
  
  // MARK: Properties
  static let instance = NDIControls()
  var delegate: NDIControlsDelegate?
    
  // MARK: - NDI Properties
  private(set) var ndiWrapper: NDIWrapper
  private(set) var isSending: Bool = false
  private let imageQueue = DispatchQueue(label: "ndi.mtiImageQueue", qos: .userInitiated)
  
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
        print("Config.shared.context is nil")
        return
      }
      
      do {
        let renderOutput = try self.pbRenderer.render(image, using: context)
        ndiWrapper.send(renderOutput.pixelBuffer)
      } catch {
        print("Cannot render image")
        print(error)
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
    print("Web server did start")
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
  func getCurrentCamera() -> Camera?
  func highlightPointOfInterest(pointOfInterest: CGPoint) -> Bool
  func setPreset4K() -> Bool
  func setPreset1080() -> Bool
  func setPreset720() -> Bool
  func switchMicrophone(uniqueID: String) -> Bool
}
