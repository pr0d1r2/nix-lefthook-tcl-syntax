#!/usr/bin/env bats

setup() {
    TCL_SYNTAX_TEST_TMPDIR="$(mktemp -d)"
    TCL_SYNTAX_TMP="$TCL_SYNTAX_TEST_TMPDIR"
}

teardown() {
    cd "$BATS_TEST_DIRNAME"
    rm -rf "$TCL_SYNTAX_TEST_TMPDIR"
}

@test "remote hook includes both Tcl and Expect files" {
    run grep -c 'glob: "*.{tcl,exp}"' lefthook-remote.yml
    [ "$status" -eq 0 ]
    [ "$output" = 2 ]
}

@test "no args exits 0" {
    run lefthook-tcl-syntax
    [ "$status" -eq 0 ]
}

@test "non-existent file is skipped" {
    run lefthook-tcl-syntax /nonexistent/file.tcl
    [ "$status" -eq 0 ]
}

@test "non-tcl files are skipped" {
    echo 'hello' > "$TCL_SYNTAX_TMP/readme.md"
    run lefthook-tcl-syntax "$TCL_SYNTAX_TMP/readme.md"
    [ "$status" -eq 0 ]
}

@test "complete tcl script passes" {
    cat > "$TCL_SYNTAX_TMP/good.tcl" <<'TCL'
proc hello {} {
    puts "hello"
}
TCL
    run lefthook-tcl-syntax "$TCL_SYNTAX_TMP/good.tcl"
    [ "$status" -eq 0 ]
}

@test "unclosed brace fails" {
    cat > "$TCL_SYNTAX_TMP/bad.tcl" <<'TCL'
proc hello {} {
    puts "hello"
TCL
    run lefthook-tcl-syntax "$TCL_SYNTAX_TMP/bad.tcl"
    [ "$status" -ne 0 ]
}

@test "unclosed bracket fails" {
    cat > "$TCL_SYNTAX_TMP/bad.tcl" <<'TCL'
set x [expr 1 + 2
TCL
    run lefthook-tcl-syntax "$TCL_SYNTAX_TMP/bad.tcl"
    [ "$status" -ne 0 ]
}

@test "unclosed quote fails" {
    cat > "$TCL_SYNTAX_TMP/bad.tcl" <<'TCL'
set x "hello
TCL
    run lefthook-tcl-syntax "$TCL_SYNTAX_TMP/bad.tcl"
    [ "$status" -ne 0 ]
}

@test ".exp files are accepted" {
    cat > "$TCL_SYNTAX_TMP/good.exp" <<'TCL'
expect "hello"
TCL
    run lefthook-tcl-syntax "$TCL_SYNTAX_TMP/good.exp"
    [ "$status" -eq 0 ]
}

@test "hash inside set brace block fails" {
    cat > "$TCL_SYNTAX_TMP/bad.tcl" <<'TCL'
set mylist {
    item1
    # this is not a comment
    item2
}
TCL
    run lefthook-tcl-syntax "$TCL_SYNTAX_TMP/bad.tcl"
    [ "$status" -ne 0 ]
}

@test "hash inside proc body is fine" {
    cat > "$TCL_SYNTAX_TMP/good.tcl" <<'TCL'
proc hello {} {
    # this is a real comment
    puts "hello"
}
TCL
    run lefthook-tcl-syntax "$TCL_SYNTAX_TMP/good.tcl"
    [ "$status" -eq 0 ]
}

@test "hash in set block with nested braces on opening line fails" {
    cat > "$TCL_SYNTAX_TMP/bad.tcl" <<'TCL'
set config {key {val}
    # literal not a comment
    key2 val2
}
TCL
    run lefthook-tcl-syntax "$TCL_SYNTAX_TMP/bad.tcl"
    [ "$status" -ne 0 ]
}

@test "multiple files: only bad one fails" {
    cat > "$TCL_SYNTAX_TMP/good.tcl" <<'TCL'
puts "ok"
TCL
    cat > "$TCL_SYNTAX_TMP/bad.tcl" <<'TCL'
proc hello {} {
TCL
    run lefthook-tcl-syntax "$TCL_SYNTAX_TMP/good.tcl" "$TCL_SYNTAX_TMP/bad.tcl"
    [ "$status" -ne 0 ]
}
