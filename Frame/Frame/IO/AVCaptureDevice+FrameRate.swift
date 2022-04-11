// Source: https://gist.github.com/Limon-O-O/1fe698e2e0d002bcd4adcc8d245276d2
extension AVCaptureDevice {
  enum FrameRateError: Error {
    case unsupportedFrameRate
    case noActiveDepthDataFormat
  }
  
  /// http://stackoverflow.com/questions/21612191/set-a-custom-avframeraterange-for-an-avcapturesession#27566730
  func configureDesiredFrameRate(_ desiredFrameRate: Int) throws {
    
    var isFPSSupported = false
    let videoSupportedFrameRateRanges = activeFormat.videoSupportedFrameRateRanges
    for range in videoSupportedFrameRateRanges {
      if (range.maxFrameRate >= Double(desiredFrameRate) && range.minFrameRate <= Double(desiredFrameRate)) {
        isFPSSupported = true
        break
      }
    }
    
    if isFPSSupported {
      try lockForConfiguration()
      activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: Int32(desiredFrameRate))
      activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: Int32(desiredFrameRate))
      unlockForConfiguration()
    } else {
      throw FrameRateError.unsupportedFrameRate
    }
  }
  
  func configureDesiredFrameRateForDepth(_ desiredFrameRate: Int) throws {
    var isFPSSupported = false
    guard let videoSupportedFrameRateRanges = activeDepthDataFormat?.videoSupportedFrameRateRanges else {
      throw FrameRateError.noActiveDepthDataFormat
    }
    for range in videoSupportedFrameRateRanges {
      if (range.maxFrameRate >= Double(desiredFrameRate) && range.minFrameRate <= Double(desiredFrameRate)) {
        isFPSSupported = true
        break
      }
    }
    
    if isFPSSupported {
      try lockForConfiguration()
      activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: Int32(desiredFrameRate))
      activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: Int32(desiredFrameRate))
      unlockForConfiguration()
    } else {
      throw FrameRateError.unsupportedFrameRate
    }
  }
}
