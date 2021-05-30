import Foundation
import GCDWebServer

class NDIControls: NSObject {
  
  // MARK: Properties
  static let instance = NDIControls()
  var delegate: NDIControlsDelegate?
  
  private var isPreparingPixelBufferPool = false
  
  // MARK: - NDI Properties
  private(set) var ndiWrapper: NDIWrapper
  private(set) var isSending: Bool = false
  
  // MARK: - Web server properties
  private let webServer = GCDWebServer()
  
  // MARK: Web server functions
  func startWebServer() {    
    addWebServerHandlers()
    webServer.delegate = self
    webServer.start(withPort: 80, bonjourName: UIDevice.current.name)
  }
  
  func addWebServerHandlers() {
    // MARK: - Get NDI status
    webServer.addHandler(forMethod: "GET", path: "/ndi/status", request: GCDWebServerRequest.self) { [unowned self] (request) -> GCDWebServerResponse? in
      
      let status: [String: Bool] = ["started": self.isSending]
      
      var response: GCDWebServerDataResponse
      do {
        let data = try JSONEncoder().encode(status)
        response = GCDWebServerDataResponse(data: data, contentType: "application/json")
      } catch {
        print("Cannot serialise JSON. Error: \(error.localizedDescription)")
        response = GCDWebServerDataResponse(statusCode: 500)
      }
      response.setValue("*", forAdditionalHeader: "Access-Control-Allow-Origin")
      return response
    }
    
    
    // MARK: - Get cameras JSON
    webServer.addHandler(forMethod: "GET", path: "/cameras", request: GCDWebServerRequest.self) { (request) -> GCDWebServerResponse? in
      guard let cameras = Config.shared.cameras else { return GCDWebServerErrorResponse(statusCode: 500) }
      var cameraObjects: [Camera] = []
      for camera in cameras {
        cameraObjects.append(Camera(camera: camera))
      }
      
      var response: GCDWebServerDataResponse
      do {
        let data = try JSONEncoder().encode(cameraObjects)
        response = GCDWebServerDataResponse(data: data, contentType: "application/json")
      } catch {
        print("Cannot serialise JSON. Error: \(error.localizedDescription)")
        response = GCDWebServerDataResponse(statusCode: 500)
      }
      response.setValue("*", forAdditionalHeader: "Access-Control-Allow-Origin")
      return response
    }
    
    // MARK: - Get active camera
    webServer.addHandler(forMethod: "GET", path: "/cameras/active", request: GCDWebServerRequest.self) { [unowned self] (request) -> GCDWebServerResponse? in
      if delegate == nil {
        return GCDWebServerDataResponse(statusCode: 501)
      }
      guard let camera = self.delegate!.getCurrentCamera() else {
        return GCDWebServerDataResponse(statusCode: 501)
      }
      
      var response: GCDWebServerDataResponse
      do {
        let data = try JSONEncoder().encode(camera)
        response = GCDWebServerDataResponse(data: data, contentType: "application/json")
      } catch {
        print("Cannot serialise JSON. Error: \(error.localizedDescription)")
        response = GCDWebServerDataResponse(statusCode: 500)
      }
      response.setValue("*", forAdditionalHeader: "Access-Control-Allow-Origin")
      return response
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
        
        var response: GCDWebServerDataResponse
        if hasCameraSwitched {
          response = GCDWebServerDataResponse(statusCode: 200)
       } else {
        response = GCDWebServerDataResponse(statusCode: 500)
        }
        response.setValue("*", forAdditionalHeader: "Access-Control-Allow-Origin")
        return response
      }
    }
    
