set pagination off
set confirm off
set debuginfod enabled off
set print thread-events off
set print frame-arguments none
set follow-fork-mode parent
set detach-on-fork on
set disable-randomization off
handle SIGPIPE nostop noprint pass
handle SIGUSR1 nostop noprint pass
handle SIGINT nostop noprint pass
handle SIGTERM nostop noprint pass
handle SIGHUP nostop noprint pass
handle SIGSEGV stop print nopass
handle SIGABRT stop print nopass
handle SIGBUS stop print nopass
handle SIGILL stop print nopass
handle SIGFPE stop print nopass
run
if !$_isvoid($_exitcode)
  quit $_exitcode
end
if !$_isvoid($_exitsignal)
  echo SWAY_CAPTURE_TERMINATED_WITHOUT_STACK\n
  quit 1
end
echo SWAY_CRASH_BACKTRACE_BEGIN\n
thread apply all bt
info sharedlibrary
echo SWAY_CRASH_BACKTRACE_END\n
kill
quit 1