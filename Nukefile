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
              (set @cflags "-g -DLINUX -I/usr/local/include -fconstant-string-class=NSConstantString ")
              (set @ldflags "-L/usr/local/lib -lNuFound -lNu -levent -lcrypto"))
      (else nil))

;; framework description
(set @framework "Nunja")
(set @framework_identifier "nu.programming.nunja")
(set @framework_creator_code "????")

(compilation-tasks)
(framework-tasks)

(task "clobber" => "clean" is
      (SH "rm -rf #{@framework_dir}"))

(task "default" => "framework")

(task "doc" is (SH "nudoc"))

(task "install" => "framework" is
      (SH "sudo cp nunjad /usr/local/bin")
      (SH "sudo rm -rf /Library/Frameworks/#{@framework}.framework")
      (SH "ditto #{@framework}.framework /Library/Frameworks/#{@framework}.framework"))

(task "test" => "framework" is
      (SH "nutest test/test_*.nu"))
