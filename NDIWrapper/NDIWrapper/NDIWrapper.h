#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface NDIWrapper : NSObject

+ (void)initialize;
- (void)start:(NSString *)name;
- (void)stop;
- (void)sendPixelBuffer:(CVPixelBufferRef)pixelBuffer;
- (void)send:(CVPixelBufferRef)videoSample withAudio:(CMSampleBufferRef)audioSample;
@end
