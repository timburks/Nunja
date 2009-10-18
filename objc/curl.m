/*!
@header curl.m
@discussion Simple wrappers for libcurl.
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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <curl/curl.h>
#include <curl/types.h>
#include <curl/easy.h>

#import <Foundation/Foundation.h>

#import "helpers.h"

// this class is a drop-in replacement for NSMutableData
// it calls a handler for each line of data that it receives
// use it to receive data from http connections that are held open by the server
@interface LineCollector : NSObject 
{
   NSMutableString *partial;
   id handler;
}
@end

@implementation LineCollector

- (id) initWithHandler:(id) h {
   [super init];
   handler = h;
   partial = [[NSMutableString alloc] init];
   return self;
}

- (void) appendBytes:(void *) ptr length:(int) length {
   char *buffer = (char *) malloc((length + 1) * sizeof(char));
   memcpy(buffer,ptr,length);
   buffer[length] = 0;
   
   int start = 0;
   int i;
   for (i = 0; i < length; i++) {
      if (buffer[i] == '\r') {
         buffer[i] = 0;
         [partial appendFormat:@"%s", &buffer[start]];
         [handler handleString:partial];
         [partial release];
         partial = [[NSMutableString alloc] init];
         start = i+2;
      }
   }
   if (start < length) {
      [partial appendFormat:@"%s", &buffer[start]];
   }
}

- (void) dealloc {
   [partial release];
}

@end

#define USERAGENT "Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_5_5; en-us) AppleWebKit/525.27.1 (KHTML, like Gecko) Version/3.2.1 Safari/525.27.1"

static size_t WriteMemoryCallback(void *ptr, size_t size, size_t nmemb, void *data)
{
    [((NSMutableData *) data) appendBytes:ptr length:size*nmemb];
    return size*nmemb;
}

static size_t HeaderFunctionCallback(void *ptr, size_t size, size_t nmemb, void *data)
{
    NSString *line = [[NSString alloc] initWithData:[NSData dataWithBytes:ptr length:nmemb] encoding:NSUTF8StringEncoding];
    //NSLog(@"line(%d,%d) - %@", size, nmemb, line);

    size_t keyLength =strcspn(ptr, " ");
    if (nmemb == 2) {
        //NSLog(@"blank line");
    }
    else if (((char *) ptr)[keyLength-1] == ':') {
        if (keyLength < nmemb) {
            //NSLog(@"%d %d", keyLength, nmemb);
            NSString *value = [[NSString alloc] initWithData:[NSData dataWithBytes:ptr+keyLength+1 length:(nmemb - keyLength -3)] encoding:NSUTF8StringEncoding];
            NSString *key = [[NSString alloc] initWithData:[NSData dataWithBytes:ptr length:keyLength-1] encoding:NSUTF8StringEncoding];
            //NSLog(@"key is %@", key);
            //NSLog(@"value is %@", value);
            [[((NSMutableDictionary *) data) objectForKey:@"header"] setObject:value forKey:key];
        }
    }
    else {
        size_t codeLength = strcspn(ptr+keyLength+1, " ");
        NSString *code = [[NSString alloc] initWithData:[NSData dataWithBytes:ptr+keyLength+1 length:codeLength] encoding:NSUTF8StringEncoding];
        [((NSMutableDictionary *) data) setObject:code forKey:@"code"];
        //NSLog(@"code is %@", code);
    }
    return size*nmemb;
}

@interface NuCURL : NSObject
{
    NSString *userAgent;
}

@end

@implementation NuCURL

- (NuCURL *) init
{
    curl_global_init(CURL_GLOBAL_ALL);
    userAgent = [[NSString alloc] initWithCString:USERAGENT encoding:NSUTF8StringEncoding];
    return [super init];
}

- (NuCURL *) initWithUserAgent:(NSString *) _userAgent {
    [super init];
    curl_global_init(CURL_GLOBAL_ALL);
    userAgent = [_userAgent retain];
    return self;
}

- (void) dealloc
{
    curl_global_cleanup();
    [super dealloc];
}




- (NSDictionary *) get:(NSString *) path 
           httpHeaders:(NSDictionary *) httpHeaders
                  form:(NSDictionary *) formData 
               userpwd:(NSString *) userpwd
{
    struct curl_slist *hdr_slist = NULL;

    NSMutableData *body = [NSMutableData data];
    NSMutableDictionary *header = [NSMutableDictionary dictionary];
    NSMutableDictionary *result = [NSMutableDictionary dictionaryWithObjectsAndKeys:header, @"header", body, @"body", nil];
    CURL *curl_handle = curl_easy_init();
    curl_easy_setopt(curl_handle, CURLOPT_URL, [path cStringUsingEncoding:NSUTF8StringEncoding]);
    curl_easy_setopt(curl_handle, CURLOPT_WRITEFUNCTION, WriteMemoryCallback);
    curl_easy_setopt(curl_handle, CURLOPT_WRITEDATA, (void *) body);
    curl_easy_setopt(curl_handle, CURLOPT_HEADERFUNCTION, HeaderFunctionCallback);
    curl_easy_setopt(curl_handle, CURLOPT_HEADERDATA, (void *) result);
    curl_easy_setopt(curl_handle, CURLOPT_USERAGENT, [userAgent cStringUsingEncoding:NSUTF8StringEncoding]);
    
    if (httpHeaders)
    {
        NSEnumerator* e;
        id key;
        
        e = [httpHeaders keyEnumerator];
        
        while ((key = [e nextObject]))
        {
            NSString* h = [NSString stringWithFormat:@"%@: %@", key, [httpHeaders objectForKey: key]];
            hdr_slist = curl_slist_append(hdr_slist, [h cStringUsingEncoding:NSUTF8StringEncoding]);
        }
        curl_easy_setopt(curl_handle, CURLOPT_HTTPHEADER, hdr_slist);
    }

    if (userpwd)
    {
        curl_easy_setopt(curl_handle, CURLOPT_USERPWD, [userpwd cStringUsingEncoding:NSUTF8StringEncoding]);
    }

    curl_easy_perform(curl_handle);
    curl_easy_cleanup(curl_handle);

    if (hdr_slist)
    {
        curl_slist_free_all(hdr_slist);
    }
   
    return result;
}


// Convenience functions for backward compatibility...
- (NSDictionary *) get:(NSString *) path
{
    return [self get:path httpHeaders:nil form:nil userpwd:nil];
}

- (NSDictionary *) get:(NSString *) path userpwd:(NSString *) userpwd
{
    return [self get:path httpHeaders:nil form:nil userpwd:userpwd];
}



- (NSDictionary *) post:(NSString *) path
            httpHeaders:(NSDictionary *) httpHeaders
                   form:(NSDictionary *) formData
               postBody:(NSString* ) postBody
                userpwd:(NSString *) userpwd
                 command:(NSString *) command   // can pass in "PUT", "DELETE", nil
               collector:(id) collector
{
    struct curl_slist *hdr_slist = NULL;

    id body = collector ? collector : [NSMutableData data];
    NSMutableDictionary *header = [NSMutableDictionary dictionary];
    NSMutableDictionary *result = [NSMutableDictionary dictionaryWithObjectsAndKeys:header, @"header", body, @"body", nil];
    CURL *curl_handle = curl_easy_init();

    curl_easy_setopt(curl_handle, CURLOPT_URL, [path cStringUsingEncoding:NSUTF8StringEncoding]);
    
    if (formData)
    {
        curl_easy_setopt(curl_handle, CURLOPT_POSTFIELDS, [[formData urlQueryString] cStringUsingEncoding:NSUTF8StringEncoding]);
    }

    if (postBody)
    {
        curl_easy_setopt(curl_handle, CURLOPT_POSTFIELDS, [postBody cStringUsingEncoding:NSUTF8StringEncoding]);
    }

    if (command)
    {
        curl_easy_setopt(curl_handle, CURLOPT_CUSTOMREQUEST, [command cStringUsingEncoding:NSUTF8StringEncoding]);
    }

    curl_easy_setopt(curl_handle, CURLOPT_WRITEFUNCTION, WriteMemoryCallback);
    curl_easy_setopt(curl_handle, CURLOPT_WRITEDATA, (void *) body);
    curl_easy_setopt(curl_handle, CURLOPT_HEADERFUNCTION, HeaderFunctionCallback);
    curl_easy_setopt(curl_handle, CURLOPT_HEADERDATA, (void *) result);
    curl_easy_setopt(curl_handle, CURLOPT_USERAGENT, [userAgent cStringUsingEncoding:NSUTF8StringEncoding]);

    if (httpHeaders)
    {
        NSEnumerator* e;
        id key;
        
        e = [httpHeaders keyEnumerator];
        
        while ((key = [e nextObject]))
        {
            NSString* h = [NSString stringWithFormat:@"%@: %@", key, [httpHeaders objectForKey: key]];
            hdr_slist = curl_slist_append(hdr_slist, [h cStringUsingEncoding:NSUTF8StringEncoding]);
        }
        curl_easy_setopt(curl_handle, CURLOPT_HTTPHEADER, hdr_slist);
    }

    if (userpwd)
    {
        curl_easy_setopt(curl_handle, CURLOPT_USERPWD, [userpwd cStringUsingEncoding:NSUTF8StringEncoding]);
    }

    curl_easy_perform(curl_handle);
    curl_easy_cleanup(curl_handle);

    if (hdr_slist)
    {
        curl_slist_free_all(hdr_slist);
    }
   
    return result;
}

- (NSDictionary *) post:(NSString *) path
            httpHeaders:(NSDictionary *) httpHeaders
                   form:(NSDictionary *) formData
               postBody:(NSString* ) postBody
                userpwd:(NSString *) userpwd
                 command:(NSString *) command 
{
   return [self post:path httpHeaders:httpHeaders form:formData postBody:postBody userpwd:userpwd command:command collector:nil];
}

- (NSDictionary *) post:(NSString *) path withForm:(NSDictionary *) formData
{
    return [self post:path httpHeaders:nil form:formData postBody:nil userpwd:nil command:nil];
}

- (NSDictionary *) post:(NSString *) path withForm:(NSDictionary *) formData userpwd:(NSString *) userpwd 
{
    return [self post:path httpHeaders:nil form:formData postBody:nil userpwd:userpwd command:nil];
}



// nonworking
+ (NSData *) post:(NSString *) path withMultipartForm:(NSDictionary *) formData
{
    curl_global_init(CURL_GLOBAL_ALL);
    CURL *curl = curl_easy_init();

    struct curl_httppost *formpost=NULL;
    struct curl_httppost *lastptr=NULL;
    struct curl_slist *headerlist=NULL;
    static const char buf[] = "Expect:";

    /* Fill in the file upload field */
    curl_formadd(&formpost,
        &lastptr,
        CURLFORM_COPYNAME, "sendfile",
        CURLFORM_FILE, "postit2.c",
        CURLFORM_END);

    /* Fill in the filename field */
    curl_formadd(&formpost,
        &lastptr,
        CURLFORM_COPYNAME, "filename",
        CURLFORM_COPYCONTENTS, "postit2.c",
        CURLFORM_END);

    /* Fill in the submit field too, even if this is rarely needed */
    curl_formadd(&formpost,
        &lastptr,
        CURLFORM_COPYNAME, "submit",
        CURLFORM_COPYCONTENTS, "send",
        CURLFORM_END);

    /* initalize custom header list (stating that Expect: 100-continue is not
       wanted */
    headerlist = curl_slist_append(headerlist, buf);
    if(curl) {
        NSLog(@"posting");
        /* what URL that receives this POST */
        curl_easy_setopt(curl, CURLOPT_URL, [path cStringUsingEncoding:NSUTF8StringEncoding]);

        curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headerlist);
        curl_easy_setopt(curl, CURLOPT_HTTPPOST, formpost);
        CURLcode res = curl_easy_perform(curl);
        NSLog(@"result %d", res);
        /* always cleanup */
        curl_easy_cleanup(curl);

        /* then cleanup the formpost chain */
        curl_formfree(formpost);
        /* free slist */
        curl_slist_free_all (headerlist);
    }
    return 0;
}

@end
