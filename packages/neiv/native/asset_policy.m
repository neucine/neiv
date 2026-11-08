#import "asset_policy.h"

BOOL CynaNavigationAllowed(NSURL *url) {
    return [url.scheme isEqualToString:@"cyna-app"] && [url.host isEqualToString:@"local"];
}

NSString *CynaAssetPath(NSString *root, NSURL *url) {
    if (!CynaNavigationAllowed(url)) return nil;
    NSString *path = url.path.stringByRemovingPercentEncoding;
    if (!path || ![path hasPrefix:@"/"] || [path hasPrefix:@"//"] || [path containsString:@"\\"] ||
        [path.pathComponents containsObject:@".."] || [path.pathComponents containsObject:@"."]) return nil;
    NSString *relative = [path substringFromIndex:1];
    if (!relative.length) return nil;
    NSString *canonicalRoot = [[root stringByResolvingSymlinksInPath] stringByStandardizingPath];
    NSString *candidate = [[[canonicalRoot stringByAppendingPathComponent:relative] stringByResolvingSymlinksInPath] stringByStandardizingPath];
    if (![candidate hasPrefix:[canonicalRoot stringByAppendingString:@"/"]]) return nil;
    return candidate;
}

NSString *CynaAssetMime(NSString *path) {
    NSDictionary *types = @{@"html":@"text/html", @"js":@"text/javascript", @"mjs":@"text/javascript",
        @"css":@"text/css", @"json":@"application/json", @"svg":@"image/svg+xml", @"png":@"image/png",
        @"jpg":@"image/jpeg", @"jpeg":@"image/jpeg", @"webp":@"image/webp", @"woff2":@"font/woff2"};
    return types[path.pathExtension.lowercaseString] ?: @"application/octet-stream";
}
