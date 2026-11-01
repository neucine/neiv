#import "app_host_plugin.h"
#import "surface.h"

@interface CynaColorPlugin : NSObject <CynaHostPlugin, CynaSurfaceProvider>
@end

@implementation CynaColorPlugin
- (void)attachToRoot:(NSView *)root webview:(WKWebView *)webview slots:(CynaSlotHost *)slots {
    (void)root; (void)webview; (void)slots;
}
- (void)receiveMessage:(NSDictionary *)message { (void)message; }
- (void)navigationStarted {}
- (void)close {}
- (NSDictionary<NSString *, id<CynaSurfaceProvider>> *)surfaceProviders {
    return @{@"color": self};
}
- (NSDictionary<NSString *, NSNumber *> *)surfaceCapabilities {
    BOOL available = MTLCreateSystemDefaultDevice() != nil;
    return @{@"available": @(available), @"metal": @YES, @"pixelFormat": @YES};
}
- (NSView *)createSurfaceWithOptions:(NSDictionary *)options {
    NSNumber *raw = [options[@"level"] isKindOfClass:NSNumber.class] ? options[@"level"] : nil;
    if (!raw || raw.doubleValue != raw.integerValue || raw.integerValue < 0 || raw.integerValue > 1000 || options.count != 1) return nil;
    ColorSurface *surface = [[ColorSurface alloc] initWithFrame:NSZeroRect];
    if (!surface.device) return nil;
    surface.level = raw.integerValue;
    surface.accessibilityElement = YES;
    surface.accessibilityLabel = @"Color surface";
    surface.accessibilityRole = NSAccessibilityGroupRole;
    return surface;
}
- (BOOL)setColorSurface:(NSView *)surface level:(NSInteger)level {
    if (![surface isKindOfClass:ColorSurface.class]) return NO;
    ((ColorSurface *)surface).level = level;
    return YES;
}
- (BOOL)setSurface:(NSView *)surface suspended:(BOOL)suspended {
    if (![surface isKindOfClass:ColorSurface.class]) return NO;
    ((ColorSurface *)surface).suspended = suspended;
    return YES;
}
- (void)surface:(NSView *)surface didChangeFrame:(NSRect)frame scale:(CGFloat)scale visible:(BOOL)visible {
    if (![surface isKindOfClass:ColorSurface.class]) return;
    ColorSurface *color = (ColorSurface *)surface;
    CGSize size = CGSizeMake(frame.size.width * scale, frame.size.height * scale);
    if (!CGSizeEqualToSize(color.drawableSize, size)) color.drawableSize = size;
    if (visible && !color.suspended) color.needsDisplay = YES;
}
@end
