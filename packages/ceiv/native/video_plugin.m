#import "app_host_plugin.h"
#import "video.h"
#import <QuartzCore/QuartzCore.h>
#include <math.h>

@interface CynaVideoPlugin : NSObject <CynaHostPlugin, CynaSurfaceProvider>
@property(nonatomic, weak) WKWebView *webview;
@property(nonatomic, strong) VideoSurface *video;
@property(nonatomic, strong) NSTimer *timer;
@property(nonatomic) BOOL playing;
@property(nonatomic) double position;
@property(nonatomic) NSUInteger seekId;
@property(nonatomic) CFTimeInterval seekReceived;
@property(nonatomic) CFTimeInterval seekPresented;
@property(nonatomic) CFTimeInterval seekCompleted;
@property(nonatomic) BOOL awaitingFrame;
@property(nonatomic) BOOL seekInProgress;
@property(nonatomic) CFTimeInterval lastAnchorTime;
@property(nonatomic) float lastAnchorRate;
@property(nonatomic) NSUInteger surfaceRevision;
@end

@implementation CynaVideoPlugin
- (void)attachToRoot:(NSView *)root webview:(WKWebView *)webview slots:(CynaSlotHost *)slots {
    (void)root; (void)slots;
    self.webview = webview;
}
- (NSDictionary<NSString *, id<CynaSurfaceProvider>> *)surfaceProviders {
    return @{@"video.player": self};
}
- (NSDictionary<NSString *, NSNumber *> *)surfaceCapabilities {
    BOOL available = [[NSBundle mainBundle] URLForResource:@"sample" withExtension:@"mp4" subdirectory:@"media"] != nil;
    return @{@"available": @(available), @"media": @YES, @"decodedFrame": @YES};
}
- (NSView *)createSurfaceWithOptions:(NSDictionary *)options {
    if (options.count != 0 || self.video) return nil;
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"sample" withExtension:@"mp4" subdirectory:@"media"];
    if (!url) return nil;
    self.surfaceRevision++;
    self.video = [[VideoSurface alloc] initWithFrame:NSZeroRect videoURL:url];
    self.video.accessibilityElement = YES;
    self.video.accessibilityLabel = @"Native video preview";
    self.video.accessibilityRole = NSAccessibilityGroupRole;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(videoDidEnd:)
        name:AVPlayerItemDidPlayToEndTimeNotification object:self.video.player.currentItem];
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0 / 60.0 target:self
        selector:@selector(playbackTick:) userInfo:nil repeats:YES];
    return self.video;
}
- (void)destroySurface:(NSView *)surface {
    if (surface != self.video) return;
    self.surfaceRevision++;
    [self.timer invalidate];
    self.timer = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.video.player pause];
    self.video = nil;
    self.playing = NO;
    self.awaitingFrame = NO;
    self.seekInProgress = NO;
    self.seekId = 0;
    self.position = 0;
    self.seekReceived = 0;
    self.seekCompleted = 0;
    self.seekPresented = 0;
    self.lastAnchorRate = 0;
    self.lastAnchorTime = 0;
}
- (void)receiveMessage:(NSDictionary *)body {
    if ([body[@"kind"] isEqualToString:@"playback"]) [self handlePlayback:body];
}
- (void)navigationStarted {
    self.video.hidden = YES;
    self.playing = NO;
    [self.video.player pause];
}
- (void)close {
    if (self.video) [self destroySurface:self.video];
    self.webview = nil;
}

- (void)sendPlaybackEvent:(NSDictionary *)event {
    NSData *json = [NSJSONSerialization dataWithJSONObject:event options:0 error:nil];
    NSString *literal = [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding];
    if (literal) [self.webview evaluateJavaScript:[NSString stringWithFormat:@"window.cynaPlayback(%@)", literal]
                                completionHandler:nil];
}

- (void)sendPlaybackAnchor {
    double position = CMTimeGetSeconds(self.video.player.currentTime);
    if (!isfinite(position)) return;
    self.position = position;
    self.lastAnchorTime = CACurrentMediaTime();
    float rate = self.playing && self.video.player.timeControlStatus == AVPlayerTimeControlStatusPlaying
        ? self.video.player.rate : 0;
    self.lastAnchorRate = rate;
    [self sendPlaybackEvent:@{ @"kind": @"anchor", @"seekId": @(self.seekId),
        @"position": @(position), @"rate": @(rate),
        @"nativeTime": @(self.lastAnchorTime) }];
}

- (void)videoDidEnd:(NSNotification *)notification {
    (void)notification;
    if (!self.playing) return;
    NSUInteger seekId = self.seekId;
    NSUInteger revision = self.surfaceRevision;
    __weak CynaVideoPlugin *weakSelf = self;
    [self.video.player seekToTime:kCMTimeZero completionHandler:^(BOOL finished) {
        dispatch_async(dispatch_get_main_queue(), ^{
            CynaVideoPlugin *host = weakSelf;
            if (!host || !finished || !host.playing || host.seekId != seekId || host.surfaceRevision != revision) return;
            [host.video.player play];
            [host sendPlaybackAnchor];
        });
    }];
}

