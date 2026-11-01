#import <AppKit/AppKit.h>

// Private, window-owned placement boundary for optional native views.
@interface CynaSlotHost : NSObject
@property(nonatomic, copy) void (^onPlacement)(NSString *slotId, NSView *view, NSRect frame, CGFloat scale, BOOL visible);
- (instancetype)initWithRoot:(NSView *)root webview:(NSView *)webview;
- (BOOL)registerView:(NSView *)view slotId:(NSString *)slotId;
- (BOOL)unregisterView:(NSString *)slotId;
- (BOOL)setVisible:(BOOL)visible slotId:(NSString *)slotId;
- (void)updateFromMessage:(NSDictionary *)message;
- (void)refreshPlacementForSlot:(NSString *)slotId;
- (void)invalidate;
- (void)close;
@end
