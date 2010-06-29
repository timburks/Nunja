
#import "Nunja.h"
#import "NunjaRequest.h"

@interface NunjaRequestHandler : NSObject {
   NSString *httpMethod;    
   NSString *path;			
   id block;			  // A Nu or C block to be invoked to handle the request.
   
   NSMutableArray *parts; // internal, used to expand pattern for request routing
}

+ (NunjaRequestHandler *) handlerWithHTTPMethod:(id)httpMethod path:(id)path block:(id)block;

- (NSString *) httpMethod;
- (NSString *) path;
- (NSMutableArray *) parts;

- (BOOL) handleRequest:(NunjaRequest *)request;
@end