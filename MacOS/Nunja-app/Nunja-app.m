#import <Nunja/Nunja.h>

@interface ServerDelegate : NunjaDelegate 
{
}
@end

@implementation ServerDelegate

- (void) nunjaDidFinishLaunching {
	[self addHandlerWithHTTPMethod:@"GET"
							  path:@"/hello"
							 block:^(NunjaRequest *REQUEST) {
								 NSMutableString *result = [NSMutableString string];
								 [result appendString:@"Hello.\n"];
								 [REQUEST setContentType:@"text/plain"];
								 return result;
							 }];
	
	[self addHandlerWithHTTPMethod:@"GET"
							  path:@"/block/me:"
							 block:^(NunjaRequest *REQUEST) {
								 NSMutableString *result = [NSMutableString string];
								 [result appendString:@"Handling 'block'\n"];
								 [result appendString:@"Bindings\n"];
								 [result appendString:[[REQUEST bindings] description]];
								 [result appendString:@"\n"];
								 [result appendString:@"Query\n"];
								 [result appendString:[[REQUEST query] description]];
								 [REQUEST setContentType:@"text/plain"];
								 return result;
							 }];
	
	[self addHandlerWithHTTPMethod:@"GET"
							  path:@"/pwd"
							 block:^(NunjaRequest *REQUEST) {
								 NSMutableString *result = [NSMutableString string];
								 [result appendString:[[NSFileManager defaultManager] currentDirectoryPath]];
								 [REQUEST setContentType:@"text/plain"];
								 return result;
							 }];
	
}
@end

int main (int argc, const char * argv[])
{
	return NunjaMain(argc, argv, @"ServerDelegate");
}
