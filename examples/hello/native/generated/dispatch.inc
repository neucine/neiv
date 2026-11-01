// Generated from Cyna exports. Do not edit.
#import "command_validation.h"
#include <math.h>
#include <string.h>
extern int hello_open_window(void);
extern int hello_publish_update(void);
extern int hello_show_native_label(void);
extern int hello_surface_lifecycle(void);
extern int hello_rename_current(void);
extern int hello_close_current(void);
extern int hello_file_dialog_status(void);
extern int hello_service_denial(void);
extern int hello_optional_service_denial(void);
extern int hello_app_identity(void);
extern int hello_double(int);
extern int hello_slow_double(int);
extern int hello_score(const char *, int, double);
extern int hello_payload_size(const char *);
extern int hello_label(char *, int);
extern double hello_half(double);
extern int hello_invert(int);
extern int hello_summary(char *, int);
static id dispatch_command(NSString *command, NSDictionary *args, NSDictionary **error) {
    if (![args isKindOfClass:NSDictionary.class]) { *error = CynaCommandError(@"INVALID_ARGUMENT", @"Invalid command arguments"); return nil; }
    if ([command isEqualToString:@"openWindow"]) {
        if (args.count > 0) { *error = CynaCommandError(@"INVALID_ARGUMENT", @"Invalid command arguments"); return nil; }
        id result = @(hello_open_window());
        if (!CynaCommandValid(result, @{@"type": @"int32", @"min": @(-2147483648), @"max": @(2147483647)}, 0)) { *error = CynaCommandError(@"INVALID_RESULT", @"Invalid native command result"); return nil; }
        return result;
    }
    if ([command isEqualToString:@"publishUpdate"]) {
        if (args.count > 0) { *error = CynaCommandError(@"INVALID_ARGUMENT", @"Invalid command arguments"); return nil; }
        id result = @(hello_publish_update());
        if (!CynaCommandValid(result, @{@"type": @"int32", @"min": @(-2147483648), @"max": @(2147483647)}, 0)) { *error = CynaCommandError(@"INVALID_RESULT", @"Invalid native command result"); return nil; }
        return result;
    }
    if ([command isEqualToString:@"showNativeLabel"]) {
        if (args.count > 0) { *error = CynaCommandError(@"INVALID_ARGUMENT", @"Invalid command arguments"); return nil; }
        id result = @(hello_show_native_label());
        if (!CynaCommandValid(result, @{@"type": @"int32", @"min": @(-2147483648), @"max": @(2147483647)}, 0)) { *error = CynaCommandError(@"INVALID_RESULT", @"Invalid native command result"); return nil; }
        return result;
    }
    if ([command isEqualToString:@"surfaceLifecycle"]) {
        if (args.count > 0) { *error = CynaCommandError(@"INVALID_ARGUMENT", @"Invalid command arguments"); return nil; }
        id result = @(hello_surface_lifecycle());
        if (!CynaCommandValid(result, @{@"type": @"int32", @"min": @(-2147483648), @"max": @(2147483647)}, 0)) { *error = CynaCommandError(@"INVALID_RESULT", @"Invalid native command result"); return nil; }
        return result;
    }
    if ([command isEqualToString:@"renameCurrent"]) {
        if (args.count > 0) { *error = CynaCommandError(@"INVALID_ARGUMENT", @"Invalid command arguments"); return nil; }
        id result = @(hello_rename_current());
        if (!CynaCommandValid(result, @{@"type": @"int32", @"min": @(-2147483648), @"max": @(2147483647)}, 0)) { *error = CynaCommandError(@"INVALID_RESULT", @"Invalid native command result"); return nil; }
        return result;
    }
    if ([command isEqualToString:@"closeCurrent"]) {
        if (args.count > 0) { *error = CynaCommandError(@"INVALID_ARGUMENT", @"Invalid command arguments"); return nil; }
        id result = @(hello_close_current());
        if (!CynaCommandValid(result, @{@"type": @"int32", @"min": @(-2147483648), @"max": @(2147483647)}, 0)) { *error = CynaCommandError(@"INVALID_RESULT", @"Invalid native command result"); return nil; }
        return result;
    }
    if ([command isEqualToString:@"fileDialogStatus"]) {
        if (args.count > 0) { *error = CynaCommandError(@"INVALID_ARGUMENT", @"Invalid command arguments"); return nil; }
        id result = @(hello_file_dialog_status());
        if (!CynaCommandValid(result, @{@"type": @"int32", @"min": @(-2147483648), @"max": @(2147483647)}, 0)) { *error = CynaCommandError(@"INVALID_RESULT", @"Invalid native command result"); return nil; }
        return result;
    }
    if ([command isEqualToString:@"serviceDenial"]) {
        if (args.count > 0) { *error = CynaCommandError(@"INVALID_ARGUMENT", @"Invalid command arguments"); return nil; }
        id result = @(hello_service_denial());
        if (!CynaCommandValid(result, @{@"type": @"int32", @"min": @(-2147483648), @"max": @(2147483647)}, 0)) { *error = CynaCommandError(@"INVALID_RESULT", @"Invalid native command result"); return nil; }
        return result;
    }
    if ([command isEqualToString:@"optionalServiceDenial"]) {
        if (args.count > 0) { *error = CynaCommandError(@"INVALID_ARGUMENT", @"Invalid command arguments"); return nil; }
        id result = @(hello_optional_service_denial());
        if (!CynaCommandValid(result, @{@"type": @"int32", @"min": @(-2147483648), @"max": @(2147483647)}, 0)) { *error = CynaCommandError(@"INVALID_RESULT", @"Invalid native command result"); return nil; }
        return result;
    }
    if ([command isEqualToString:@"appIdentity"]) {
        if (args.count > 0) { *error = CynaCommandError(@"INVALID_ARGUMENT", @"Invalid command arguments"); return nil; }
        id result = @(hello_app_identity());
        if (!CynaCommandValid(result, @{@"type": @"int32", @"min": @(-2147483648), @"max": @(2147483647)}, 0)) { *error = CynaCommandError(@"INVALID_RESULT", @"Invalid native command result"); return nil; }
        return result;
    }
    if ([command isEqualToString:@"math.double"]) {
        if (args.count > 1) { *error = CynaCommandError(@"INVALID_ARGUMENT", @"Invalid command arguments"); return nil; }
        id value_raw = args[@"value"];
        if (!CynaCommandValid(value_raw, @{@"type": @"int32", @"min": @(-10000), @"max": @(10000)}, 0)) { *error = CynaCommandError(@"INVALID_ARGUMENT", @"Invalid command arguments"); return nil; }
        int value = [value_raw intValue];
        id result = @(hello_double(value));
        if (!CynaCommandValid(result, @{@"type": @"int32", @"min": @(-2147483648), @"max": @(2147483647)}, 0)) { *error = CynaCommandError(@"INVALID_RESULT", @"Invalid native command result"); return nil; }
        return result;
    }
    if ([command isEqualToString:@"math.slowDouble"]) {
        if (args.count > 1) { *error = CynaCommandError(@"INVALID_ARGUMENT", @"Invalid command arguments"); return nil; }
        id value_raw = args[@"value"];
        if (!CynaCommandValid(value_raw, @{@"type": @"int32", @"min": @(-10000), @"max": @(10000)}, 0)) { *error = CynaCommandError(@"INVALID_ARGUMENT", @"Invalid command arguments"); return nil; }
        int value = [value_raw intValue];
        id result = @(hello_slow_double(value));
        if (!CynaCommandValid(result, @{@"type": @"int32", @"min": @(-2147483648), @"max": @(2147483647)}, 0)) { *error = CynaCommandError(@"INVALID_RESULT", @"Invalid native command result"); return nil; }
        return result;
    }
    if ([command isEqualToString:@"text.score"]) {
        if (args.count > 3) { *error = CynaCommandError(@"INVALID_ARGUMENT", @"Invalid command arguments"); return nil; }
        id text_raw = args[@"text"];
        if (!CynaCommandValid(text_raw, @{@"type": @"string", @"maxBytes": @(64)}, 0)) { *error = CynaCommandError(@"INVALID_ARGUMENT", @"Invalid command arguments"); return nil; }
        const char *text = [text_raw UTF8String];
        id enabled_raw = args[@"enabled"];
        if (!CynaCommandValid(enabled_raw, @{@"type": @"boolean"}, 0)) { *error = CynaCommandError(@"INVALID_ARGUMENT", @"Invalid command arguments"); return nil; }
        int enabled = [enabled_raw intValue];
        id factor_raw = args[@"factor"];
        if (!CynaCommandValid(factor_raw, @{@"type": @"number", @"min": @(0), @"max": @(10)}, 0)) { *error = CynaCommandError(@"INVALID_ARGUMENT", @"Invalid command arguments"); return nil; }
        double factor = [factor_raw doubleValue];
        id result = @(hello_score(text, enabled, factor));
        if (!CynaCommandValid(result, @{@"type": @"int32", @"min": @(-2147483648), @"max": @(2147483647)}, 0)) { *error = CynaCommandError(@"INVALID_RESULT", @"Invalid native command result"); return nil; }
        return result;
    }
    if ([command isEqualToString:@"data.size"]) {
        if (args.count > 1) { *error = CynaCommandError(@"INVALID_ARGUMENT", @"Invalid command arguments"); return nil; }
        id payload_raw = args[@"payload"];
        if (!CynaCommandValid(payload_raw, @{@"type": @"record", @"fields": @{@"title": @{@"type": @"string", @"maxBytes": @(64)}, @"flags": @{@"type": @"array", @"maxItems": @(4), @"items": @{@"type": @"boolean"}}, @"note": @{@"type": @"optional", @"value": @{@"type": @"string", @"maxBytes": @(32)}}}}, 0)) { *error = CynaCommandError(@"INVALID_ARGUMENT", @"Invalid command arguments"); return nil; }
        NSData *payload_data = [NSJSONSerialization dataWithJSONObject:payload_raw ?: NSNull.null options:NSJSONWritingFragmentsAllowed error:nil];
        NSString *payload_json = [[NSString alloc] initWithData:payload_data encoding:NSUTF8StringEncoding];
        if (!payload_json || payload_data.length > 65536) { *error = CynaCommandError(@"INVALID_ARGUMENT", @"Command arguments too large"); return nil; }
        const char *payload = [payload_json UTF8String];
        id result = @(hello_payload_size(payload));
        if (!CynaCommandValid(result, @{@"type": @"int32", @"min": @(-2147483648), @"max": @(2147483647)}, 0)) { *error = CynaCommandError(@"INVALID_RESULT", @"Invalid native command result"); return nil; }
        return result;
    }
    if ([command isEqualToString:@"text.label"]) {
        if (args.count > 0) { *error = CynaCommandError(@"INVALID_ARGUMENT", @"Invalid command arguments"); return nil; }
        char out[65536] = {0};
        int count = hello_label(out, 65536);
        id result = count >= 0 && count <= 65536 ? [[NSString alloc] initWithBytes:out length:(NSUInteger)count encoding:NSUTF8StringEncoding] : nil;
        if (!CynaCommandValid(result, @{@"type": @"string", @"maxBytes": @(16)}, 0)) { *error = CynaCommandError(@"INVALID_RESULT", @"Invalid native command result"); return nil; }
        return result;
    }
    if ([command isEqualToString:@"math.half"]) {
        if (args.count > 1) { *error = CynaCommandError(@"INVALID_ARGUMENT", @"Invalid command arguments"); return nil; }
        id value_raw = args[@"value"];
        if (!CynaCommandValid(value_raw, @{@"type": @"number", @"min": @(-100), @"max": @(100)}, 0)) { *error = CynaCommandError(@"INVALID_ARGUMENT", @"Invalid command arguments"); return nil; }
        double value = [value_raw doubleValue];
        double raw = hello_half(value); id result = isfinite(raw) ? @(raw) : nil;
        if (!CynaCommandValid(result, @{@"type": @"number", @"min": @(-50), @"max": @(50)}, 0)) { *error = CynaCommandError(@"INVALID_RESULT", @"Invalid native command result"); return nil; }
        return result;
    }
    if ([command isEqualToString:@"logic.invert"]) {
        if (args.count > 1) { *error = CynaCommandError(@"INVALID_ARGUMENT", @"Invalid command arguments"); return nil; }
        id value_raw = args[@"value"];
        if (!CynaCommandValid(value_raw, @{@"type": @"boolean"}, 0)) { *error = CynaCommandError(@"INVALID_ARGUMENT", @"Invalid command arguments"); return nil; }
        int value = [value_raw intValue];
        int raw = hello_invert(value); id result = raw == 0 || raw == 1 ? @((BOOL)raw) : nil;
        if (!CynaCommandValid(result, @{@"type": @"boolean"}, 0)) { *error = CynaCommandError(@"INVALID_RESULT", @"Invalid native command result"); return nil; }
        return result;
    }
    if ([command isEqualToString:@"data.summary"]) {
        if (args.count > 0) { *error = CynaCommandError(@"INVALID_ARGUMENT", @"Invalid command arguments"); return nil; }
        char out[65536] = {0};
        int count = hello_summary(out, 65536);
        id result = nil;
        if (count >= 0 && count <= 65536) { NSData *data = [NSData dataWithBytes:out length:(NSUInteger)count]; result = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingFragmentsAllowed error:nil]; }
        if (!CynaCommandValid(result, @{@"type": @"record", @"fields": @{@"message": @{@"type": @"string", @"maxBytes": @(32)}, @"values": @{@"type": @"array", @"maxItems": @(3), @"items": @{@"type": @"int32", @"min": @(-2147483648), @"max": @(2147483647)}}, @"enabled": @{@"type": @"optional", @"value": @{@"type": @"boolean"}}}}, 0)) { *error = CynaCommandError(@"INVALID_RESULT", @"Invalid native command result"); return nil; }
        return result;
    }
    *error = CynaCommandError(@"UNKNOWN_COMMAND", @"Unsupported command"); return nil;
}
