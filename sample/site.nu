;; @file       sample.nu
;; @discussion Sample site demonstrating the Nunja web server.
;; @copyright  Copyright (c) 2008 Tim Burks, Neon Design Technology, Inc.
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

(load "NuHTTPHelpers")
(load "Nu:template")

;; import some useful C functions
(global random  (NuBridgedFunction functionWithName:"random" signature:"l"))
(global srandom (NuBridgedFunction functionWithName:"srandom" signature:"vI"))

(class NunjaRequest
     (- post is ((self body) urlQueryDictionary)))

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

;; global variables
(set sessionCookies (dict))
(set friends (array))

(set page-layout (NuTemplate codeForString:<<-TEMPLATE
<html>
<head>
<%= (if (RESPONSE "HEAD") (then (RESPONSE "HEAD")) (else "")) %>
<% (if (RESPONSE "TITLE") (then %>
<title><%= (RESPONSE "TITLE") %></title>
<% )) %>
</head>
<body>
<%= (RESPONSE "BODY") %>
</body>
</html>
TEMPLATE))

;; front page.
(get "/"
     (set RESPONSE (dict))
     (set sessionCookieName ((REQUEST cookies) "session"))
     (set sessionCookie (if sessionCookieName (then (sessionCookies sessionCookieName)) (else nil)))
     (set user (sessionCookie user))
     
     (RESPONSE setValue:"Friends" forKey:"TITLE")
     (set template <<-TEMPLATE
<h1>Hello!</h1>
<p>Let's make a list.</p>
<% (if user (then %>
<h2>Your friends</h2>
<ul>
<% (friends each: (do (friend) %>
<% (set deletion ((dict "name" (friend "name")) urlQueryString)) %>
<li><%= (friend "name") %> (<%= (friend "email") %>) (<a href="/delete?<%= deletion %>">X</a>)</li>
<% )) %>
<li><a href="/addfriend">Add a friend</a></li>
</ul>
<hr/>
<p>You are logged in as <%= user %>. <a href="/logout">Log out.</a></p>
<% ) (else %>
<form action="/login" method="post">
<p>First, please sign in.</p>
<label for="username">username: </label> <input type="text" name="username"/><br/>
<label for="password">password: </label> <input type="password" name="password"/><br/>
<input type="submit" value="Submit" />
</form>
<% )) %>
TEMPLATE)
     (RESPONSE setValue:(eval (NuTemplate codeForString:template)) forKey:"BODY")
     (eval page-layout))

;; login page.
(get "/login"
     (set RESPONSE (dict))
     (RESPONSE setValue:"Log in" forKey:"TITLE")
     (RESPONSE setValue:(eval (NuTemplate codeForString:<<-HTML
<form action="/login" method="post">
<p>Please sign in.</p>
<label for="username">username: </label> <input type="text" name="username"/><br/>
<label for="password">password: </label> <input type="password" name="password"/><br/>
<input type="submit" value="Submit" />
</form>	
HTML)) forKey:"BODY")
     (eval page-layout))

;; login POST handler.
(post "/login"
      (set RESPONSE (dict))
      (set post (REQUEST post))
      (if (eq (post "response") "Cancel")
          (then
               (REQUEST redirectResponseToLocation:"/"))
          (else
               (set username (post "username"))
               (set password (post "password"))
               (if (and (> (username length) 0) (eq username password))
                   (then
                        (set sessionCookie (NunjaCookie cookieForUser:username))
                        (sessionCookies setObject:sessionCookie forKey:(sessionCookie value))
                        (REQUEST setValue:(sessionCookie stringValue) forResponseHeader:"Set-Cookie")
                        (REQUEST redirectResponseToLocation:"/"))
                   (else
                        (RESPONSE setValue:"Please try again" forKey:"TITLE")
                        (RESPONSE setValue:(eval (NuTemplate codeForString:<<-HTML
<p>Invalid Password.  Your password is your username.</p>
<form action="/login" method="post">
<label for="username">username: </label> <input type="text" name="username"/><br/>
<label for="password">password: </label> <input type="password" name="password"/><br/>
<input type="submit" name="response" value="Submit" />
<input type="submit" name="response" value="Cancel" />
</form>	
HTML)) forKey:"BODY")
                        (eval page-layout))))))

;; logout, also with a GET. In the real world, we would prefer a POST.
(get "/logout"
     (set sessionCookieName ((REQUEST cookies) "session"))
     (if sessionCookieName (sessionCookies removeObjectForKey:sessionCookieName))
     (REQUEST redirectResponseToLocation:"/"))

;; add-a-friend page.
(get "/addfriend"
     (set RESPONSE (dict))
     (RESPONSE setValue:"Add a friend" forKey:"TITLE")
     (RESPONSE setValue:(eval (NuTemplate codeForString:<<-HTML
<h1>Add a friend</h1>
<form action="/addfriend" method="post">
<p>
<label for="name">name: </label><input type="text" name="name"/><br/>
<label for="email">email: </label><input type="text" name="email"/><br/>
<input type="submit" name="response" value="Submit" />         
<input type="submit" name="response" value="Cancel"/>
</p>
</form>
HTML)) forKey:"BODY")
     (eval page-layout))

;; add-a-friend POST handler.
(post "/addfriend"
      (set post (REQUEST post))
      (if (eq (post "response") "Submit")
          (friends << (dict name:(post "name") email:(post "email"))))
      (REQUEST redirectResponseToLocation:"/"))

;; delete-a-friend with a GET. Strictly, this should be a post, but we use a get to show how it would be done.
(get "/delete"
     (set post (REQUEST query))
     (set friends (friends select:(do (friend) (!= (friend "name") (post "name")))))
     (REQUEST redirectResponseToLocation:"/"))

