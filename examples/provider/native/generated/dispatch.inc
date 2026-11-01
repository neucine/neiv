// Generated from Cyna exports. Do not edit.
#import "command_validation.h"
#include <math.h>
#include <string.h>
extern int provider_show(void);
extern int provider_hide(void);
extern int provider_detach(void);
extern int provider_attach(void);
extern int provider_scale(void);
extern int provider_focus(void);
static id dispatch_command(NSString *command, NSDictionary *args, NSDictionary **error) {
    if (![args isKindOfClass:NSDictionary.class]) { *error = CynaCommandError(@"INVALID_ARGUMENT", @"Invalid command arguments"); return nil; }
    if ([command isEqualToString:@"show"]) {
        if (args.count > 0) { *error = CynaCommandError(@"INVALID_ARGUMENT", @"Invalid command arguments"); return nil; }
        id result = @(provider_show());
        if (!CynaCommandValid(result, @{@"type": @"int32", @"min": @(-2147483648), @"max": @(2147483647)}, 0)) { *error = CynaCommandError(@"INVALID_RESULT", @"Invalid native command result"); return nil; }
        return result;
    }
    if ([command isEqualToString:@"hide"]) {
        if (args.count > 0) { *error = CynaCommandError(@"INVALID_ARGUMENT", @"Invalid command arguments"); return nil; }
        id result = @(provider_hide());
        if (!CynaCommandValid(result, @{@"type": @"int32", @"min": @(-2147483648), @"max": @(2147483647)}, 0)) { *error = CynaCommandError(@"INVALID_RESULT", @"Invalid native command result"); return nil; }
        return result;
    }
    if ([command isEqualToString:@"detachSurface"]) {
        if (args.count > 0) { *error = CynaCommandError(@"INVALID_ARGUMENT", @"Invalid command arguments"); return nil; }
        id result = @(provider_detach());
        if (!CynaCommandValid(result, @{@"type": @"int32", @"min": @(-2147483648), @"max": @(2147483647)}, 0)) { *error = CynaCommandError(@"INVALID_RESULT", @"Invalid native command result"); return nil; }
        return result;
    }
    if ([command isEqualToString:@"attachSurface"]) {
        if (args.count > 0) { *error = CynaCommandError(@"INVALID_ARGUMENT", @"Invalid command arguments"); return nil; }
        id result = @(provider_attach());
        if (!CynaCommandValid(result, @{@"type": @"int32", @"min": @(-2147483648), @"max": @(2147483647)}, 0)) { *error = CynaCommandError(@"INVALID_RESULT", @"Invalid native command result"); return nil; }
        return result;
    }
    if ([command isEqualToString:@"scale"]) {
        if (args.count > 0) { *error = CynaCommandError(@"INVALID_ARGUMENT", @"Invalid command arguments"); return nil; }
        id result = @(provider_scale());
        if (!CynaCommandValid(result, @{@"type": @"int32", @"min": @(-2147483648), @"max": @(2147483647)}, 0)) { *error = CynaCommandError(@"INVALID_RESULT", @"Invalid native command result"); return nil; }
        return result;
    }
    if ([command isEqualToString:@"focusSurface"]) {
        if (args.count > 0) { *error = CynaCommandError(@"INVALID_ARGUMENT", @"Invalid command arguments"); return nil; }
        id result = @(provider_focus());
        if (!CynaCommandValid(result, @{@"type": @"int32", @"min": @(-2147483648), @"max": @(2147483647)}, 0)) { *error = CynaCommandError(@"INVALID_RESULT", @"Invalid native command result"); return nil; }
        return result;
    }
    *error = CynaCommandError(@"UNKNOWN_COMMAND", @"Unsupported command"); return nil;
}
