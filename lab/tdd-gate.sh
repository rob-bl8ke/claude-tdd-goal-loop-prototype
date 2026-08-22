#!/usr/bin/env bash
# tdd-gate.sh — deterministic TDD phase gate.
#
# Portable boilerplate. Only the PROJECT CONFIGURATION block below is
# stack-specific; the defaults target Maven + Surefire. Everything else works
# unchanged on any project whose test runner prints a summary line.
#
#   tdd-gate.sh init "<slice 1 title>" "<slice 2 title>" ...  bootstrap state.json
#   tdd-gate.sh reset                                         start a fresh run
#   tdd-gate.sh red "<expected-failure-substring>"             assert red, for the right reason
#   tdd-gate.sh green                                          assert green, suite did not shrink
#   tdd-gate.sh done <n> "<files touched>"                     record slice + append evidence
#
# Exit 0 = gate passed. Exit 1 = gate failed; stop the loop for a human.
#
# Why a script rather than an agent: running the suite and comparing counts is a
# fact, not a judgement. Asked to do it, an LLM will occasionally invent test
# names it never saw. See AGENTS.md for the measured comparison.

set -uo pipefail
cd "$(dirname "$0")/.."

STATE="${TDD_STATE:-lab/state.json}"
EVIDENCE="${TDD_EVIDENCE:-lab/evidence.md}"
LOG="${TDD_GATE_LOG:-${TMPDIR:-/tmp}/tdd-gate-tests.log}"

# ===========================================================================
# PROJECT CONFIGURATION — the only stack-specific part of this file.
# ===========================================================================

# `clean` is deliberate: without it an incremental test-compile can report
# "Nothing to compile" after a fresh edit due to filesystem timestamp
# granularity, and the gate would then grade the PREVIOUS build's output.
TEST_CMD="${TDD_TEST_CMD:-mvn -B clean test}"
COMPILE_ERROR_RE="${TDD_COMPILE_ERROR_RE:-COMPILATION ERROR|cannot find symbol}"

# Emit "<executed> <failed> <skipped>". Return non-zero if no summary line was
# found at all, which the gate treats as "the suite did not run", not as success.
#
# NOTE: <executed> must EXCLUDE skipped tests. Surefire's "Tests run: 4" counts
# the 3 it skipped, so reporting it raw lets an agent turn a red test green with
# @Disabled while the suite count still appears to grow. Verified on this repo:
# 4 tests, 3 @Disabled → "Tests run: 4, Failures: 0, Errors: 0, Skipped: 3".
parse_counts() {
  local line run fail err skip
  line=$(grep -Eo 'Tests run: [0-9]+, Failures: [0-9]+, Errors: [0-9]+(, Skipped: [0-9]+)?' "$LOG" | tail -1)
  [ -z "$line" ] && return 1
  run=$(sed -E 's/Tests run: ([0-9]+).*/\1/' <<<"$line")
  fail=$(sed -E 's/.*Failures: ([0-9]+).*/\1/' <<<"$line")
  err=$(sed -E 's/.*Errors: ([0-9]+).*/\1/' <<<"$line")
  skip=0
  [[ "$line" == *Skipped:* ]] && skip=$(sed -E 's/.*Skipped: ([0-9]+).*/\1/' <<<"$line")
  echo "$(( run - skip )) $(( fail + err )) $skip"
}

# Emit the failing assertions, one per line. This is fed verbatim to code-writer,
# so keep it terse and information-dense.
parse_failures() {
  grep -E '^\[ERROR\]   [A-Za-z]' "$LOG" | sed 's/^\[ERROR\]   //' | head -20
}

# Emit compiler diagnostics when the build will not compile.
parse_compile_errors() {
  grep -E '^\[ERROR\].*\.java' "$LOG" | head -15
}

# --- Recipes for other stacks ---------------------------------------------
# Override TEST_CMD via env, and replace the three parsers above. parse_counts
# must emit THREE fields — "<executed> <failed> <skipped>" — with skipped
# excluded from executed. Emit 0 for skipped if the runner cannot report it.
#
#   pytest    TEST_CMD="pytest -q"
#             counts   → the "N passed, M failed, K skipped" tail line
#             failures → grep -E '^(FAILED|E  )'
#             compile  → grep -E '^E  +(SyntaxError|IndentationError|ImportError)'
#             skipped  → "K skipped" / "K deselected"; also flag @pytest.mark.skip
#
#   jest      TEST_CMD="npx jest --ci"
#             counts   → "Tests:  N failed, M passed, K total"
#             failures → grep -E '^\s+●'
#             compile  → grep -E 'SyntaxError|Cannot find module'
#             skipped  → "K skipped" / "K todo"; total INCLUDES them, subtract
#
#   go        TEST_CMD="go test ./..."
#             counts   → count '^--- FAIL' and '^--- PASS' lines
#             failures → grep -E '^\s+--- FAIL'
#             compile  → grep -E '^[^ ]+\.go:[0-9]+:'
#             skipped  → count '^--- SKIP' lines
#
#   cargo     TEST_CMD="cargo test"
#             counts   → "test result: ok. N passed; M failed; K ignored"
#             failures → grep -E '^(test .* FAILED|thread .* panicked)'
#             compile  → grep -E '^error(\[E[0-9]+\])?:'
#             skipped  → the "K ignored" field
# ===========================================================================

now() { date -u +%Y-%m-%dT%H:%M:%SZ; }
prev_count() { grep -o '"testCount"[[:space:]]*:[[:space:]]*[0-9]*' "$STATE" | grep -o '[0-9]*$'; }

