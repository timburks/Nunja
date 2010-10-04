/*!
 @file Nunja.m
 @discussion Core of the Nunja web server.
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

#include <event2/event.h>
#include <event2/http.h>
#include <event2/event_compat.h>
#include <event2/http_compat.h>
#include <event2/http_struct.h>
#include <event2/buffer.h>
#include <event2/buffer_compat.h>

#include <netdb.h>
#include <arpa/inet.h>                            // inet_ntoa
#include <event2/dns.h>
#include <event2/dns_compat.h>

#include <signal.h>                               // SIGPIPE

#define HTTP_SEEOTHER 303
#define HTTP_DENIED 403

#import <Foundation/Foundation.h>
#import <Nu/Nu.h>

#import "NunjaMain.h"
#import "NunjaRequest.h"
#import "NunjaDelegate.h"

void nunja_response_helper(struct evhttp_request *req, int code, NSString *message, NSData *data);

void NunjaInit()
{
    static int initialized = 0;
    if (!initialized) {
        initialized = 1;
        [Nu loadNuFile:@"nunja" fromBundleWithIdentifier:@"nu.programming.nunja" withContext:nil];
    }
}

BOOL verbose_nunja = NO;

@interface ConcreteNunja : Nunja
{
    struct event_base *event_base;
    struct evhttp *httpd;
    id<NSObject,NunjaDelegate> delegate;
}

- (id) delegate;
@end

@implementation ConcreteNunja

+ (void) load
{
    NunjaInit();
}

static void nunja_request_handler(struct evhttp_request *req, void *nunja_pointer)
{
    Nunja *nunja = (Nunja *) nunja_pointer;
    id delegate = [nunja delegate];
    if (delegate) {
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NunjaRequest *request = [[NunjaRequest alloc] initWithNunja:nunja request:req];
        [delegate handleRequest:request];
        [request release];
        [pool release];
    }
    else {
        nunja_response_helper(req, HTTP_OK, @"OK",
            [[NSString stringWithFormat:@"Please set the Nunja delegate.<br/>If you are running nunjad, use the '-s' option to specify a site.<br/>\nRequest: %s\n",
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

- (int) bindToAddress:(NSString *) address port:(int) port
{
    return evhttp_bind_socket(httpd, [address cStringUsingEncoding:NSUTF8StringEncoding], port);
}

static void sig_pipe(int signo)
{
    NSLog(@"SIGPIPE: lost connection during write. (signal %d)", signo);
}

- (void) run
{
    if (signal(SIGPIPE, sig_pipe) == SIG_ERR) {
        NSLog(@"failed to setup SIGPIPE handler.");
    }
    event_base_dispatch(event_base);
}

- (void) dealloc
{
    evhttp_free(httpd);
    [super dealloc];
}

- (id) delegate
{
    if (!delegate) {
        [self setDelegate:[[[NunjaDefaultDelegate alloc] init] autorelease]];
    }
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
    NSData *data = nil;
    if (req->response_code != HTTP_OK) {
        if (req->response_code == HTTP_SEEOTHER) {
            fprintf(stdout, "REDIRECTING\n");
            //NSDictionary *headers = nunja_request_headers_helper(req);
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

@implementation Nunja

static Nunja *sharedNunja = nil;

+ (Nunja *) nunja
{
    if (!sharedNunja)
        sharedNunja = [[ConcreteNunja alloc] init];
    return sharedNunja;
}

+ (void) setVerbose:(BOOL) v
{
    verbose_nunja = v;
}

+ (BOOL) verbose {return verbose_nunja;}

- (void) run
{
}

- (int) bindToAddress:(NSString *) address port:(int) port
{
    return 0;
}

- (void) setDelegate:(id) d
{
}

- (id) delegate
{
    return nil;
}

static NSMutableDictionary *mimeTypes = nil;

+ (NSMutableDictionary *) mimeTypes
{
    return mimeTypes;
}

+ (void) setMimeTypes:(NSMutableDictionary *) dictionary
{
    [dictionary retain];
    [mimeTypes release];
    mimeTypes = dictionary;
}

+ (NSString *) mimeTypeForFileWithName:(NSString *) pathName
{
    if (mimeTypes) {
        NSString *suffix = [[pathName componentsSeparatedByString:@"."] lastObject];
        NSString *mimeType = [mimeTypes objectForKey:suffix];
        if (mimeType)
            return mimeType;
    }
    // default
    return @"text/html; charset=utf-8";
}

@end

int NunjaMain(int argc, const char *argv[], NSString *NunjaDelegateClassName)
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

    int port = 5000;
    NSString *site = @".";

    BOOL localOnly = NO;
    int i = 0;
    while (i < argc) {
        if (!strcmp(argv[i], "-s") ||
        !strcmp(argv[i], "--site")) {
            if (++i < argc) {
                site = [[[NSString alloc] initWithCString:argv[i]] autorelease];
            }
        }
        else if (!strcmp(argv[i], "-p") ||
        !strcmp(argv[i], "--port")) {
            if (++i < argc) {
                port = atoi(argv[i]);
            }
        }
        else if (!strcmp(argv[i], "-l") ||
        !strcmp(argv[i], "--local")) {
            localOnly = YES;
        }
        else if (!strcmp(argv[i], "-v") ||
        !strcmp(argv[i], "--verbose")) {
            [Nunja setVerbose:YES];
        }
        i++;
    }

    Nunja *nunja = [Nunja nunja];
    int status;
    if (localOnly) {
        status = [nunja bindToAddress:@"127.0.0.1" port:port];
    }
    else {
        status = [nunja bindToAddress:@"0.0.0.0" port:port];
    }
    if (status != 0) {
        NSLog(@"Unable to start service on port %d. Is another server running?", port);
    }
    else {
        Class NunjaDelegateClass = NunjaDelegateClassName ?  NSClassFromString(NunjaDelegateClassName) : [NunjaDefaultDelegate class];
        id delegate = [[[NunjaDelegateClass alloc] init] autorelease];
        [nunja setDelegate:delegate];
        [delegate configureSite:site];
        if ([delegate respondsToSelector:@selector(applicationDidFinishLaunching)]) {
            [delegate applicationDidFinishLaunching];
        }
        if ([Nunja verbose]) {
            [delegate dump];
        }
        NSLog(@"Nunjad is running on port %d", port);
        [nunja run];
    }
    [pool drain];
    return 0;
}
