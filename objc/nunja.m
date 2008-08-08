/*!
@file nunja.m
@discussion Objective-C components of the Nunja web server.
@copyright Copyright (c) 2008 Neon Design Technology, Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

#include <sys/types.h>
#include <sys/time.h>
#include <sys/queue.h>
#include <event.h>
#include <evhttp.h>
#define HTTP_SEEOTHER 303
#define HTTP_DENIED 403

#include <netdb.h>
#include <evdns.h>

#import <Foundation/Foundation.h>
#import <Nu/Nu.h>
#import "nunja.h"

void NunjaInit()
{
    static initialized = 0;
    if (!initialized) {
        initialized = 1;
        [Nu loadNuFile:@"nunja" fromBundleWithIdentifier:@"nu.programming.nunja" withContext:nil];
    }
}

@class Nunja;

@implementation SuperNunja
@end

static BOOL verbose_nunja = NO;
static BOOL local_nunja = NO;

@interface NunjaRequest : NSObject
{
    Nunja *nunja;
    struct evhttp_request *req;
}

@end

@implementation NunjaRequest

- (id) initWithNunja:(Nunja *)n request:(struct evhttp_request *)r
{
    [super init];
    nunja = n;
    req = r;
    return self;
}

- (Nunja *) nunja {return nunja;}

- (NSString *) uri
{
    return [NSString stringWithCString:evhttp_request_uri(req) encoding:NSUTF8StringEncoding];
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

- (NSString *) remoteHost
{
    return [NSString stringWithCString:req->remote_host encoding:NSUTF8StringEncoding];
}

- (int) remotePort {
    return req->remote_port;
}

static NSDictionary *nunja_request_headers_helper(struct evhttp_request *req)
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    struct evkeyval *header;
    TAILQ_FOREACH(header, req->input_headers, next) {
        [dict setObject:[NSString stringWithCString:header->value encoding:NSUTF8StringEncoding]
            forKey:[NSString stringWithCString:header->key encoding:NSUTF8StringEncoding]];
    }
    return dict;
}

- (NSDictionary *) requestHeaders
{
    return nunja_request_headers_helper(req);
}

static NSDictionary *nunja_response_headers_helper(struct evhttp_request *req)
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    struct evkeyval *header;
    TAILQ_FOREACH(header, req->output_headers, next) {
        [dict setObject:[NSString stringWithCString:header->value encoding:NSUTF8StringEncoding]
            forKey:[NSString stringWithCString:header->key encoding:NSUTF8StringEncoding]];
    }
    return dict;
}

- (NSDictionary *) responseHeaders
{
    return nunja_response_headers_helper(req);
}

- (int) setValue:(const char *) value forResponseHeader:(const char *) key
{
    return evhttp_add_header(req->output_headers, key, value);
}

- (NSString *) valueForResponseHeader:(const char *) key
{
    const char *value = evhttp_find_header(req->output_headers, key);
    return value ? [NSString stringWithCString:value encoding:NSUTF8StringEncoding] : nil;
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
    if (verbose_nunja) {
        NSLog(@"RESPONSE %d %@ %@", code, message, [nunja_response_headers_helper(req) description]);
    }
    struct evbuffer *buf = evbuffer_new();
    if (buf == NULL) err(1, "failed to create response buffer");
    evbuffer_add(buf, [data bytes], [data length]);
    evhttp_send_reply(req, code, [message cStringUsingEncoding:NSUTF8StringEncoding], buf);
    evbuffer_free(buf);
}

- (void) respondWithString:(NSString *) string
{
    nunja_response_helper(req, HTTP_OK, @"OK", [string dataUsingEncoding:NSUTF8StringEncoding]);
}

- (void) respondWithData:(NSData *) data
{
    nunja_response_helper(req, HTTP_OK, @"OK", data);
}

- (void) respondWithCode:(int) code message:(NSString *) message string:(NSString *) string
{
    nunja_response_helper(req, code, message, [string dataUsingEncoding:NSUTF8StringEncoding]);
}

- (void) respondWithCode:(int) code message:(NSString *) message data:(NSData *) data
{
    nunja_response_helper(req, code, message, data);
}

@end

@protocol NunjaDelegate
- (void) handleRequest:(NunjaRequest *)request;
@end

@interface Nunja : SuperNunja
{
    struct event_base *event_base;
    struct evhttp *httpd;
    id<NSObject,NunjaDelegate> delegate;
}

- (id) delegate;
@end

@implementation Nunja

+ (void) setVerbose:(BOOL) v
{
    verbose_nunja = v;
}

+ (BOOL) verbose {return verbose_nunja;}

+ (void) setLocalOnly:(BOOL) l
{
    local_nunja = l;
}

+ (BOOL) localOnly {return local_nunja;}

+ (void) load
{
    NunjaInit();
}

static void nunja_request_handler(struct evhttp_request *req, void *nunja_pointer)
{
    Nunja *nunja = (Nunja *) nunja_pointer;
    id delegate = [nunja delegate];
    if (delegate) {
        [delegate handleRequest:[[[NunjaRequest alloc] initWithNunja:nunja request:req] autorelease]];
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
    evdns_init();
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

@class NuBlock;
@class NuCell;

static void nunja_dns_gethostbyname_cb(int result, char type, int count, int ttl, void *addresses, void *arg)
{
    id address = nil;
    if (result == DNS_ERR_TIMEOUT) {
        fprintf(stdout, "[Timed out] ");
    }
    else if (result != DNS_ERR_NONE) {
        fprintf(stdout, "[Error code %d] ", result);
    }
    else {
        fprintf(stdout, "type: %d, count: %d, ttl: %d\n", type, count, ttl);
        switch (type) {
            case DNS_IPv4_A:
            {
                struct in_addr *in_addrs = addresses;
                if (ttl < 0) {
                    // invalid resolution
                }
                else if (count == 0) {
                    // no addresses
                }
                else {
                    address = [NSString stringWithFormat:@"%s", inet_ntoa(in_addrs[0])];
                }
                break;
            }
            case DNS_PTR:
                /* may get at most one PTR */
                // this needs review. TB.
                if (count == 1)
                    fprintf(stdout, "addresses: %s ", *(char **)addresses);
                break;
            default:
                break;
        }
    }
    NuBlock *block = (NuBlock *) arg;
    NuCell *args = [[NuCell alloc] init];
    [args setCar:address];
    [block evalWithArguments:args context:nil];
    [block release];
    [args release];
}

