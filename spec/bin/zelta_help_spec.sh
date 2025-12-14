#Include spec/lib/hello.sh

Describe 'zelta help'

    trim() {
      printf '%s' "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
    }

    help_msg_expected() {
          cat <<'EXPECTED'
usage: zelta command args ...
where 'command' is one of the following:

        version

        match [-Hp] [-d max] [-o field[,...]] source-endpoint target-endpoint

        backup [-bcdDeeFhhLMpuVw] [-iIjnpqRtTv]
               [initiator] source-endpoint target-endpoint

        sync [bcdDeeFhhLMpuVw] [-iIjnpqRtTv]
             [initiator] source-endpoint target-endpoint

        clone [-d max] source-dataset target-dataset

        policy [backup-options] [site|host|dataset] ...

Each endpoint is of the form: [user@][host:]dataset

Each dataset is of the form: pool/[dataset/]*dataset[@name]

For further help on a command or topic, run: zelta help [<topic>]
EXPECTED
    }


    Describe 'option question mark'
       #It 'shows a help message (whitespace‑insensitive)'
       #       expected="$(help_msg_expected)"

       #       When run ./bin/zelta -?
       #       The stderr result of trim should equal "$(trim "$expected")"
       # End

       It 'shows help lines'
           When run  ./bin/zelta -?
	         The line 1 of stderr should eq "usage: zelta command args ..."
	         # The line 4 of stderr should match pattern '^[[:space:]]*version'
	         # etc. for key lines

           The stderr should match pattern "*zelta*"
	         #The status should be defined
	         The stderr should not be empty file
	         The status should be failure
       End


          #When run RESULT="({ ./bin/zelta -? 2>&1 1>/dev/null; } 2>&1)"
       #  When run $(RESULT='*zelta command*version*match*backup*sync*clone*policy*')

#When run $(RESULT='hi')

       # It 'matches normalized help'
       #     RESULT=$({ ./bin/zelta -? 2>&1 1>/dev/null; } 2>&1)
       #     trimmed=$(trim "$RESULT")
       # 	   #When run true # Dummy command
       #     "$trimmed" should match pattern '*zelta*'
       #     #The stderr should not be empty file
       #     #The status should be failure
       # 	   #The status should be success
       # End

#       It 'matches normalized help'
#           RESULT=$({ ./bin/zelta -? 2>&1 1>/dev/null; } 2>&1)
#           #trimmed=$(trim "$RESULT")
#           #The value "$trimmed" should match pattern '*zelta*'
#	   The value "$RESULT" should match pattern '*zelta*'
#       End

       It 'matches normalized help'
         capture_stderr ./bin/zelta -?
         The value "$RESULT" should match pattern '*zelta*'
       End

    End


#    Describe 'option question mark'
#        It 'shows a help message'
#            help_msg=$(help_msg_expected)
#            EXPECTED=$(trim "$help_msg")
#
#            When call ./bin/zelta -?
#            #RESULT=The stderr
#            RESULT=$(trim stderr)
#
#            #The stderr should eq "$EXPECTED"
#            "$RESULT" should eq "$EXPECTED"
#        End
#    End

End
