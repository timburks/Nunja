/*!
 @file Nunja.h
 @discussion Core of the Nunja web server.
 @copyright Copyright (c) 2010 Neon Design Technology, Inc.
 
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

#import <Foundation/Foundation.h>
#import <Nu/Nu.h>

@class NunjaRequest;

@protocol NunjaDelegateProtocol
// Override this to perform Objective-C setup of your Nunja.
- (void) nunjaDidFinishLaunching;

// Call this within nunjaDidFinishLaunching to add a handler.
- (void) addHandlerWithHTTPMethod:(NSString *)httpMethod path:(NSString *)path block:(id)block;

// Call this within nunjaDidFinishLaunching to set the 404 handler.
- (void) setDefaultHandlerWithBlock:(id) block;

// Override this to add your own custom request processing. You probably won't need this.
- (void) handleRequest:(NunjaRequest *)request;
@end


@interface Nunja : NSObject {}
// Get a Nunja instance. We only support one per process.
+ (Nunja *) nunja;

// Control logging
+ (void) setVerbose:(BOOL) v;
+ (BOOL) verbose;

// Known MIME types
+ (NSMutableDictionary *) mimeTypes;
+ (void) setMimeTypes:(NSMutableDictionary *) dictionary;
+ (NSString *) mimeTypeForFileWithName:(NSString *) filename;

// The delegate performs all request handling.
- (void) setDelegate:(id<NunjaDelegateProtocol>) d;
- (id<NunjaDelegateProtocol>) delegate;

// Bind the server to a specified address and port.
- (int) bindToAddress:(NSString *) address port:(int) port;

// Run the server.
- (void) run;

@end


// Run Nunja. Pass nil for NunjaDelegateClassName to set up your site with Nu (site.nu).
int NunjaMain(int argc, const char *argv[], NSString *NunjaDelegateClassName);