- (void) resolveDomainName:(NSString *) name andDo:(NuBlock *) block
{
    [block retain];
    evdns_resolve_ipv4([name cStringUsingEncoding:NSUTF8StringEncoding], 0, nunja_dns_gethostbyname_cb, block);
}

void nunja_http_request_done(struct evhttp_request *req, void *arg)
{
    fprintf(stdout, "received %d bytes\n", (int) arg);
    NSData *data = nil;
    if (req->response_code != HTTP_OK) {
        if (req->response_code == HTTP_SEEOTHER) {
            fprintf(stdout, "REDIRECTING\n");
            NSDictionary *headers = nunja_request_headers_helper(req);
            NSLog(@"%@", [headers description]);
            return;                               // this is not handled yet.
        }
        fprintf(stdout, "FAILED to get OK (response = %d)\n", req->response_code);
    }
    else if (evhttp_find_header(req->input_headers, "Content-Type") == NULL) {
        fprintf(stdout, "FAILED to find Content-Type\n");
    }
    else {
        data = [NSData dataWithBytes:EVBUFFER_DATA(req->input_buffer) length:EVBUFFER_LENGTH(req->input_buffer)];
    }
    NuBlock *block = (NuBlock *) arg;
    NuCell *args = [[NuCell alloc] init];
    [args setCar:data];
    [block evalWithArguments:args context:nil];
    [block release];
    [args release];
    fprintf(stdout, "end of callback\n");
    // leaking...
    //evhttp_connection_free(req->evcon);
}

- (void) getResourceFromHost:(NSString *) host address:(NSString *) address port:(int)port path:(NSString *)path andDo:(NuBlock *) block
{
    [block retain];
    // make the connection
    struct evhttp_connection *evcon = evhttp_connection_new([address cStringUsingEncoding:NSUTF8StringEncoding], port);
    if (evcon == NULL) {
        fprintf(stdout, "FAILED to connect\n");
        NuCell *args = [[NuCell alloc] init];
        [block evalWithArguments:args context:nil];
        [block release];
        [args release];
        return;
    }
    // make the request
    struct evhttp_request *req = evhttp_request_new(nunja_http_request_done, block);
    evhttp_add_header(req->output_headers, "Host", [host cStringUsingEncoding:NSUTF8StringEncoding]);
    // give ownership of the request to the connection
    if (evhttp_make_request(evcon, req, EVHTTP_REQ_GET, [path cStringUsingEncoding:NSUTF8StringEncoding]) == -1) {
        fprintf(stdout, "FAILED to make the request \n");
    }
}

- (void) postDataToHost:(NSString *) host address:(NSString *) address port:(int)port path:(NSString *)path data:(NSData *) data andDo:(NuBlock *) block
{
    [block retain];
    // make the connection
    struct evhttp_connection *evcon = evhttp_connection_new([address cStringUsingEncoding:NSUTF8StringEncoding], port);
    if (evcon == NULL) {
        fprintf(stdout, "FAILED to connect\n");
        NuCell *args = [[NuCell alloc] init];
        [block evalWithArguments:args context:nil];
        [block release];
        [args release];
        return;
    }
    // make the request
    struct evhttp_request *req = evhttp_request_new(nunja_http_request_done, block);
    evhttp_add_header(req->output_headers, "Host", [host cStringUsingEncoding:NSUTF8StringEncoding]);
    evhttp_add_header(req->output_headers, "Content-Length", [[NSString stringWithFormat:@"%d", [data length]] cStringUsingEncoding:NSUTF8StringEncoding]);
    evhttp_add_header(req->output_headers, "Content-Type", "application/x-www-form-urlencoded");
    evbuffer_add(req->output_buffer, [data bytes], [data length]);

    // give ownership of the request to the connection
    if (evhttp_make_request(evcon, req, EVHTTP_REQ_POST, [path cStringUsingEncoding:NSUTF8StringEncoding]) == -1) {
        fprintf(stdout, "FAILED to make the request \n");
    }
}

@end
