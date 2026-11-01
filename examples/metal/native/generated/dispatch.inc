// Generated from Cyna exports. Do not edit.
#import "command_validation.h"
#include <math.h>
#include <string.h>
extern int metal_show(void);
extern int metal_hide(void);
static id dispatch_command(NSString *command, NSDictionary *args, NSDictionary **error) {
    if (![args isKindOfClass:NSDictionary.class]) { *error = CynaCommandError(@"INVALID_ARGUMENT", @"Invalid command arguments"); return nil; }
    if ([command isEqualToString:@"show"]) {
        if (args.count > 0) { *error = CynaCommandError(@"INVALID_ARGUMENT", @"Invalid command arguments"); return nil; }
        id result = @(metal_show());
        if (!CynaCommandValid(result, @{@"type": @"int32", @"min": @(-2147483648), @"max": @(2147483647)}, 0)) { *error = CynaCommandError(@"INVALID_RESULT", @"Invalid native command result"); return nil; }
        return result;
    }
    if ([command isEqualToString:@"hide"]) {
        if (args.count > 0) { *error = CynaCommandError(@"INVALID_ARGUMENT", @"Invalid command arguments"); return nil; }
        id result = @(metal_hide());
        if (!CynaCommandValid(result, @{@"type": @"int32", @"min": @(-2147483648), @"max": @(2147483647)}, 0)) { *error = CynaCommandError(@"INVALID_RESULT", @"Invalid native command result"); return nil; }
        return result;
    }
    *error = CynaCommandError(@"UNKNOWN_COMMAND", @"Unsupported command"); return nil;
}
