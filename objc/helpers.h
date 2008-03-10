/*!
@header helpers.h
@discussion General utilities for the Nunja web server.
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

#import <Foundation/Foundation.h>

@interface NSString (Nunja)
/*! URL-encode a string. */
- (NSString *) urlEncode;
/*! Decode a url-encoded string. */
- (NSString *) urlDecode;
/*! Convert a url query into a dictionary. */
- (NSDictionary *) urlQueryDictionary;
@end

@interface NSDictionary (Nunja)
/*! Convert a dictionary into a url query string. */
- (NSString *) urlQueryString;
@end

@interface NSData (Nunja)
/*! Get a dictionary from an encoded post. */
- (NSDictionary *) urlQueryDictionary;
/*! Get a dictionary corresponding to a multipart-encoded message body. */
- (NSDictionary *) multipartDictionaryWithBoundary:(NSString *) boundary;
@end
