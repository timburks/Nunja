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

(case (set SYSTEM ((NSString stringWithShellCommand:"uname") chomp))
      ("Darwin" (import Foundation))
      ("Linux" (global NSLog (NuBridgedFunction functionWithName:"NSLog" signature:"v@"))
               (global NSUTF8StringEncoding 4))
      (else nil))

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
     
     ;; Get an RFC822-compliant representation of a date, expressed in GMT.
     (- (id) rfc822-GMT is
        (set result ((NSMutableString alloc) init))
        (result appendString:
                (self descriptionWithCalendarFormat:"%a, %d %b %Y %H:%M:%S GMT"
                      timeZone:(NSTimeZone timeZoneWithName:"GMT") locale:nil))
        result)
     
     ;; Get an RFC1123-compliant representation of a date.
     (- (id) rfc1123 is
        (set result ((NSMutableString alloc) init))
        (result appendString:
                (self descriptionWithCalendarFormat:"%a, %d %b %Y %H:%M:%S "
                      timeZone:(NSTimeZone timeZoneWithName:"GMT") locale:nil))
        (result appendString:((NSTimeZone timeZoneWithName:"GMT") abbreviation))
        result)
     
     ;; Get an RFC3339-compliant representation of a date.
     (- (id) rfc3339 is
        (set result ((NSMutableString alloc) init))
        (result appendString:
                (self descriptionWithCalendarFormat:"%Y-%m-%dT%H:%M:%S%z"
                      timeZone:(NSTimeZone localTimeZone) locale:nil))
        (result insertString:":" atIndex:(- (result length) 2))
        result))

;; Declare a get action.
(global get (macro get (path *body)
                 `(((Nunja nunja) delegate)
                   addHandlerWithHTTPMethod:"GET"
                   path:,path
                   block:(do (REQUEST) ,@*body))))

;; Declare a post action.
(global post (macro post (path *body)
                  `(((Nunja nunja) delegate)
                    addHandlerWithHTTPMethod:"POST"
                    path:,path
                    block:(do (REQUEST) ,@*body))))

;; Declare a put action.
(global put (macro post (path *body)
                 `(((Nunja nunja) delegate)
                   addHandlerWithHTTPMethod:"PUT"
                   path:,path
                   block:(do (REQUEST) ,@*body))))

;; Declare a delete action.
(global delete (macro post (path *body)
                    `(((Nunja nunja) delegate)
                      addHandlerWithHTTPMethod:"DELETE"
                      path:,path
                      block:(do (REQUEST) ,@*body))))

;; Declare a 404 handler.
(global get-404 (macro get-404 (*body)
                     `(((Nunja nunja) delegate)
                       setDefaultHandlerWithBlock:(do (REQUEST) ,@*body))))

(class Nunja
     (+ (id) nunjaWithCommandLineArguments is
        (set argv ((NSProcessInfo processInfo) arguments))
        (set argi 0)
        
        ;; if we're running as a nush script, skip the nush path
        (if (/(.*)nush$/ findInString:(argv 0))
            (set argi (+ argi 1)))
        
        ;; skip the program name
        (set argi (+ argi 1))
        
        ;; the option(s) we need to set
        (set port 3000)
        (set localOnly NO)
        
        ;; process the remaining arguments
        (while (< argi (argv count))
               (case (argv argi)
                     ("-p"        (set argi (+ argi 1)) (set port ((argv argi) intValue)))
                     ("--port"    (set argi (+ argi 1)) (set port ((argv argi) intValue)))
                     ("-l"        (set localOnly YES))
                     ("--local"   (set localOnly YES))
                     ("-v"        (Nunja setVerbose:YES))
                     ("--verbose" (Nunja setVerbose:YES))
                     (else (puts (+ "unknown option: " (argv argi)))
                           (exit -1)))
               (set argi (+ argi 1)))
        
        (set nunja (Nunja nunja))
        (if (eq (nunja bindToAddress:(if localOnly (then "127.0.0.1") (else "0.0.0.0"))
                       port:port) 0)
            (then (puts (+ "Nunja is running on port " port)))
            (else (puts (+ "Unable to start service on port " port ". Is another server running?")
                        (exit -1))))
        nunja))

(Nunja setMimeTypes:
       (dict "ai"    "application/postscript"
             "asc"   "text/plain"
             "avi"   "video/x-msvideo"
             "bin"   "application/octet-stream"
             "bmp"   "image/bmp"
             "class" "application/octet-stream"
             "cer"   "application/pkix-cert"
             "crl"   "application/pkix-crl"
             "crt"   "application/x-x509-ca-cert"
             "css"   "text/css"
             "dll"   "application/octet-stream"
             "dmg"   "application/octet-stream"
             "dms"   "application/octet-stream"
             "doc"   "application/msword"
             "dvi"   "application/x-dvi"
             "eps"   "application/postscript"
             "etx"   "text/x-setext"
             "exe"   "application/octet-stream"
             "gif"   "image/gif"
             "htm"   "text/html"
             "html"  "text/html"
             "ico"   "application/icon"
             "ics"   "text/calendar"
             "jpe"   "image/jpeg"
             "jpeg"  "image/jpeg"
             "jpg"   "image/jpeg"
             "js"    "text/javascript"
             "lha"   "application/octet-stream"
             "lzh"   "application/octet-stream"
             "mobileconfig"   "application/x-apple-aspen-config"
             "mov"   "video/quicktime"
             "mpe"   "video/mpeg"
             "mpeg"  "video/mpeg"
             "mpg"   "video/mpeg"
             "m3u8"  "application/x-mpegURL"
             "pbm"   "image/x-portable-bitmap"
             "pdf"   "application/pdf"
             "pgm"   "image/x-portable-graymap"
             "png"   "image/png"
             "pnm"   "image/x-portable-anymap"
             "ppm"   "image/x-portable-pixmap"
             "ppt"   "application/vnd.ms-powerpoint"
             "ps"    "application/postscript"
             "qt"    "video/quicktime"
             "ras"   "image/x-cmu-raster"
             "rb"    "text/plain"
             "rd"    "text/plain"
             "rtf"   "application/rtf"
             "sgm"   "text/sgml"
             "sgml"  "text/sgml"
             "so"    "application/octet-stream"
             "tif"   "image/tiff"
             "tiff"  "image/tiff"
             "ts"    "video/MP2T"
             "txt"   "text/plain"
             "xbm"   "image/x-xbitmap"
             "xls"   "application/vnd.ms-excel"
             "xml"   "text/xml"
             "xpm"   "image/x-xpixmap"
             "xwd"   "image/x-xwindowdump"
             "zip"   "application/zip"))
