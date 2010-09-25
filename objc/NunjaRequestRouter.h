#import <Foundation/Foundation.h>

@class NunjaRequest;
@class NunjaRequestHandler;

@interface NunjaRequestRouter : NSObject
{
    NSMutableDictionary *keyHandlers;
    NSMutableArray *patternHandlers;
    NSString *token;
    NunjaRequestHandler *handler;
}

+ (NunjaRequestRouter *) routerWithToken:(id) token;
- (NSString *) token;
- (void) insertHandler:(NunjaRequestHandler *) handler level:(int) level;
- (BOOL) routeAndHandleRequest:(NunjaRequest *) request parts:(NSArray *) parts level:(int) level;
@end
