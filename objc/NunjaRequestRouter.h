#import <Foundation/Foundation.h>

@class NunjaRequest;
@class NunjaRequestHandler;

@interface NunjaRequestRouter : NSObject {
   NSMutableDictionary *contents;
   NSString *token;
   NunjaRequestHandler *handler;
}

+ (NunjaRequestRouter *) routerWithToken:(id) token;
- (NSString *) token;
- (void) dump:(int) level;
- (id) routeRequest:(NunjaRequest *) request parts:(NSArray *) parts level:(int) level;
- (void) insertHandler:(NunjaRequestHandler *) handler level:(int) level;
@end
