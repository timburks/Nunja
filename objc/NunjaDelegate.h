#import <Foundation/Foundation.h>

@class NunjaRequestHandler;
@class NunjaRequestRouter;

@interface NunjaDelegate : NSObject <NunjaDelegateProtocol>
{
	NunjaRequestHandler *defaultHandler;
	NunjaRequestRouter *router;
}

- (id) initWithSite:(NSString *) site;

- (void) addHandler:(NunjaRequestHandler *) handler;
- (void) addHandlerWithHTTPMethod:(NSString *)httpMethod path:(NSString *)path block:(id)block;
- (void) setDefaultHandlerWithBlock:(id) block;

- (void) dump;

@end


