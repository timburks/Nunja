/*!
    @file nunja.m
    @copyright Copyright (c) 2008 Tim Burks, Neon Design Technology, Inc.
    @discussion Objective-C components of the Nunja web server.
*/

#include <sys/types.h>
#include <sys/time.h>
#include <sys/queue.h>
#include <event.h>
#include <evhttp.h>

#import <Foundation/Foundation.h>
#ifdef DARWIN
#import <Nu/Nu.h>
#else
#import "Nu.h"
#endif

@interface NunjaRequest : NSObject
{
    struct evhttp_request *req;
}

@end

@implementation NunjaRequest

- (id) initWithRequest:(struct evhttp_request *)r
{
    [super init];
    req = r;
    return self;
}

- (NSString *) uri
{
    return [NSString stringWithCString:evhttp_request_uri(req) encoding:NSUTF8StringEncoding];
}

void NunjaInit()
{
printf ("initializing\n");
    static initialized = 0;
    if (!initialized) {
        initialized = 1;
        [Nu loadNuFile:@"nunja" fromBundleWithIdentifier:@"nu.programming.nunja" withContext:nil];
    }
}

- (NSData *) body
{
    if (!req->input_buffer->buffer)
        return nil;
    else {
        NSData *data = [NSData dataWithBytes:req->input_buffer->buffer length:req->input_buffer->off];
    }
}

- (NSString *) command
{
    switch (req->type) {
        case EVHTTP_REQ_GET:
            return @"GET";
        case EVHTTP_REQ_POST:
            return @"POST";
        case EVHTTP_REQ_HEAD:
            return @"HEAD";
        default:
            return @"UNKNOWN";
    }
}

- (NSDictionary *) requestHeaders
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    struct evkeyval *header;
    TAILQ_FOREACH(header, req->input_headers, next) {
        [dict setObject:[NSString stringWithCString:header->value encoding:NSUTF8StringEncoding]
            forKey:[NSString stringWithCString:header->key encoding:NSUTF8StringEncoding]];
    }
    return dict;
}

- (NSDictionary *) responseHeaders
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    struct evkeyval *header;
    TAILQ_FOREACH(header, req->output_headers, next) {
        [dict setObject:[NSString stringWithCString:header->value encoding:NSUTF8StringEncoding]
            forKey:[NSString stringWithCString:header->key encoding:NSUTF8StringEncoding]];
    }
    return dict;
}

- (int) setValue:(const char *) value forResponseHeader:(const char *) key
{
    return evhttp_add_header(req->output_headers, key, value);
}

- (int) removeResponseHeader:(const char *) key
{
    return evhttp_remove_header(req->output_headers, key);
}

- (void) clearResponseHeaders
{
    evhttp_clear_headers(req->output_headers);
}

static void nunja_response_helper(struct evhttp_request *req, int code, NSString *message, NSData *data)
{
    struct evbuffer *buf = evbuffer_new();
    if (buf == NULL) err(1, "failed to create response buffer");
    evbuffer_add(buf, [data bytes], [data length]);
    evhttp_send_reply(req, code, [message cStringUsingEncoding:NSUTF8StringEncoding], buf);
    evbuffer_free(buf);
}

- (void) respondWithString:(NSString *) string
{
    NSLog(@"RESPONSE -----");
    NSLog([[self responseHeaders] description]);
    nunja_response_helper(req, HTTP_OK, @"OK", [string dataUsingEncoding:NSUTF8StringEncoding]);
}

- (void) respondWithData:(NSData *) data
{
    NSLog(@"RESPONSE -----");
    NSLog([[self responseHeaders] description]);
    nunja_response_helper(req, HTTP_OK, @"OK", data);
}

- (void) respondWithCode:(int) code message:(NSString *) message string:(NSString *) string
{
    NSLog([NSString stringWithFormat:@"RESPONSE (%d) -----", code]);
    NSLog([[self responseHeaders] description]);
    nunja_response_helper(req, code, message, [string dataUsingEncoding:NSUTF8StringEncoding]);
}

- (void) respondWithCode:(int) code message:(NSString *) message data:(NSData *) data
{
    NSLog([NSString stringWithFormat:@"RESPONSE (%d) -----", code]);
    NSLog([[self responseHeaders] description]);
    nunja_response_helper(req, code, message, data);
}

@end

@protocol NunjaDelegate
- (void) handleRequest:(NunjaRequest *)request;
@end

@interface Nunja : NSObject
{
    struct event_base *event_base;
    struct evhttp *httpd;
    id<NSObject,NunjaDelegate> delegate;
}

- (id) delegate;
@end

@implementation Nunja

+ (void) load {
	NunjaInit();
}

static void nunja_request_handler(struct evhttp_request *req, void *nunja_pointer)
{
    Nunja *nunja = (Nunja *) nunja_pointer;

    id delegate = [nunja delegate];
    if (delegate) {
        [delegate handleRequest:[[[NunjaRequest alloc] initWithRequest:req] autorelease]];
    }
    else {
        nunja_response_helper(req, HTTP_OK, @"OK",
            [[NSString stringWithFormat:@"Please set the Nunja server delegate.<br/>If you are running nunjad, use the '-s' option to specify a site.<br/>\nRequest: %s\n",
            evhttp_request_uri(req)]
            dataUsingEncoding:NSUTF8StringEncoding]);
    }
}

- (id) init
{
    [super init];
    event_base = event_init();
    httpd = evhttp_new(event_base);
    evhttp_set_gencb(httpd, nunja_request_handler, self);
    delegate = nil;
    return self;
}

- (int) bindToAddress:(const char *) address port:(int) port
{
    return evhttp_bind_socket(httpd, address, port);
}

- (void) run
{
    event_base_dispatch(event_base);
}

- (void) dealloc
{
    evhttp_free(httpd);
    [super dealloc];
}

- (id) delegate
{
    return delegate;
}

- (void) setDelegate:(id) d
{
    [d retain];
    [delegate release];
    delegate = d;
}

@end
