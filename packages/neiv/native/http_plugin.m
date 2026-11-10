#import "app_host_plugin.h"
#include <fcntl.h>
#include <unistd.h>

static NSTask *neivLocalServerTask;
static NSDictionary *neivLocalServerConfig;
static NSUInteger neivLocalServerUsers;
static NSString *neivLocalServerLogPath;

static NSDictionary *NeivStartLocalServer(NSDictionary *server) {
    NSString *resources = NSBundle.mainBundle.resourcePath;
    NSString *directory = [resources stringByAppendingPathComponent:@"local-http-server"];
    NSString *executable = [directory stringByAppendingPathComponent:server[@"executable"]];
    NSTask *task = [NSTask new];
    task.executableURL = [NSURL fileURLWithPath:executable];
    task.currentDirectoryURL = [NSURL fileURLWithPath:directory];
    task.arguments = server[@"args"];
    NSPipe *pipe = [NSPipe pipe];
    task.standardOutput = pipe;
    NSString *logDirectory = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Logs/Neiv"];
    [[NSFileManager defaultManager] createDirectoryAtPath:logDirectory withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *bundleID = NSBundle.mainBundle.bundleIdentifier ?: @"app";
    neivLocalServerLogPath = [logDirectory stringByAppendingPathComponent:[bundleID stringByAppendingString:@"-server.log"]];
    int logFD = open(neivLocalServerLogPath.fileSystemRepresentation, O_WRONLY | O_CREAT | O_TRUNC, 0600);
    task.standardError = logFD >= 0 ? [[NSFileHandle alloc] initWithFileDescriptor:logFD closeOnDealloc:YES] : NSFileHandle.fileHandleWithStandardError;
    NSError *error = nil;
    if (![task launchAndReturnError:&error]) {
        NSLog(@"Neiv local server launch failed: %@", error.localizedDescription);
        return nil;
    }
    dispatch_semaphore_t ready = dispatch_semaphore_create(0);
    NSMutableData *line = [NSMutableData data];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSFileHandle *reader = pipe.fileHandleForReading;
        while (line.length < 8192) {
            NSData *chunk = [reader readDataOfLength:1];
            if (!chunk.length) break;
            const char byte = *(const char *)chunk.bytes;
            if (byte == '\n') break;
            [line appendData:chunk];
        }
        dispatch_semaphore_signal(ready);
        while ([reader readDataOfLength:4096].length) {}
    });
    if (dispatch_semaphore_wait(ready, dispatch_time(DISPATCH_TIME_NOW, 15 * NSEC_PER_SEC)) != 0) {
        NSLog(@"Neiv local server startup timed out");
        [task terminate];
        return nil;
    }
    NSDictionary *config = [NSJSONSerialization JSONObjectWithData:line options:0 error:&error];
    if (![config isKindOfClass:NSDictionary.class]) {
        NSLog(@"Neiv local server handshake failed: %@", error.localizedDescription);
        [task terminate];
        return nil;
    }
    neivLocalServerTask = task;
    neivLocalServerConfig = config;
    return config;
}

@interface NeivHttpEventStream : NSObject <NSURLSessionDataDelegate>
@property(nonatomic, weak) WKWebView *webview;
@property(nonatomic, strong) NSURLSession *session;
@property(nonatomic, strong) NSURLSessionDataTask *task;
@property(nonatomic, strong) NSMutableData *buffer;
@property(nonatomic, copy) NSString *streamId;
@property(nonatomic) NSInteger status;
- (void)send:(NSString *)kind value:(id)value;
@end

@implementation NeivHttpEventStream
- (void)send:(NSString *)kind value:(id)value {
    NSDictionary *payload = @{ @"streamId": self.streamId, @"kind": kind, @"value": value ?: NSNull.null };
    NSData *data = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
    NSString *json = data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
    if (!json) return;
    dispatch_async(dispatch_get_main_queue(), ^{ [self.webview evaluateJavaScript:[NSString stringWithFormat:@"window.neivHttpEvent?.(%@)", json] completionHandler:nil]; });
}
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    self.status = [(NSHTTPURLResponse *)response statusCode];
    if (self.status != 200) [self send:@"error" value:[NSString stringWithFormat:@"Event stream HTTP %ld", (long)self.status]];
    completionHandler(self.status == 200 ? NSURLSessionResponseAllow : NSURLSessionResponseCancel);
}
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveData:(NSData *)data {
    [self.buffer appendData:data];
    if (self.buffer.length > 1048576) { [self send:@"error" value:@"Event stream frame too large"]; [task cancel]; return; }
    while (YES) {
        const unsigned char *bytes = self.buffer.bytes;
        NSUInteger end = NSNotFound;
        for (NSUInteger i = 0; i + 1 < self.buffer.length; i++) if (bytes[i] == '\n' && bytes[i + 1] == '\n') { end = i; break; }
        if (end == NSNotFound) break;
        NSData *frame = [self.buffer subdataWithRange:NSMakeRange(0, end)];
        [self.buffer replaceBytesInRange:NSMakeRange(0, end + 2) withBytes:NULL length:0];
        NSString *text = [[NSString alloc] initWithData:frame encoding:NSUTF8StringEncoding];
        for (NSString *line in [text componentsSeparatedByString:@"\n"]) {
            if (![line hasPrefix:@"data: "]) continue;
            NSData *json = [[line substringFromIndex:6] dataUsingEncoding:NSUTF8StringEncoding];
            id value = [NSJSONSerialization JSONObjectWithData:json options:0 error:nil];
            if (value) [self send:@"data" value:value];
        }
    }
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (error.code != NSURLErrorCancelled) [self send:@"closed" value:error.localizedDescription ?: @""];
}
@end

