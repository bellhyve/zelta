# Check `zelta rebase` option processing and dry-run planning

Describe 'zelta rebase'
	It 'requires three operands'
		When run command zelta rebase old-prod new-upstream
		The status should be failure
		The error should include 'requires OLD_PROD, NEW_UPSTREAM, and NEW_PROD'
	End
	It 'shows the clone-origin backup primitive in dry-run mode'
		When run command zelta rebase -n old-prod new-upstream new-prod
		The status should be success
		The output should include "zelta ipc-run backup --target-origin 'old-prod'"
	End
	It 'plans preserve-file copy commands in dry-run mode'
		When run command zelta rebase -n --rebase-file examples/bsdcan/rebase/web01.zeltarebase old-prod new-upstream new-prod
		The status should be success
		The output should include "cp -p '/old-prod/etc/local.conf' '/new-prod/etc/local.conf'"
	End
End
