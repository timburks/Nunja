;; @file       nunja.nu
;; @discussion Nu components of the Nunja web server.
;; @copyright  Copyright (c) 2008-2009 Neon Design Technology, Inc.
;;
;;   Licensed under the Apache License, Version 2.0 (the "License");
;;   you may not use this file except in compliance with the License.
;;   You may obtain a copy of the License at
;;
;;       http://www.apache.org/licenses/LICENSE-2.0
;;
;;   Unless required by applicable law or agreed to in writing, software
;;   distributed under the License is distributed on an "AS IS" BASIS,
;;   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
;;   See the License for the specific language governing permissions and
;;   limitations under the License.

;; import some useful C functions
(global random  (NuBridgedFunction functionWithName:"random" signature:"l"))
(global srandom (NuBridgedFunction functionWithName:"srandom" signature:"vI"))

(case (set SYSTEM ((NSString stringWithShellCommand:"uname") chomp))
      ("Darwin" (import Foundation))
      ("Linux" (global NSLog (NuBridgedFunction functionWithName:"NSLog" signature:"v@"))
               (global NSUTF8StringEncoding 1))
      (else nil))

(load "Nu:template")
(load "Nunja:mime")

;; @class NSDate
;; @discussion Extensions for Nunja.
(class NSDate
     
     ;; Get an RFC822-compliant representation of a date.
     (- (id) rfc822 is
        (set result ((NSMutableString alloc) init))
        (result appendString:
                (self descriptionWithCalendarFormat:"%a, %d %b %Y %H:%M:%S "
                      timeZone:(NSTimeZone localTimeZone) locale:nil))
        (result appendString:((NSTimeZone localTimeZone) abbreviation))
        result)
     
     ;; Get an RFC1123-compliant representation of a date.
     (- (id) rfc1123 is
        (set result ((NSMutableString alloc) init))
        (result appendString:
                (self descriptionWithCalendarFormat:"%a, %d %b %Y %H:%M:%S "
                      timeZone:(NSTimeZone timeZoneWithName:"GMT") locale:nil))
        (result appendString:((NSTimeZone timeZoneWithName:"GMT") abbreviation))
        result))

;; use this pattern to extract a cookie from a header
(set cookie-pattern (regex -"[ ]*([^=]*)=(.*)"))

;; @class NunjaCookie
;; @discussion A class for managing user-identifying cookies.
(class NunjaCookie is NSObject
     (ivars)
     (ivar-accessors)
     
     ;; Generate a random identifier for use in a cookie.
     (+ (id) randomIdentifier is
        "#{((random) stringValue)}#{((random) stringValue)}#{((random) stringValue)}#{((random) stringValue)}")
     
     ;; Construct a cookie for a specified user.
     (+ (id) cookieForUser:(id) user is
        ((self alloc) initWithUser:user
         value:(self randomIdentifier)
         expiration:(NSDate dateWithTimeIntervalSinceNow:3600)))
     
     ;; Initialize a cookie for a specified user.
     (- (id) initWithUser:(id) user value:(id) value expiration:(id) expiration is
        (super init)
        (set @name "session")
        (set @user user)
        (set @value value)
        (set @expiration expiration)
        (set @stringValue nil)
        self)
     
     ;; Get a string description of a cookie.
     (- (id) description is
        "cookie=#{@name} value=#{@value} user=#{@user} expiration=#{(@expiration rfc822)}")
     
     ;; Get a string value for a cookie suitable for inclusion in a response header.
     (- (id) stringValue is "#{@name}=#{@value}; Expires:#{(@expiration rfc1123)}; Path=/"))

