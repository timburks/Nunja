;; @file       mime.nu
;; @discussion MIME types known to Nunja.
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

(set MIME-TYPES
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
           "tif"   "image/tiff"
           "tiff"  "image/tiff"
           "txt"   "text/plain"
           "xbm"   "image/x-xbitmap"
           "xls"   "application/vnd.ms-excel"
           "xml"   "text/xml"
           "xpm"   "image/x-xpixmap"
           "xwd"   "image/x-xwindowdump"
           "zip"   "application/zip"))

;; Guess the MIME type from the file extension of the requested file.
(function mime-type (pathName)
     (set suffix ((pathName componentsSeparatedByString:".") lastObject))
     (MIME-TYPES objectForKey:suffix withDefault:"text/html; charset=utf-8"))