set_count() {
  local tmp; tmp=$(mktemp)
  sed "s/\"testCount\"[[:space:]]*:[[:space:]]*[0-9]*/\"testCount\": $1/" "$STATE" > "$tmp" && mv "$tmp" "$STATE"
}

run_tests() { $TEST_CMD > "$LOG" 2>&1; }
compile_failed() { grep -qE "$COMPILE_ERROR_RE" "$LOG"; }
fail() { echo "❌ GATE FAILED — $1"; echo "   full log: $LOG"; exit 1; }

case "${1:-}" in

  init)
    shift
    [ $# -eq 0 ] && { echo 'usage: tdd-gate.sh init "<slice 1>" "<slice 2>" ...'; exit 2; }
    { echo "{"
      echo "  \"goal\": \"${TDD_GOAL:-see spec.md}\","
      echo "  \"testCount\": 0,"
      echo "  \"slices\": ["
      i=0
      for t in "$@"; do
        i=$((i+1)); sep=","; [ "$i" -eq "$#" ] && sep=""
        echo "    { \"n\": $i, \"title\": \"$t\", \"done\": false }$sep"
      done
      echo "  ]"
      echo "}"
    } > "$STATE"
    echo "✅ initialised $STATE with $# slices"
    ;;

  reset)
    tmp=$(mktemp)
    sed -e 's/"done": true/"done": false/g' \
        -e 's/"testCount"[[:space:]]*:[[:space:]]*[0-9]*/"testCount": 0/' "$STATE" > "$tmp" && mv "$tmp" "$STATE"
    if grep -q '^## Execution Log' "$EVIDENCE" 2>/dev/null; then
      tmp=$(mktemp)
      awk '/^## Execution Log/{print; print ""; print "_Evidence will be appended here as the TDD Goal Loop runs._"; exit} {print}' "$EVIDENCE" > "$tmp" && mv "$tmp" "$EVIDENCE"
    fi
    echo "✅ reset — all slices pending, suite count 0, evidence log cleared"
    ;;

  red)
    expected="${2:-}"
    run_tests
    if compile_failed; then
      echo "--- compiler output ---"; parse_compile_errors
      fail "tests do not compile. A red test must fail on its assertion, not on syntax."
    fi
    counts=$(parse_counts) || fail "no test summary found — the suite did not run"
    read -r run bad skipped <<<"$counts"; skipped=${skipped:-0}
    [ "$bad" -eq 0 ] && fail "expected failing tests, got $run passing. The test does not exercise new behaviour."
    [ "$skipped" -ne 0 ] && [ -z "${TDD_ALLOW_SKIPPED:-}" ] && \
      fail "$skipped test(s) skipped. A skipped test proves nothing — remove @Disabled/@Ignore. (Set TDD_ALLOW_SKIPPED=1 if this project skips legitimately.)"

    excerpt=$(parse_failures)
    if [ -n "$expected" ] && ! grep -qF "$expected" <<<"$excerpt"; then
      echo "--- actual failures ---"; echo "$excerpt"
      fail "failing for the wrong reason. Expected to see: $expected"
    fi
    echo "✅ RED — $bad of $run tests fail, compile clean, failure reason matches"
    echo "$excerpt"
    ;;

  green)
    before=$(prev_count)
    run_tests
    if compile_failed; then
      echo "--- compiler output ---"; parse_compile_errors
      fail "production code does not compile"
    fi
    counts=$(parse_counts) || fail "no test summary found — the suite did not run"
    read -r run bad skipped <<<"$counts"; skipped=${skipped:-0}
    if [ "$bad" -ne 0 ]; then
      echo "--- still failing ---"; parse_failures
      fail "$bad of $run tests still failing"
    fi
    [ "$skipped" -ne 0 ] && [ -z "${TDD_ALLOW_SKIPPED:-}" ] && \
      fail "$skipped test(s) skipped. Disabling a test is not making it pass — remove @Disabled/@Ignore. (Set TDD_ALLOW_SKIPPED=1 if this project skips legitimately.)"
    [ "$run" -lt "${before:-0}" ] && fail "executed test count shrank ${before} → ${run}; tests were deleted"

    set_count "$run"
    echo "✅ GREEN — $run/$run executed pass, 0 failures, $skipped skipped (was ${before:-0}, +$(( run - ${before:-0} )) new)"
    ;;

  done)
    n="${2:?slice number required}"; files="${3:-}"
    run=$(prev_count)
    title=$(grep "\"n\": $n," "$STATE" | grep -o '"title": "[^"]*"' | head -1 | sed 's/"title": "//;s/"$//')
    tmp=$(mktemp)
    awk -v n="$n" '
      $0 ~ "\"n\": " n "," { inslice=1 }
      inslice && /"done": false/ { sub(/"done": false/, "\"done\": true"); inslice=0 }
      { print }' "$STATE" > "$tmp" && mv "$tmp" "$STATE"
    { echo ""
      echo "## Slice $n: $title"
      echo ""
      echo "- **Completed:** $(now)"
      echo "- **Gates:** RED ✅ → GREEN ✅ (asserted by \`lab/tdd-gate.sh\`, not inferred)"
      echo "- **Suite:** $run/$run passing"
      [ -n "$files" ] && echo "- **Files:** $files"
    } >> "$EVIDENCE"
    echo "✅ Slice $n recorded — suite at $run tests"
    ;;

  *) echo 'usage: tdd-gate.sh {init "<t1>" "<t2>"...|reset|red "<expected>"|green|done <n> "<files>"}'; exit 2 ;;
esac
