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
  
  // MARK: Create a brand new SampleBuffer from a CVPixelBuffer
  func createSampleBufferFrom(pixelBuffer: CVPixelBuffer) -> CMSampleBuffer? {
    var sampleBuffer: CMSampleBuffer?
    
    var timimgInfo  = CMSampleTimingInfo()
    var formatDescription: CMFormatDescription? = nil
    CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixelBuffer, formatDescriptionOut: &formatDescription)
    
    let osStatus = CMSampleBufferCreateReadyWithImageBuffer(
      allocator: kCFAllocatorDefault,
      imageBuffer: pixelBuffer,
      formatDescription: formatDescription!,
      sampleTiming: &timimgInfo,
      sampleBufferOut: &sampleBuffer
    )
    
    // Print out errors
    if osStatus == kCMSampleBufferError_AllocationFailed {
      print("osStatus == kCMSampleBufferError_AllocationFailed")
    }
    if osStatus == kCMSampleBufferError_RequiredParameterMissing {
      print("osStatus == kCMSampleBufferError_RequiredParameterMissing")
    }
    if osStatus == kCMSampleBufferError_AlreadyHasDataBuffer {
      print("osStatus == kCMSampleBufferError_AlreadyHasDataBuffer")
    }
    if osStatus == kCMSampleBufferError_BufferNotReady {
      print("osStatus == kCMSampleBufferError_BufferNotReady")
    }
    if osStatus == kCMSampleBufferError_SampleIndexOutOfRange {
      print("osStatus == kCMSampleBufferError_SampleIndexOutOfRange")
    }
    if osStatus == kCMSampleBufferError_BufferHasNoSampleSizes {
      print("osStatus == kCMSampleBufferError_BufferHasNoSampleSizes")
    }
    if osStatus == kCMSampleBufferError_BufferHasNoSampleTimingInfo {
      print("osStatus == kCMSampleBufferError_BufferHasNoSampleTimingInfo")
    }
    if osStatus == kCMSampleBufferError_ArrayTooSmall {
      print("osStatus == kCMSampleBufferError_ArrayTooSmall")
    }
    if osStatus == kCMSampleBufferError_InvalidEntryCount {
      print("osStatus == kCMSampleBufferError_InvalidEntryCount")
    }
    if osStatus == kCMSampleBufferError_CannotSubdivide {
      print("osStatus == kCMSampleBufferError_CannotSubdivide")
    }
    if osStatus == kCMSampleBufferError_SampleTimingInfoInvalid {
      print("osStatus == kCMSampleBufferError_SampleTimingInfoInvalid")
    }
    if osStatus == kCMSampleBufferError_InvalidMediaTypeForOperation {
      print("osStatus == kCMSampleBufferError_InvalidMediaTypeForOperation")
    }
    if osStatus == kCMSampleBufferError_InvalidSampleData {
      print("osStatus == kCMSampleBufferError_InvalidSampleData")
    }
    if osStatus == kCMSampleBufferError_InvalidMediaFormat {
      print("osStatus == kCMSampleBufferError_InvalidMediaFormat")
    }
    if osStatus == kCMSampleBufferError_Invalidated {
      print("osStatus == kCMSampleBufferError_Invalidated")
    }
    if osStatus == kCMSampleBufferError_DataFailed {
      print("osStatus == kCMSampleBufferError_DataFailed")
    }
    if osStatus == kCMSampleBufferError_DataCanceled {
      print("osStatus == kCMSampleBufferError_DataCanceled")
    }
    
    guard let buffer = sampleBuffer else {
      print("Cannot create sample buffer")
      return nil
    }
    
    return buffer
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
