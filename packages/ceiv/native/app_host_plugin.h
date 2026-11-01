#import <AppKit/AppKit.h>
#import <WebKit/WebKit.h>
#import "slot_host.h"

// Private macOS extension point. Ordinary apps do not link a plugin.
@protocol CynaSurfaceProvider <NSObject>
- (NSView *)createSurfaceWithOptions:(NSDictionary *)options;
@optional
- (NSDictionary<NSString *, NSNumber *> *)surfaceCapabilities;
- (BOOL)setSurface:(NSView *)surface suspended:(BOOL)suspended;
- (void)surface:(NSView *)surface didChangeFrame:(NSRect)frame scale:(CGFloat)scale visible:(BOOL)visible;
- (void)destroySurface:(NSView *)surface;
@end

@protocol CynaHostPlugin <NSObject>
- (void)attachToRoot:(NSView *)root webview:(WKWebView *)webview slots:(CynaSlotHost *)slots;
- (void)receiveMessage:(NSDictionary *)message;
- (void)navigationStarted;
- (void)close;
@optional
- (NSDictionary<NSString *, id<CynaSurfaceProvider>> *)surfaceProviders;
- (BOOL)setColorSurface:(NSView *)surface level:(NSInteger)level;
@end