;; @class NunjaRequest
;; @discussion A class for managing requests received by the server.
(class NunjaRequest
     (ivar-accessors)
     
     (- (id) cookies is
        (unless @_cookies
                (set @_cookies
                     (if (set cookies ((self requestHeaders) objectForKey:"Cookie"))
                         (then (set cookieDictionary (dict))
                               ((cookies componentsSeparatedByString:";") each:
                                (do (cookieDescription)
                                    (if (set match (cookie-pattern findInString:cookieDescription))
                                        (cookieDictionary setObject:(match groupAtIndex:2)
                                             forKey:(match groupAtIndex:1)))))
                               cookieDictionary)
                         (else (dict)))))
        @_cookies)
     
     (- (id) post is
        (if (Nunja verbose)
            (puts "body is")
            (puts ((NSString alloc) initWithData:(self body) encoding:NSUTF8StringEncoding)))
        (set d (((NSString alloc) initWithData:(self body) encoding:NSUTF8StringEncoding) urlQueryDictionary))
        (if (Nunja verbose)
            (puts (d description)))
        d)
     
     (- (void) setContentType:(id)t is (self setValue:t forResponseHeader:"Content-Type"))
     
     (- (void) redirectToLocation:(id) location is
        (self setValue:location forResponseHeader:"Location")
        (self respondWithCode:303 message:"redirecting" string:"redirecting")))

;; An HTTP request handler. Handlers consist of an action, a pattern, and a block.
;; The action is an HTTP verb such as "get" or "post", the pattern is either an NSString
;; or a NuRegex, and the block is a NuBlock to be evaluated in the request handling.
;; Request handers are typically created using the "get" or "post" macros and are responsible
;; for setting the response headers and returning the appropriate response data, which can be
;; either raw data (in an NSData object) or a string containing HTML text.
(class NunjaRequestHandler is NSObject
     (ivar (id) action (id) pattern (id) block (id) keys)
     (ivars)
     (ivar-accessors)
     
     (- (void) setValue:(id) value forKey:(id) key is
        (puts "this should not get called")
        (puts "#{key}: #{value}"))
     
     ;; Create a handler with a specified action, pattern, and block. Used internally.
     (+ (id) handlerWithAction:(id)action pattern:(id)pattern block:(id)block is
        ;; if the pattern is a string that has dynamic parts, turn it into a regex
        (set keys nil)
        (if (pattern isKindOfClass:NSString)
            (set dynamic-part-regex (regex -"/:([^/]*)"))
            (set tokens (dynamic-part-regex findAllInString:pattern))
            (if (tokens count)
                (set keys (tokens map:(do (token) (token groupAtIndex:1))))
                (set newpattern (+ "^" (dynamic-part-regex replaceWithString:-"/([^/]*)" inString:pattern) "$"))
                (set pattern (regex newpattern))))
        
        (set handler ((self alloc) init))
        (handler setAction:action)
        (handler setPattern:pattern)
        (handler setKeys:keys)
        (handler setBlock:block)
        handler)
     
     ;; Try to match the handler against a specified action and path. Used internally.
     (- (id)matchRequest:(id)request  is
        (if (or (eq (request command) @action)
                (and (eq (request command) "HEAD") (eq @action "GET")))
            (then
                 (set path (request path))
                 (cond ;; match against a string
                       ((@pattern isKindOfClass:NSString)
                        (eq @pattern path))
                       ;; match against a regular expression
                       ((@pattern isKindOfClass:NuRegex)
                        (set match (@pattern findInString:path))
                        (if match
                            (then
                                 (request setMatch:match)
                                 (if (and @keys (eq (+ (@keys count) 1) (match count)))
                                     (set bindings (dict))
                                     ((@keys count) times:
                                      (do (i)
                                          (bindings setValue:(match groupAtIndex:(+ i 1))
                                               forKey:(@keys objectAtIndex:i))))
                                     (request setBindings:bindings))
                                 YES)
                            (else nil)))
                       ;; unsupported pattern type, no match
                       (else nil)))
            ;; unsupported action, no match
            (else nil)))
     
     (set text-html-pattern (regex "^text/html.*$"))
     
     ;; Handle a request. Used internally.
     (- (id)handleRequest:(id)request is
        (if (Nunja verbose)
            (puts "handling request #{(request uri)}")
            (puts "request from host #{(request remoteHost)} port #{(request remotePort)}"))
        (let (body (@block request))
             (cond
                  ;; return without responding, this means the handler has rejected the URL
                  ((not body) nil)
                  ;; return data objects as-is
                  ((body isKindOfClass:NSData) ;; we should set the content type if it isn't set
                   (request respondWithData:body)
                   t)
                  ;; return other non-strings as their stringValues
                  ((not (body isKindOfClass:NSString))
                   (request respondWithString:(body stringValue))
                   t)
                  ;; if a content type is set and it isn't text/html, return string as-is
                  ((and (set content-type (request valueForResponseHeader:"Content-Type"))
                        (not (text-html-pattern findInString:content-type)))
                   (request respondWithString:body)
                   t)
                  ;; return string as html
                  (else (request setContentType:"text/html; charset=UTF-8")
                        (request respondWithString:body)
                        t))))
     
     ;; Return a response redirecting the client to a new location.  This method may be called from action handlers.
     (- (id)redirectResponse:(id)request toLocation:(id)location is
        (request setValue:location forResponseHeader:"Location")
        (request respondWithCode:303 message:"redirecting" string:"redirecting")))

