#import "app_host_plugin.h"

@interface CynaDemoSurface : NSView
@property(nonatomic, weak) NSView *webview;
@end

@implementation CynaDemoSurface
- (BOOL)acceptsFirstResponder { return YES; }
- (BOOL)becomeFirstResponder {
    self.layer.borderColor = NSColor.systemYellowColor.CGColor;
    self.layer.borderWidth = 3;
    return YES;
}
- (BOOL)resignFirstResponder {
    self.layer.borderWidth = 0;
    return YES;
}
- (void)mouseDown:(NSEvent *)event {
    (void)event;
    [self.window makeFirstResponder:self];
}
- (void)keyDown:(NSEvent *)event {
    if (event.keyCode == 53) { [self.window makeFirstResponder:self.webview]; return; }
    if ([[event.charactersIgnoringModifiers lowercaseString] isEqualToString:@"a"]) {
        self.layer.backgroundColor = NSColor.systemPurpleColor.CGColor;
        self.accessibilityValue = @"Key A received";
    }
}
@end

@interface CynaDemoPlugin : NSObject <CynaHostPlugin, CynaSurfaceProvider>
@property(nonatomic, weak) NSView *webview;
@end

@implementation CynaDemoPlugin
- (void)attachToRoot:(NSView *)root webview:(WKWebView *)webview slots:(CynaSlotHost *)slots {
    (void)root; (void)slots;
    self.webview = webview;
}
- (void)receiveMessage:(NSDictionary *)message { (void)message; }
- (void)navigationStarted {}
- (void)close {}
- (NSDictionary<NSString *, id<CynaSurfaceProvider>> *)surfaceProviders {
    return @{@"demo.color":self};
}
- (NSView *)createSurfaceWithOptions:(NSDictionary *)options {
    if (options.count != 0) return nil;
    CynaDemoSurface *view = [CynaDemoSurface new];
    view.webview = self.webview;
    view.wantsLayer = YES;
    view.layer.backgroundColor = NSColor.systemTealColor.CGColor;
    view.accessibilityElement = YES;
    view.accessibilityLabel = @"App provider surface";
    view.accessibilityRole = NSAccessibilityGroupRole;
    return view;
}
@end
