import Foundation
import GCDWebServer

class NDIControls: NSObject {
  
  // MARK: Properties
  static let instance = NDIControls()
  var delegate: NDIControlsDelegate?
  
  // MARK: - NDI Properties
  private(set)var ndiWrapper: NDIWrapper
  private(set) var isSending: Bool = false
  
  // MARK: - Web server properties
  private let webServer = GCDWebServer()
  
  
  // MARK: Web server functions
  func startWebServer() {
    // Get the path to the website directory
    let websiteTemplate = Bundle.main.path(forResource: "WebServerTemplates", ofType: nil)
    
    guard let templateDirectory = websiteTemplate else { return }
  
    // Add a default handler to server static files (anything other than HTML files)
    webServer.addGETHandler(forBasePath: "/", directoryPath: templateDirectory, indexFilename: "index.html", cacheAge: 0, allowRangeRequests: true)
    
    addWebServerHandlers()
    webServer.delegate = self
    webServer.start(withPort: 8080, bonjourName: UIDevice.current.name)
  }
  
  func addWebServerHandlers() {
    // MARK: - Get cameras JSON
    webServer.addHandler(forMethod: "GET", path: "/cameras", request: GCDWebServerRequest.self) { [unowned self] (request) -> GCDWebServerResponse? in
      guard let cameras = Config.shared.cameras else { return GCDWebServerErrorResponse(statusCode: 500) }
      var cameraObjects: [Camera] = []
      for camera in cameras {
        cameraObjects.append(Camera(camera: camera))
      }
      
      let data = try! JSONEncoder().encode(cameraObjects)
      return GCDWebServerDataResponse(data: data, contentType: "application/json")
    }
    
    // MARK: - Switch camera
    webServer.addHandler(forMethod: "POST", path: "/cameras/select", request: GCDWebServerURLEncodedFormRequest.self) { [unowned self] (request) -> GCDWebServerResponse? in
      // GCDWebServerURLEncodedFormRequest expects the body data to be contained in a x-www-form-urlencoded
      let r = request as! GCDWebServerURLEncodedFormRequest
      guard let cameraUniqueID = r.arguments["uniqueID"] else { return GCDWebServerDataResponse(statusCode: 400) }
      
      if delegate == nil {
        return GCDWebServerDataResponse(statusCode: 501)
      } else {
        let hasCameraSwitched = self.delegate!.switchCamera(uniqueID: cameraUniqueID)
        if hasCameraSwitched {
          return GCDWebServerDataResponse(statusCode: 200)
        } else {
          return GCDWebServerDataResponse(statusCode: 500)
        }
      }
    }
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

// MARK: GCDWebServerDelegate
extension NDIControls: GCDWebServerDelegate {
  func webServerDidStart(_ server: GCDWebServer) {
    NotificationCenter.default.post(name: .ndiWebServerDidStart, object: server.serverURL?.absoluteString ?? "Unknown")
  }
}

protocol NDIControlsDelegate {
  func switchCamera(uniqueID: String) -> Bool
}
