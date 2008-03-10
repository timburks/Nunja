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

;; global variables
(set $sessionCookies (dict))
(set $friends (array))

;; front page.
(get "/"
     (set sessionCookieName ((request cookies) "session"))
     (set sessionCookie (if sessionCookieName (then ($sessionCookies sessionCookieName)) (else nil)))
     (set user (sessionCookie user))
     
     (set TITLE "Friends")
     (set template <<-TEMPLATE
<h1>Hello!</h1>
<p>Let's make a list.</p>
<% (if user (then %>
<h2>Your friends</h2>
<ul>
<% ($friends each: (do (friend) %>
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
     (eval (NuTemplate codeForString:template)))

;; login page.
(get "/login"
     (set TITLE "Log in")
     <<-HTML
<form action="/login" method="post">
<p>Please sign in.</p>
<label for="username">username: </label> <input type="text" name="username"/><br/>
<label for="password">password: </label> <input type="password" name="password"/><br/>
<input type="submit" value="Submit" />
</form>	
HTML)

;; login POST handler.
(post "/login"
      (set post (request post))
      (if (eq (post "response") "Cancel")
          (then
               (self redirectResponse:request toLocation:"/"))
          (else
               (set username (post "username"))
               (set password (post "password"))
               (if (and (> (username length) 0) (eq username password))
                   (then
                        (set sessionCookie (NunjaCookie cookieForUser:username))
                        ($sessionCookies setObject:sessionCookie forKey:(sessionCookie value))
                        (request setValue:(sessionCookie stringValue) forResponseHeader:"Set-Cookie")
                        (self redirectResponse:request toLocation:"/"))
                   (else
                        (set TITLE "Please try again")
                        <<-HTML
<p>Invalid Password.  Your password is your username.</p>
<form action="/login" method="post">
<label for="username">username: </label> <input type="text" name="username"/><br/>
<label for="password">password: </label> <input type="password" name="password"/><br/>
<input type="submit" name="response" value="Submit" />
<input type="submit" name="response" value="Cancel" />
</form>	
			HTML)))))

;; logout, also with a GET. In the real world, we would prefer a POST.
(get "/logout"
     (set sessionCookieName ((request cookies) "session"))
     (if sessionCookieName ($sessionCookies removeObjectForKey:sessionCookieName))
     (self redirectResponse:request toLocation:"/"))

;; add-a-friend page.
(get "/addfriend"
     (set TITLE "Add a friend")
     <<-HTML
<h1>Add a friend</h1>
<form action="/addfriend" method="post">
<p>
<label for="name">name: </label><input type="text" name="name"/><br/>
<label for="email">email: </labellabel><input type="text" name="email"/><br/>
<input type="submit" name="response" value="Submit" />         
<input type="submit" name="response" value="Cancel"/>
</p>
</form>
HTML)

;; add-a-friend POST handler.
(post "/addfriend"
      (set post (request post))
      (if (eq (post "response") "Submit")
          ($friends << (dict name:(post "name") email:(post "email"))))
      (self redirectResponse:request toLocation:"/"))

;; delete-a-friend with a GET. Strictly, this should be a post, but we use a get to show how it would be done.
(get (regex -"^/delete\?(.*)$")
     (set post ((@match groupAtIndex:1) urlQueryDictionary))
     (set $friends ($friends select:(do (friend) (!= (friend "name") (post "name")))))
     (self redirectResponse:request toLocation:"/"))

(get "/about" <<-END
<h1>About this site</h1>
<p>It is running on Nunja!</p>
END)

(get "/recycle.ico"
     (request setValue:"application/icon" forResponseHeader:"Content-Type")
     (NSData dataWithContentsOfFile:"public/favicon.ico"))
