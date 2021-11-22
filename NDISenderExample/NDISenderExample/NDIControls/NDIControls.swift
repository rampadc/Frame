import Foundation
import GCDWebServer
import MetalPetal

class NDIControls: NSObject {
  
  // MARK: Properties
  static let instance = NDIControls()
  var delegate: NDIControlsDelegate?
  
  private var isPreparingPixelBufferPool = false
  
  // MARK: - NDI Properties
  private(set) var ndiWrapper: NDIWrapper
  private(set) var isSending: Bool = false
  
  // MARK: - Web server properties
  let webServer = GCDWebServer()
  
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
  
//  func send(image: CIImage) {
//    if isSending {
//      let pixelBuffer: CVImageBuffer? = overwritePixelBufferWithImage(image: image)
//      if pixelBuffer == nil {
//        return
//      }
//      ndiWrapper.send(pixelBuffer!)
//    }
//  }
  
  func send(image: MTIImage) {
    if isSending {
      
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
  
  // MARK: Create a brand new pixel buffer from a CIImage
//  func createPixelBufferFrom(image: CIImage) -> CVPixelBuffer? {
//    // based on https://stackoverflow.com/questions/54354138/how-can-you-make-a-cvpixelbuffer-directly-from-a-ciimage-instead-of-a-uiimage-in
//
//    let attrs = [
//      kCVPixelBufferCGImageCompatibilityKey: false,
//      kCVPixelBufferCGBitmapContextCompatibilityKey: false,
//      kCVPixelBufferWidthKey: Int(image.extent.width),
//      kCVPixelBufferHeightKey: Int(image.extent.height)
//    ] as CFDictionary
//    var pixelBuffer : CVPixelBuffer?
//    let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(image.extent.width), Int(image.extent.height), kCVPixelFormatType_32BGRA, attrs, &pixelBuffer)
//
//    if status == kCVReturnInvalidPixelFormat {
//      print("status == kCVReturnInvalidPixelFormat")
//    }
//    if status == kCVReturnInvalidSize {
//      print("status == kCVReturnInvalidSize")
//    }
//    if status == kCVReturnPixelBufferNotMetalCompatible {
//      print("status == kCVReturnPixelBufferNotMetalCompatible")
//    }
//    if status == kCVReturnPixelBufferNotOpenGLCompatible {
//      print("status == kCVReturnPixelBufferNotOpenGLCompatible")
//    }
//
//    guard (status == kCVReturnSuccess) else {
//      return nil
//    }
//
//    Config.shared.context?.render(image, to: pixelBuffer!)
//    return pixelBuffer
//  }
  
  // MARK: Use an existing pixel buffer pool
//  func overwritePixelBufferWithImage(image: CIImage) -> CVPixelBuffer? {
//    guard let bufferPool = Config.shared.bufferPool else {
//      return nil
//    }
//    // take a pixel buffer out from pool
//    var pbuf: CVPixelBuffer?
//    CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, bufferPool, &pbuf)
//    guard pbuf != nil else {
//      print("Allocation failure")
//      return nil
//    }
//    
//    Config.shared.ciContext?.render(image, to: pbuf!)
//    
//    return pbuf
//  }
  
  // MARK: Create buffer pool
  func preparePixelBufferPool(widthOfFrame width: Int, heightOfFrame height: Int) {
    if !isPreparingPixelBufferPool {
      isPreparingPixelBufferPool = true
      
      let pixelBufferAttributes = [
        kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
        kCVPixelBufferCGImageCompatibilityKey: false,
        kCVPixelBufferCGBitmapContextCompatibilityKey: false,
        kCVPixelBufferWidthKey: width,
        kCVPixelBufferHeightKey: height
      ] as CFDictionary
      
      let poolAttributes = [
        kCVPixelBufferPoolMinimumBufferCountKey: 3
      ] as CFDictionary
      
      let status = CVPixelBufferPoolCreate(
        kCFAllocatorDefault,
        poolAttributes,
        pixelBufferAttributes,
        &Config.shared.bufferPool)
      
      if status == kCVReturnWouldExceedAllocationThreshold {
        print("status == kCVReturnWouldExceedAllocationThreshold")
      } else if status == kCVReturnPoolAllocationFailed {
        print("status == kCVReturnPoolAllocationFailed")
      } else if status == kCVReturnInvalidPoolAttributes {
        print("status == kCVReturnInvalidPoolAttributes")
      } else if status == kCVReturnRetry {
        print("status == kCVReturnRetry")
      } else if status == kCVReturnSuccess {
        print("status == kCVReturnSuccess")
      } else if status == kCVReturnInvalidArgument {
        print("status == kCVReturnInvalidArgument")
      } else if status == kCVReturnAllocationFailed {
        print("status == kCVReturnAllocationFailed")
      } else if status == kCVReturnUnsupported {
        print("status == kCVReturnUnsupported")
      } else {
        print("Unknown status: \(status)")
      }
      
      if Config.shared.bufferPool == nil {
        fatalError("Cannot create buffer pool")
      } else {
        // upon creation of buffer pool, turn off preparing flag
        isPreparingPixelBufferPool = false
        print("Created buffer pool")
      }
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
    
    preparePixelBufferPool(widthOfFrame: widthOfFrame, heightOfFrame: heightOfFrame)
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
