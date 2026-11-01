#import <AppKit/AppKit.h>
#import <AVFoundation/AVFoundation.h>

@interface VideoSurface : NSView
@property(nonatomic, strong, readonly) AVPlayer *player;
@property(nonatomic, strong, readonly) AVPlayerItemVideoOutput *output;
- (instancetype)initWithFrame:(NSRect)frame videoURL:(NSURL *)url;
@end
