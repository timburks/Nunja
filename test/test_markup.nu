;; test_markup.nu
;;  tests for Nunja markup operator
;;
;;  Copyright (c) 2010 Tim Burks, Neon Design Technology, Inc.

(load "Nunja")

(class TestMarkup is NuTestCase
     
     (- testMarkup is
        (set &html (NunjaMarkupOperator operatorWithTag:"html" prefix:"<!DOCTYPE html>\n"))
        (set &body (NunjaMarkupOperator operatorWithTag:"body"))
        
        (assert_equal "<body/>" (&body))
        (assert_equal "<body/>" (&body incomplete:))
        (assert_equal "<body attr=\"val\"/>" (&body attr:"val"))
        (assert_equal "<!DOCTYPE html>\n<html><body this=\"is\" a=\"test\">hello, world</body></html>" (&html (&body this:"is" a:"test" "hello," " world")))))

