// Generated from Cyna exports. Do not edit.
#import "command_validation.h"
#include <math.h>
#include <string.h>
extern int cyna_app_video_show(void);
extern int cyna_app_video_detach(void);
extern int cyna_app_video_attach(void);
extern int cyna_app_add(int, int);
extern int cyna_app_surface_level(int);
static id dispatch_command(NSString *command, NSDictionary *args, NSDictionary **error) {
    if (![args isKindOfClass:NSDictionary.class]) { *error = CynaCommandError(@"INVALID_ARGUMENT", @"Invalid command arguments"); return nil; }
    if ([command isEqualToString:@"videoShow"]) {
        if (args.count > 0) { *error = CynaCommandError(@"INVALID_ARGUMENT", @"Invalid command arguments"); return nil; }
        id result = @(cyna_app_video_show());
        if (!CynaCommandValid(result, @{@"type": @"int32", @"min": @(-2147483648), @"max": @(2147483647)}, 0)) { *error = CynaCommandError(@"INVALID_RESULT", @"Invalid native command result"); return nil; }
        return result;
    }
    if ([command isEqualToString:@"videoDetach"]) {
        if (args.count > 0) { *error = CynaCommandError(@"INVALID_ARGUMENT", @"Invalid command arguments"); return nil; }
        id result = @(cyna_app_video_detach());
        if (!CynaCommandValid(result, @{@"type": @"int32", @"min": @(-2147483648), @"max": @(2147483647)}, 0)) { *error = CynaCommandError(@"INVALID_RESULT", @"Invalid native command result"); return nil; }
        return result;
    }
    if ([command isEqualToString:@"videoAttach"]) {
        if (args.count > 0) { *error = CynaCommandError(@"INVALID_ARGUMENT", @"Invalid command arguments"); return nil; }
        id result = @(cyna_app_video_attach());
        if (!CynaCommandValid(result, @{@"type": @"int32", @"min": @(-2147483648), @"max": @(2147483647)}, 0)) { *error = CynaCommandError(@"INVALID_RESULT", @"Invalid native command result"); return nil; }
        return result;
    }
    if ([command isEqualToString:@"math.add"]) {
        if (args.count > 2) { *error = CynaCommandError(@"INVALID_ARGUMENT", @"Invalid command arguments"); return nil; }
        id value_raw = args[@"value"];
        if (!CynaCommandValid(value_raw, @{@"type": @"int32", @"min": @(-1000000), @"max": @(1000000)}, 0)) { *error = CynaCommandError(@"INVALID_ARGUMENT", @"Invalid command arguments"); return nil; }
        int value = [value_raw intValue];
        id delta_raw = args[@"delta"];
        if (!CynaCommandValid(delta_raw, @{@"type": @"int32", @"min": @(-1000000), @"max": @(1000000)}, 0)) { *error = CynaCommandError(@"INVALID_ARGUMENT", @"Invalid command arguments"); return nil; }
        int delta = [delta_raw intValue];
        id result = @(cyna_app_add(value, delta));
        if (!CynaCommandValid(result, @{@"type": @"int32", @"min": @(-2147483648), @"max": @(2147483647)}, 0)) { *error = CynaCommandError(@"INVALID_RESULT", @"Invalid native command result"); return nil; }
        return result;
    }
    if ([command isEqualToString:@"surface.setLevel"]) {
        if (args.count > 1) { *error = CynaCommandError(@"INVALID_ARGUMENT", @"Invalid command arguments"); return nil; }
        id level_raw = args[@"level"];
        if (!CynaCommandValid(level_raw, @{@"type": @"int32", @"min": @(0), @"max": @(1000)}, 0)) { *error = CynaCommandError(@"INVALID_ARGUMENT", @"Invalid command arguments"); return nil; }
        int level = [level_raw intValue];
        id result = @(cyna_app_surface_level(level));
        if (!CynaCommandValid(result, @{@"type": @"int32", @"min": @(-2147483648), @"max": @(2147483647)}, 0)) { *error = CynaCommandError(@"INVALID_RESULT", @"Invalid native command result"); return nil; }
        return result;
    }
    *error = CynaCommandError(@"UNKNOWN_COMMAND", @"Unsupported command"); return nil;
}
