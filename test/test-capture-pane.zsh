#!/usr/bin/env zsh
# Tests capture-pane backend selection without touching live terminals.

emulate -L zsh

script=${0:A:h}/../capture-pane
failures=0

assert_eq() {
    local label=$1 want=$2 got=$3
    if [[ $got == $want ]]; then
        print "  ok: $label"
    else
        print "  FAIL: $label\n    want: $want\n    got:  $got"
        (( ++failures ))
    fi
}

sandbox=$(mktemp -d ${TMPDIR:-/tmp}/test-capture-pane.XXXXXX)
trap "rm -rf $sandbox" EXIT
mkdir $sandbox/bin
calls=$sandbox/calls
stderr_file=$sandbox/stderr
screen_file=$sandbox/screen
print "ghostty output" > $screen_file

print -r -- '#!/bin/sh
printf "tmux %s\n" "$*" >> "$CAPTURE_PANE_TEST_CALLS"
printf "%s\n" "tmux output"' > $sandbox/bin/tmux

print -r -- '#!/bin/sh
printf "herdr %s\n" "$*" >> "$CAPTURE_PANE_TEST_CALLS"
printf "%s\n" "herdr output"' > $sandbox/bin/herdr

print -r -- '#!/bin/sh
printf "%s\n" "osascript" >> "$CAPTURE_PANE_TEST_CALLS"' > $sandbox/bin/osascript

print -r -- '#!/bin/sh
printf "%s\n" "pbpaste" >> "$CAPTURE_PANE_TEST_CALLS"
printf "%s\n" "$CAPTURE_PANE_TEST_SCREEN"' > $sandbox/bin/pbpaste

chmod +x $sandbox/bin/{tmux,herdr,osascript,pbpaste}
test_path=$sandbox/bin:/usr/bin:/bin

run_capture_pane() {
    : > $calls
    : > $stderr_file
    output=$(CAPTURE_PANE_TEST_CALLS=$calls \
        CAPTURE_PANE_TEST_SCREEN=$screen_file PATH=$test_path \
        TMUX=${TEST_TMUX:-} HERDR_PANE_ID=${TEST_HERDR_PANE_ID:-} \
        GHOSTTY_RESOURCES_DIR=${TEST_GHOSTTY:-} \
        /bin/zsh $script $@ 2> $stderr_file)
    run_rc=$?
    stderr=$(<$stderr_file)
}

print "capture-pane:"

TEST_TMUX=tmux-pane TEST_HERDR_PANE_ID= TEST_GHOSTTY=ghostty run_capture_pane
assert_eq "tmux-only env captures tmux" "tmux output" $output
assert_eq "tmux command" "tmux capture-pane -pS -" "$(<$calls)"

TEST_TMUX= TEST_HERDR_PANE_ID=herdr:pane TEST_GHOSTTY=ghostty run_capture_pane
assert_eq "herdr-only env captures herdr" "herdr output" $output
assert_eq "herdr command" \
    "herdr pane read herdr:pane --lines 100000" "$(<$calls)"

TEST_TMUX=tmux-pane TEST_HERDR_PANE_ID=herdr:pane TEST_GHOSTTY=ghostty run_capture_pane
assert_eq "ambiguous nesting exits with usage error" 2 $run_rc
assert_eq "ambiguous nesting requires an explicit choice" \
    "capture-pane: both tmux and herdr detected; use --tmux, --herdr, or --ghostty" $stderr
assert_eq "ambiguous nesting invokes nothing" "" "$(<$calls)"

TEST_TMUX=tmux-pane TEST_HERDR_PANE_ID=herdr:pane TEST_GHOSTTY=ghostty \
    run_capture_pane --tmux
assert_eq "explicit tmux captures the requested layer" "tmux output" $output

TEST_TMUX=tmux-pane TEST_HERDR_PANE_ID=herdr:pane TEST_GHOSTTY=ghostty \
    run_capture_pane --herdr
assert_eq "explicit herdr captures the requested layer" "herdr output" $output

TEST_TMUX=tmux-pane TEST_HERDR_PANE_ID=herdr:pane TEST_GHOSTTY=ghostty \
    run_capture_pane --ghostty
assert_eq "explicit Ghostty captures the outer surface" "ghostty output" $output
assert_eq "Ghostty bridge commands" $'osascript\npbpaste' "$(<$calls)"

TEST_TMUX= TEST_HERDR_PANE_ID= TEST_GHOSTTY=ghostty run_capture_pane
assert_eq "Ghostty-only env is the automatic fallback" "ghostty output" $output

TEST_TMUX= TEST_HERDR_PANE_ID= TEST_GHOSTTY= run_capture_pane --herdr
assert_eq "explicit missing backend fails" 1 $run_rc
assert_eq "explicit missing backend explains requirement" \
    "capture-pane: --herdr requires a herdr pane" $stderr

run_capture_pane --unknown
assert_eq "unknown option exits with usage error" 2 $run_rc
assert_eq "unknown option prints usage" \
    "Usage: capture-pane [--tmux|--herdr|--ghostty]" $stderr

if (( failures )); then
    print "$failures failure(s)"
    exit 1
fi
print "all passed"
