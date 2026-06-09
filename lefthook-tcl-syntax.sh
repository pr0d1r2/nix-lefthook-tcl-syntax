# shellcheck shell=bash
# Lefthook-compatible Tcl syntax checker.
# Usage: lefthook-tcl-syntax file1.tcl [file2.exp ...]
# Non-.tcl/.exp files are skipped silently.
# NOTE: sourced by writeShellApplication — no shebang or set needed.

if [ $# -eq 0 ]; then
  exit 0
fi

failed=0
for f in "$@"; do
  [ -f "$f" ] || continue
  case "$f" in
    *.exp | *.tcl) ;;
    *) continue ;;
  esac

  rc=0
  err="$(
    tclsh /dev/stdin "$f" 2>&1 <<'TCL'
set path [lindex $argv 0]
set fd [open $path r]
set content [read $fd]
close $fd
if {![info complete $content]} {
    puts stderr "$path: incomplete Tcl (unclosed braces, brackets, or quotes)"
    exit 1
}

set lineno 0
set in_set_block 0
set set_depth 0
set errors 0
foreach line [split $content \n] {
    incr lineno
    if {!$in_set_block && [regexp {^\s*set\s+\S+\s+\{} $line]} {
        set in_set_block 1
        set set_depth 1
        set closes [llength [regexp -all -inline {\}} $line]]
        set set_depth [expr {$set_depth - $closes}]
        if {$set_depth <= 0} { set in_set_block 0 }
        continue
    }
    if {$in_set_block} {
        set opens [llength [regexp -all -inline {\{} $line]]
        set closes [llength [regexp -all -inline {\}} $line]]
        set set_depth [expr {$set_depth + $opens - $closes}]
        if {[regexp {^\s+#} $line]} {
            puts stderr "$path:$lineno: # inside set { } block is a literal, not a comment"
            incr errors
        }
        if {$set_depth <= 0} { set in_set_block 0 }
    }
}
if {$errors > 0} { exit 1 }
exit 0
TCL
  )" || rc=$?

  if [ "$rc" -ne 0 ]; then
    printf '%s\n' "$err" >&2
    failed=1
  fi
done

exit "$failed"
