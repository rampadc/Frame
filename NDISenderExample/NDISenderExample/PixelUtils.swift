//
//  PixelsUtils.swift
//  NDISenderExample
//
//  Created by Cong Nguyen on 6/4/2022.
//

import Foundation
import os

class PixelUtils {
  private let logger = Logger(subsystem: Config.shared.subsystem, category: "CameraCapture")
  static let instance = PixelUtils()
  
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
      logger.error("Cannot create sample buffer. Error: kCMSampleBufferError_AllocationFailed")
    }
    if osStatus == kCMSampleBufferError_RequiredParameterMissing {
      logger.error("Cannot create sample buffer. Error: kCMSampleBufferError_RequiredParameterMissing")
    }
    if osStatus == kCMSampleBufferError_AlreadyHasDataBuffer {
      logger.error("Cannot create sample buffer. Error: kCMSampleBufferError_AlreadyHasDataBuffer")
    }
    if osStatus == kCMSampleBufferError_BufferNotReady {
      logger.error("Cannot create sample buffer. Error: kCMSampleBufferError_BufferNotReady")
    }
    if osStatus == kCMSampleBufferError_SampleIndexOutOfRange {
      logger.error("Cannot create sample buffer. Error: kCMSampleBufferError_SampleIndexOutOfRange")
    }
    if osStatus == kCMSampleBufferError_BufferHasNoSampleSizes {
      logger.error("Cannot create sample buffer. Error: kCMSampleBufferError_BufferHasNoSampleSizes")
    }
    if osStatus == kCMSampleBufferError_BufferHasNoSampleTimingInfo {
      logger.error("Cannot create sample buffer. Error: kCMSampleBufferError_BufferHasNoSampleTimingInfo")
    }
    if osStatus == kCMSampleBufferError_ArrayTooSmall {
      logger.error("Cannot create sample buffer. Error: kCMSampleBufferError_ArrayTooSmall")
    }
    if osStatus == kCMSampleBufferError_InvalidEntryCount {
      logger.error("Cannot create sample buffer. Error: kCMSampleBufferError_InvalidEntryCount")
    }
    if osStatus == kCMSampleBufferError_CannotSubdivide {
      logger.error("Cannot create sample buffer. Error: kCMSampleBufferError_CannotSubdivide")
    }
    if osStatus == kCMSampleBufferError_SampleTimingInfoInvalid {
      logger.error("Cannot create sample buffer. Error: kCMSampleBufferError_SampleTimingInfoInvalid")
    }
    if osStatus == kCMSampleBufferError_InvalidMediaTypeForOperation {
      logger.error("Cannot create sample buffer. Error: kCMSampleBufferError_InvalidMediaTypeForOperation")
    }
    if osStatus == kCMSampleBufferError_InvalidSampleData {
      logger.error("Cannot create sample buffer. Error: kCMSampleBufferError_InvalidSampleData")
    }
    if osStatus == kCMSampleBufferError_InvalidMediaFormat {
      logger.error("Cannot create sample buffer. Error: kCMSampleBufferError_InvalidMediaFormat")
    }
    if osStatus == kCMSampleBufferError_Invalidated {
      logger.error("Cannot create sample buffer. Error: kCMSampleBufferError_Invalidated")
    }
    if osStatus == kCMSampleBufferError_DataFailed {
      logger.error("Cannot create sample buffer. Error: kCMSampleBufferError_DataFailed")
    }
    if osStatus == kCMSampleBufferError_DataCanceled {
      logger.error("Cannot create sample buffer. Error: kCMSampleBufferError_DataCanceled")
    }
    
    guard let buffer = sampleBuffer else {
      logger.error("Cannot create sample buffer. Error: UNKNOWN")
      return nil
    }
    
    return buffer
  }
  
  private init() {}
}
