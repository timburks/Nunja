/*!
    @header NuHTTP.h
    @copyright Copyright (c) 2007 Tim Burks, Neon Design Technology, Inc.
    @discussion General utilities for the NuHTTP web server.
*/

#import <Cocoa/Cocoa.h>

@interface NSString (NuHTTP)
/*! URL-encode a string. */
- (NSString *) urlEncode;
/*! Decode a url-encoded string. */
- (NSString *) urlDecode;
/*! Convert a url query into a dictionary. */
- (NSDictionary *) urlQueryDictionary;
@end

@interface NSDictionary (NuHTTP)
/*! Convert a dictionary into a url query string. */
- (NSString *) urlQueryString;
@end

@interface NSData (NuHTTP)
/*! Get a dictionary from an encoded post. */
- (NSDictionary *) urlQueryDictionary;
/*! Get a dictionary corresponding to a multipart-encoded message body. */
- (NSDictionary *) multipartDictionaryWithBoundary:(NSString *) boundary;
@end


