
#import "NunjaDelegate.h"
#import "NunjaRequestRouter.h"
#import "NunjaRequestHandler.h"
#import "Nunja.h"

@implementation NunjaDelegate

static NunjaDelegate *_sharedDelegate;

+ (NunjaDelegate *) sharedDelegate {
	return _sharedDelegate;
}

- (id) init
{
    if (self = [super init]) {
        self->router = [[NunjaRequestRouter routerWithToken:@""] retain];
    }
    _sharedDelegate = self;
    return self;
}

- (id) initWithSite:(id) site 
{
	self = [self init];
	
	id parser = [NSClassFromString(@"Nu") parser];
		
	// set working directory to site path
	chdir([site cStringUsingEncoding:NSUTF8StringEncoding]);
	
	// load site description
	NSString *filename = [NSString stringWithFormat:@"site.nu", site];
	NSString *sourcecode = [NSString stringWithContentsOfFile:filename];
	if (sourcecode) {
		[parser parseEval:sourcecode];	
	}
	return self;
}

- (void) setDefaultHandlerWithBlock:(id) block {
	id handler = [NunjaRequestHandler handlerWithHTTPMethod:@"GET" path:@"" block:block];
	[handler retain];
	[self->defaultHandler release];
	self->defaultHandler = handler;
}

- (void) addHandler:(id) handler
{
    [self->router insertHandler:handler level:0];
}

- (void) addHandlerWithHTTPMethod:(NSString *)httpMethod path:(NSString *)path block:(id)block 
{
	[self addHandler:[NunjaRequestHandler handlerWithHTTPMethod:httpMethod path:path block:block]];
}

- (void) dump
{
    [self->router dump:0];
}

- (void) handleRequest:(NunjaRequest *) request
{
    id path = [request path];
    if ([Nunja verbose]) {
        NSLog(@"REQUEST %@ %@ ----", [request HTTPMethod], path);
        NSLog(@"%@", [request requestHeaders]);
    }
    [request setValue:@"Nunja" forResponseHeader:@"Server"];
    [request setBindings:[NSMutableDictionary dictionary]];
	
    id httpMethod = [request HTTPMethod];
    if ([httpMethod isEqualToString:@"HEAD"])
        httpMethod = @"GET";
	
    id parts = [[NSString stringWithFormat:@"%@%@", httpMethod, [request path]] componentsSeparatedByString:@"/"];
    if (([parts count] > 2) && [[parts lastObject] isEqualToString:@""]) {
        parts = [parts subarrayWithRange:NSMakeRange(0, [parts count]-1)];
    }
	
    BOOL handled = NO;                            // [[NunjaCache sharedCache] handleRequest:request];
	
    if (!handled) {
        NunjaRequestHandler *handler = [router routeRequest:request parts:parts level:0];
        if (handler) {
            handled = [handler handleRequest:request];
        }
    }
	
    if (!handled) {                               // does the path end in a '/'? If so, append index.html
		unichar lastCharacter = [path characterAtIndex:[path length] - 1];
		if (lastCharacter == '/') {
			if (!handled) {
				NSString *filename = [NSString stringWithFormat:@"public%@index.html", path];
				if ([[NSFileManager defaultManager] fileExistsAtPath:filename]) {
					NSData *data = [NSData dataWithContentsOfFile:filename];
					[request setValue:[Nunja mimeTypeForFileWithName:filename] forResponseHeader:@"Content-Type"];
					[request setValue:@"max-age=3600" forResponseHeader:@"Cache-Control"];
					[request respondWithData:data];
					handled = YES;
				}
			}
			if (!handled) {
				NSString *filename = [NSString stringWithFormat:@"public%@prog_index.m3u8", path];
				if ([[NSFileManager defaultManager] fileExistsAtPath:filename]) {
					NSData *data = [NSData dataWithContentsOfFile:filename];
					[request setValue:[Nunja mimeTypeForFileWithName:filename] forResponseHeader:@"Content-Type"];
					[request setValue:@"max-age=3600" forResponseHeader:@"Cache-Control"];
					[request respondWithData:data];
					handled = YES;
				}
			}
		}
	}
	
	if (!handled) {                               
		// look for a file or directory that matches the path
		NSString *filename = [NSString stringWithFormat:@"public%@", path];
		BOOL isDirectory = NO;
		BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:filename isDirectory:&isDirectory];
		if (fileExists) {
			if (isDirectory) {
				unichar lastCharacter = [path characterAtIndex:[path length] - 1];
				if (lastCharacter != '/') {
					// for a directory, redirect to the same path with '/' appended
					[request setValue:[path stringByAppendingString:@"/"] forResponseHeader:@"Location"];
					[request respondWithCode:301 message:@"moved permanently" string:@"Moved Permanently"];
					handled = YES;
				}
			} else {
				// for a file, send its contents
				NSData *data = [NSData dataWithContentsOfFile:filename];
				[request setValue:[Nunja mimeTypeForFileWithName:filename] forResponseHeader:@"Content-Type"];
				[request setValue:@"max-age=3600" forResponseHeader:@"Cache-Control"];
				[request respondWithData:data];
				handled = YES;
			}
		}
	}
	
	if (!handled) {                               // try appending .html to the path
		NSString *filename = [NSString stringWithFormat:@"public%@.html", path];
		if ([[NSFileManager defaultManager] fileExistsAtPath:filename]) {
			NSData *data = [NSData dataWithContentsOfFile:filename];
			[request setValue:@"text/html" forResponseHeader:@"Content-Type"];
			[request setValue:@"max-age=3600" forResponseHeader:@"Cache-Control"];
			[request respondWithData:data];
			handled = YES;
		}
	}
	
	if (!handled) {
		if (defaultHandler) {
			[defaultHandler handleRequest:request];
		}
		else {
			[request respondWithCode:404
							 message:@"Not Found"
							  string:[NSString stringWithFormat:@"Not Found. You said: %@ %@", [request HTTPMethod], [request path]]];
		}
	}
}

- (void) nunjaDidFinishLaunching {
	
}

@end