(get "/about"
     (set RESPONSE (dict))
     (RESPONSE setValue:<<-END
<h1>About this site</h1>
<p>It is running on Nunja!</p>
END forKey:"BODY")
     (eval page-layout))


;; image uploads
(post "/postimage"
      (set RESPONSE (dict))
      (puts (REQUEST description))
      (set postBody (REQUEST body))
      (puts ((REQUEST requestHeaders) description))
      (set contentType ((REQUEST requestHeaders) "Content-Type"))
      (set boundary ((contentType componentsSeparatedByString:"=") lastObject))
      (set postDictionary (postBody multipartDictionaryWithBoundary:boundary))
      (puts ((postDictionary allKeys) description))
      (set image (postDictionary objectForKey:"image"))
      (set data (image objectForKey:"data"))
      (data writeToFile:"image.png" atomically:NO)
      (RESPONSE setValue:(+ "Thanks for uploading!<br/><pre>" ((postDictionary allKeys) description) "</pre>") forKey:"BODY")
      (eval page-layout))

;; multipart form upload
;; curl -F "file1=@README" -F "file2=@LICENSE" http://localhost:3000/multipart
(post "/multipart"
      (set RESPONSE (dict))
      (puts (REQUEST description))
      (set postBody (REQUEST body))
      (puts ((REQUEST requestHeaders) description))
      (set contentType ((REQUEST requestHeaders) "Content-Type"))
      (set boundary ((contentType componentsSeparatedByString:"=") lastObject))
      (set postDictionary (postBody multipartDictionaryWithBoundary:boundary))
      (RESPONSE setValue:(+ "Thanks for uploading!<br/><pre>" (postDictionary description) "</pre>") forKey:"BODY")
      (eval page-layout))

;; large file download
(get "/data/size:"
     (REQUEST setValue:"application/octet-stream" forResponseHeader:"Content-Type")
     (set size ((REQUEST bindings) size:))
     (set megabytes (if (eq size "")
                        then 1
                        else (size doubleValue)))
     (if (> megabytes 256)
         (then
              (puts "too large. sending 1 byte instead.")
              (set data (NSData dataWithSize:1)))
         (else
              (set data (NSData dataWithSize:(* megabytes 1024 1024)))))
     data)

;; perform a dns lookup
;; ex: /dns/programming.nu
(get "/dns/hostname:"
     (set hostname ((REQUEST bindings) hostname:))
     ((REQUEST nunja) resolveDomainName:hostname andDo:
      (do (address)
          (if address
              (REQUEST respondWithString:"resolved #{hostname} as #{address}")
              else
              (REQUEST respondWithString:"unable to resolve #{hostname}"))))
     nil) ;; return nil to leave the connection open

(if NO
    ;; request and return a resource from a specified host
    ;; ex: /proxy/programming.nu/about
    (get (regex -"/proxy/([^\/]+)/(.*)")
         (set host ((REQUEST match) groupAtIndex:1))
         (set path (+ "/" ((REQUEST match) groupAtIndex:2)))
         ((REQUEST nunja) resolveDomainName:host andDo:
          (do (address)
              (if address
                  (then ((REQUEST nunja) getResourceFromHost:host address:address port:80 path:path andDo:
                         (do (data)
                             (if data
                                 (then (REQUEST respondWithData:data))
                                 (else (REQUEST respondWithString:"unable to load #{path}"))))))
                  (else (REQUEST respondWithString:"unable to resolve host #{host}")))))
         nil) ;; return nil to leave the connection open
    )

(get "/posttest"
     (set host "localhost")
     (set path "/login")
     ((REQUEST nunja) resolveDomainName:host andDo:
      (do (address)
          (if address
              (set postdata (((dict username:"bob" password:"bob") urlQueryString) dataUsingEncoding:NSUTF8StringEncoding))
              (then ((REQUEST nunja) postDataToHost:host address:address port:3000 path:path data:postdata andDo:
                     (do (data)
                         (if data
                             (then (REQUEST respondWithData:data))
                             (else (REQUEST respondWithString:"unable to load #{path}"))))))
              (else (REQUEST respondWithString:"unable to resolve host #{host}")))))
     nil) ;; return nil to leave the connection open

(global upload-count 0)

(post "/upload"
      (REQUEST setValue:"text/plain" forResponseHeader:"Content-Type")
      (set response "uploading item #{(global upload-count (+ upload-count 1))}\n#{((NSDate date) description)}\n")
      (response appendString:((REQUEST requestHeaders) description))
      (response appendString:"\n")
      response)

;; TESTED ACTIONS - the following handlers are tested by Nunja unit tests and should not be changed lightly
(get "/hello"
     "hello")

(get "/recycle.ico"
     (REQUEST setValue:"application/icon" forResponseHeader:"Content-Type")
     (NSData dataWithContentsOfFile:"public/favicon.ico"))

(get "/follow/me:"
     (REQUEST setValue:"text/plain" forResponseHeader:"Content-Type")
     (+ "/follow/" ((REQUEST bindings) "me")))

(get "/a:/before/b:"
     (REQUEST setValue:"text/plain" forResponseHeader:"Content-Type")
     (+ "/" ((REQUEST bindings) "b") "/after/" ((REQUEST bindings) "a")))

(get "/get"
     (set q (REQUEST query))
     (set a (((q allKeys) sort) map:
             (do (key)
                 (+ key ":" (q key)))))
     (a componentsJoinedByString:","))

(post "/post"
      (set q (REQUEST post))
      (set a (((q allKeys) sort) map:
              (do (key)
                  (+ key ":" (q key)))))
      (a componentsJoinedByString:","))

(get "/foo/rest:"
     ((REQUEST bindings) rest:))

(get-404
        "Resource Not Found: #{(REQUEST path)}")


