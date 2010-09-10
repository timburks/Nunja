#import <Foundation/Foundation.h>

@class NunjaRequestHandler;
@class NunjaRequestRouter;

@interface NunjaDefaultDelegate : NSObject <NunjaDelegate>
{
    NunjaRequestHandler *defaultHandler;
    NunjaRequestRouter *router;
}

- (void) configureSite:(NSString *) site;

- (void) addHandler:(NunjaRequestHandler *) handler;
- (void) addHandlerWithHTTPMethod:(NSString *)httpMethod path:(NSString *)path block:(id)block;
- (void) setDefaultHandlerWithBlock:(id) block;

- (void) dump;

@end