    // MARK: - Zoom camera
    webServer.addHandler(forMethod: "POST", pathRegex: "/camera/zoom", request: GCDWebServerURLEncodedFormRequest.self) { [unowned self] (request) -> GCDWebServerResponse? in
      let r = request as! GCDWebServerURLEncodedFormRequest
      guard let zoomFactor = r.arguments["zoomFactor"] else { return GCDWebServerDataResponse(statusCode: 400) }
      
      if self.delegate == nil {
        return GCDWebServerDataResponse(statusCode: 501)
      }
      
      guard let zf = Float(zoomFactor) else { return GCDWebServerDataResponse(statusCode: 400) }
      
      var response: GCDWebServerDataResponse
      if self.delegate!.zoom(factor: zf) {
        response = GCDWebServerDataResponse(statusCode: 200)
      } else {
        response = GCDWebServerDataResponse(statusCode: 500)
      }
      response.setValue("*", forAdditionalHeader: "Access-Control-Allow-Origin")
      return response
    }
    
    // MARK: - Exposure bias adjustment
    webServer.addHandler(forMethod: "POST", pathRegex: "/camera/exposure/bias", request: GCDWebServerURLEncodedFormRequest.self) { [unowned self] (request) -> GCDWebServerResponse? in
      let r = request as! GCDWebServerURLEncodedFormRequest
      guard let bias = Float(r.arguments["bias"] ?? "invalidNumber") else {
        return GCDWebServerDataResponse(statusCode: 400)
      }
      
      if self.delegate == nil {
        return GCDWebServerDataResponse(statusCode: 501)
      }
      
      var response: GCDWebServerDataResponse
      if self.delegate!.setExposureCompensation(bias: bias)  {
        response = GCDWebServerDataResponse(statusCode: 200)
      } else {
        response = GCDWebServerDataResponse(statusCode: 500)
      }
      response.setValue("*", forAdditionalHeader: "Access-Control-Allow-Origin")
      return response
    }
    
    // MARK: - White balance
    webServer.addHandler(forMethod: "GET", pathRegex: "/camera/white-balance/mode/auto", request: GCDWebServerRequest.self) { [unowned self] (request) -> GCDWebServerResponse? in
      if self.delegate == nil {
        return GCDWebServerDataResponse(statusCode: 501)
      }
      
      var response: GCDWebServerDataResponse
      if self.delegate!.setWhiteBalanceMode(mode: .continuousAutoWhiteBalance) {
        response = GCDWebServerDataResponse(statusCode: 200)
      } else {
        response = GCDWebServerDataResponse(statusCode: 500)
      }
      response.setValue("*", forAdditionalHeader: "Access-Control-Allow-Origin")
      return response
    }
    
    webServer.addHandler(forMethod: "GET", pathRegex: "/camera/white-balance/mode/locked", request: GCDWebServerRequest.self) { [unowned self] (request) -> GCDWebServerResponse? in
      if self.delegate == nil {
        return GCDWebServerDataResponse(statusCode: 501)
      }
      
      var response: GCDWebServerDataResponse
      if self.delegate!.setWhiteBalanceMode(mode: .locked) {
        response = GCDWebServerDataResponse(statusCode: 200)
      } else {
        response = GCDWebServerDataResponse(statusCode: 500)
      }
      response.setValue("*", forAdditionalHeader: "Access-Control-Allow-Origin")
      return response
    }
    
    webServer.addHandler(forMethod: "GET", pathRegex: "/camera/white-balance/temp-tint", request: GCDWebServerRequest.self) { [unowned self] (request) -> GCDWebServerResponse? in
      if self.delegate == nil {
        return GCDWebServerDataResponse(statusCode: 501)
      }
      
      let respData: [String: Float] = [
        "temperature": self.delegate!.getWhiteBalanceTemp(),
        "tint": self.delegate!.getWhiteBalanceTint()
      ]
      
      var response: GCDWebServerDataResponse
      do {
        let json = try JSONEncoder().encode(respData)
        response = GCDWebServerDataResponse(data: json, contentType: "application/json")
      } catch {
        print("Cannot convert to JSON")
        response = GCDWebServerDataResponse(statusCode: 500)
      }
      response.setValue("*", forAdditionalHeader: "Access-Control-Allow-Origin")
      return response
    }
    
