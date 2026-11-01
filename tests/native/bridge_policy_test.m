#import <AppKit/AppKit.h>
#import <WebKit/WebKit.h>
#import "bridge_policy.h"
#include <assert.h>

@interface BridgeFixture : NSObject <WKURLSchemeHandler, WKScriptMessageHandler>
@property(nonatomic) NSUInteger accepted;
@property(nonatomic) NSUInteger rejected;
@end
@implementation BridgeFixture
- (void)webView:(WKWebView *)webView startURLSchemeTask:(id<WKURLSchemeTask>)task {
    (void)webView;
    NSString *html = [task.request.URL.path isEqualToString:@"/frame.html"]
        ? @"<script>window.webkit.messageHandlers.cyna.postMessage('sub')</script>"
        : @"<script>window.webkit.messageHandlers.cyna.postMessage('main')</script><iframe src='cyna-app://local/frame.html'></iframe>";
    NSData *data = [html dataUsingEncoding:NSUTF8StringEncoding];
    NSURLResponse *response = [[NSURLResponse alloc] initWithURL:task.request.URL MIMEType:@"text/html"
        expectedContentLength:data.length textEncodingName:@"utf-8"];
    [task didReceiveResponse:response]; [task didReceiveData:data]; [task didFinish];
}
- (void)webView:(WKWebView *)webView stopURLSchemeTask:(id<WKURLSchemeTask>)task { (void)webView; (void)task; }
- (void)userContentController:(WKUserContentController *)controller didReceiveScriptMessage:(WKScriptMessage *)message {
    (void)controller;
    if (CynaBridgeAllowed(message)) self.accepted++;
    else self.rejected++;
}
@end

int main(void) {
    @autoreleasepool {
        (void)NSApplication.sharedApplication;
        BridgeFixture *fixture = [BridgeFixture new];
        WKWebViewConfiguration *config = [WKWebViewConfiguration new];
        [config setURLSchemeHandler:fixture forURLScheme:@"cyna-app"];
        [config.userContentController addScriptMessageHandler:fixture name:@"cyna"];
        WKWebView *view = [[WKWebView alloc] initWithFrame:NSMakeRect(0, 0, 320, 240) configuration:config];
        [view loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"cyna-app://local/index.html"]]];
        NSDate *limit = [NSDate dateWithTimeIntervalSinceNow:5];
        while (fixture.accepted + fixture.rejected < 2 && limit.timeIntervalSinceNow > 0)
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
        assert(fixture.accepted == 1);
        assert(fixture.rejected == 1);
        [config.userContentController removeScriptMessageHandlerForName:@"cyna"];
    }
    return 0;
}
