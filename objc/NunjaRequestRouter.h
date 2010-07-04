#import <Foundation/Foundation.h>

@class NunjaRequest;
@class NunjaRequestHandler;

@interface NunjaRequestRouter : NSObject {
   NSMutableDictionary *contents;
   NSMutableSet *tokens;
   NunjaRequestHandler *handler;
}

+ (NunjaRequestRouter *) routerWithToken:(id) token;
- (NSMutableSet *) tokens;
- (void) dump:(int) level;
- (id) routeRequest:(NunjaRequest *) request parts:(NSArray *) parts level:(int) level;
- (void) insertHandler:(NunjaRequestHandler *) handler level:(int) level;
@end

