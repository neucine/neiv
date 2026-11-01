#import <Foundation/Foundation.h>
#import "asset_policy.h"
#include <assert.h>

int main(void) {
    @autoreleasepool {
        NSString *root = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
        NSFileManager *files = NSFileManager.defaultManager;
        assert([files createDirectoryAtPath:root withIntermediateDirectories:YES attributes:nil error:nil]);
        NSString *html = [root stringByAppendingPathComponent:@"index.html"];
        assert([@"ok" writeToFile:html atomically:YES encoding:NSUTF8StringEncoding error:nil]);
        NSString *outside = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
        assert([@"secret" writeToFile:outside atomically:YES encoding:NSUTF8StringEncoding error:nil]);
        assert([files createSymbolicLinkAtPath:[root stringByAppendingPathComponent:@"escape.txt"] withDestinationPath:outside error:nil]);
        assert(CynaNavigationAllowed([NSURL URLWithString:@"cyna-app://local/index.html"]));
        assert(!CynaNavigationAllowed([NSURL URLWithString:@"https://example.com/"]));
        assert(!CynaNavigationAllowed([NSURL URLWithString:@"cyna-app://remote/index.html"]));
        assert([CynaAssetPath(root, [NSURL URLWithString:@"cyna-app://local/index.html"]) isEqualToString:html]);
        assert(!CynaAssetPath(root, [NSURL URLWithString:@"cyna-app://local/%2e%2e/outside"]));
        assert(!CynaAssetPath(root, [NSURL URLWithString:@"cyna-app://local/%252e%252e/outside"]));
        assert(!CynaAssetPath(root, [NSURL URLWithString:@"cyna-app://local/escape.txt"]));
        assert([CynaAssetMime(@"App.mjs") isEqualToString:@"text/javascript"]);
        assert([CynaAssetMime(@"image.png") isEqualToString:@"image/png"]);
        assert([CynaAssetMime(@"file.bin") isEqualToString:@"application/octet-stream"]);
        [files removeItemAtPath:root error:nil];
        [files removeItemAtPath:outside error:nil];
    }
    return 0;
}
