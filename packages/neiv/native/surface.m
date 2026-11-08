#import "surface.h"
#include <math.h>

@interface ColorSurface ()
@property(nonatomic, strong) id<MTLCommandQueue> queue;
@end

@implementation ColorSurface

- (instancetype)initWithFrame:(NSRect)frame {
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    self = [super initWithFrame:frame device:device];
    if (self) {
        self.queue = [device newCommandQueue];
        self.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
        self.framebufferOnly = YES;
        self.paused = YES;
        self.enableSetNeedsDisplay = YES;
        self.delegate = self;
        self.level = 250;
    }
    return self;
}

- (void)setLevel:(NSInteger)level {
    _level = MAX(0, MIN(1000, level));
    if (!self.suspended) [self draw];
}

- (void)setSuspended:(BOOL)suspended {
    BOOL wasSuspended = _suspended;
    _suspended = suspended;
    if (wasSuspended && !suspended) [self draw];
}

- (void)drawInMTKView:(MTKView *)view {
    if (self.suspended) return;
    id<CAMetalDrawable> drawable = view.currentDrawable;
    MTLRenderPassDescriptor *pass = view.currentRenderPassDescriptor;
    if (!drawable || !pass || !self.queue) return;
    double amount = (double)self.level / 1000.0;
    double phase = fmod(self.playbackPosition, 10.0) / 10.0;
    pass.colorAttachments[0].loadAction = MTLLoadActionClear;
    pass.colorAttachments[0].clearColor = MTLClearColorMake(0.06 + amount * 0.55 + phase * 0.2,
                                                           0.20 + phase * 0.5,
                                                           0.34 + amount * 0.20, 1.0);
    id<MTLCommandBuffer> buffer = [self.queue commandBuffer];
    id<MTLRenderCommandEncoder> encoder = [buffer renderCommandEncoderWithDescriptor:pass];
    [encoder endEncoding];
    if (self.onPresented) {
        void (^callback)(NSUInteger) = self.onPresented;
        NSUInteger token = self.presentationToken;
        [buffer addCompletedHandler:^(id<MTLCommandBuffer> commandBuffer) {
            (void)commandBuffer;
            callback(token);
        }];
    }
    [buffer presentDrawable:drawable];
    [buffer commit];
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
    (void)view; (void)size;
    if (!self.suspended) [self draw];
}

@end
