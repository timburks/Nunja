
#import <Foundation/Foundation.h>

#include <sys/types.h>
#include <sys/time.h>
#include <sys/queue.h>
#include <event.h>
#include <evhttp.h>

void nunja_response_helper(struct evhttp_request *req, int code, NSString *message, NSData *data);
NSDictionary *nunja_request_headers_helper(struct evhttp_request *req);

@class Nunja;

@interface NunjaRequest : NSObject
{
    Nunja *nunja;
    struct evhttp_request *req;
    NSString *_uri;
    NSString *_path;
    NSDictionary *_parameters;
    NSDictionary *_query;
    NSDictionary *_bindings;
    id _cookies;
    int _responded;
    int _responseCode;
    NSString *_responseMessage;
}

- (id) initWithNunja:(Nunja *)n request:(struct evhttp_request *)r;
- (Nunja *) nunja;
- (NSString *) uri;
- (NSString *) path;
- (NSDictionary *) parameters;
- (NSDictionary *) query;
- (id) bindings;
- (void) setBindings:(id) bindings;
- (NSData *) body;
- (NSString *) HTTPMethod;
- (NSString *) remoteHost;
- (int) remotePort;
- (NSDictionary *) requestHeaders;
- (NSDictionary *) responseHeaders;
- (int) setValue:(NSString *) value forResponseHeader:(NSString *) key;
- (NSString *) valueForResponseHeader:(NSString *) key;
- (int) removeResponseHeader:(NSString *) key;
- (void) clearResponseHeaders;
- (int) responseCode;
- (void) setResponseCode:(int) code message:(NSString *) message;
- (int) setValue:(NSString *) value forResponseHeader:(NSString *) key;
- (BOOL) respondWithString:(NSString *) string;
- (BOOL) respondWithData:(NSData *) data;
- (BOOL) respondWithCode:(int) code message:(NSString *) message string:(NSString *) string;
- (BOOL) respondWithCode:(int) code message:(NSString *) message data:(NSData *) data;
- (NSDictionary *) cookies;
- (void) setContentType:(NSString *)content_type;
- (int) redirectResponseToLocation:(NSString *) location;


@end
