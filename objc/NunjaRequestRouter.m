
#import "NunjaRequestHandler.h"
#import "NunjaRequestRouter.h"
#import "NunjaRequest.h"

static NSString *spaces(int n)
{
    NSMutableString *result = [NSMutableString string];
    for (int i = 0; i < n; i++) {
        [result appendString:@" "];
    }
    return result;
}

@implementation NunjaRequestRouter

+ (NunjaRequestRouter *) routerWithToken:(NSString *) token
{
    NunjaRequestRouter *router = [[[self alloc] init] autorelease];
    router->keyHandlers = [[NSMutableDictionary alloc] init];
    router->patternHandlers = [[NSMutableArray alloc] init];
	router->token = [token copy];
    return router;
}

- (NSString *) token
{
    return token;
}

- (NSString *) descriptionWithLevel:(int) level
{
    NSMutableString *result;
    if (level >= 2) {
        result = [NSMutableString stringWithFormat:@"%@/%@%@\n",
            spaces(level),
            self->token,
            self->handler ? @"  " : @" -"];
    }
    else {
        result = [NSMutableString stringWithFormat:@"%@%@\n",
            spaces(level),
            self->token];
    }
    id keys = [[self->keyHandlers allKeys] sortedArrayUsingSelector:@selector(compare:)];
    for (int i = 0; i < [keys count]; i++) {
        id key = [keys objectAtIndex:i];
        id value = [self->keyHandlers objectForKey:key];
        [result appendString:[value descriptionWithLevel:(level+1)]];
    }
    for (int i = 0; i < [self->patternHandlers count]; i++) {
        id value = [self->patternHandlers objectAtIndex:i];
        [result appendString:[value descriptionWithLevel:(level+1)]];
    }
    return result;
}

- (NSString *) description
{
    return [self descriptionWithLevel:0];
}

- (BOOL) routeAndHandleRequest:(NunjaRequest *) request parts:(NSArray *) parts level:(int) level
{
    if (level == [parts count]) {
        BOOL handled = NO;
        @try
        {
            handled = [self->handler handleRequest:request];
        }
        @catch (id exception) {
            NSLog(@"Nunja handler exception: %@ %@", [exception description], [request description]);
            if (YES) {                            // DEBUGGING
                [request setContentType:@"text/plain"];
                [request respondWithString:[exception description]];
                handled = YES;
            }
        }
        return handled;
    }
    else {
        id key = [parts objectAtIndex:level];
        id child;
        if (child = [self->keyHandlers objectForKey:key]) {
            if ([child routeAndHandleRequest:request parts:parts level:(level+1)]) {
                return YES;
            }
        }
        for (int i = 0; i < [self->patternHandlers count]; i++) {
            child = [self->patternHandlers objectAtIndex:i];
			NSString *childToken = [child token];
            if ([childToken characterAtIndex:0] == '*') {
                NSArray *remainingParts = [parts subarrayWithRange:NSMakeRange(level, [parts count] - level)];
                NSString *remainder = [remainingParts componentsJoinedByString:@"/"];
                [[request bindings] setObject:remainder
                    forKey:[childToken substringToIndex:([childToken length]-1)]];
                if ([child routeAndHandleRequest:request parts:parts level:[parts count]]) {
                    return YES;
                }
            }
            else {
                [[request bindings] setObject:key
                    forKey:[childToken substringToIndex:([childToken length]-1)]];
                if ([child routeAndHandleRequest:request parts:parts level:(level + 1)]) {
                    return YES;
                }
            }
            // otherwise, remove bindings and continue
            [[request bindings] removeObjectForKey:[childToken substringToIndex:([childToken length]-1)]];
        }
        return NO;
    }
}

- (void) insertHandler:(NunjaRequestHandler *) h level:(int) level
{
    if (level == [[h parts] count]) {
        self->handler = [h retain];
    }
    else {
        id key = [[h parts] objectAtIndex:level];
        BOOL key_is_pattern = ([key length] > 0) && ([key characterAtIndex:([key length] - 1)] == ':');
        id child = key_is_pattern ? nil : [self->keyHandlers objectForKey:key];
        if (!child) {
            child = [NunjaRequestRouter routerWithToken:key];
        }
        if (key_is_pattern) {
            [self->patternHandlers addObject:child];
        }
        else {
            [self->keyHandlers setObject:child forKey:key];
        }
        [child insertHandler:h level:level+1];
    }
}

@end