    webServer.addHandler(forMethod: "POST", pathRegex: "/camera/white-balance/temp-tint", request: GCDWebServerURLEncodedFormRequest.self) { [unowned self] (request) -> GCDWebServerResponse? in
      let r = request as! GCDWebServerURLEncodedFormRequest
      guard let temp = Float(r.arguments["temperature"] ?? "invalidNumber"),
            let tint = Float(r.arguments["tint"] ?? "invalidNumber")
      else {
        return GCDWebServerDataResponse(statusCode: 400)
      }
      
      if self.delegate == nil {
        return GCDWebServerDataResponse(statusCode: 501)
      }
      
      var response: GCDWebServerDataResponse
      if self.delegate!.setTemperatureAndTint(temperature: temp, tint: tint) {
        response = GCDWebServerDataResponse(statusCode: 200)
      } else {
        response = GCDWebServerDataResponse(statusCode: 500)
      }
      response.setValue("*", forAdditionalHeader: "Access-Control-Allow-Origin")
      return response
    }
    
    webServer.addHandler(forMethod: "GET", pathRegex: "/camera/white-balance/grey", request: GCDWebServerRequest.self) { [unowned self] (request) -> GCDWebServerResponse? in
      if self.delegate == nil {
        return GCDWebServerDataResponse(statusCode: 501)
      }
      
      var response: GCDWebServerDataResponse
      if self.delegate!.lockGrey() {
        response = GCDWebServerDataResponse(statusCode: 200)
      } else {
        response = GCDWebServerDataResponse(statusCode: 500)
      }
      response.setValue("*", forAdditionalHeader: "Access-Control-Allow-Origin")
      return response
    }
        
    // MARK: - Focus
    webServer.addHandler(forMethod: "POST", pathRegex: "/camera/focus", request: GCDWebServerURLEncodedFormRequest.self) { [unowned self] (request) -> GCDWebServerResponse? in
      let r = request as! GCDWebServerURLEncodedFormRequest
      guard let x = Double(r.arguments["x"] ?? "invalidNumber"),
            let y = Double(r.arguments["y"] ?? "invalidNumber")
      else {
        return GCDWebServerDataResponse(statusCode: 400)
      }
      
      if self.delegate == nil {
        return GCDWebServerDataResponse(statusCode: 501)
      }
      
      var response: GCDWebServerDataResponse
      if self.delegate!.highlightPointOfInterest(pointOfInterest: CGPoint(x: x, y: y)) {
        response = GCDWebServerDataResponse(statusCode: 200)
      } else {
        response = GCDWebServerDataResponse(statusCode: 500)
      }
      response.setValue("*", forAdditionalHeader: "Access-Control-Allow-Origin")
      return response
    }
    
    // MARK: - on-screen controls
    webServer.addHandler(forMethod: "GET", pathRegex: "/controls/hide", request: GCDWebServerRequest.self) { [unowned self] (request) -> GCDWebServerResponse? in
      if self.delegate == nil {
        return GCDWebServerDataResponse(statusCode: 501)
      }
      
      var response: GCDWebServerDataResponse
      if self.delegate!.hideControls() {
        response = GCDWebServerDataResponse(statusCode: 200)
      } else {
        response = GCDWebServerDataResponse(statusCode: 500)
      }
      response.setValue("*", forAdditionalHeader: "Access-Control-Allow-Origin")
      return response
    }
    
    webServer.addHandler(forMethod: "GET", pathRegex: "/controls/show", request: GCDWebServerRequest.self) { [unowned self] (request) -> GCDWebServerResponse? in
      if self.delegate == nil {
        return GCDWebServerDataResponse(statusCode: 501)
      }
      
      var response: GCDWebServerDataResponse
      if self.delegate!.showControls() {
        response = GCDWebServerDataResponse(statusCode: 200)
      } else {
        response = GCDWebServerDataResponse(statusCode: 500)
      }
      response.setValue("*", forAdditionalHeader: "Access-Control-Allow-Origin")
      return response
    }
    
