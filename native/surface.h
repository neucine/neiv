#import <MetalKit/MetalKit.h>

@interface ColorSurface : MTKView <MTKViewDelegate>
@property(nonatomic) NSInteger level;
@property(nonatomic) BOOL suspended;
@property(nonatomic) double playbackPosition;
@property(nonatomic) NSUInteger presentationToken;
@property(nonatomic, copy) void (^onPresented)(NSUInteger token);
@end
