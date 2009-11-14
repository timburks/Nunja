;; test_server.nu
;;  tests for Nunja web serving.
;;
;;  Copyright (c) 2009 Tim Burks, Neon Design Technology, Inc.

(load "NuHTTPHelpers")
(load "Nunja")

(set sleep (NuBridgedFunction functionWithName:"sleep" signature:"vi"))

(class TestServer is NuTestCase
     (- setup is
        (system "rm -f nunjad.pid")
        (system "nunjad -p 3000 -s sample &")
        (until ((NSFileManager defaultManager) fileExistsAtPath:"nunjad.pid")
               (sleep 1)))
     
     (- teardown is
        (set pid ((NSString stringWithContentsOfFile:"nunjad.pid") chomp))
        (system (+ "kill -9 " pid))
        (system "rm -f nunjad.pid"))
     
     (- testServer is
        ;; test a simple get
        (assert_equal "hello" (NSString stringWithShellCommand:"curl -s http://localhost:3000/hello"))
        
        ;; test path bindings
        (assert_equal "/follow/my-lead" (NSString stringWithShellCommand:"curl -s http://localhost:3000/follow/my-lead"))
        (assert_equal "/beauty/after/age" (NSString stringWithShellCommand:"curl -s http://localhost:3000/age/before/beauty"))
        
        ;; test regular expression action handler
        (assert_equal "more-stuff" (NSString stringWithShellCommand:"curl -s http://localhost:3000/foo/more-stuff"))
        (assert_equal "anything&^%$#@!goes" (NSString stringWithShellCommand:"curl -s 'http://localhost:3000/foo/anything&^%$#@!goes'"))
        
        ;; test query parameters
        (assert_equal "a:123,b:456,c:789" (NSString stringWithShellCommand:"curl -s 'http://localhost:3000/get?a=123&b=456&c=789'"))
        
        ;; test post
        (assert_equal "a:123,b:456,c:789" (NSString stringWithShellCommand:"curl -s -d a=123 -d b=456 -d c=789 'http://localhost:3000/post'"))
        
        ;; get a file served from the server's file system
        (set favicon (NSData dataWithShellCommand:"curl -s http://localhost:3000/favicon.ico"))
        (set favicon_gold (NSData dataWithContentsOfFile:"sample/public/favicon.ico"))
        (assert_equal favicon_gold favicon)
        
        ;; get a file served from the server's file system
        (set favicon (NSData dataWithShellCommand:"curl -s http://localhost:3000/recycle.ico"))
        (set favicon_gold (NSData dataWithContentsOfFile:"sample/public/favicon.ico"))
        (assert_equal favicon_gold favicon)))








