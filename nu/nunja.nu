;; @file       nunja.nu
;; @discussion Nu components of the Nunja web server.
;; @copyright  Copyright (c) 2008 Neon Design Technology, Inc.
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
     (ivar (id) cookies)
     
     (- (id) cookies is
        (unless @cookies
                (set @cookies
                     (if (set cookies ((self requestHeaders) objectForKey:"Cookie"))
                         (then (set cookieDictionary (dict))
                               ((cookies componentsSeparatedByString:";") each:
                                (do (cookieDescription)
                                    (if (set match (cookie-pattern findInString:cookieDescription))
                                        (cookieDictionary setObject:(match groupAtIndex:2)
                                             forKey:(match groupAtIndex:1)))))
                               cookieDictionary)
                         (else (dict)))))
        @cookies)
     
     (- (id) post is
        (if (Nunja verbose)
            (NSLog "body is")
            (NSLog ((NSString alloc) initWithData:(self body) encoding:NSUTF8StringEncoding)))
        (set d (((NSString alloc) initWithData:(self body) encoding:NSUTF8StringEncoding) urlQueryDictionary))
        (if (Nunja verbose)
            (NSLog (d description)))
        d))

;; An HTTP request handler. Handlers consist of an action, a pattern, and a set of statements.
;; The action is an HTTP verb such as "get" or "post", the pattern is either an NSString
;; or a NuRegex, and the statements are Nu expressions to be evaluated in the request handling.
;; Request handers are typically created using the "get" or "post" macros and are responsible
;; for setting the response headers and returning the appropriate response data, which can be
;; either raw data (in an NSData object) or a string containing HTML text.
(class NunjaRequestHandler is NSObject
     (ivar (id) action (id) pattern (id) statements)
     (ivars)
     (ivar-accessors)
     
     (- (void) setValue:(id) value forKey:(id) key is
        (NSLog "this should not get called")
        (NSLog "#{key}: #{value}"))
     
     ;; Create a handler with a specified action, pattern, and statements. Used internally.
     (+ (id) handlerWithAction:(id)action pattern:(id)pattern statements:(id)statements is
        (set handler ((self alloc) init))
        (handler setAction:action)
        (handler setPattern:pattern)
        (if (send statements isKindOfClass:NuBlock)
            (then (handler setStatements:statements))
            (else (handler setStatements:(cons 'progn statements))))
        handler)
     
     ;; Try to match the handler against a specified action and path. Used internally.
     (- (id)matchAction:(id)action path:(id)path is
        (if (eq @action action)
            (then (cond ((@pattern isKindOfClass:NSString)
                         (set @match (eq @pattern path)))
                        ((@pattern isKindOfClass:NuRegex)
                         (set @match (@pattern findInString:path))
                         (eq path (@match group)))
                        (else nil)))
            (else nil)))
     
     (set text-html-pattern (regex "^text/html.*$"))
     
     ;; Handle a request. Used internally.
     (- (id)handleRequest:(id)request is
        (if (Nunja verbose)
            (NSLog "handling request #{(request uri)}")
            (NSLog "request from host #{(request remoteHost)} port #{(request remotePort)}"))
        (set response (dict))
        (set HEAD nil)
        (set TITLE nil)
        
        (if (send @statements isKindOfClass:NuCell)
            (then (set BODY (eval @statements)))          ;; deprecated, evaluates statements in the instance method context
            (else (set BODY (@statements @match request response)))) ;; new style, evaluates a function with a lexical closure
        
        (unless BODY (return)) ;; return early and leave connection open, this expects the handler to have created a closure
        
        (cond ;; return data objects as-is
              ((BODY isKindOfClass:NSData)
               (request respondWithData:BODY))
              ;; return non-strings as their stringValues
              ((not (BODY isKindOfClass:NSString))
               (request respondWithString:(BODY stringValue)))
              ;; if a content type is set and it isn't text/html, return string as-is
              ((and (set content-type (request valueForResponseHeader:"Content-Type"))
                    (not (text-html-pattern findInString:content-type)))
               (request respondWithString:BODY))
              ;; otherwise, return the string wrapped in html tags
              (else
                   (set html "<html>\n<head>\n")
                   (if (response "HEAD")
                       (then (html appendString:(response "HEAD")))
                       (else (if HEAD (html appendString:HEAD))))
                   (if (response "TITLE")
                       (then (html appendString:(+ "\n<title>" (response "TITLE") "</title>")))
                       (else (if TITLE (html appendString:(+ "\n<title>" TITLE "</title>")))))
                   (set bodyAttributes (response "BODY_ATTRIBUTES"))
                   (html appendString:"</head>\n")
                   (if bodyAttributes
                       (then (html appendString:"<body #{bodyAttributes}>\n"))
                       (else (html appendString:"<body>\n")))
                   (html appendString:BODY)
                   (html appendString:"\n</body>\n</html>\n")
                   (request respondWithString:html))))
     
     ;; Return a response redirecting the client to a new location.  This method may be called from action handlers.
     (- (id)redirectResponse:(id)request toLocation:(id)location is
        (request setValue:location forResponseHeader:"Location")
        (request respondWithCode:303 message:"redirecting" string:"redirecting")))

(class Nunja
     ;; Return a response redirecting the client to a new location.  This method may be called from action handlers.
     (+ (id)redirectResponse:(id)request toLocation:(id)location is
        (request setValue:location forResponseHeader:"Location")
        (request respondWithCode:303 message:"redirecting" string:"redirecting")))

;; @class NunjaDelegate
;; @discussion The Nunja's delegate. Responsible for handling requests.
(class NunjaDelegate is NSObject
     (ivar (id) handlers (id) root)
     (ivar-accessors)
     
     (- (id) initWithSite:(id) site is
        (self init)
        (set @handlers (array))
        (set $nunjaDelegate self)
        (set @root site)
        (load (+ site "/site.nu"))
        self)
     
     (- (void) handleRequest:(id) request is
        (set path (request uri))
        (set command (request command))
        (if (Nunja verbose)
            (NSLog (+ "REQUEST " command " " path "-----"))
            (NSLog ((request requestHeaders) description)))
        (request setValue:"Nunja" forResponseHeader:"Server")
        
        (set matches (@handlers select:(do (handler) (handler matchAction:command path:path))))
        (if (matches count)
            (then ((matches 0) handleRequest:request))
            (else ;; look for a file that matches the path
                  (set filename (+ @root "/public" path))
                  (if ((NSFileManager defaultManager) fileExistsAtPath:filename)
                      (then
                           (set data (NSData dataWithContentsOfFile:filename))
                           (request setValue:(mime-type filename) forResponseHeader:"Content-Type")
                           (request setValue:"max-age=3600, must-revalidate" forResponseHeader:"Cache-Control")
                           (request respondWithData:data))
                      (else
                           (puts ((NSString alloc) initWithData:(request body) encoding:NSUTF8StringEncoding))
                           (request respondWithCode:404 message:"Not Found" string:"Not Found. You said: #{command} #{path}")))))))

(global nunja-site-prefix nil) ;; default

;; Declare a get action.
(global get
        (macro-0 _
             (if $do-it-the-old-way
                 (then
                      (set __pattern    (eval (car margs)))
                      (set __statements (cdr margs))
                      (($nunjaDelegate handlers) << (NunjaRequestHandler handlerWithAction:"GET" pattern:__pattern statements:__statements)))
                 (else
                      (set __pattern    (eval (car margs)))
                      (set __function (eval (append '(do (MATCH REQUEST RESPONSE) (nunja-site-prefix)) (cdr margs))))
                      (($nunjaDelegate handlers) << (NunjaRequestHandler handlerWithAction:"GET" pattern:__pattern statements:__function))))))

;; Declare a post action.
(global post
        (macro-0 _
             (if $do-it-the-old-way
                 (then
                      (set __pattern    (eval (car margs)))
                      (set __statements (cdr margs))
                      (($nunjaDelegate handlers) << (NunjaRequestHandler handlerWithAction:"POST" pattern:__pattern statements:__statements)))
                 (else
                      (set __pattern    (eval (car margs)))
                      (set __function (eval (append '(do (MATCH REQUEST RESPONSE) (nunja-site-prefix)) (cdr margs))))
                      (($nunjaDelegate handlers) << (NunjaRequestHandler handlerWithAction:"POST" pattern:__pattern statements:__function))))))

;; Set the top-level directory for a site
(global root
        (macro-0 _
             ($nunjaDelegate setRoot:(eval (car margs)))))

