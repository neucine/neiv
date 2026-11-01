#import <AppKit/AppKit.h>
#import "slot_host.h"
#include <assert.h>

int main(void) {
    @autoreleasepool {
        NSView *root = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 200, 100)];
        NSView *webview = [[NSView alloc] initWithFrame:root.bounds];
        [root addSubview:webview];
        CynaSlotHost *slots = [[CynaSlotHost alloc] initWithRoot:root webview:webview];
        __block NSRect reportedFrame = NSZeroRect;
        __block CGFloat reportedScale = 0;
        __block BOOL reportedVisible = NO;
        slots.onPlacement = ^(NSString *slotId, NSView *view, NSRect frame, CGFloat scale, BOOL visible) {
            (void)slotId; (void)view;
            reportedFrame = frame;
            reportedScale = scale;
            reportedVisible = visible;
        };
        NSView *surface = [NSView new];
        assert([slots registerView:surface slotId:@"preview"]);
        [slots updateFromMessage:@{@"slot":@"early", @"x":@10, @"y":@10, @"width":@40, @"height":@20}];
        NSView *early = [NSView new];
        assert([slots registerView:early slotId:@"early"]);
        assert(!early.hidden && NSEqualRects(early.frame, NSMakeRect(10, 70, 40, 20)));
        assert([slots unregisterView:@"early"]);
        assert(![slots registerView:[NSView new] slotId:@"preview"]);
        assert(surface.hidden);
        [slots updateFromMessage:@{@"slot":@"preview", @"x":@10, @"y":@20, @"width":@50, @"height":@30}];
        assert(!surface.hidden && NSEqualRects(surface.frame, NSMakeRect(10, 50, 50, 30)));
        root.frame = NSMakeRect(0, 0, 200, 140);
        assert(!surface.hidden && NSEqualRects(surface.frame, NSMakeRect(10, 90, 50, 30)));
        root.frame = NSMakeRect(0, 0, 200, 100);
        assert(reportedVisible && reportedScale == 1 && NSEqualRects(reportedFrame, surface.frame));
        assert([slots setVisible:NO slotId:@"preview"]);
        assert(surface.hidden);
        assert(!reportedVisible);
        [slots updateFromMessage:@{@"slot":@"preview", @"x":@10, @"y":@20, @"width":@50, @"height":@30}];
        assert(surface.hidden);
        assert([slots setVisible:YES slotId:@"preview"]);
        assert(!surface.hidden);
        [slots updateFromMessage:@{@"slot":@"preview", @"x":@190, @"y":@20, @"width":@50, @"height":@30}];
        assert(!surface.hidden && NSEqualRects(surface.frame, NSMakeRect(190, 50, 10, 30)));
        assert([slots unregisterView:@"preview"]);
        assert([slots registerView:surface slotId:@"preview"]);
        assert(!surface.hidden && NSEqualRects(surface.frame, NSMakeRect(190, 50, 10, 30)));
        [slots updateFromMessage:@{@"slot":@"preview", @"x":@10, @"y":@20, @"width":@0, @"height":@30}];
        assert(surface.hidden);
        [slots invalidate];
        assert([slots unregisterView:@"preview"]);
        assert(![slots unregisterView:@"preview"]);
        assert(![slots setVisible:YES slotId:@"preview"]);
        assert(surface.superview == nil);
        assert([slots registerView:surface slotId:@"preview"]);
        assert(surface.hidden);
        [slots close];
        assert(surface.superview == nil);
    }
    return 0;
}
