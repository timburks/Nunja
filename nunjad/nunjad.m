#import <Foundation/Foundation.h>

@protocol NunjaProtocol 
- (int) bindToAddress:(const char *) address port:(int) port;
- (BOOL) localOnly;
- (void) setLocalOnly:(BOOL) l;
- (void) setVerbose:(BOOL) v;
- (void) setController:(id) controller;
- (void) run;
@end

int main (int argc, const char * argv[]) {
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	Class Nunja = NSClassFromString(@"Nunja");
	Class NunjaController = NSClassFromString(@"NunjaController");
	
	int port = 5000;
	NSString *site = nil;
	
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
			[Nunja setLocalOnly:YES];
		}
		else if (!strcmp(argv[i], "-v") ||
				 !strcmp(argv[i], "--verbose")) {
			[Nunja setVerbose:YES];
		}	
		i++;
	}
	
	if (!site) {
		NSLog(@"Please specify a site description with the -s or --site option");
	} else {
		id<NunjaProtocol> nunja = [[Nunja alloc] init];
		if ([Nunja localOnly]) {
			[nunja bindToAddress:"127.0.0.1" port:port];
		} else {
			[nunja bindToAddress:"0.0.0.0" port:port];
		}
		[nunja setController:[[NunjaController alloc] initWithSite:site]];
		[nunja run];
	}
	
    [pool drain];
    return 0;
}