@interface NeivHttpPlugin : NSObject <CynaHostPlugin, WKScriptMessageHandler>
@property(nonatomic, weak) WKWebView *webview;
@property(nonatomic, strong) NSURL *baseURL;
@property(nonatomic, strong) NSDictionary<NSString *, NSString *> *headers;
@property(nonatomic, copy) NSString *startupError;
@property(nonatomic, strong) NSURLSession *session;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NeivHttpEventStream *> *streams;
@end

@implementation NeivHttpPlugin
- (void)attachToRoot:(NSView *)root webview:(WKWebView *)webview slots:(CynaSlotHost *)slots {
    (void)root; (void)slots;
    self.webview = webview;
    NSDictionary *manifest = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:[NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:@"app.json"]] options:0 error:nil];
    NSDictionary *server = [manifest[@"localHttp"] isKindOfClass:NSDictionary.class] ? manifest[@"localHttp"][@"server"] : nil;
    NSDictionary *configuration;
    if (server) {
        if (neivLocalServerTask && !neivLocalServerTask.isRunning) {
            neivLocalServerTask = nil;
            neivLocalServerConfig = nil;
        }
        configuration = neivLocalServerConfig ?: NeivStartLocalServer(server);
    }
    else {
        NSString *path = [NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:@"neiv-http.json"];
        NSData *data = [NSData dataWithContentsOfFile:path];
        configuration = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
    }
    NSString *endpoint = [configuration[@"endpoint"] isKindOfClass:NSString.class] ? configuration[@"endpoint"] : nil;
    NSDictionary *headers = [configuration[@"headers"] isKindOfClass:NSDictionary.class] ? configuration[@"headers"] : nil;
    NSURL *url = endpoint ? [NSURL URLWithString:endpoint] : nil;
    if ([url.scheme isEqualToString:@"http"] && [url.host isEqualToString:@"127.0.0.1"] && url.port && headers.count > 0) {
        BOOL valid = YES;
        NSCharacterSet *invalidName = [[NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-"] invertedSet];
        for (id key in headers) {
            if (![key isKindOfClass:NSString.class] || ![headers[key] isKindOfClass:NSString.class] ||
                [key length] < 1 || [key length] > 64 || [headers[key] length] > 4096 ||
                [key rangeOfCharacterFromSet:invalidName].location != NSNotFound ||
                [headers[key] rangeOfCharacterFromSet:[NSCharacterSet newlineCharacterSet]].location != NSNotFound)
                valid = NO;
        }
        if (valid) { self.baseURL = url; self.headers = headers; if (server) neivLocalServerUsers++; }
    }
    if (server && !self.baseURL && neivLocalServerUsers == 0) {
        self.startupError = neivLocalServerLogPath
            ? [NSString stringWithFormat:@"Local HTTP server failed to start. Server log: %@", neivLocalServerLogPath]
            : @"Local HTTP server failed to start; check its repository and server logs";
        if (neivLocalServerTask.isRunning) [neivLocalServerTask terminate];
        neivLocalServerTask = nil;
        neivLocalServerConfig = nil;
    }
    self.session = [NSURLSession sessionWithConfiguration:NSURLSessionConfiguration.ephemeralSessionConfiguration];
    self.streams = [NSMutableDictionary dictionary];
    [webview.configuration.userContentController addScriptMessageHandler:self name:@"neivHttp"];
}
- (void)receiveMessage:(NSDictionary *)message { (void)message; }
- (void)navigationStarted {}
- (void)close {
    [self.webview.configuration.userContentController removeScriptMessageHandlerForName:@"neivHttp"];
    for (NeivHttpEventStream *stream in self.streams.allValues) [stream.session invalidateAndCancel];
    [self.streams removeAllObjects];
    [self.session invalidateAndCancel];
    if (neivLocalServerTask && self.baseURL && neivLocalServerUsers > 0 && --neivLocalServerUsers == 0) {
        if (neivLocalServerTask.isRunning) [neivLocalServerTask terminate];
        neivLocalServerTask = nil;
        neivLocalServerConfig = nil;
    }
}
- (void)reply:(NSNumber *)identifier status:(NSInteger)status body:(id)body error:(NSString *)error {
    NSMutableDictionary *payload = [@{@"id": identifier, @"status": @(status), @"body": body ?: NSNull.null} mutableCopy];
    if (error) payload[@"error"] = error;
    NSData *encoded = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
    NSString *json = encoded ? [[NSString alloc] initWithData:encoded encoding:NSUTF8StringEncoding] : nil;
    if (!json) return;
    dispatch_async(dispatch_get_main_queue(), ^{ [self.webview evaluateJavaScript:[NSString stringWithFormat:@"window.neivHttpReply?.(%@)", json] completionHandler:nil]; });
}
- (void)userContentController:(WKUserContentController *)controller didReceiveScriptMessage:(WKScriptMessage *)message {
    (void)controller;
    NSDictionary *input = [message.body isKindOfClass:NSDictionary.class] ? message.body : nil;
    NSString *action = [input[@"action"] isKindOfClass:NSString.class] ? input[@"action"] : nil;
    if ([action isEqualToString:@"stopEvents"]) {
        NSString *streamId = [input[@"streamId"] isKindOfClass:NSString.class] ? input[@"streamId"] : nil;
        NeivHttpEventStream *stream = self.streams[streamId];
        [stream.session invalidateAndCancel]; [self.streams removeObjectForKey:streamId]; return;
    }
    if ([action isEqualToString:@"startEvents"]) {
        NSString *streamId = [input[@"streamId"] isKindOfClass:NSString.class] ? input[@"streamId"] : nil;
        NSString *path = [input[@"path"] isKindOfClass:NSString.class] ? input[@"path"] : nil;
        NSRegularExpression *valid = [NSRegularExpression regularExpressionWithPattern:@"^[A-Za-z0-9_-]{1,100}$" options:0 error:nil];
        if (!self.baseURL || !streamId || [valid numberOfMatchesInString:streamId options:0 range:NSMakeRange(0, streamId.length)] != 1 || !path || ![path hasPrefix:@"/"] || [path hasPrefix:@"//"] || [path containsString:@"\\"] || path.length > 2048) return;
        NSURL *url = [NSURL URLWithString:path relativeToURL:self.baseURL];
        if (![url.host isEqualToString:self.baseURL.host] || ![url.port isEqual:self.baseURL.port]) return;
        NeivHttpEventStream *old = self.streams[streamId]; [old.session invalidateAndCancel];
        NeivHttpEventStream *stream = [NeivHttpEventStream new]; stream.webview = self.webview; stream.streamId = streamId; stream.buffer = [NSMutableData data];
        stream.session = [NSURLSession sessionWithConfiguration:NSURLSessionConfiguration.ephemeralSessionConfiguration delegate:stream delegateQueue:nil];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url.absoluteURL];
        request.timeoutInterval = 3600; for (NSString *key in self.headers) [request setValue:self.headers[key] forHTTPHeaderField:key];
        stream.task = [stream.session dataTaskWithRequest:request]; self.streams[streamId] = stream; [stream.task resume]; return;
    }
    NSNumber *identifier = [input[@"id"] isKindOfClass:NSNumber.class] ? input[@"id"] : nil;
    NSString *method = [input[@"method"] isKindOfClass:NSString.class] ? input[@"method"] : nil;
    NSString *path = [input[@"path"] isKindOfClass:NSString.class] ? input[@"path"] : nil;
    if (!identifier) return;
    if (!self.baseURL) { [self reply:identifier status:0 body:nil error:self.startupError ?: @"Local HTTP bridge is not configured"]; return; }
    if (![@[@"GET", @"POST"] containsObject:method]) { [self reply:identifier status:0 body:nil error:@"Unsupported HTTP method"]; return; }
    if (!path || ![path hasPrefix:@"/"] || [path hasPrefix:@"//"] || [path containsString:@"\\"] || path.length > 2048) { [self reply:identifier status:0 body:nil error:@"Invalid request path"]; return; }
    NSURL *url = [NSURL URLWithString:path relativeToURL:self.baseURL];
    if (![url.host isEqualToString:self.baseURL.host] || ![url.port isEqual:self.baseURL.port]) { [self reply:identifier status:0 body:nil error:@"Invalid request destination"]; return; }
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url.absoluteURL];
    request.HTTPMethod = method; request.timeoutInterval = 30;
    for (NSString *key in self.headers) [request setValue:self.headers[key] forHTTPHeaderField:key];
    if ([method isEqualToString:@"POST"]) {
        id body = input[@"body"] ?: @{};
        NSData *encoded = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
        if (!encoded || encoded.length > 1048576) { [self reply:identifier status:0 body:nil error:@"Invalid request body"]; return; }
        request.HTTPBody = encoded; [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    }
    [[self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) { [self reply:identifier status:0 body:nil error:error.localizedDescription]; return; }
        if (data.length > 1048576) { [self reply:identifier status:0 body:nil error:@"Response body too large"]; return; }
        NSInteger status = [(NSHTTPURLResponse *)response statusCode];
        id body = data.length ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : @{};
        [self reply:identifier status:status body:body error:nil];
    }] resume];
}
@end
