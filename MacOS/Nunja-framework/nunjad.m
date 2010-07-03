#import <Foundation/Foundation.h>
#import "Nunja/Nunja.h"


@interface MyNunjaDelegate : NunjaDelegate 
{
}
@end

@implementation MyNunjaDelegate

- (void) nunjaDidFinishLaunching {	
#ifdef DARWIN
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
#endif
}
@end

int main (int argc, const char * argv[])
{
	return NunjaMain(argc, argv, @"MyNunjaDelegate");
}
