#import "video.h"

@implementation VideoSurface {
    AVPlayer *_player;
    AVPlayerItemVideoOutput *_output;
}

- (instancetype)initWithFrame:(NSRect)frame videoURL:(NSURL *)url {
    self = [super initWithFrame:frame];
    if (self) {
        AVPlayerItem *item = [AVPlayerItem playerItemWithURL:url];
        _output = [[AVPlayerItemVideoOutput alloc] initWithPixelBufferAttributes:
                   @{(NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)}];
        [item addOutput:_output];
        _player = [AVPlayer playerWithPlayerItem:item];
        _player.actionAtItemEnd = AVPlayerActionAtItemEndPause;
        self.wantsLayer = YES;
        AVPlayerLayer *layer = [AVPlayerLayer playerLayerWithPlayer:_player];
        layer.videoGravity = AVLayerVideoGravityResizeAspect;
        self.layer = layer;
    }
    return self;
}

- (AVPlayer *)player { return _player; }
- (AVPlayerItemVideoOutput *)output { return _output; }
@end
