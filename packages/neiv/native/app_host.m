#import "app_host.h"
#import <AppKit/AppKit.h>
#import <WebKit/WebKit.h>
#import <CoreGraphics/CoreGraphics.h>
#import <UserNotifications/UserNotifications.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import "app_host_plugin.h"
#import "asset_policy.h"
#import "bridge_policy.h"
#import "command_validation.h"
#include <math.h>
#include <string.h>
#include <stdio.h>
static _Thread_local long long currentWindowHandle;

static NSDictionary *initialWindow;
static BOOL quitOnLastWindow = YES;
static NSDictionary *eventSchemas;
static NSArray<NSString *> *appCapabilities;
static NSStatusItem *statusItem;
static NSDictionary *appManifest;
static void (*lifecycleCallback)(const char *);
void neiv_app_on_lifecycle(void (*callback)(const char *)) { lifecycleCallback = callback; }
@class CynaAppHost;
static __weak CynaAppHost *runningHost;
static void refreshHostMenu(void);
static NSArray *applicationMenuTree;
static NSSet<NSString *> *applicationActionIds;
static NSMutableDictionary<NSString *, NSDictionary *> *backendActionStates;
static int (*backendActionCallback)(const char *, const char *, long long, const char *);
void neiv_menu_on_action(int (*callback)(const char *, const char *, long long, const char *)) { backendActionCallback = callback; }
static void onMain(void (^operation)(void));
void neiv_app_set_quit_on_last_window(int enabled) { quitOnLastWindow = enabled != 0; }
static void refreshHostMenu(void);
static NSMutableDictionary<NSString *, NSArray *> *contextMenuTrees;
static BOOL menuTreeValid(NSArray *tree, NSMutableSet *ids, NSMutableSet *actionIds, NSMutableSet *shortcuts, NSUInteger depth) {
    if (depth > 8 || tree.count > 64) return NO;
    NSSet *roles = [NSSet setWithArray:@[@"quit", @"close", @"undo", @"redo", @"cut", @"copy", @"paste", @"selectAll"]];
    for (id raw in tree) {
        if (![raw isKindOfClass:NSDictionary.class]) return NO;
        NSDictionary *item = raw;
        if ([item[@"separator"] isEqual:@YES]) continue;
        NSString *label = [item[@"label"] isKindOfClass:NSString.class] ? item[@"label"] : nil;
        if (!label.length || label.length > 80) return NO;
        NSArray *children = [item[@"items"] isKindOfClass:NSArray.class] ? item[@"items"] : nil;
        if (children) {
            NSString *submenuId = [item[@"id"] isKindOfClass:NSString.class] ? item[@"id"] : nil;
            if (!submenuId.length || submenuId.length > 100 || [ids containsObject:submenuId]) return NO;
            [ids addObject:submenuId];
            if (!menuTreeValid(children, ids, actionIds, shortcuts, depth + 1)) return NO;
            continue;
        }
        NSString *role = [item[@"role"] isKindOfClass:NSString.class] ? item[@"role"] : nil;
        NSString *identifier = [item[@"id"] isKindOfClass:NSString.class] ? item[@"id"] : nil;
        if (role) { if (![roles containsObject:role] || identifier) return NO; }
        else if (!identifier.length || identifier.length > 100 || [ids containsObject:identifier]) return NO;
        if (identifier) { [ids addObject:identifier]; [actionIds addObject:identifier]; }
        NSString *shortcut = [item[@"shortcut"] isKindOfClass:NSString.class] ? item[@"shortcut"] : nil;
        if (shortcut) {
            NSArray<NSString *> *parts = [shortcut componentsSeparatedByString:@"+"];
            if (parts.count < 2 || parts.count > 5) return NO;
            NSString *key = parts.lastObject.lowercaseString;
            BOOL letter = key.length == 1 && [[NSCharacterSet letterCharacterSet] characterIsMember:[key characterAtIndex:0]];
            BOOL named = [@[@"enter", @"escape", @"f1", @"f2", @"f3", @"f4", @"f5", @"f6",
                @"f7", @"f8", @"f9", @"f10", @"f11", @"f12"] containsObject:key];
            if (!letter && !named) return NO;
            NSMutableSet *mods = [NSMutableSet new];
            for (NSString *part in [parts subarrayWithRange:NSMakeRange(0, parts.count - 1)]) {
                if (![@[@"Cmd", @"CmdOrCtrl", @"Ctrl", @"Alt", @"Shift"] containsObject:part] || [mods containsObject:part]) return NO;
                [mods addObject:part];
            }
            if ([mods containsObject:@"Cmd"] && [mods containsObject:@"CmdOrCtrl"]) return NO;
            if ([mods containsObject:@"CmdOrCtrl"]) { [mods removeObject:@"CmdOrCtrl"]; [mods addObject:@"Cmd"]; }
            NSString *canonical = [NSString stringWithFormat:@"%@:%@", [[mods.allObjects sortedArrayUsingSelector:@selector(compare:)] componentsJoinedByString:@"+"], key];
            BOOL command = [mods containsObject:@"Cmd"];
            if ([shortcuts containsObject:canonical] || (command && mods.count == 1 && [@[@"q",@"w",@"n",@"r"] containsObject:key])) return NO;
            [shortcuts addObject:canonical];
        }
    }
    return YES;
}
int neiv_menu_set_application(const char *treeJson) {
    if (!treeJson || strlen(treeJson) > 65536) return -1;
    NSString *text = [NSString stringWithUTF8String:treeJson];
    NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding];
    id tree = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
    NSMutableSet *ids = [NSMutableSet new];
    NSMutableSet *actionIds = [NSMutableSet new];
    if (![tree isKindOfClass:NSArray.class] || !menuTreeValid(tree, ids, actionIds, [NSMutableSet new], 0)) return -1;
    applicationMenuTree = tree;
    applicationActionIds = actionIds;
    backendActionStates = [NSMutableDictionary new];
    return 0;
}
int neiv_menu_set_state(const char *actionId, int enabled, int checked, int visible) {
    if (!actionId) return -1;
    NSString *identifier = [NSString stringWithUTF8String:actionId];
    if (![applicationActionIds containsObject:identifier]) return -1;
    onMain(^{
        backendActionStates[identifier] = @{@"enabled":@((BOOL)enabled), @"checked":@((BOOL)checked), @"visible":@((BOOL)visible)};
        refreshHostMenu();
    });
    return 0;
}
int neiv_menu_register_context(const char *identifier, const char *treeJson) {
    if (!identifier || !treeJson || strlen(identifier) > 100 || strlen(treeJson) > 65536) return -1;
    NSString *name = [NSString stringWithUTF8String:identifier];
    NSString *text = [NSString stringWithUTF8String:treeJson];
    NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding];
    id tree = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
    if (!name.length || ![tree isKindOfClass:NSArray.class] || !menuTreeValid(tree, [NSMutableSet new], [NSMutableSet new], [NSMutableSet new], 0)) return -1;
    if (!contextMenuTrees) contextMenuTrees = [NSMutableDictionary new];
    if (contextMenuTrees[name]) return -1;
    contextMenuTrees[name] = tree;
    return 0;
}

@interface CynaContextPopup : NSObject
@property(nonatomic, copy) NSString *selected;
- (NSMenu *)menuWithTree:(NSArray *)tree;
@end
static void applyMenuStates(NSMenu *menu, NSDictionary *states) {
    for (NSMenuItem *item in menu.itemArray) {
        if (item.submenu) applyMenuStates(item.submenu, states);
        if (!item.representedObject) continue;
        NSDictionary *state = states[item.representedObject] ?: backendActionStates[item.representedObject];
        item.enabled = [state[@"enabled"] boolValue];
        item.hidden = state && [state[@"visible"] isEqual:@NO];
        item.state = [state[@"checked"] boolValue] ? NSControlStateValueOn : NSControlStateValueOff;
    }
}
@implementation CynaContextPopup
- (void)choose:(NSMenuItem *)item { self.selected = item.representedObject; }
- (NSMenu *)menuWithTree:(NSArray *)tree {
    NSMenu *menu = [NSMenu new];
    for (id raw in tree) {
        if (![raw isKindOfClass:NSDictionary.class]) continue;
        NSDictionary *item = raw;
        if ([item[@"separator"] isEqual:@YES]) { [menu addItem:NSMenuItem.separatorItem]; continue; }
        NSString *label = [item[@"label"] isKindOfClass:NSString.class] ? item[@"label"] : nil;
        if (!label.length || label.length > 80) continue;
        NSArray *children = [item[@"items"] isKindOfClass:NSArray.class] ? item[@"items"] : nil;
        if (children) {
            NSMenuItem *parent = [NSMenuItem new]; parent.title = label;
            parent.submenu = [self menuWithTree:children]; [menu addItem:parent]; continue;
        }
        NSString *actionId = [item[@"id"] isKindOfClass:NSString.class] ? item[@"id"] : nil;
        NSString *role = [item[@"role"] isKindOfClass:NSString.class] ? item[@"role"] : nil;
        if (!actionId.length && !role.length) continue;
        NSDictionary *roleSelectors = @{@"quit":@"terminate:", @"close":@"performClose:", @"undo":@"undo:",
            @"redo":@"redo:", @"cut":@"cut:", @"copy":@"copy:", @"paste":@"paste:", @"selectAll":@"selectAll:"};
        SEL action = role ? NSSelectorFromString(roleSelectors[role]) : @selector(choose:);
        NSMenuItem *entry = [[NSMenuItem alloc] initWithTitle:label action:action keyEquivalent:@""];
        if (actionId) { entry.representedObject = actionId; entry.target = self; }
        else if ([role isEqualToString:@"quit"]) entry.target = NSApp;
        [menu addItem:entry];
    }
    return menu;
}
@end
int neiv_set_initial_window(const char *title, int width, int height) {
    if (!title || width < 320 || width > 3000 || height < 240 || height > 2000) return -1;
    NSString *name = [NSString stringWithUTF8String:title];
    if (!name || !name.length || name.length > 80) return -1;
    initialWindow = @{@"title":name, @"width":@(width), @"height":@(height)};
    return 0;
}