(class Nunja
     ;; Return a response redirecting the client to a new location.  This method may be called from action handlers.
     (+ (id)redirectResponse:(id)request toLocation:(id)location is
        (request setValue:location forResponseHeader:"Location")
        (request respondWithCode:303 message:"redirecting" string:"redirecting")))

;; @class NunjaController
;; @discussion The Nunja Controller. Responsible for handling requests.
(class NunjaController is NSObject
     (ivar (id) handlers (id) root)
     (ivar-accessors)
     
     (set privateSharedController nil) ;; private shared variable
     
     (+ (id) sharedController is
        privateSharedController)
     
     (- (id) initWithSite:(id) site is
        (self init)
        (set @handlers (array))
        (set privateSharedController self)
        (set @root site)
        (load (+ site "/site.nu"))
        self)
     
     (- (void) handleRequest:(id) request is
        (set path (request path))
        (if (Nunja verbose)
            (puts (+ "REQUEST " (request command) " " path "-----"))
            (puts ((request requestHeaders) description)))
        (request setValue:"Nunja" forResponseHeader:"Server")
        
        (set handled nil)
        (@handlers each:
             (do (handler)
                 (if (and (not handled) (handler matchRequest:request))
                     (set handled (handler handleRequest:request)))))
        
        (unless handled ;; look for a file that matches the path
                (set filename (+ @root "/public" path))
                (if ((NSFileManager defaultManager) fileExistsAtPath:filename)
                    (then
                         (set data (NSData dataWithContentsOfFile:filename))
                         (request setValue:(mime-type filename) forResponseHeader:"Content-Type")
                         (request setValue:"max-age=3600" forResponseHeader:"Cache-Control")
                         (request respondWithData:data))
                    (else
                         (puts ((NSString alloc) initWithData:(request body) encoding:NSUTF8StringEncoding))
                         (request respondWithCode:404 message:"Not Found" string:"Not Found. You said: #{(request command)} #{(request path)}"))))))

;; Declare a get action.
(macro-1 get (pattern *body)
     `(((NunjaController sharedController) handlers)
       << (NunjaRequestHandler handlerWithAction:"GET"
               pattern:,pattern
               block:(do (REQUEST) ,@*body))))

;; Declare a post action.
(macro-1 post (pattern *body)
     `(((NunjaController sharedController) handlers)
       << (NunjaRequestHandler handlerWithAction:"POST"
               pattern:,pattern
               block:(do (REQUEST) ,@*body))))

;; Set the top-level directory for a site
(macro-1 root (top-level-directory)
     `((NunjaController sharedController) setRoot:,top-level-directory))


