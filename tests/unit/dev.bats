#!/usr/bin/env bats

setup() {
    load "${BATS_LIB_PATH}/bats-support/load.bash"
    load "${BATS_LIB_PATH}/bats-assert/load.bash"

    TEST_TEMP="$(mktemp -d)"
    git init "$TEST_TEMP/repo" >/dev/null 2>&1
    mkdir -p "$TEST_TEMP/repo/.git/hooks"
    touch "$TEST_TEMP/repo/.git/hooks/pre-commit"

    sed 's|@BATS_LIB_PATH@|/test/lib|' "$BATS_TEST_DIRNAME/../../dev.sh" > "$TEST_TEMP/dev.sh"

    mkdir -p "$TEST_TEMP/bin"
    cat > "$TEST_TEMP/bin/lefthook" <<'SH'
#!/usr/bin/env bash
echo "lefthook $*" >> "$LEFTHOOK_LOG"
SH
    chmod +x "$TEST_TEMP/bin/lefthook"
}

teardown() {
    rm -rf "$TEST_TEMP"
}

@test "sets BATS_LIB_PATH from placeholder" {
    cd "$TEST_TEMP/repo"
    run bash -c 'unset BATS_LIB_PATH; source "$1"; echo "$BATS_LIB_PATH"' -- "$TEST_TEMP/dev.sh"
    assert_success
    assert_output "/test/lib/share/bats"
}

@test "runs lefthook install when hooks are missing" {
    cd "$TEST_TEMP/repo"
    rm "$TEST_TEMP/repo/.git/hooks/pre-commit"
    # shellcheck disable=SC2030
    export PATH="$TEST_TEMP/bin:$PATH"
    # shellcheck disable=SC2030
    export LEFTHOOK_LOG="$TEST_TEMP/log"
    # shellcheck disable=SC1091
    source "$TEST_TEMP/dev.sh"
    assert [ -f "$LEFTHOOK_LOG" ]
    run cat "$LEFTHOOK_LOG"
    assert_output "lefthook install"
}

@test "skips lefthook install when hooks exist" {
    cd "$TEST_TEMP/repo"
    # shellcheck disable=SC2031
    export PATH="$TEST_TEMP/bin:$PATH"
    # shellcheck disable=SC2031
    export LEFTHOOK_LOG="$TEST_TEMP/log"
    # shellcheck disable=SC1091
    source "$TEST_TEMP/dev.sh"
    assert [ ! -f "$LEFTHOOK_LOG" ]
}