@interface CynaAssetHandler : NSObject <WKURLSchemeHandler>
@property(nonatomic, copy) NSString *root;
@end
@implementation CynaAssetHandler
- (void)webView:(WKWebView *)webView startURLSchemeTask:(id<WKURLSchemeTask>)task {
    (void)webView;
    NSURL *url = task.request.URL;
    NSString *file = CynaAssetPath(self.root, url);
    if (!file) {
        [task didFailWithError:[NSError errorWithDomain:@"CynaApp" code:403 userInfo:nil]]; return;
    }
    NSData *data = [NSData dataWithContentsOfFile:file];
    if (!data) { [task didFailWithError:[NSError errorWithDomain:@"CynaApp" code:404 userInfo:nil]]; return; }
    NSString *mime = CynaAssetMime(file);
    NSURLResponse *response = [[NSURLResponse alloc] initWithURL:url MIMEType:mime expectedContentLength:data.length
                                               textEncodingName:[mime hasPrefix:@"text/"] ? @"utf-8" : nil];
    [task didReceiveResponse:response]; [task didReceiveData:data]; [task didFinish];
}
- (void)webView:(WKWebView *)webView stopURLSchemeTask:(id<WKURLSchemeTask>)task { (void)webView; (void)task; }
@end

@interface CynaWindow : NSObject <NSWindowDelegate, WKScriptMessageHandler, WKNavigationDelegate>
@property(nonatomic, strong) NSWindow *window;
@property(nonatomic, strong) WKWebView *webview;
@property(nonatomic, copy) NSString *assetRoot;
@property(nonatomic, strong) NSArray<NSString *> *capabilities;
@property(nonatomic, copy) NSString *windowId;
@property(nonatomic) long long handle;
@property(nonatomic, copy) void (^onClose)(NSString *windowId);
@property(nonatomic, copy) void (^onState)(NSDictionary *event);
@property(nonatomic) NSUInteger generation;
@property(nonatomic, strong) NSMutableSet<NSNumber *> *pendingIds;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *subscriptions;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *subscriptionTopics;
@property(nonatomic, strong) NSDictionary<NSString *, NSDictionary *> *actionStates;
@property(nonatomic, strong) NSMutableSet<NSString *> *pendingActions;
@property(nonatomic) BOOL closeGuardEnabled;
@property(nonatomic) BOOL closeApproved;
@property(nonatomic, copy) NSString *pendingCloseRequest;
@property(nonatomic) NSUInteger eventsInFlight;
@property(nonatomic) CynaCommandDispatcher dispatcher;
@property(nonatomic, strong) id<CynaHostPlugin> plugin;
@property(nonatomic, strong) CynaSlotHost *slots;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSTextField *> *textSlots;
@property(nonatomic, strong) NSMutableDictionary<NSNumber *, NSString *> *surfaceIds;
@property(nonatomic, strong) NSMutableDictionary<NSNumber *, NSView *> *nativeSurfaces;
@property(nonatomic, strong) NSMutableDictionary<NSNumber *, id<CynaSurfaceProvider>> *surfaceProviders;
@property(nonatomic, strong) NSMutableSet<NSNumber *> *attachedSurfaces;
@property(nonatomic, strong) NSMutableDictionary<NSNumber *, NSNumber *> *surfaceVisibility;
- (instancetype)initWithManifest:(NSDictionary *)manifest dispatcher:(CynaCommandDispatcher)dispatcher;
@end

