#import "NDIWrapper.h"
#import "Processing.NDI.Lib.h"

@implementation NDIWrapper {
  NDIlib_send_instance_t my_ndi_send;
}

+ (void)initialize {
  NDIlib_initialize();
}

- (void)start:(NSString *)name {
  if (my_ndi_send) {
    my_ndi_send = nil;
  }
  
  NDIlib_send_create_t options;
  options.p_ndi_name = [name cStringUsingEncoding: NSUTF8StringEncoding];
  options.p_groups = NULL;
  options.clock_video = true;
  options.clock_audio = false;
  my_ndi_send = NDIlib_send_create(&options);
  
  if (!my_ndi_send) {
    NSLog(@"ERROR: Failed to create sender");
  } else {
    NSLog(@"Successfully created sender");
  }
}

- (void)stop {
  if (my_ndi_send) {
    NDIlib_send_destroy(my_ndi_send);
    my_ndi_send = nil;
  }
}

- (void)sendPixelBuffer:(CVPixelBufferRef)pixelBuffer {
  if (!my_ndi_send) {
    NSLog(@"ERROR: NDI instance is nil");
    return;
  }
  
  // Create a video frame
  NDIlib_FourCC_type_e fourCC;
  OSType imageFormat = CVPixelBufferGetPixelFormatType(pixelBuffer);
  switch (imageFormat) {
    case kCVPixelFormatType_32BGRA:
      fourCC = NDIlib_FourCC_type_BGRA;
      break;
    case kCVPixelFormatType_32RGBA:
      fourCC = NDIlib_FourCC_type_RGBA;
      break;
    case kCVPixelFormatType_422YpCbCr8:
      fourCC = NDIlib_FourCC_type_UYVY;
      break;
    default:
      fourCC = NDIlib_FourCC_type_BGRA;
      break;
  }
  int width = (int) CVPixelBufferGetWidth(pixelBuffer);
  int height = (int) CVPixelBufferGetHeight(pixelBuffer);
  float aspectRatio = (float) width / (float) height;
  
  NDIlib_video_frame_v2_t video_frame;
  video_frame.frame_rate_N = 30000;
  video_frame.frame_rate_D = 1000;
  video_frame.xres = width;
  video_frame.yres = height;
  video_frame.FourCC = fourCC;
  video_frame.frame_format_type = NDIlib_frame_format_type_progressive;
  video_frame.picture_aspect_ratio = aspectRatio;
  video_frame.line_stride_in_bytes = (int)CVPixelBufferGetBytesPerRow(pixelBuffer);
  
  CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
  video_frame.p_data = CVPixelBufferGetBaseAddress(pixelBuffer);
  CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
  
  NDIlib_send_send_video_async_v2(my_ndi_send, &video_frame);
}

- (void)sendAudioBuffer:(AVAudioPCMBuffer *)audioSample {
  if (!my_ndi_send) {
    NSLog(@"ERROR: NDI instance is nil");
    return;
  }
  
  NDIlib_audio_frame_v2_t audio_frame;
  audio_frame.sample_rate = audioSample.format.sampleRate;
  audio_frame.no_channels = audioSample.format.channelCount;
  audio_frame.no_samples = audioSample.frameLength;
  audio_frame.channel_stride_in_bytes = (int)audioSample.stride;
  audio_frame.p_data = audioSample.floatChannelData[0];
  audio_frame.p_metadata = NULL;
  
  NDIlib_send_send_audio_v2(my_ndi_send, &audio_frame);
}

@end