- (void)handlePlayback:(NSDictionary *)body {
    if (!self.video) return;
    NSString *action = [body[@"action"] isKindOfClass:NSString.class] ? body[@"action"] : @"";
    if ([action isEqualToString:@"toggle"]) {
        self.playing = !self.playing;
        if (self.playing) [self.video.player play];
        else [self.video.player pause];
        [self sendPlaybackAnchor];
    } else if ([action isEqualToString:@"seek"]) {
        NSNumber *value = [body[@"position"] isKindOfClass:NSNumber.class] ? body[@"position"] : nil;
        NSNumber *identifier = [body[@"seekId"] isKindOfClass:NSNumber.class] ? body[@"seekId"] : nil;
        if (!value || !identifier || !isfinite(value.doubleValue) || value.doubleValue < 0 || value.doubleValue > 10 ||
            identifier.unsignedIntegerValue <= self.seekId) return;
        self.position = value.doubleValue;
        self.seekId = identifier.unsignedIntegerValue;
        self.seekReceived = CACurrentMediaTime();
        self.seekPresented = 0;
        self.seekCompleted = 0;
        self.awaitingFrame = NO;
        self.seekInProgress = YES;
        [self sendPlaybackEvent:@{ @"kind": @"accepted", @"seekId": @(self.seekId) }];
        NSUInteger seekId = self.seekId;
        NSUInteger revision = self.surfaceRevision;
        __weak CynaVideoPlugin *weakSelf = self;
        CMTime target = CMTimeMakeWithSeconds(self.position, 600);
        [self.video.player seekToTime:target toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero
                    completionHandler:^(BOOL finished) {
            dispatch_async(dispatch_get_main_queue(), ^{
                CynaVideoPlugin *host = weakSelf;
                if (!host || !finished || seekId != host.seekId || host.surfaceRevision != revision) return;
                host.seekCompleted = CACurrentMediaTime();
                host.seekInProgress = NO;
                host.awaitingFrame = YES;
                [host sendPlaybackEvent:@{ @"kind": @"seekCompleted", @"seekId": @(seekId),
                    @"receiveToSeekMs": @((host.seekCompleted - host.seekReceived) * 1000.0) }];
            });
        }];
    } else if ([action isEqualToString:@"indicator"]) {
        NSNumber *identifier = [body[@"seekId"] isKindOfClass:NSNumber.class] ? body[@"seekId"] : nil;
        if (identifier.unsignedIntegerValue != self.seekId || !self.seekPresented) return;
        [self sendPlaybackEvent:@{ @"kind": @"measurement", @"seekId": @(self.seekId),
            @"receiveToFrameMs": @((self.seekPresented - self.seekReceived) * 1000.0),
            @"receiveToIndicatorMs": @((CACurrentMediaTime() - self.seekReceived) * 1000.0) }];
    }
}

- (void)playbackTick:(NSTimer *)timer {
    (void)timer;
    if (self.awaitingFrame) {
        CMTime displayTime = kCMTimeInvalid;
        CMTime requested = CMTimeMakeWithSeconds(self.position, 600);
        CVPixelBufferRef frame = [self.video.output copyPixelBufferForItemTime:requested itemTimeForDisplay:&displayTime];
        if (frame && CMTIME_IS_VALID(displayTime) &&
            fabs(CMTimeGetSeconds(displayTime) - self.position) <= 0.05) {
            CVPixelBufferRelease(frame);
            self.awaitingFrame = NO;
            self.seekPresented = CACurrentMediaTime();
            [self sendPlaybackEvent:@{ @"kind": @"frameReady", @"seekId": @(self.seekId),
                @"position": @(self.position),
                @"receiveToFrameMs": @((self.seekPresented - self.seekReceived) * 1000.0) }];
            [self sendPlaybackAnchor];
        } else if (CACurrentMediaTime() - self.seekReceived > 2.0) {
            if (frame) CVPixelBufferRelease(frame);
            self.awaitingFrame = NO;
            [self sendPlaybackEvent:@{ @"kind": @"frameTimeout", @"seekId": @(self.seekId) }];
        } else if (frame) {
            CVPixelBufferRelease(frame);
        }
    }
    if (self.playing && !self.video.hidden && !self.seekInProgress && !self.awaitingFrame) {
        float rate = self.video.player.timeControlStatus == AVPlayerTimeControlStatusPlaying
            ? self.video.player.rate : 0;
        if (rate != self.lastAnchorRate || CACurrentMediaTime() - self.lastAnchorTime >= 1.0)
            [self sendPlaybackAnchor];
    }
}

@end