@implementation CynaWindow
- (instancetype)initWithManifest:(NSDictionary *)manifest dispatcher:(CynaCommandDispatcher)dispatcher {
    if (!(self = [super init])) return nil;
    self.windowId = NSUUID.UUID.UUIDString;
    self.pendingIds = [NSMutableSet new];
    self.subscriptions = [NSMutableDictionary new];
    self.subscriptionTopics = [NSMutableDictionary new];
    self.actionStates = @{};
    self.pendingActions = [NSMutableSet new];
    self.dispatcher = dispatcher;
    self.textSlots = [NSMutableDictionary new];
    self.surfaceIds = [NSMutableDictionary new];
    self.nativeSurfaces = [NSMutableDictionary new];
    self.surfaceProviders = [NSMutableDictionary new];
    self.attachedSurfaces = [NSMutableSet new];
    self.surfaceVisibility = [NSMutableDictionary new];
    self.capabilities = [manifest[@"capabilities"] isKindOfClass:NSArray.class] ? manifest[@"capabilities"] : @[];
    NSDictionary *options = initialWindow ?: @{};
    CGFloat width = [options[@"width"] doubleValue];
    CGFloat height = [options[@"height"] doubleValue];
    if (width < 320 || width > 3000) width = 900;
    if (height < 240 || height > 2000) height = 600;
    NSRect bounds = NSMakeRect(0, 0, width, height);
    self.window = [[NSWindow alloc] initWithContentRect:bounds styleMask:NSWindowStyleMaskTitled |
        NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable
        backing:NSBackingStoreBuffered defer:NO];
    self.window.releasedWhenClosed = NO;
    // Close without a transform animation so AppKit has no animation retaining
    // the window after the close transaction. The host releases it next turn.
    self.window.animationBehavior = NSWindowAnimationBehaviorNone;
    self.window.title = [options[@"title"] isKindOfClass:NSString.class] ? options[@"title"] : manifest[@"name"];
    CGFloat minWidth = [options[@"minWidth"] doubleValue];
    CGFloat minHeight = [options[@"minHeight"] doubleValue];
    if (minWidth > 0 && minHeight > 0) self.window.contentMinSize = NSMakeSize(minWidth, minHeight);
    self.window.delegate = self;
    NSScreen *target = NSScreen.mainScreen;
    for (NSScreen *screen in NSScreen.screens) {
        NSNumber *number = screen.deviceDescription[@"NSScreenNumber"];
        if (number && CGDisplayIsBuiltin(number.unsignedIntValue)) { target = screen; break; }
    }
    [self.window setFrameOrigin:NSMakePoint(NSMidX(target.visibleFrame) - width / 2,
                                           NSMidY(target.visibleFrame) - height / 2)];
    self.assetRoot = [[[[NSBundle mainBundle].resourcePath stringByAppendingPathComponent:@"web"] stringByResolvingSymlinksInPath] stringByStandardizingPath];
    WKWebViewConfiguration *config = [WKWebViewConfiguration new];
    config.websiteDataStore = WKWebsiteDataStore.nonPersistentDataStore;
    [config.userContentController addScriptMessageHandler:self name:@"cyna"];
    NSString *pluginName = manifest[@"nativePlugin"];
    if ([manifest[@"localHttp"] isEqual:@YES] || [manifest[@"localHttp"] isKindOfClass:NSDictionary.class])
        pluginName = @"NeivHttpPlugin";
    [config.userContentController addScriptMessageHandler:self name:@"surface"];
    if ([pluginName isKindOfClass:NSString.class]) {
        Class pluginClass = NSClassFromString(pluginName);
        if (pluginClass && [pluginClass conformsToProtocol:@protocol(CynaHostPlugin)]) {
            self.plugin = [pluginClass new];
        }
    }
    CynaAssetHandler *assets = [CynaAssetHandler new];
    assets.root = self.assetRoot;
    [config setURLSchemeHandler:assets forURLScheme:@"cyna-app"];
    self.webview = [[WKWebView alloc] initWithFrame:bounds configuration:config];
    self.webview.navigationDelegate = self;
    self.webview.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    NSView *root = [[NSView alloc] initWithFrame:bounds];
    root.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [root addSubview:self.webview];
    self.window.contentView = root;
    self.slots = [[CynaSlotHost alloc] initWithRoot:root webview:self.webview];
    __weak CynaWindow *weakWindow = self;
    self.slots.onPlacement = ^(NSString *slotId, NSView *view, NSRect frame, CGFloat scale, BOOL visible) {
        CynaWindow *window = weakWindow;
        if (!window) return;
        if (!visible && window.window.firstResponder == view)
            [window.window makeFirstResponder:window.webview];
        for (NSNumber *identifier in window.nativeSurfaces) {
            if (window.nativeSurfaces[identifier] != view || ![window.surfaceIds[identifier] isEqualToString:slotId]) continue;
            id<CynaSurfaceProvider> provider = window.surfaceProviders[identifier];
            if ([provider respondsToSelector:@selector(surface:didChangeFrame:scale:visible:)])
                [provider surface:view didChangeFrame:frame scale:scale visible:visible];
            break;
        }
    };
    [self.plugin attachToRoot:root webview:self.webview slots:self.slots];
    NSString *entry = [manifest[@"entry"] isKindOfClass:NSString.class] ? manifest[@"entry"] : @"index.html";
    NSURL *url = [NSURL URLWithString:[@"cyna-app://local/" stringByAppendingString:entry]];
    [self.webview loadRequest:[NSURLRequest requestWithURL:url]];
    if (![options[@"visible"] isEqual:@NO]) [self.window makeKeyAndOrderFront:nil];
    return self;
}
- (void)windowWillClose:(NSNotification *)note {
    (void)note;
    [self.webview evaluateJavaScript:@"window.cynaInvalidate?.('window closed')" completionHandler:nil];
    self.generation++;
    [self.pendingIds removeAllObjects];
    [self.subscriptions removeAllObjects];
    [self.subscriptionTopics removeAllObjects];
    [self.pendingActions removeAllObjects];
    self.pendingCloseRequest = nil;
    self.eventsInFlight = 0;
    [self.webview.configuration.userContentController removeScriptMessageHandlerForName:@"cyna"];
    [self.webview.configuration.userContentController removeScriptMessageHandlerForName:@"surface"];
    for (NSNumber *identifier in self.nativeSurfaces) {
        id<CynaSurfaceProvider> provider = self.surfaceProviders[identifier];
        if ([provider respondsToSelector:@selector(destroySurface:)]) [provider destroySurface:self.nativeSurfaces[identifier]];
    }
    [self.nativeSurfaces removeAllObjects];
    [self.surfaceProviders removeAllObjects];
    [self.plugin close];
    [self.slots close];
    [self.textSlots removeAllObjects];
    [self.surfaceIds removeAllObjects];
    [self.attachedSurfaces removeAllObjects];
    [self.surfaceVisibility removeAllObjects];
    self.webview.navigationDelegate = nil;
    self.window.delegate = nil;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.onClose) self.onClose(self.windowId);
    });
}
- (BOOL)windowShouldClose:(NSWindow *)sender {
    (void)sender;
    if (self.closeApproved || !self.closeGuardEnabled) return YES;
    if (self.pendingCloseRequest) return NO;
    NSString *requestId = NSUUID.UUID.UUIDString;
    self.pendingCloseRequest = requestId;
    NSUInteger generation = self.generation;
    NSData *json = [NSJSONSerialization dataWithJSONObject:@{@"requestId":requestId} options:0 error:nil];
    NSString *literal = [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding];
    [self.webview evaluateJavaScript:[NSString stringWithFormat:@"window.cynaCloseRequest?.(%@)", literal] completionHandler:nil];
    __weak CynaWindow *weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 300 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        CynaWindow *window = weakSelf;
        if (window.generation == generation && [window.pendingCloseRequest isEqualToString:requestId])
            window.pendingCloseRequest = nil; // Timeout cancels the close.
    });
    return NO;
}
- (void)windowDidBecomeKey:(NSNotification *)note {
    (void)note; refreshHostMenu();
    if (self.handle && self.onState) self.onState(@{@"state":@"focused", @"window":@(self.handle)});
}
- (void)windowDidResignKey:(NSNotification *)note {
    (void)note; refreshHostMenu();
    if (self.handle && self.onState) self.onState(@{@"state":@"blurred", @"window":@(self.handle)});
}
- (void)windowDidResize:(NSNotification *)note {
    (void)note;
    if (self.handle && self.onState) self.onState(@{@"state":@"resized", @"window":@(self.handle),
        @"width":@((int)self.window.contentView.bounds.size.width),
        @"height":@((int)self.window.contentView.bounds.size.height)});
}
- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
    (void)webView; (void)navigation;
    [self.webview evaluateJavaScript:@"window.cynaInvalidate?.('page navigated')" completionHandler:nil];
    self.generation++;
    [self.pendingIds removeAllObjects];
    [self.subscriptions removeAllObjects];
    [self.subscriptionTopics removeAllObjects];
    [self.pendingActions removeAllObjects];
    self.closeGuardEnabled = NO;
    self.pendingCloseRequest = nil;
    self.actionStates = @{};
    self.eventsInFlight = 0;
    [self.slots invalidate];
    for (NSString *slotId in self.textSlots.allKeys) [self.slots unregisterView:slotId];
    for (NSString *slotId in self.surfaceIds.allValues) [self.slots unregisterView:slotId];
    [self.textSlots removeAllObjects];
    [self.surfaceIds removeAllObjects];
    [self.attachedSurfaces removeAllObjects];
    [self.surfaceVisibility removeAllObjects];
    for (NSNumber *identifier in self.nativeSurfaces) {
        id<CynaSurfaceProvider> provider = self.surfaceProviders[identifier];
        if ([provider respondsToSelector:@selector(destroySurface:)]) [provider destroySurface:self.nativeSurfaces[identifier]];
    }
    [self.nativeSurfaces removeAllObjects];
    [self.surfaceProviders removeAllObjects];
    [self.plugin navigationStarted];
}
- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    (void)webView; (void)navigation;
    [self sendHandshake];
}
- (void)sendHandshake {
    NSDictionary *handshake = @{@"protocol":@1, @"window":self.windowId, @"handle":@(self.handle), @"generation":@(self.generation)};
    NSData *json = [NSJSONSerialization dataWithJSONObject:handshake options:0 error:nil];
    NSString *literal = [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding];
    if (literal) [self.webview evaluateJavaScript:[NSString stringWithFormat:@"window.cynaHandshake?.(%@)", literal] completionHandler:nil];
}
- (void)dispatchAction:(NSString *)actionId source:(NSString *)source contextData:(id)contextData {
    if (!self.actionStates[actionId] && backendActionCallback) {
        NSDictionary *state = backendActionStates[actionId];
        if (!state || [state[@"enabled"] boolValue]) {
            NSData *data = [NSJSONSerialization dataWithJSONObject:contextData ?: NSNull.null
                options:NSJSONWritingFragmentsAllowed error:nil];
            NSString *payload = data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : @"null";
            if (backendActionCallback(actionId.UTF8String, source.UTF8String, self.handle, payload.UTF8String) == 0) return;
        }
    }
    if (self.pendingActions.count >= 64) return;
    NSString *requestId = NSUUID.UUID.UUIDString;
    [self.pendingActions addObject:requestId];
    NSDictionary *request = @{@"id":actionId, @"requestId":requestId, @"source":source,
        @"window":@(self.handle), @"data":contextData ?: NSNull.null};
    NSData *data = [NSJSONSerialization dataWithJSONObject:request options:0 error:nil];
    NSString *literal = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    [self.webview evaluateJavaScript:[NSString stringWithFormat:@"window.cynaAction?.(%@)", literal] completionHandler:nil];
    NSUInteger generation = self.generation;
    __weak CynaWindow *weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        CynaWindow *window = weakSelf;
        if (window.generation == generation) [window.pendingActions removeObject:requestId];
    });
}
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)action
 decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    (void)webView;
    NSURL *url = action.request.URL;
    BOOL allowed = CynaNavigationAllowed(url);
    decisionHandler(allowed ? WKNavigationActionPolicyAllow : WKNavigationActionPolicyCancel);
}
- (void)sendBridgeReply:(NSDictionary *)reply {
    NSData *json = [NSJSONSerialization dataWithJSONObject:reply options:0 error:nil];
    NSString *literal = [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding];
    if (literal) [self.webview evaluateJavaScript:[NSString stringWithFormat:@"window.cynaReply?.(%@)", literal] completionHandler:nil];
}
- (BOOL)emitEvent:(id)payload topic:(NSString *)topic {
    BOOL delivered = YES;
    for (NSString *subscriptionId in self.subscriptions.allKeys) {
        if (![self.subscriptionTopics[subscriptionId] isEqualToString:topic]) continue;
        NSUInteger sequence = self.subscriptions[subscriptionId].unsignedIntegerValue + 1;
        self.subscriptions[subscriptionId] = @(sequence);
        if (self.eventsInFlight >= 64) { delivered = NO; continue; }
        NSDictionary *event = @{@"topic":topic, @"subscriptionId":subscriptionId,
            @"sequence":@(sequence), @"payload":payload};
        NSData *json = [NSJSONSerialization dataWithJSONObject:event options:0 error:nil];
        NSString *literal = [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding];
        if (literal) {
            self.eventsInFlight++;
            NSUInteger generation = self.generation;
            __weak CynaWindow *weakSelf = self;
            [self.webview evaluateJavaScript:[NSString stringWithFormat:@"window.cynaEvent?.(%@)", literal]
                completionHandler:^(id value, NSError *error) {
                    (void)value; (void)error;
                    CynaWindow *host = weakSelf;
                    if (host && host.generation == generation && host.eventsInFlight) host.eventsInFlight--;
                }];
        }
    }
    return delivered;
}
- (void)userContentController:(WKUserContentController *)controller didReceiveScriptMessage:(WKScriptMessage *)message {
    (void)controller;
    if (!CynaBridgeAllowed(message)) return;
    NSDictionary *body = [message.body isKindOfClass:NSDictionary.class] ? message.body : @{};
    if ([message.name isEqualToString:@"surface"]) {
        if ([body[@"kind"] isEqualToString:@"slot"]) [self.slots updateFromMessage:body];
        else [self.plugin receiveMessage:body];
        return;
    }
    if ([body[@"kind"] isEqualToString:@"hello"]) { [self sendHandshake]; return; }
    NSNumber *requestId = [body[@"id"] isKindOfClass:NSNumber.class] ? body[@"id"] : nil;
    if (!requestId || requestId.longLongValue < 1 || requestId.longLongValue > 9007199254740991LL ||
        requestId.doubleValue != (double)requestId.longLongValue) return;
    if (![body[@"protocol"] isEqual:@1] || ![body[@"window"] isEqual:self.windowId] ||
        ![body[@"generation"] isEqual:@(self.generation)]) return;
    NSString *kind = [body[@"kind"] isKindOfClass:NSString.class] ? body[@"kind"] : @"";
    if ([kind isEqualToString:@"cancel"]) { [self.pendingIds removeObject:requestId]; return; }
    if ([kind isEqualToString:@"close-handler"]) {
        if (![body[@"enabled"] isKindOfClass:NSNumber.class]) return;
        self.closeGuardEnabled = [body[@"enabled"] boolValue];
        if (!self.closeGuardEnabled) self.pendingCloseRequest = nil;
        return;
    }
    if ([kind isEqualToString:@"close-reply"]) {
        NSString *closeRequest = [body[@"requestId"] isKindOfClass:NSString.class] ? body[@"requestId"] : nil;
        if (!closeRequest || ![closeRequest isEqualToString:self.pendingCloseRequest] ||
            ![body[@"allow"] isKindOfClass:NSNumber.class]) return;
        self.pendingCloseRequest = nil;
        if ([body[@"allow"] boolValue]) {
            self.closeApproved = YES;
            [self.window performClose:nil];
        }
        return;
    }
    if ([kind isEqualToString:@"action-reply"]) {
        NSString *actionRequestId = [body[@"requestId"] isKindOfClass:NSString.class] ? body[@"requestId"] : nil;
        if (actionRequestId && [self.pendingActions containsObject:actionRequestId]) {
            [self.pendingActions removeObject:actionRequestId];
            if (![body[@"ok"] isEqual:@YES]) NSLog(@"Neiv action %@ failed in window %lld", actionRequestId, self.handle);
        }
        return;
    }
    if ([kind isEqualToString:@"action-state"]) {
        NSDictionary *states = [body[@"states"] isKindOfClass:NSDictionary.class] ? body[@"states"] : nil;
        if (!states || states.count > 128) return;
        for (id key in states) {
            if (![key isKindOfClass:NSString.class] || [key length] > 100 || ![states[key] isKindOfClass:NSDictionary.class]) return;
        }
        self.actionStates = states;
        refreshHostMenu();
        return;
    }
    if ([kind isEqualToString:@"invoke"] && [body[@"command"] isEqualToString:@"__neiv.context.popup"]) {
        NSDictionary *args = [body[@"args"] isKindOfClass:NSDictionary.class] ? body[@"args"] : nil;
        NSString *menuId = [args[@"menuId"] isKindOfClass:NSString.class] ? args[@"menuId"] : nil;
        NSNumber *x = [args[@"x"] isKindOfClass:NSNumber.class] ? args[@"x"] : nil;
        NSNumber *y = [args[@"y"] isKindOfClass:NSNumber.class] ? args[@"y"] : nil;
        NSArray *tree = contextMenuTrees[menuId];
        NSString *dataText = [args[@"data"] isKindOfClass:NSString.class] ? args[@"data"] : nil;
        NSData *contextBytes = [dataText dataUsingEncoding:NSUTF8StringEncoding];
        id contextData = contextBytes ? [NSJSONSerialization JSONObjectWithData:contextBytes options:NSJSONReadingFragmentsAllowed error:nil] : nil;
        if (!tree || !x || !y || !isfinite(x.doubleValue) || !isfinite(y.doubleValue) ||
            !dataText || contextBytes.length > 16384 || !contextData ||
            x.doubleValue < 0 || y.doubleValue < 0 || x.doubleValue > self.webview.bounds.size.width ||
            y.doubleValue > self.webview.bounds.size.height) {
            [self sendBridgeReply:@{@"id":requestId,@"ok":@NO,@"error":@{@"code":@"INVALID_ARGUMENT",@"message":@"Invalid context menu"}}];
            return;
        }
        CynaContextPopup *popup = [CynaContextPopup new];
        NSMenu *menu = [popup menuWithTree:tree];
        applyMenuStates(menu, self.actionStates);
        [menu popUpMenuPositioningItem:nil atLocation:NSMakePoint(x.doubleValue, self.webview.bounds.size.height - y.doubleValue) inView:self.webview];
        if (popup.selected) [self dispatchAction:popup.selected source:@"context" contextData:contextData];
        [self sendBridgeReply:@{@"id":requestId,@"ok":@YES,@"value":popup.selected ?: NSNull.null}];
        return;
    }
    if ([kind isEqualToString:@"invoke"] && [body[@"command"] isKindOfClass:NSString.class] &&
        ([body[@"command"] hasPrefix:@"__neiv.shell."] || [body[@"command"] hasPrefix:@"__neiv.clipboard."] ||
         [body[@"command"] hasPrefix:@"__neiv.tray."] || [body[@"command"] hasPrefix:@"__neiv.notification."])) {
        NSString *command = body[@"command"];
        NSDictionary *args = [body[@"args"] isKindOfClass:NSDictionary.class] ? body[@"args"] : @{};
        id value = nil;
        NSString *errorCode = nil;
        if ([command isEqualToString:@"__neiv.shell.openExternal"]) {
            NSString *url = [args[@"url"] isKindOfClass:NSString.class] ? args[@"url"] : nil;
            int status = url ? neiv_shell_open_external(url.UTF8String) : -1;
            if (status == 0) value = @YES;
            else errorCode = status == -2 ? @"CAPABILITY_DENIED" : status == -3 ? @"UNAVAILABLE" : @"INVALID_ARGUMENT";
        } else if ([command isEqualToString:@"__neiv.clipboard.readText"]) {
            if (![appCapabilities containsObject:@"clipboard.read"]) errorCode = @"CAPABILITY_DENIED";
            else {
                NSString *text = [NSPasteboard.generalPasteboard stringForType:NSPasteboardTypeString];
                if (text && [text lengthOfBytesUsingEncoding:NSUTF8StringEncoding] > 65535) errorCode = @"LIMIT_EXCEEDED";
                else value = text ?: NSNull.null;
            }
        } else if ([command isEqualToString:@"__neiv.clipboard.writeText"]) {
            NSString *text = [args[@"text"] isKindOfClass:NSString.class] ? args[@"text"] : nil;
            int status = text ? neiv_clipboard_write_text(text.UTF8String) : -1;
            if (status == 0) value = @YES;
            else errorCode = status == -2 ? @"CAPABILITY_DENIED" : status == -3 ? @"UNAVAILABLE" : @"INVALID_ARGUMENT";
        } else if ([command isEqualToString:@"__neiv.tray.setTitle"]) {
            NSString *title = [args[@"title"] isKindOfClass:NSString.class] ? args[@"title"] : nil;
            int status = title ? neiv_tray_set_title(title.UTF8String) : -1;
            if (status == 0) value = @YES;
            else errorCode = status == -2 ? @"CAPABILITY_DENIED" : @"INVALID_ARGUMENT";
        } else if ([command isEqualToString:@"__neiv.tray.clear"]) {
            int status = neiv_tray_clear();
            if (status == 0) value = @YES;
            else errorCode = @"CAPABILITY_DENIED";
        } else if ([command isEqualToString:@"__neiv.notification.show"]) {
            NSString *title = [args[@"title"] isKindOfClass:NSString.class] ? args[@"title"] : nil;
            NSString *message = [args[@"body"] isKindOfClass:NSString.class] ? args[@"body"] : nil;
            int status = title && message ? neiv_notification_show(title.UTF8String, message.UTF8String) : -1;
            if (status == 0) value = @YES;
            else errorCode = status == -2 ? @"CAPABILITY_DENIED" : @"INVALID_ARGUMENT";
        } else errorCode = @"UNKNOWN_COMMAND";
        if (errorCode) [self sendBridgeReply:@{@"id":requestId, @"ok":@NO,
            @"error":@{@"code":errorCode, @"message":@"Desktop service failed"}}];
        else [self sendBridgeReply:@{@"id":requestId, @"ok":@YES, @"value":value}];
        return;
    }
    if ([kind isEqualToString:@"invoke"] && [body[@"command"] isKindOfClass:NSString.class] &&
        [body[@"command"] hasPrefix:@"__neiv.dialog."]) {
        NSString *command = body[@"command"];
        NSDictionary *args = [body[@"args"] isKindOfClass:NSDictionary.class] ? body[@"args"] : @{};
        NSString *message = [args[@"message"] isKindOfClass:NSString.class] ? args[@"message"] : @"";
        if (message.length > 500) {
            [self sendBridgeReply:@{@"id":requestId,@"ok":@NO,@"error":@{@"code":@"INVALID_ARGUMENT",@"message":@"Dialog text too long"}}]; return;
        }
        id result = nil;
        if ([command isEqualToString:@"__neiv.dialog.alert"] || [command isEqualToString:@"__neiv.dialog.confirm"]) {
            NSAlert *alert = [NSAlert new]; alert.messageText = message.length ? message : @"Notice";
            [alert addButtonWithTitle:[command hasSuffix:@"confirm"] ? @"OK" : @"Close"];
            if ([command hasSuffix:@"confirm"]) [alert addButtonWithTitle:@"Cancel"];
            NSModalResponse response = [alert runModal];
            result = [command hasSuffix:@"confirm"] ? @((BOOL)(response == NSAlertFirstButtonReturn)) : @YES;
        } else if ([command isEqualToString:@"__neiv.dialog.openFile"] || [command isEqualToString:@"__neiv.dialog.saveFile"] ||
                   [command isEqualToString:@"__neiv.dialog.openFiles"] || [command isEqualToString:@"__neiv.dialog.saveFileWithOptions"]) {
            BOOL opening = [command isEqualToString:@"__neiv.dialog.openFile"] || [command isEqualToString:@"__neiv.dialog.openFiles"];
            NSString *capability = opening ? @"dialog.open" : @"dialog.save";
            if (![self.capabilities containsObject:capability]) {
                [self sendBridgeReply:@{@"id":requestId,@"ok":@NO,@"error":@{@"code":@"CAPABILITY_DENIED",@"message":@"File dialog capability was not declared"}}]; return;
            }
            NSArray *extensions = args[@"extensions"];
            if (extensions) {
                if (![extensions isKindOfClass:NSArray.class] || extensions.count > 16) {
                    [self sendBridgeReply:@{@"id":requestId,@"ok":@NO,@"error":@{@"code":@"INVALID_ARGUMENT",@"message":@"Invalid extensions"}}]; return;
                }
                for (id raw in extensions) {
                    if (![raw isKindOfClass:NSString.class] || [raw length] < 1 || [raw length] > 12 ||
                        [[raw stringByTrimmingCharactersInSet:[NSCharacterSet alphanumericCharacterSet]] length]) {
                        [self sendBridgeReply:@{@"id":requestId,@"ok":@NO,@"error":@{@"code":@"INVALID_ARGUMENT",@"message":@"Invalid extension"}}]; return;
                    }
                }
            }
            NSSavePanel *panel = opening ? [NSOpenPanel openPanel] : [NSSavePanel savePanel];
            panel.title = message;
            if (extensions.count) {
                NSMutableArray<UTType *> *types = [NSMutableArray new];
                for (NSString *extension in extensions) {
                    UTType *type = [UTType typeWithFilenameExtension:extension];
                    if (type) [types addObject:type];
                }
                if (types.count != extensions.count) {
                    [self sendBridgeReply:@{@"id":requestId,@"ok":@NO,@"error":@{@"code":@"INVALID_ARGUMENT",@"message":@"Unknown file extension"}}]; return;
                }
                panel.allowedContentTypes = types;
            }
            if ([command isEqualToString:@"__neiv.dialog.openFiles"]) {
                NSOpenPanel *openPanel = (NSOpenPanel *)panel;
                openPanel.allowsMultipleSelection = [args[@"multiple"] boolValue];
                if ([openPanel runModal] == NSModalResponseOK) {
                    NSMutableArray *paths = [NSMutableArray new];
                    for (NSURL *url in openPanel.URLs) if (url.path) [paths addObject:url.path];
                    result = paths;
                } else result = NSNull.null;
            } else result = [panel runModal] == NSModalResponseOK ? panel.URL.path ?: NSNull.null : NSNull.null;
        } else {
            [self sendBridgeReply:@{@"id":requestId,@"ok":@NO,@"error":@{@"code":@"UNKNOWN_COMMAND",@"message":@"Unknown dialog"}}]; return;
        }
        [self sendBridgeReply:@{@"id":requestId,@"ok":@YES,@"value":result}];
        return;
    }
    if ([kind isEqualToString:@"unsubscribe"]) {
        NSString *subscriptionId = [body[@"subscriptionId"] isKindOfClass:NSString.class] ? body[@"subscriptionId"] : nil;
        if (subscriptionId) { [self.subscriptions removeObjectForKey:subscriptionId]; [self.subscriptionTopics removeObjectForKey:subscriptionId]; }
        return;
    }
    if ([kind isEqualToString:@"subscribe"]) {
        NSString *topic = [body[@"topic"] isKindOfClass:NSString.class] ? body[@"topic"] : nil;
        if (![topic isEqualToString:@"app.windows"] && ![topic isEqualToString:@"app.lifecycle"] && !eventSchemas[topic]) {
            [self sendBridgeReply:@{@"id":requestId,@"ok":@NO,@"error":@{@"code":@"UNKNOWN_TOPIC",@"message":@"Unsupported event topic"}}];
        } else if (self.subscriptions.count >= 16) {
            [self sendBridgeReply:@{@"id":requestId,@"ok":@NO,@"error":@{@"code":@"LIMIT_EXCEEDED",@"message":@"Too many subscriptions"}}];
        } else {
            NSString *subscriptionId = NSUUID.UUID.UUIDString;
            self.subscriptions[subscriptionId] = @0;
            self.subscriptionTopics[subscriptionId] = topic;
            [self sendBridgeReply:@{@"id":requestId,@"ok":@YES,@"value":subscriptionId}];
        }
        return;
    }
    if (![kind isEqualToString:@"invoke"]) return;
    if ([self.pendingIds containsObject:requestId] || self.pendingIds.count >= 256) {
        [self sendBridgeReply:@{@"id":requestId,@"ok":@NO,@"error":@{@"code":@"LIMIT_EXCEEDED",@"message":@"Too many pending commands or duplicate ID"}}];
        return;
    }
    NSData *payload = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    if (!payload || payload.length > 65536) {
        [self sendBridgeReply:@{@"id":requestId, @"ok":@NO,
            @"error":@{@"code":@"INVALID_ARGUMENT", @"message":@"Command arguments too large"}}];
        return;
    }
    NSString *command = [body[@"command"] isKindOfClass:NSString.class] ? body[@"command"] : @"";
    NSDictionary *args = [body[@"args"] isKindOfClass:NSDictionary.class] ? body[@"args"] : @{};
    NSNumber *deadline = [body[@"deadlineMs"] isKindOfClass:NSNumber.class] ? body[@"deadlineMs"] : @10000;
    if (deadline.doubleValue < 1 || deadline.doubleValue > 30000 || !isfinite(deadline.doubleValue)) {
        [self sendBridgeReply:@{@"id":requestId,@"ok":@NO,@"error":@{@"code":@"INVALID_ARGUMENT",@"message":@"Invalid deadline"}}];
        return;
    }
    [self.pendingIds addObject:requestId];
    NSUInteger generation = self.generation;
    CynaCommandDispatcher dispatcher = self.dispatcher;
    __weak CynaWindow *weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(deadline.doubleValue * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        CynaWindow *host = weakSelf;
        if (!host || host.generation != generation || ![host.pendingIds containsObject:requestId]) return;
        [host.pendingIds removeObject:requestId];
        [host sendBridgeReply:@{@"id":requestId,@"ok":@NO,@"error":@{@"code":@"TIMEOUT",@"message":@"Native command timed out"}}];
    });
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSDictionary *error = nil;
        currentWindowHandle = self.handle;
        id result = dispatcher(command, args, &error);
        currentWindowHandle = 0;
        NSDictionary *reply = result ? @{@"id":requestId,@"ok":@YES,@"value":result} :
            @{@"id":requestId,@"ok":@NO,@"error":error ?: @{@"code":@"COMMAND_ERROR",@"message":@"Native command failed"}};
        dispatch_async(dispatch_get_main_queue(), ^{
            CynaWindow *host = weakSelf;
            if (!host || !host.window.isVisible || host.generation != generation ||
                ![host.pendingIds containsObject:requestId]) return;
            [host.pendingIds removeObject:requestId];
            [host sendBridgeReply:reply];
        });
    });
}
@end