    // MARK: - ndi control
    webServer.addHandler(forMethod: "GET", pathRegex: "/ndi/start", request: GCDWebServerRequest.self) { [unowned self] (request) -> GCDWebServerResponse? in
      if self.delegate == nil {
        return GCDWebServerDataResponse(statusCode: 501)
      }
      
      var response: GCDWebServerDataResponse
      self.delegate!.startNDI()
      response = GCDWebServerDataResponse(statusCode: 200)
      response.setValue("*", forAdditionalHeader: "Access-Control-Allow-Origin")
      return response
    }
    
    webServer.addHandler(forMethod: "GET", pathRegex: "/ndi/stop", request: GCDWebServerRequest.self) { [unowned self] (request) -> GCDWebServerResponse? in
      if self.delegate == nil {
        return GCDWebServerDataResponse(statusCode: 501)
      }
      
      var response: GCDWebServerDataResponse
      self.delegate!.stopNDI()
      response = GCDWebServerDataResponse(statusCode: 200)
      response.setValue("*", forAdditionalHeader: "Access-Control-Allow-Origin")
      return response
    }
    
    // MARK: - swtich session preset
    webServer.addHandler(forMethod: "GET", pathRegex: "/preset/1080p", request: GCDWebServerRequest.self) { [unowned self] (request) -> GCDWebServerResponse? in
      if self.delegate == nil {
        return GCDWebServerDataResponse(statusCode: 501)
      }
      
      var response: GCDWebServerDataResponse
      if self.delegate!.setPreset1080() {
        response = GCDWebServerDataResponse(statusCode: 200)
      } else {
        response = GCDWebServerDataResponse(statusCode: 500)
      }
      response = GCDWebServerDataResponse(statusCode: 200)
      response.setValue("*", forAdditionalHeader: "Access-Control-Allow-Origin")
      return response
    }
    
    webServer.addHandler(forMethod: "GET", pathRegex: "/preset/720p", request: GCDWebServerRequest.self) { [unowned self] (request) -> GCDWebServerResponse? in
      if self.delegate == nil {
        return GCDWebServerDataResponse(statusCode: 501)
      }
      
      var response: GCDWebServerDataResponse
      if self.delegate!.setPreset720() {
        response = GCDWebServerDataResponse(statusCode: 200)
      } else {
        response = GCDWebServerDataResponse(statusCode: 500)
      }
      response = GCDWebServerDataResponse(statusCode: 200)
      response.setValue("*", forAdditionalHeader: "Access-Control-Allow-Origin")
      return response
    }
    
    webServer.addHandler(forMethod: "GET", pathRegex: "/preset/4K", request: GCDWebServerRequest.self) { [unowned self] (request) -> GCDWebServerResponse? in
      if self.delegate == nil {
        return GCDWebServerDataResponse(statusCode: 501)
      }
      
      var response: GCDWebServerDataResponse
      if self.delegate!.setPreset4K() {
        response = GCDWebServerDataResponse(statusCode: 200)
      } else {
        response = GCDWebServerDataResponse(statusCode: 500)
      }
      response = GCDWebServerDataResponse(statusCode: 200)
      response.setValue("*", forAdditionalHeader: "Access-Control-Allow-Origin")
      return response
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
      let pixelBuffer: CVImageBuffer? = overwritePixelBufferWithImage(image: image)
      if pixelBuffer == nil {
        return
      }
      ndiWrapper.send(pixelBuffer!)
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
  
  // MARK: Use an existing pixel buffer pool
  func overwritePixelBufferWithImage(image: CIImage) -> CVPixelBuffer? {
    guard let bufferPool = Config.shared.bufferPool else {
      return nil
    }
    // take a pixel buffer out from pool
    var pbuf: CVPixelBuffer?
    CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, bufferPool, &pbuf)
    guard pbuf != nil else {
      print("Allocation failure")
      return nil
    }
    
    Config.shared.ciContext?.render(image, to: pbuf!)
    
    return pbuf
  }
  
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
}
