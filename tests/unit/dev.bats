#!/usr/bin/env bats

setup() {
    load "${BATS_LIB_PATH}/bats-support/load.bash"
    load "${BATS_LIB_PATH}/bats-assert/load.bash"

    TEST_TMPDIR="$(mktemp -d)"
    git init "$TEST_TMPDIR/repo" >/dev/null 2>&1
    mkdir -p "$TEST_TMPDIR/repo/.git/hooks"
    touch "$TEST_TMPDIR/repo/.git/hooks/pre-commit"

    sed 's|@BATS_LIB_PATH@|/test/lib|' dev.sh > "$TEST_TMPDIR/dev.sh"

    mkdir -p "$TEST_TMPDIR/bin"
    cat > "$TEST_TMPDIR/bin/lefthook" <<'SH'
#!/usr/bin/env bash
echo "lefthook $*" >> "$LEFTHOOK_LOG"
SH
    chmod +x "$TEST_TMPDIR/bin/lefthook"
}

teardown() {
    cd "$BATS_TEST_DIRNAME"
    rm -rf "$TEST_TMPDIR"
}

@test "sets BATS_LIB_PATH from placeholder" {
    cd "$TEST_TMPDIR/repo"
    run bash -c 'unset BATS_LIB_PATH; source "$1"; echo "$BATS_LIB_PATH"' -- "$TEST_TMPDIR/dev.sh"
    assert_success
    assert_output "/test/lib/share/bats"
}

@test "runs lefthook install when hooks are missing" {
    cd "$TEST_TMPDIR/repo"
    rm "$TEST_TMPDIR/repo/.git/hooks/pre-commit"
    # shellcheck disable=SC2030
    export PATH="$TEST_TMPDIR/bin:$PATH"
    # shellcheck disable=SC2030
    export LEFTHOOK_LOG="$TEST_TMPDIR/log"
    # shellcheck disable=SC1091
    source "$TEST_TMPDIR/dev.sh"
    assert [ -f "$LEFTHOOK_LOG" ]
    run cat "$LEFTHOOK_LOG"
    assert_output "lefthook install"
}

@test "skips lefthook install when hooks exist" {
    cd "$TEST_TMPDIR/repo"
    # shellcheck disable=SC2031
    export PATH="$TEST_TMPDIR/bin:$PATH"
    # shellcheck disable=SC2031
    export LEFTHOOK_LOG="$TEST_TMPDIR/log"
    # shellcheck disable=SC1091
    source "$TEST_TMPDIR/dev.sh"
    assert [ ! -f "$LEFTHOOK_LOG" ]
}
