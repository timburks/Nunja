;; test_salt.nu
;;  tests for Nunja password salting helper.
;;
;;  Copyright (c) 2007 Tim Burks, Neon Design Technology, Inc.

(load "Nunja")

(class TestSalt is NuTestCase
     
     (- testSalt is
        (set salted (Nunja saltedPassword:"secret" withSalt:"sauce"))
        ;; golden result obtained with "openssl passwd -1 -salt sauce"
        (assert_equal "$1$sauce$ToKwxvX1ZyeiswSSzdPRi0" salted)))


