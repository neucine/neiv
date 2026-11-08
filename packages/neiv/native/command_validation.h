#import <Foundation/Foundation.h>

BOOL CynaCommandValid(id value, NSDictionary *spec, NSUInteger depth);
NSDictionary *CynaCommandError(NSString *code, NSString *message);
