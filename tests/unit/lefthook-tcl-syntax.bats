#!/usr/bin/env bats

# Test this repository's package, not a stale copy from the caller's PATH.
setup_file() {
    TCL_SYNTAX_OUT="$(nix build "$BATS_TEST_DIRNAME/../..#default" --no-link --print-out-paths)"
    export TCL_SYNTAX_OUT
}

setup() {
    load "${BATS_LIB_PATH}/bats-support/load.bash"
    load "${BATS_LIB_PATH}/bats-assert/load.bash"

    REPO_ROOT="$BATS_TEST_DIRNAME/../.."
    TMP="$BATS_TEST_TMPDIR"
    PATH="$TCL_SYNTAX_OUT/bin:$PATH"
}

@test "remote hook includes both Tcl and Expect files" {
    run grep -cF 'glob: "*.{tcl,exp}"' "$REPO_ROOT/lefthook-remote.yml"
    assert_success
    assert_output 2
}

@test "CI guardrails workflow is pinned to a full commit SHA" {
    run awk '
        /^[[:space:]]*uses:[[:space:]]*"?pr0d1r2\/set-and-setting\/\.github\/workflows\/guardrails\.yml@/ {
            count++
            prefix = "pr0d1r2/set-and-setting/.github/workflows/guardrails.yml@"
            line = $0
            sub(/^[[:space:]]*uses:[[:space:]]*/, "", line)
            quoted = line ~ /^"/
            sub(/^"/, "", line)
            if (quoted) {
                if (line !~ /"[[:space:]]*(#.*)?$/) {
                    invalid = 1
                    next
                }
                sub(/"[[:space:]]*(#.*)?$/, "", line)
                if (line ~ /[[:space:]]/) {
                    invalid = 1
                    next
                }
            }
            if (index(line, prefix) != 1) {
                invalid = 1
                next
            }
            sha = substr(line, length(prefix) + 1)
            split(sha, fields, /[[:space:]]+/)
            if (length(fields[1]) != 40 || fields[1] !~ /^[0-9a-f]+$/) {
                invalid = 1
                next
            }
            suffix = substr(sha, length(fields[1]) + 1)
            if (suffix !~ /^[[:space:]]*(#.*)?$/) {
                invalid = 1
            }
        }
        END { exit !(count == 1 && !invalid) }
    ' "$REPO_ROOT/.github/workflows/ci.yml"
    assert_success
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

@test "hash in set block with nested braces on opening line fails" {
    cat > "$TMP/bad.tcl" <<'TCL'
set config {key {val}
    # literal not a comment
    key2 val2
}
TCL
    run lefthook-tcl-syntax "$TMP/bad.tcl"
    assert_failure
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
