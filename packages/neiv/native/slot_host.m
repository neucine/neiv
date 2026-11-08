#import "slot_host.h"
#include <math.h>

@interface CynaSlotHost ()
@property(nonatomic, weak) NSView *root;
@property(nonatomic, weak) NSView *webview;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSView *> *views;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *requestedVisibility;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *placementVisibility;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSDictionary *> *placements;
@end

@implementation CynaSlotHost
- (void)reportPlacement:(NSString *)slotId view:(NSView *)view {
    if (self.onPlacement) self.onPlacement(slotId, view, view.frame,
        self.root.window.backingScaleFactor ?: 1.0, !view.hidden && view.superview != nil);
}
- (void)backingChanged:(NSNotification *)notification {
    (void)notification;
    for (NSString *slotId in self.views) {
        NSDictionary *placement = self.placements[slotId];
        if (placement) [self updateFromMessage:placement];
        else [self reportPlacement:slotId view:self.views[slotId]];
    }
}
- (instancetype)initWithRoot:(NSView *)root webview:(NSView *)webview {
    if (!(self = [super init])) return nil;
    self.root = root;
    self.webview = webview;
    self.views = [NSMutableDictionary new];
    self.requestedVisibility = [NSMutableDictionary new];
    self.placementVisibility = [NSMutableDictionary new];
    self.placements = [NSMutableDictionary new];
    if (root.window) [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(backingChanged:)
        name:NSWindowDidChangeBackingPropertiesNotification object:root.window];
    return self;
}
- (BOOL)registerView:(NSView *)view slotId:(NSString *)slotId {
    NSAssert(NSThread.isMainThread, @"slot registration must run on the main thread");
    if (!view || ![slotId isKindOfClass:NSString.class] || !slotId.length ||
        slotId.length > 64 || self.views[slotId] || !self.root) return NO;
    view.hidden = YES;
    // Web coordinates are measured from the top. Keep that edge anchored while
    // AppKit resizes the WebView, before the next WebKit placement message.
    view.autoresizingMask = NSViewMinYMargin;
    [self.root addSubview:view];
    self.views[slotId] = view;
    self.requestedVisibility[slotId] = @YES;
    self.placementVisibility[slotId] = @NO;
    if (self.placements[slotId]) [self updateFromMessage:self.placements[slotId]];
    else [self reportPlacement:slotId view:view];
    return YES;
}
- (BOOL)unregisterView:(NSString *)slotId {
    NSAssert(NSThread.isMainThread, @"slot cleanup must run on the main thread");
    NSView *view = self.views[slotId];
    if (!view) return NO;
    view.hidden = YES;
    [self reportPlacement:slotId view:view];
    [view removeFromSuperview];
    [self.views removeObjectForKey:slotId];
    [self.requestedVisibility removeObjectForKey:slotId];
    [self.placementVisibility removeObjectForKey:slotId];
    return YES;
}
- (BOOL)setVisible:(BOOL)visible slotId:(NSString *)slotId {
    NSAssert(NSThread.isMainThread, @"slot visibility must run on the main thread");
    NSView *view = self.views[slotId];
    if (!view) return NO;
    self.requestedVisibility[slotId] = @(visible);
    view.hidden = !visible || ![self.placementVisibility[slotId] boolValue];
    if (!view.hidden) view.needsDisplay = YES;
    [self reportPlacement:slotId view:view];
    return YES;
}
- (void)updateFromMessage:(NSDictionary *)message {
    NSAssert(NSThread.isMainThread, @"slot updates must run on the main thread");
    NSString *slotId = [message[@"slot"] isKindOfClass:NSString.class] ? message[@"slot"] : nil;
    if (!slotId.length || slotId.length > 64) return;
    NSView *view = self.views[slotId];
    NSNumber *x = [message[@"x"] isKindOfClass:NSNumber.class] ? message[@"x"] : nil;
    NSNumber *y = [message[@"y"] isKindOfClass:NSNumber.class] ? message[@"y"] : nil;
    NSNumber *width = [message[@"width"] isKindOfClass:NSNumber.class] ? message[@"width"] : nil;
    NSNumber *height = [message[@"height"] isKindOfClass:NSNumber.class] ? message[@"height"] : nil;
    if (!x || !y || !width || !height || !isfinite(x.doubleValue) || !isfinite(y.doubleValue) ||
        !isfinite(width.doubleValue) || !isfinite(height.doubleValue) || width.doubleValue <= 0 ||
        height.doubleValue <= 0 || width.doubleValue > 10000 || height.doubleValue > 10000 ||
        fabs(x.doubleValue) > 100000 || fabs(y.doubleValue) > 100000) {
        [self.placements removeObjectForKey:slotId];
        if (!view) return;
        self.placementVisibility[slotId] = @NO;
        view.hidden = YES;
        [self reportPlacement:slotId view:view];
        return;
    }
    if (self.placements[slotId] || self.placements.count < 64)
        self.placements[slotId] = @{@"slot":slotId, @"x":x, @"y":y, @"width":width, @"height":height};
    if (!view || !self.webview) return;
    NSRect bounds = self.webview.bounds;
    NSRect frame = NSMakeRect(x.doubleValue, NSHeight(bounds) - y.doubleValue - height.doubleValue,
                              width.doubleValue, height.doubleValue);
    NSRect visible = NSIntersectionRect(frame, bounds);
    BOOL inBounds = !NSIsEmptyRect(visible);
    self.placementVisibility[slotId] = @(inBounds);
    view.hidden = !inBounds || ![self.requestedVisibility[slotId] boolValue];
    if (inBounds) {
        view.frame = visible;
        if (!view.hidden) view.needsDisplay = YES;
    }
    [self reportPlacement:slotId view:view];
}
- (void)refreshPlacementForSlot:(NSString *)slotId {
    NSView *view = self.views[slotId];
    if (!view) return;
    NSDictionary *placement = self.placements[slotId];
    if (placement) [self updateFromMessage:placement];
    else [self reportPlacement:slotId view:view];
}
- (void)invalidate {
    NSAssert(NSThread.isMainThread, @"slot invalidation must run on the main thread");
    for (NSString *slotId in self.views) {
        self.placementVisibility[slotId] = @NO;
        self.views[slotId].hidden = YES;
        [self reportPlacement:slotId view:self.views[slotId]];
    }
    [self.placements removeAllObjects];
}
- (void)close {
    NSAssert(NSThread.isMainThread, @"slot cleanup must run on the main thread");
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    for (NSView *view in self.views.allValues) [view removeFromSuperview];
    [self.views removeAllObjects];
    [self.requestedVisibility removeAllObjects];
    [self.placementVisibility removeAllObjects];
    [self.placements removeAllObjects];
}
@end
