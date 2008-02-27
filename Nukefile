
;; source files
(set @m_files     (filelist "^objc/.*.m$"))
(set @nu_files 	  (filelist "^nu/.*nu$"))

(set @ldflags  "-framework Foundation -framework Nu -levent")

;; framework description
(set @framework 			 "Nunja")
(set @framework_identifier   "nu.programming.nunja")
(set @framework_creator_code "????")

(compilation-tasks)
(framework-tasks)

(task "clobber" => "clean" is
      (SH "rm -rf #{@framework_dir}"))

(task "default" => "framework")

(task "doc" is (SH "nudoc"))

(task "install" => "framework" is
      (SH "sudo rm -rf /Library/Frameworks/#{@framework}.framework")
      (SH "ditto #{@framework}.framework /Library/Frameworks/#{@framework}.framework"))

(task "test" => "framework" is
      (SH "nutest test/test_*.nu"))