@interface CynaAppHost : NSObject <NSApplicationDelegate>
@property(nonatomic, strong) NSMutableDictionary<NSString *, CynaWindow *> *windows;
@property(nonatomic, strong) NSDictionary *manifest;
@property(nonatomic) CynaCommandDispatcher dispatcher;
- (CynaWindow *)createWindow;
- (CynaWindow *)windowForHandle:(long long)handle;
- (void)installMenuItems:(NSArray *)items inMenu:(NSMenu *)menu;
- (void)refreshMenu;
@end
static long long nextWindowHandle;
static long long nextSurfaceHandle;
@implementation CynaAppHost
- (void)applicationDidFinishLaunching:(NSNotification *)note {
    (void)note;
    self.windows = [NSMutableDictionary new];
    runningHost = self;
    NSMenu *mainMenu = [NSMenu new];
    NSMenuItem *appItem = [NSMenuItem new];
    appItem.title = appManifest[@"name"];
    [mainMenu addItem:appItem];
    NSMenu *appMenu = [NSMenu new];
    [appMenu addItemWithTitle:@"Quit" action:@selector(terminate:) keyEquivalent:@"q"];
    appItem.submenu = appMenu;
    NSMenuItem *fileItem = [NSMenuItem new];
    fileItem.title = @"File";
    [mainMenu addItem:fileItem];
    NSMenu *fileMenu = [NSMenu new];
    [fileMenu addItemWithTitle:@"New Window" action:@selector(newWindow:) keyEquivalent:@"n"].target = self;
    [fileMenu addItemWithTitle:@"Close Window" action:@selector(closeWindow:) keyEquivalent:@"w"].target = self;
    fileItem.submenu = fileMenu;
    if (applicationMenuTree.count) {
        NSMenuItem *customItem = [NSMenuItem new];
        customItem.title = @"Actions";
        [mainMenu addItem:customItem];
        NSMenu *customMenu = [NSMenu new];
        [self installMenuItems:applicationMenuTree inMenu:customMenu];
        customItem.submenu = customMenu;
    }
    NSApp.mainMenu = mainMenu;
    [self newWindow:nil];
    [NSApp activateIgnoringOtherApps:YES];
}
- (void)installMenuItems:(NSArray *)items inMenu:(NSMenu *)menu {
    for (id raw in items) {
        if (![raw isKindOfClass:NSDictionary.class]) continue;
        NSDictionary *item = raw;
        if ([item[@"separator"] isEqual:@YES]) { [menu addItem:NSMenuItem.separatorItem]; continue; }
        NSString *label = [item[@"label"] isKindOfClass:NSString.class] ? item[@"label"] : nil;
        if (!label.length || label.length > 80) continue;
        NSArray *children = [item[@"items"] isKindOfClass:NSArray.class] ? item[@"items"] : nil;
        if (children) {
            NSMenuItem *parent = [NSMenuItem new]; parent.title = label;
            NSMenu *submenu = [NSMenu new]; [self installMenuItems:children inMenu:submenu];
            parent.submenu = submenu; [menu addItem:parent]; continue;
        }
        NSString *actionId = [item[@"id"] isKindOfClass:NSString.class] ? item[@"id"] : nil;
        NSString *role = [item[@"role"] isKindOfClass:NSString.class] ? item[@"role"] : nil;
        if (!actionId.length && !role.length) continue;
        NSString *shortcut = [item[@"shortcut"] isKindOfClass:NSString.class] ? item[@"shortcut"] : @"";
        NSString *key = @""; NSEventModifierFlags modifiers = 0;
        NSArray *parts = [shortcut componentsSeparatedByString:@"+"];
        if (parts.count >= 2) {
            key = [parts.lastObject lowercaseString];
            if ([key isEqualToString:@"enter"]) key = @"\r";
            else if ([key isEqualToString:@"escape"]) key = [NSString stringWithFormat:@"%C", (unichar)27];
            else if ([key hasPrefix:@"f"] && key.length <= 3) {
                NSInteger number = [[key substringFromIndex:1] integerValue];
                if (number >= 1 && number <= 12) {
                    unichar functionKey = (unichar)(NSF1FunctionKey + number - 1);
                    key = [NSString stringWithCharacters:&functionKey length:1];
                }
            }
            for (NSString *part in [parts subarrayWithRange:NSMakeRange(0, parts.count - 1)]) {
                if ([part isEqualToString:@"Cmd"] || [part isEqualToString:@"CmdOrCtrl"]) modifiers |= NSEventModifierFlagCommand;
                else if ([part isEqualToString:@"Ctrl"]) modifiers |= NSEventModifierFlagControl;
                else if ([part isEqualToString:@"Alt"]) modifiers |= NSEventModifierFlagOption;
                else if ([part isEqualToString:@"Shift"]) modifiers |= NSEventModifierFlagShift;
            }
            if (key.length != 1) key = @"";
        }
        NSDictionary *roleSelectors = @{@"quit":@"terminate:", @"close":@"performClose:", @"undo":@"undo:",
            @"redo":@"redo:", @"cut":@"cut:", @"copy":@"copy:", @"paste":@"paste:", @"selectAll":@"selectAll:"};
        SEL action = role ? NSSelectorFromString(roleSelectors[role]) : @selector(performAppAction:);
        NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:label action:action keyEquivalent:key];
        menuItem.keyEquivalentModifierMask = modifiers;
        menuItem.target = [role isEqualToString:@"quit"] ? NSApp : role ? nil : self;
        if (actionId) menuItem.representedObject = actionId;
        [menu addItem:menuItem];
    }
}
- (void)performAppAction:(NSMenuItem *)item {
    NSString *actionId = item.representedObject;
    for (CynaWindow *window in self.windows.allValues) {
        if (window.window != NSApp.keyWindow) continue;
        NSString *source = NSApp.currentEvent.type == NSEventTypeKeyDown ? @"shortcut" : @"menu";
        [window dispatchAction:actionId source:source contextData:nil];
        return;
    }
}
- (void)refreshMenu {
    if (!NSApp.mainMenu) return;
    CynaWindow *focused = nil;
    for (CynaWindow *window in self.windows.allValues) if (window.window == NSApp.keyWindow) { focused = window; break; }
    NSMutableArray<NSMenu *> *menus = [NSMutableArray arrayWithObject:NSApp.mainMenu];
    while (menus.count) {
        NSMenu *menu = menus.lastObject; [menus removeLastObject];
        for (NSMenuItem *item in menu.itemArray) {
            if (item.submenu) [menus addObject:item.submenu];
            if (!item.representedObject) continue;
            NSDictionary *state = focused.actionStates[item.representedObject] ?: backendActionStates[item.representedObject];
            item.enabled = [state[@"enabled"] boolValue];
            item.hidden = state && [state[@"visible"] isEqual:@NO];
            item.state = [state[@"checked"] boolValue] ? NSControlStateValueOn : NSControlStateValueOff;
        }
    }
}
- (void)newWindow:(id)sender {
    (void)sender;
    [self createWindow];
}
- (CynaWindow *)createWindow {
    CynaWindow *window = [[CynaWindow alloc] initWithManifest:self.manifest dispatcher:self.dispatcher];
    if (!window) return nil;
    window.handle = ++nextWindowHandle;
    if ([window.plugin respondsToSelector:@selector(windowHandleAssigned:)])
        [window.plugin windowHandleAssigned:window.handle];
    long long handle = window.handle;
    __weak CynaAppHost *weakSelf = self;
    window.onClose = ^(NSString *windowId) {
        [weakSelf.windows removeObjectForKey:windowId];
        [weakSelf broadcastWindowEvent:@{@"state":@"closed", @"window":@(handle)}];
    };
    window.onState = ^(NSDictionary *event) { [weakSelf broadcastWindowEvent:event]; };
    self.windows[window.windowId] = window;
    [self broadcastWindowEvent:@{@"state":@"opened", @"window":@(window.handle)}];
    return window;
}
- (CynaWindow *)windowForHandle:(long long)handle {
    if (handle < 1) return nil;
    for (CynaWindow *window in self.windows.allValues) if (window.handle == handle) return window;
    return nil;
}
- (void)broadcastWindowEvent:(NSDictionary *)payload {
    for (CynaWindow *window in self.windows.allValues) [window emitEvent:payload topic:@"app.windows"];
}
- (void)emitLifecycle:(NSString *)state {
    if (lifecycleCallback) lifecycleCallback(state.UTF8String);
    for (CynaWindow *window in self.windows.allValues) [window emitEvent:@{@"state":state} topic:@"app.lifecycle"];
}
- (void)applicationDidBecomeActive:(NSNotification *)note { (void)note; [self emitLifecycle:@"activated"]; }
- (void)applicationDidResignActive:(NSNotification *)note { (void)note; [self emitLifecycle:@"deactivated"]; }
- (void)applicationWillTerminate:(NSNotification *)note { (void)note; [self emitLifecycle:@"terminating"]; }
- (void)closeWindow:(id)sender { (void)sender; [NSApp.keyWindow performClose:nil]; }
- (void)reloadWindow:(id)sender {
    (void)sender;
    for (CynaWindow *window in self.windows.allValues) {
        if (window.window == NSApp.keyWindow) {
            [self broadcastWindowEvent:@{@"state":@"reloading", @"window":@(window.handle)}];
            [window.webview reload]; break;
        }
    }
}
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)app { (void)app; return quitOnLastWindow; }
- (BOOL)applicationShouldHandleReopen:(NSApplication *)app hasVisibleWindows:(BOOL)visible {
    (void)app;
    if (!visible && self.windows.count == 0) [self createWindow];
    return YES;
}
@end

