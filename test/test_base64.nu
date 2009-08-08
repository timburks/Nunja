;; test_base64.nu
;;  tests for Nunja base64 encoding/decoding.
;;
;;  Copyright (c) 2009 Tim Burks, Neon Design Technology, Inc.

(load "Nunja")

(class TestBase64 is NuTestCase
     
     (- testSanity is
        (set d (NSData dataWithContentsOfFile:"image.png"))
        (assert_equal (d base64) (((d base64) dataUsingBase64Encoding) base64))
        (assert_equal d  ((d base64) dataUsingBase64Encoding))))


