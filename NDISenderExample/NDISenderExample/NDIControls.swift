import Foundation
import GCDWebServer

class NDIControls: NSObject {
   var ndiWrapper: NDIWrapper
  private(set) var isSending: Bool = false
  private let webServer = GCDWebServer()
  
  static let instance = NDIControls()
    
  func startWebServer() {
    webServer.addDefaultHandler(forMethod: "GET", request: GCDWebServerRequest.self, processBlock: {request in
      return GCDWebServerDataResponse(html:"<html><body><p>Hello World</p></body></html>")
    })
    webServer.delegate = self
    webServer.start(withPort: 8080, bonjourName: UIDevice.current.name)
  }
  
  func start() {
    isSending = true
    ndiWrapper.start(UIDevice.current.name)
  }
  
  func stop() {
    isSending = false
    ndiWrapper.stop()
  }
  
  func send(sampleBuffer: CMSampleBuffer) {
    if isSending {
      ndiWrapper.send(sampleBuffer)
    }
  }
  
  func send(image: CIImage) {
    if isSending {
      let pixelBuffer: CVImageBuffer? = createPixelBufferFrom(image: image)
      ndiWrapper.send(pixelBuffer!)
    }
  }
  
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
  
  func createPixelBufferFrom(image: CIImage) -> CVPixelBuffer? {
    // based on https://stackoverflow.com/questions/54354138/how-can-you-make-a-cvpixelbuffer-directly-from-a-ciimage-instead-of-a-uiimage-in
    
    let attrs = [
      kCVPixelBufferCGImageCompatibilityKey: false,
      kCVPixelBufferCGBitmapContextCompatibilityKey: false,
      kCVPixelBufferWidthKey: Int(image.extent.width),
      kCVPixelBufferHeightKey: Int(image.extent.height)
    ] as CFDictionary
    var pixelBuffer : CVPixelBuffer?
    let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(image.extent.width), Int(image.extent.height), kCVPixelFormatType_32BGRA, attrs, &pixelBuffer)
  
    if status == kCVReturnInvalidPixelFormat {
      print("status == kCVReturnInvalidPixelFormat")
    }
    if status == kCVReturnInvalidSize {
      print("status == kCVReturnInvalidSize")
    }
    if status == kCVReturnPixelBufferNotMetalCompatible {
      print("status == kCVReturnPixelBufferNotMetalCompatible")
    }
    if status == kCVReturnPixelBufferNotOpenGLCompatible {
      print("status == kCVReturnPixelBufferNotOpenGLCompatible")
    }
    
    guard (status == kCVReturnSuccess) else {
      return nil
    }
    
    Config.shared.ciContext?.render(image, to: pixelBuffer!)
    return pixelBuffer
  }
  
  private override init() {
    ndiWrapper = NDIWrapper()
    
    super.init()
  }
}

extension NDIControls: GCDWebServerDelegate {
  func webServerDidStart(_ server: GCDWebServer) {
    NotificationCenter.default.post(name: .ndiWebServerDidStart, object: server.serverURL?.absoluteString ?? "Unknown")
  }
}

extension Notification.Name {
  static let ndiWebServerDidStart = Notification.Name("ndiWebServerDidStart")
}