static void refreshHostMenu(void) { [runningHost refreshMenu]; }
static void onMain(void (^operation)(void)) {
    if (NSThread.isMainThread) operation();
    else dispatch_sync(dispatch_get_main_queue(), operation);
}
void neiv_app_quit(void) { onMain(^{ [NSApp terminate:nil]; }); }
int neiv_app_current(void) { return runningHost ? 1 : 0; }
static int copyAppText(NSString *text, char *out, int capacity) {
    if (!text || !out || capacity < 1) return -1;
    const char *bytes = text.UTF8String;
    size_t count = strlen(bytes);
    if (count >= (size_t)capacity) return -1;
    memcpy(out, bytes, count + 1);
    return (int)count;
}
int neiv_app_id(char *out, int capacity) { return copyAppText(appManifest[@"id"], out, capacity); }
int neiv_app_name(char *out, int capacity) { return copyAppText(appManifest[@"name"], out, capacity); }
long long neiv_window_open_handle(const char *title, int width, int height) {
    if (!title || ![NSString stringWithUTF8String:title] || width < 320 || width > 3000 ||
        height < 240 || height > 2000) return 0;
    __block long long handle = 0;
    onMain(^{
        CynaAppHost *host = runningHost;
        if (!host) return;
        NSDictionary *previous = initialWindow;
        initialWindow = @{@"title":[NSString stringWithUTF8String:title], @"width":@(width), @"height":@(height)};
        handle = [host createWindow].handle;
        initialWindow = previous;
    });
    return handle;
}
long long neiv_window_open_options(const char *title, int width, int height,
    int minWidth, int minHeight, int visible) {
    if (!title || ![NSString stringWithUTF8String:title] || width < 320 || width > 3000 ||
        height < 240 || height > 2000 || minWidth < 0 || minHeight < 0 ||
        minWidth > width || minHeight > height) return 0;
    __block long long handle = 0;
    onMain(^{
        CynaAppHost *host = runningHost;
        if (!host) return;
        NSDictionary *previous = initialWindow;
        initialWindow = @{@"title":[NSString stringWithUTF8String:title], @"width":@(width), @"height":@(height),
            @"minWidth":@(minWidth), @"minHeight":@(minHeight), @"visible":@(visible != 0)};
        handle = [host createWindow].handle;
        initialWindow = previous;
    });
    return handle;
}
int neiv_window_get_state(long long handle, int *values) {
    if (!values) return -1;
    __block int status = -1;
    onMain(^{
        CynaWindow *window = [runningHost windowForHandle:handle];
        if (!window) return;
        values[0] = (int)window.window.frame.origin.x;
        values[1] = (int)window.window.frame.origin.y;
        values[2] = (int)window.window.contentView.bounds.size.width;
        values[3] = (int)window.window.contentView.bounds.size.height;
        values[4] = window.window.isKeyWindow ? 1 : 0;
        values[5] = window.window.isVisible ? 1 : 0;
        status = 0;
    });
    return status;
}
int neiv_window_set_size(long long handle, int width, int height) {
    if (width < 320 || width > 3000 || height < 240 || height > 2000) return -2;
    __block int status = -1;
    onMain(^{
        CynaWindow *window = [runningHost windowForHandle:handle];
        if (!window) return;
        [window.window setContentSize:NSMakeSize(width, height)];
        status = 0;
    });
    return status;
}
int neiv_window_set_bounds(long long handle, int x, int y, int width, int height) {
    if (width < 320 || width > 3000 || height < 240 || height > 2000 ||
        x < -100000 || x > 100000 || y < -100000 || y > 100000) return -2;
    __block int status = -1;
    onMain(^{
        CynaWindow *window = [runningHost windowForHandle:handle];
        if (!window) return;
        [window.window setContentSize:NSMakeSize(width, height)];
        [window.window setFrameOrigin:NSMakePoint(x, y)];
        status = 0;
    });
    return status;
}
long long neiv_window_current_handle(void) { return currentWindowHandle; }
int neiv_window_focus_handle(long long handle) {
    __block int status = -1;
    onMain(^{ CynaWindow *window = [runningHost windowForHandle:handle]; if (window) { [window.window makeKeyAndOrderFront:nil]; status = 0; } });
    return status;
}
int neiv_window_set_title_handle(long long handle, const char *title) {
    if (!title) return -1;
    NSString *value = [NSString stringWithUTF8String:title];
    if (!value || !value.length || value.length > 80) return -1;
    __block int status = -1;
    onMain(^{ CynaWindow *window = [runningHost windowForHandle:handle]; if (window) { window.window.title = value; status = 0; } });
    return status;
}
int neiv_window_close_handle(long long handle) {
    __block int status = -1;
    onMain(^{ CynaWindow *window = [runningHost windowForHandle:handle]; if (window) { [window.window performClose:nil]; status = 0; } });
    return status;
}
int neiv_window_reload_handle(long long handle) {
    __block int status = -1;
    onMain(^{ CynaWindow *window = [runningHost windowForHandle:handle]; if (window) { [window.webview reload]; status = 0; } });
    return status;
}
int neiv_publish_event(const char *topic, const char *payloadJson, long long targetHandle) {
    if (!topic || !payloadJson || strlen(payloadJson) > 65536) return -1;
    NSString *name = [NSString stringWithUTF8String:topic];
    NSString *json = [NSString stringWithUTF8String:payloadJson];
    id schema = eventSchemas[name];
    if (!schema || !json || [name isEqualToString:@"app.windows"]) return -1;
    NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
    id payload = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingFragmentsAllowed error:nil];
    if (!CynaCommandValid(payload, schema, 0)) return -1;
    __block int status = 0;
    onMain(^{
        CynaAppHost *host = runningHost;
        if (!host) { status = -3; return; }
        if (targetHandle) {
            CynaWindow *window = [host windowForHandle:targetHandle];
            if (!window) { status = -3; return; }
            if (![window emitEvent:payload topic:name]) status = -2;
        } else {
            for (CynaWindow *window in host.windows.allValues)
                if (![window emitEvent:payload topic:name]) status = -2;
        }
    });
    return status;
}
int neiv_dialog_alert(const char *message) {
    if (!message || strlen(message) > 2000) return -1;
    NSString *text = [NSString stringWithUTF8String:message]; if (!text) return -1;
    onMain(^{ NSAlert *alert = [NSAlert new]; alert.messageText = text; [alert addButtonWithTitle:@"Close"]; [alert runModal]; });
    return 0;
}
int neiv_dialog_confirm(const char *message) {
    if (!message || strlen(message) > 2000) return -1;
    NSString *text = [NSString stringWithUTF8String:message]; if (!text) return -1;
    __block int accepted = 0;
    onMain(^{ NSAlert *alert = [NSAlert new]; alert.messageText = text; [alert addButtonWithTitle:@"OK"]; [alert addButtonWithTitle:@"Cancel"]; accepted = [alert runModal] == NSAlertFirstButtonReturn; });
    return accepted;
}
int neiv_dialog_capability(int save) {
    return [appCapabilities containsObject:save ? @"dialog.save" : @"dialog.open"] ? 1 : 0;
}
static int fileDialog(BOOL save, char *out, int capacity) {
    if (!out || capacity < 1) return -2;
    __block int count = -1;
    onMain(^{
        NSSavePanel *panel = save ? [NSSavePanel savePanel] : [NSOpenPanel openPanel];
        if ([panel runModal] != NSModalResponseOK) return;
        const char *path = panel.URL.path.UTF8String;
        size_t length = path ? strlen(path) : 0;
        if (!path || length >= (size_t)capacity) { count = -2; return; }
        memcpy(out, path, length + 1);
        count = (int)length;
    });
    return count;
}
int neiv_dialog_open_file(char *out, int capacity) { return fileDialog(NO, out, capacity); }
int neiv_dialog_save_file(char *out, int capacity) { return fileDialog(YES, out, capacity); }
int neiv_dialog_paths(const char *extensionsJson, int save, char *out, int capacity) {
    if (![appCapabilities containsObject:save ? @"dialog.save" : @"dialog.open"]) return -2;
    if (!extensionsJson || !out || capacity < 1 || capacity > 65536 || strlen(extensionsJson) > 1024) return -3;
    NSData *input = [[NSString stringWithUTF8String:extensionsJson] dataUsingEncoding:NSUTF8StringEncoding];
    NSArray *extensions = input ? [NSJSONSerialization JSONObjectWithData:input options:0 error:nil] : nil;
    if (![extensions isKindOfClass:NSArray.class] || extensions.count > 16) return -3;
    NSMutableArray<UTType *> *types = [NSMutableArray new];
    for (id raw in extensions) {
        if (![raw isKindOfClass:NSString.class] || [raw length] < 1 || [raw length] > 12 ||
            [[raw stringByTrimmingCharactersInSet:[NSCharacterSet alphanumericCharacterSet]] length]) return -3;
        UTType *type = [UTType typeWithFilenameExtension:raw];
        if (!type) return -3;
        [types addObject:type];
    }
    __block int count = -1;
    onMain(^{
        NSSavePanel *panel = save ? [NSSavePanel savePanel] : [NSOpenPanel openPanel];
        if (types.count) panel.allowedContentTypes = types;
        if (!save) ((NSOpenPanel *)panel).allowsMultipleSelection = YES;
        if ([panel runModal] != NSModalResponseOK) return;
        id result = nil;
        if (save) result = panel.URL.path ?: NSNull.null;
        else {
            NSMutableArray *paths = [NSMutableArray new];
            for (NSURL *url in ((NSOpenPanel *)panel).URLs) if (url.path) [paths addObject:url.path];
            result = paths;
        }
        NSData *json = [NSJSONSerialization dataWithJSONObject:result options:NSJSONWritingFragmentsAllowed error:nil];
        if (!json || json.length >= (NSUInteger)capacity) { count = -3; return; }
        memcpy(out, json.bytes, json.length);
        out[json.length] = 0;
        count = (int)json.length;
    });
    return count;
}
int neiv_slot_set_text(long long windowHandle, const char *slotId, const char *text) {
    if (!slotId || !text || strlen(slotId) > 64 || strlen(text) > 4096) return -1;
    NSString *identifier = [NSString stringWithUTF8String:slotId];
    NSString *value = [NSString stringWithUTF8String:text];
    if (!identifier.length || !value) return -1;
    __block int status = -1;
    onMain(^{
        CynaWindow *window = [runningHost windowForHandle:windowHandle];
        if (!window) return;
        NSTextField *label = window.textSlots[identifier];
        if (!label) {
            label = [NSTextField labelWithString:value];
            label.alignment = NSTextAlignmentCenter;
            label.font = [NSFont systemFontOfSize:24 weight:NSFontWeightSemibold];
            label.textColor = NSColor.darkGrayColor;
            if (![window.slots registerView:label slotId:identifier]) return;
            window.textSlots[identifier] = label;
        }
        label.stringValue = value;
        status = 0;
    });
    return status;
}
long long neiv_surface_create_text(long long windowHandle, const char *slotId, const char *text) {
    if (!slotId || !text || strlen(slotId) > 64 || strlen(text) > 4096) return 0;
    NSString *identifier = [NSString stringWithUTF8String:slotId];
    NSString *value = [NSString stringWithUTF8String:text];
    if (!identifier.length || !value) return 0;
    __block long long surface = 0;
    onMain(^{
        CynaWindow *window = [runningHost windowForHandle:windowHandle];
        if (!window || window.textSlots[identifier]) return;
        NSTextField *label = [NSTextField labelWithString:value];
        label.alignment = NSTextAlignmentCenter;
        label.font = [NSFont systemFontOfSize:24 weight:NSFontWeightSemibold];
        if (![window.slots registerView:label slotId:identifier]) return;
        surface = ++nextSurfaceHandle;
        window.textSlots[identifier] = label;
        window.surfaceIds[@(surface)] = identifier;
        [window.attachedSurfaces addObject:@(surface)];
        window.surfaceVisibility[@(surface)] = @YES;
    });
    return surface;
}
int neiv_surface_set_text(long long surface, const char *text) {
    if (surface < 1 || !text || strlen(text) > 4096) return -1;
    NSString *value = [NSString stringWithUTF8String:text];
    if (!value) return -1;
    __block int status = -1;
    onMain(^{
        for (CynaWindow *window in runningHost.windows.allValues) {
            NSString *slotId = window.surfaceIds[@(surface)];
            if (!slotId) continue;
            window.textSlots[slotId].stringValue = value;
            status = 0; break;
        }
    });
    return status;
}
int neiv_surface_destroy(long long surface) {
    if (surface < 1) return -1;
    __block int status = -1;
    onMain(^{
        for (CynaWindow *window in runningHost.windows.allValues) {
            NSString *slotId = window.surfaceIds[@(surface)];
            if (!slotId) continue;
            NSView *view = window.nativeSurfaces[@(surface)] ?: window.textSlots[slotId];
            if (window.window.firstResponder == view) [window.window makeFirstResponder:window.webview];
            [window.slots unregisterView:slotId];
            [window.textSlots removeObjectForKey:slotId];
            [window.surfaceIds removeObjectForKey:@(surface)];
            [window.attachedSurfaces removeObject:@(surface)];
            [window.surfaceVisibility removeObjectForKey:@(surface)];
            id<CynaSurfaceProvider> provider = window.surfaceProviders[@(surface)];
            if ([provider respondsToSelector:@selector(destroySurface:)]) [provider destroySurface:window.nativeSurfaces[@(surface)]];
            [window.nativeSurfaces removeObjectForKey:@(surface)];
            [window.surfaceProviders removeObjectForKey:@(surface)];
            status = 0; break;
        }
    });
    return status;
}
int neiv_surface_set_accessibility_label(long long surface, const char *label) {
    if (surface < 1 || !label || strlen(label) > 256) return -1;
    NSString *value = [NSString stringWithUTF8String:label];
    if (!value) return -1;
    __block int status = -1;
    onMain(^{
        for (CynaWindow *window in runningHost.windows.allValues) {
            NSString *slotId = window.surfaceIds[@(surface)];
            if (!slotId) continue;
            NSView *view = window.nativeSurfaces[@(surface)] ?: window.textSlots[slotId];
            view.accessibilityLabel = value;
            status = 0; break;
        }
    });
    return status;
}
static long long createProviderSurface(long long windowHandle, NSString *identifier, NSString *kind, NSDictionary *options) {
    __block long long surface = 0;
    onMain(^{
        CynaWindow *window = [runningHost windowForHandle:windowHandle];
        if (!window) { surface = -2; return; }
        NSDictionary *providers = [window.plugin respondsToSelector:@selector(surfaceProviders)] ?
            [window.plugin surfaceProviders] : nil;
        id<CynaSurfaceProvider> provider = [providers isKindOfClass:NSDictionary.class] ? providers[kind] : nil;
        if (![provider conformsToProtocol:@protocol(CynaSurfaceProvider)]) { surface = -1; return; }
        NSView *view = [provider createSurfaceWithOptions:options];
        if (![view isKindOfClass:NSView.class]) return;
        if (![window.slots registerView:view slotId:identifier]) {
            if ([provider respondsToSelector:@selector(destroySurface:)]) [provider destroySurface:view];
            return;
        }
        surface = ++nextSurfaceHandle;
        window.surfaceIds[@(surface)] = identifier;
        [window.attachedSurfaces addObject:@(surface)];
        window.surfaceVisibility[@(surface)] = @YES;
        window.nativeSurfaces[@(surface)] = view;
        window.surfaceProviders[@(surface)] = provider;
        [window.slots refreshPlacementForSlot:identifier];
    });
    return surface;
}
int neiv_surface_get_capabilities(long long windowHandle, const char *kind, int *values) {
    if (!kind || !values || strlen(kind) == 0 || strlen(kind) > 64) return -1;
    NSString *name = [NSString stringWithUTF8String:kind];
    if (!name) return -1;
    __block int status = -2;
    onMain(^{
        CynaWindow *window = [runningHost windowForHandle:windowHandle];
        if (!window) return;
        NSDictionary *providers = [window.plugin respondsToSelector:@selector(surfaceProviders)] ?
            [window.plugin surfaceProviders] : nil;
        id<CynaSurfaceProvider> provider = [providers isKindOfClass:NSDictionary.class] ? providers[name] : nil;
        if (![provider conformsToProtocol:@protocol(CynaSurfaceProvider)]) { status = -3; return; }
        NSDictionary *report = [provider respondsToSelector:@selector(surfaceCapabilities)] ?
            [provider surfaceCapabilities] : nil;
        NSArray<NSString *> *keys = @[@"available", @"metal", @"media", @"pixelFormat",
            @"gpuCompletion", @"decodedFrame", @"softwareFallback"];
        for (NSUInteger index = 0; index < keys.count; index++) {
            id value = [report isKindOfClass:NSDictionary.class] ? report[keys[index]] : nil;
            values[index] = [value isKindOfClass:NSNumber.class] ? ([value boolValue] ? 1 : 0) :
                (index == 0 && ![report isKindOfClass:NSDictionary.class] ? 1 : 0);
        }
        status = 0;
    });
    return status;
}
long long neiv_surface_create_native(long long windowHandle, const char *slotId, const char *kind, const char *optionsJson) {
    if (!slotId || !kind || !optionsJson || strlen(slotId) > 64 || strlen(kind) > 64 || strlen(optionsJson) > 4096) return 0;
    NSString *identifier = [NSString stringWithUTF8String:slotId];
    NSString *name = [NSString stringWithUTF8String:kind];
    NSString *json = [NSString stringWithUTF8String:optionsJson];
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-"];
    if (!identifier.length || !name.length || !json ||
        [name rangeOfCharacterFromSet:allowed.invertedSet].location != NSNotFound) return 0;
    id options = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
    if (![options isKindOfClass:NSDictionary.class]) return 0;
    return createProviderSurface(windowHandle, identifier, name, options);
}
long long neiv_surface_create_color(long long windowHandle, const char *slotId, int level) {
    if (!slotId || strlen(slotId) > 64 || level < 0 || level > 1000) return 0;
    NSString *identifier = [NSString stringWithUTF8String:slotId];
    if (!identifier.length) return 0;
    return createProviderSurface(windowHandle, identifier, @"color", @{@"level":@(level)});
}
int neiv_surface_set_color_level(long long surface, int level) {
    if (surface < 1 || level < 0 || level > 1000) return -1;
    __block int status = -1;
    onMain(^{
        for (CynaWindow *window in runningHost.windows.allValues) {
            NSView *view = window.nativeSurfaces[@(surface)];
            if (!view) continue;
            status = [window.plugin setColorSurface:view level:level] ? 0 : -1;
            break;
        }
    });
    return status;
}
int neiv_surface_set_visible(long long surface, int visible) {
    if (surface < 1 || (visible != 0 && visible != 1)) return -1;
    __block int status = -1;
    onMain(^{
        for (CynaWindow *window in runningHost.windows.allValues) {
            NSString *slotId = window.surfaceIds[@(surface)];
            if (!slotId) continue;
            window.surfaceVisibility[@(surface)] = @(visible != 0);
            status = ![window.attachedSurfaces containsObject:@(surface)] ||
                [window.slots setVisible:visible != 0 slotId:slotId] ? 0 : -1;
            break;
        }
    });
    return status;
}
int neiv_surface_detach(long long surface) {
    if (surface < 1) return -1;
    __block int status = -1;
    onMain(^{
        for (CynaWindow *window in runningHost.windows.allValues) {
            NSString *slotId = window.surfaceIds[@(surface)];
            if (!slotId) continue;
            if (![window.attachedSurfaces containsObject:@(surface)]) { status = -2; break; }
            if (![window.slots unregisterView:slotId]) break;
            [window.attachedSurfaces removeObject:@(surface)];
            status = 0; break;
        }
    });
    return status;
}
int neiv_surface_attach(long long surface) {
    if (surface < 1) return -1;
    __block int status = -1;
    onMain(^{
        for (CynaWindow *window in runningHost.windows.allValues) {
            NSString *slotId = window.surfaceIds[@(surface)];
            if (!slotId) continue;
            if ([window.attachedSurfaces containsObject:@(surface)]) { status = -2; break; }
            NSView *view = window.nativeSurfaces[@(surface)] ?: window.textSlots[slotId];
            if (!view || ![window.slots registerView:view slotId:slotId]) { status = -3; break; }
            [window.slots setVisible:[window.surfaceVisibility[@(surface)] boolValue] slotId:slotId];
            [window.attachedSurfaces addObject:@(surface)];
            status = 0; break;
        }
    });
    return status;
}
int neiv_surface_get_metrics(long long surface, double *values) {
    if (surface < 1 || !values) return -1;
    __block int status = -1;
    onMain(^{
        for (CynaWindow *window in runningHost.windows.allValues) {
            NSString *slotId = window.surfaceIds[@(surface)];
            if (!slotId) continue;
            NSView *view = window.nativeSurfaces[@(surface)] ?: window.textSlots[slotId];
            if (!view) break;
            BOOL attached = [window.attachedSurfaces containsObject:@(surface)];
            values[0] = view.frame.size.width;
            values[1] = view.frame.size.height;
            values[2] = window.window.backingScaleFactor ?: 1.0;
            values[3] = attached && !view.hidden ? 1.0 : 0.0;
            values[4] = attached ? 1.0 : 0.0;
            status = 0; break;
        }
    });
    return status;
}
int neiv_surface_focus(long long surface) {
    if (surface < 1) return -1;
    __block int status = -1;
    onMain(^{
        for (CynaWindow *window in runningHost.windows.allValues) {
            NSString *slotId = window.surfaceIds[@(surface)];
            if (!slotId) continue;
            NSView *view = window.nativeSurfaces[@(surface)] ?: window.textSlots[slotId];
            if (![window.attachedSurfaces containsObject:@(surface)] || !view || view.hidden) { status = -2; break; }
            status = [view acceptsFirstResponder] && [window.window makeFirstResponder:view] ? 0 : -3;
            break;
        }
    });
    return status;
}
int neiv_surface_release_focus(long long surface) {
    if (surface < 1) return -1;
    __block int status = -1;
    onMain(^{
        for (CynaWindow *window in runningHost.windows.allValues) {
            NSString *slotId = window.surfaceIds[@(surface)];
            if (!slotId) continue;
            NSView *view = window.nativeSurfaces[@(surface)] ?: window.textSlots[slotId];
            if (!view || window.window.firstResponder != view) { status = -2; break; }
            status = [window.window makeFirstResponder:window.webview] ? 0 : -3;
            break;
        }
    });
    return status;
}
int neiv_surface_set_suspended(long long surface, int suspended) {
    if (surface < 1 || (suspended != 0 && suspended != 1)) return -1;
    __block int status = -1;
    onMain(^{
        for (CynaWindow *window in runningHost.windows.allValues) {
            NSView *view = window.nativeSurfaces[@(surface)];
            if (!view) {
                if (window.surfaceIds[@(surface)]) { status = -2; break; }
                continue;
            }
            id<CynaSurfaceProvider> provider = window.surfaceProviders[@(surface)];
            status = [provider respondsToSelector:@selector(setSurface:suspended:)] &&
                [provider setSurface:view suspended:suspended != 0] ? 0 : -2;
            break;
        }
    });
    return status;
}
int neiv_surface_is_alive(long long surface) {
    if (surface < 1) return 0;
    __block int alive = 0;
    onMain(^{
        for (CynaWindow *window in runningHost.windows.allValues) {
            if (window.surfaceIds[@(surface)]) { alive = 1; break; }
        }
    });
    return alive;
}
int neiv_shell_open_external(const char *url) {
    if (![appCapabilities containsObject:@"shell.openExternal"]) return -2;
    if (!url || strlen(url) > 2048) return -1;
    NSString *text = [NSString stringWithUTF8String:url];
    NSURLComponents *parts = text ? [NSURLComponents componentsWithString:text] : nil;
    NSString *scheme = parts.scheme.lowercaseString;
    if (!parts || ![@[@"https", @"http", @"mailto"] containsObject:scheme] ||
        parts.user || parts.password || ([scheme isEqualToString:@"https"] && !parts.host.length) ||
        ([scheme isEqualToString:@"http"] && !parts.host.length)) return -1;
    __block BOOL opened = NO;
    onMain(^{ opened = [NSWorkspace.sharedWorkspace openURL:parts.URL]; });
    return opened ? 0 : -3;
}
int neiv_clipboard_read_text(char *out, int capacity) {
    if (![appCapabilities containsObject:@"clipboard.read"]) return -2;
    if (!out || capacity < 1 || capacity > 65536) return -1;
    __block int count = -3;
    onMain(^{
        NSString *value = [NSPasteboard.generalPasteboard stringForType:NSPasteboardTypeString];
        if (!value) return;
        NSData *data = [value dataUsingEncoding:NSUTF8StringEncoding];
        if (data.length >= (NSUInteger)capacity) { count = -4; return; }
        memcpy(out, data.bytes, data.length);
        out[data.length] = 0;
        count = (int)data.length;
    });
    return count;
}
int neiv_clipboard_capability(int read) {
    return [appCapabilities containsObject:read ? @"clipboard.read" : @"clipboard.write"] ? 1 : 0;
}
int neiv_clipboard_write_text(const char *text) {
    if (![appCapabilities containsObject:@"clipboard.write"]) return -2;
    if (!text || strlen(text) > 65535) return -1;
    NSString *value = [NSString stringWithUTF8String:text];
    if (!value) return -1;
    __block BOOL written = NO;
    onMain(^{
        [NSPasteboard.generalPasteboard clearContents];
        written = [NSPasteboard.generalPasteboard setString:value forType:NSPasteboardTypeString];
    });
    return written ? 0 : -3;
}
int neiv_tray_set_title(const char *title) {
    if (![appCapabilities containsObject:@"tray"]) return -2;
    if (!title || strlen(title) > 128) return -1;
    NSString *value = [NSString stringWithUTF8String:title];
    if (!value.length || value.length > 32) return -1;
    onMain(^{
        if (!statusItem) statusItem = [NSStatusBar.systemStatusBar statusItemWithLength:NSVariableStatusItemLength];
        statusItem.button.title = value;
        statusItem.button.target = NSApp;
        statusItem.button.action = @selector(activateIgnoringOtherApps:);
    });
    return 0;
}
int neiv_tray_clear(void) {
    if (![appCapabilities containsObject:@"tray"]) return -2;
    onMain(^{
        if (statusItem) [NSStatusBar.systemStatusBar removeStatusItem:statusItem];
        statusItem = nil;
    });
    return 0;
}
int neiv_notification_show(const char *title, const char *body) {
    if (![appCapabilities containsObject:@"notification.show"]) return -2;
    if (!title || !body || strlen(title) > 256 || strlen(body) > 2048) return -1;
    NSString *heading = [NSString stringWithUTF8String:title];
    NSString *message = [NSString stringWithUTF8String:body];
    if (!heading.length || !message) return -1;
    UNUserNotificationCenter *center = UNUserNotificationCenter.currentNotificationCenter;
    [center requestAuthorizationWithOptions:UNAuthorizationOptionAlert | UNAuthorizationOptionSound
        completionHandler:^(BOOL granted, NSError *error) {
            if (!granted || error) return;
            UNMutableNotificationContent *content = [UNMutableNotificationContent new];
            content.title = heading;
            content.body = message;
            UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:NSUUID.UUID.UUIDString
                content:content trigger:nil];
            [center addNotificationRequest:request withCompletionHandler:^(NSError *addError) {
                if (addError) NSLog(@"Neiv notification failed: %@", addError.localizedDescription);
            }];
        }];
    return 0;
}
int cyna_run_app(CynaCommandDispatcher dispatcher, void (*configure)(void)) {
    @autoreleasepool {
        NSURL *url = [[NSBundle mainBundle] URLForResource:@"app" withExtension:@"json"];
        NSData *data = [NSData dataWithContentsOfURL:url];
        NSDictionary *manifest = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        if (![manifest isKindOfClass:NSDictionary.class] || !dispatcher || !configure) return 2;
        appManifest = manifest;
        appCapabilities = [manifest[@"capabilities"] isKindOfClass:NSArray.class] ? manifest[@"capabilities"] : @[];
        NSURL *eventsUrl = [[NSBundle mainBundle] URLForResource:@"events" withExtension:@"json"];
        NSData *eventsData = [NSData dataWithContentsOfURL:eventsUrl];
        eventSchemas = eventsData ? [NSJSONSerialization JSONObjectWithData:eventsData options:0 error:nil] : nil;
        if (![eventSchemas isKindOfClass:NSDictionary.class]) return 2;
        configure();
        if (!initialWindow) return 2;
        NSApplication *app = NSApplication.sharedApplication;
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];
        CynaAppHost *host = [CynaAppHost new];
        host.manifest = manifest; host.dispatcher = dispatcher;
        app.delegate = host;
        [app run];
    }
    return 0;
}
