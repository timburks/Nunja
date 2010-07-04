
#import <Foundation/Foundation.h>


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
- (NSDictionary *) post;
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
- (NSString *) redirectResponseToLocation:(NSString *) location;


@end
