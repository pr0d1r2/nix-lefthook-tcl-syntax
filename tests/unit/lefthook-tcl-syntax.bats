#!/usr/bin/env bats

setup() {
    load "${BATS_LIB_PATH}/bats-support/load.bash"
    load "${BATS_LIB_PATH}/bats-assert/load.bash"

    TMP="$BATS_TEST_TMPDIR"
}

@test "no args exits 0" {
    run lefthook-tcl-syntax
    assert_success
}

@test "non-existent file is skipped" {
    run lefthook-tcl-syntax /nonexistent/file.tcl
    assert_success
}

@test "non-tcl files are skipped" {
    echo 'hello' > "$TMP/readme.md"
    run lefthook-tcl-syntax "$TMP/readme.md"
    assert_success
}

@test "complete tcl script passes" {
    cat > "$TMP/good.tcl" <<'TCL'
proc hello {} {
    puts "hello"
}
TCL
    run lefthook-tcl-syntax "$TMP/good.tcl"
    assert_success
}

@test "unclosed brace fails" {
    cat > "$TMP/bad.tcl" <<'TCL'
proc hello {} {
    puts "hello"
TCL
    run lefthook-tcl-syntax "$TMP/bad.tcl"
    assert_failure
}

@test "unclosed bracket fails" {
    cat > "$TMP/bad.tcl" <<'TCL'
set x [expr 1 + 2
TCL
    run lefthook-tcl-syntax "$TMP/bad.tcl"
    assert_failure
}

@test "unclosed quote fails" {
    cat > "$TMP/bad.tcl" <<'TCL'
set x "hello
TCL
    run lefthook-tcl-syntax "$TMP/bad.tcl"
    assert_failure
}

@test ".exp files are accepted" {
    cat > "$TMP/good.exp" <<'TCL'
expect "hello"
TCL
    run lefthook-tcl-syntax "$TMP/good.exp"
    assert_success
}

@test "hash inside set brace block fails" {
    cat > "$TMP/bad.tcl" <<'TCL'
set mylist {
    item1
    # this is not a comment
    item2
}
TCL
    run lefthook-tcl-syntax "$TMP/bad.tcl"
    assert_failure
}

@test "hash inside proc body is fine" {
    cat > "$TMP/good.tcl" <<'TCL'
proc hello {} {
    # this is a real comment
    puts "hello"
}
TCL
    run lefthook-tcl-syntax "$TMP/good.tcl"
    assert_success
}

@test "multiple files: only bad one fails" {
    cat > "$TMP/good.tcl" <<'TCL'
puts "ok"
TCL
    cat > "$TMP/bad.tcl" <<'TCL'
proc hello {} {
TCL
    run lefthook-tcl-syntax "$TMP/good.tcl" "$TMP/bad.tcl"
    assert_failure
}
