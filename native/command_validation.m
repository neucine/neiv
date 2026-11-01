#import "command_validation.h"
#import <CoreFoundation/CoreFoundation.h>
#include <math.h>

static BOOL isBoolean(id value) {
    return [value isKindOfClass:NSNumber.class] && CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID();
}

BOOL CynaCommandValid(id value, NSDictionary *spec, NSUInteger depth) {
    if (depth > 8 || ![spec isKindOfClass:NSDictionary.class]) return NO;
    NSString *type = spec[@"type"];
    if ([type isEqualToString:@"optional"]) {
        return !value || value == NSNull.null || CynaCommandValid(value, spec[@"value"], depth + 1);
    }
    if (!value || value == NSNull.null) return NO;
    if ([type isEqualToString:@"int32"]) {
        if (![value isKindOfClass:NSNumber.class] || isBoolean(value)) return NO;
        double number = [value doubleValue];
        return isfinite(number) && number >= -2147483648.0 && number <= 2147483647.0 &&
            trunc(number) == number && number >= [spec[@"min"] doubleValue] && number <= [spec[@"max"] doubleValue];
    }
    if ([type isEqualToString:@"boolean"]) return isBoolean(value);
    if ([type isEqualToString:@"number"]) {
        if (![value isKindOfClass:NSNumber.class] || isBoolean(value)) return NO;
        double number = [value doubleValue];
        return isfinite(number) && number >= [spec[@"min"] doubleValue] && number <= [spec[@"max"] doubleValue];
    }
    if ([type isEqualToString:@"string"]) {
        if (![value isKindOfClass:NSString.class]) return NO;
        NSData *bytes = [value dataUsingEncoding:NSUTF8StringEncoding];
        if (!bytes || bytes.length > [spec[@"maxBytes"] unsignedIntegerValue]) return NO;
        for (NSUInteger index = 0; index < [value length]; index++)
            if ([value characterAtIndex:index] == 0) return NO;
        return YES;
    }
    if ([type isEqualToString:@"array"]) {
        if (![value isKindOfClass:NSArray.class] || [value count] > [spec[@"maxItems"] unsignedIntegerValue]) return NO;
        for (id item in value) if (!CynaCommandValid(item, spec[@"items"], depth + 1)) return NO;
        return YES;
    }
    if ([type isEqualToString:@"record"]) {
        NSDictionary *fields = spec[@"fields"];
        if (![value isKindOfClass:NSDictionary.class] || [value count] > fields.count) return NO;
        for (NSString *key in value) if (!fields[key]) return NO;
        for (NSString *key in fields) {
            if (![key isKindOfClass:NSString.class]) return NO;
            if (!CynaCommandValid(value[key], fields[key], depth + 1)) return NO;
        }
        return YES;
    }
    return NO;
}

NSDictionary *CynaCommandError(NSString *code, NSString *message) {
    return @{@"code": code, @"message": message};
}
