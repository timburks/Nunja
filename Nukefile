;; source files
(set @m_files     (filelist "^objc/.*.m$"))
(set @nu_files 	  (filelist "^nu/.*nu$"))

(set SYSTEM ((NSString stringWithShellCommand:"uname") chomp))
(case SYSTEM
      ("Darwin"
               (set @cflags "-g -fobjc-gc -DDARWIN")
               (set @ldflags  "-framework Foundation -framework Nu -levent -lcrypto"))
      ("Linux"
              (set @arch (list "i386"))
              ;; (set @cflags "-g -DLINUX -I/usr/local/include -fconstant-string-class=NSConstantString ")
              ;; (set @ldflags "-L/usr/local/lib -lNuFound -lNu -levent -lcrypto")
              (set gnustep_flags ((NSString stringWithShellCommand:"gnustep-config --objc-flags") chomp))
              (set gnustep_libs ((NSString stringWithShellCommand:"gnustep-config --base-libs") chomp))
              (set @cflags "-g -DLINUX -I/usr/local/include #{gnustep_flags}")
              (set @ldflags "#{gnustep_libs} -lNu -levent -lcrypto"))
      (else nil))

;; framework description
(set @framework "Nunja")
(set @framework_identifier "nu.programming.nunja")
(set @framework_creator_code "????")
(set @framework_extra_install
     (do () (SH "sudo cp nunjad /usr/local/bin")))

(compilation-tasks)
(framework-tasks)

(task "clobber" => "clean" is
      (SH "rm -rf #{@framework_dir}"))

(task "default" => "framework")

(task "doc" is (SH "nudoc"))

