import Foundation

// Source: https://stackoverflow.com/questions/70623272/force-stereo-using-cmsamplebuffer-through-an-avcapturesession-avcaptureaudiodata
extension AVAudioPCMBuffer {
  public func toSampleBuffer() -> CMSampleBuffer? {
    let audioBufferList = self.mutableAudioBufferList
    let asbd = self.format.streamDescription
    
    var sampleBuffer: CMSampleBuffer? = nil
    var format: CMFormatDescription? = nil
    
    var status = CMAudioFormatDescriptionCreate(
      allocator: kCFAllocatorDefault,
      asbd: asbd,
      layoutSize: 0,
      layout: nil,
      magicCookieSize: 0,
      magicCookie: nil,
      extensions: nil,
      formatDescriptionOut: &format)
    
    if (status != noErr) { return nil; }
    
    var timing: CMSampleTimingInfo = CMSampleTimingInfo(
      duration: CMTime(value: 1, timescale: Int32(asbd.pointee.mSampleRate)),
      presentationTimeStamp: CMClockGetTime(CMClockGetHostTimeClock()),
      decodeTimeStamp: CMTime.invalid)
    
    status = CMSampleBufferCreate(
      allocator: kCFAllocatorDefault,
      dataBuffer: nil,
      dataReady: false,
      makeDataReadyCallback: nil,
      refcon: nil,
      formatDescription: format,
      sampleCount: CMItemCount(self.frameLength),
      sampleTimingEntryCount: 1,
      sampleTimingArray: &timing,
      sampleSizeEntryCount: 0,
      sampleSizeArray: nil,
      sampleBufferOut: &sampleBuffer)
    if (status != noErr) { NSLog("CMSAmpleBufferCreate returned error: \(status)"); return nil }
    
    status = CMSampleBufferSetDataBufferFromAudioBufferList(
      sampleBuffer!,
      blockBufferAllocator: kCFAllocatorDefault,
      blockBufferMemoryAllocator: kCFAllocatorDefault,
      flags: 0,
      bufferList: audioBufferList)
    
    if (status != noErr) { NSLog("CMSampleBufferSetDataBufferFromAudioBufferList returned error: \(status)"); return nil }
    
    return sampleBuffer
  }
}
