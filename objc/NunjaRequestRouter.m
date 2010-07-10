
#import "NunjaRequestHandler.h"
#import "NunjaRequestRouter.h"
#import "NunjaRequest.h"

NSString *spaces(int n) {
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
    router->contents = [[NSMutableDictionary alloc] init];
    router->tokens = [[NSMutableSet setWithObject:token] retain];
    return router;
}

- (NSMutableSet *) tokens {
	return tokens;
}

- (void) dump:(int) level
{
    NSLog(@"%@%@\t%@", spaces(level), [[self->tokens allObjects] componentsJoinedByString:@","], self->handler);
    id keys = [self->contents allKeys];
    for (int i = 0; i < [keys count]; i++) {
        id key = [keys objectAtIndex:i];
        id value = [self->contents objectForKey:key];
        [value dump:(level+1)];
    }
}

- (id) routeRequest:(NunjaRequest *) request parts:(NSArray *) parts level:(int) level
{
    if (level == [parts count]) {
        return self->handler;
    }
    else {
        id key = [parts objectAtIndex:level];
        id response;
        id child = [self->contents objectForKey:key];
        if (child && (response = [child routeRequest:request parts:parts level:(level+1)])) {
            // if the response is non-null, we have a match
            return response;
        }
        else if (child = [self->contents objectForKey:@":"]) {
			id childTokens = [[child tokens] allObjects];
			for (int i = 0; i < [childTokens count]; i++) {
				id childToken = [childTokens objectAtIndex:i];
				[[request bindings] setObject:key forKey:[childToken substringToIndex:([childToken length]-1)]];
			}
            return [child routeRequest:request parts:parts level:(level + 1)];
        }
        else {
            return nil;
        }
    }
}

- (void) insertHandler:(NunjaRequestHandler *) h level:(int) level
{
    if (level == [[h parts] count]) {
        self->handler = [h retain];
    }
    else {
        id key = [[h parts] objectAtIndex:level];
        BOOL key_is_wildcard = ([key length] > 0) && ([key characterAtIndex:([key length] - 1)] == ':');
        id child = [self->contents objectForKey:(key_is_wildcard ? @":" : key)];
        if (!child) {
            child = [NunjaRequestRouter routerWithToken:key];
		} else {
			[[child tokens] addObject:key];
		}
		if (([key length] > 0) && (([key characterAtIndex:0] == ':') || ([key characterAtIndex:([key length] -1)] == ':'))) {
			[self->contents setObject:child forKey:@":"];
		}
		else {
			[self->contents setObject:child forKey:key];
		}
		[child insertHandler:h level:level+1];
    }
}

@end
