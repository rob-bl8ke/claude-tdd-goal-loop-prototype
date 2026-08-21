#!/usr/bin/env bash
# tdd-gate.sh — deterministic TDD phase gate.
#
# Replaces the red-verifier, green-verifier and slice-verifier agents. Running
# `mvn test` and comparing counts is a shell command and a regex, not a
# judgement call — and unlike an LLM this cannot invent test names it did not
# see. Costs ~500 tokens per gate instead of ~30k.
#
# Usage:
#   tdd-gate.sh red   "<expected-failure-substring>"  assert new tests fail for the right reason
#   tdd-gate.sh green                                 assert every test passes, count did not shrink
#   tdd-gate.sh done  <slice-n> "<files>"             mark slice complete, append evidence
#   tdd-gate.sh reset                                 start a fresh run (clears state + evidence)
#
# Exit 0 = gate passed. Exit 1 = gate failed; stop the loop for a human.

set -uo pipefail
cd "$(dirname "$0")/.."

STATE=lab/state.json
EVIDENCE=lab/evidence.md
LOG="${TDD_GATE_LOG:-${TMPDIR:-/tmp}/tdd-gate-mvn.log}"

now() { date -u +%Y-%m-%dT%H:%M:%SZ; }
prev_count() { grep -o '"testCount"[[:space:]]*:[[:space:]]*[0-9]*' "$STATE" | grep -o '[0-9]*$'; }

set_count() {
  local n=$1 tmp
  tmp=$(mktemp)
  sed "s/\"testCount\"[[:space:]]*:[[:space:]]*[0-9]*/\"testCount\": $n/" "$STATE" > "$tmp" && mv "$tmp" "$STATE"
}

# Run the suite. Never fatal — a non-zero exit is the expected case in the red phase.
run_tests() {
  mvn -B test > "$LOG" 2>&1
  echo $? > "$LOG.exit"
}

# Last matching line is surefire's aggregate summary (earlier ones are per-class).
summary_line() {
  grep -Eo 'Tests run: [0-9]+, Failures: [0-9]+, Errors: [0-9]+, Skipped: [0-9]+' "$LOG" | tail -1
}
field() { summary_line | grep -Eo "$1: [0-9]+" | grep -Eo '[0-9]+'; }

# The assertion messages, which are exactly what code-writer needs as input.
failure_excerpt() {
  grep -E '^\[ERROR\]   [A-Za-z]' "$LOG" | sed 's/^\[ERROR\]   //' | head -20
}

compile_failed() { grep -qE 'COMPILATION ERROR|cannot find symbol|BUILD FAILURE.*compile' "$LOG"; }

fail() { echo "❌ GATE FAILED — $1"; echo "   full log: $LOG"; exit 1; }

case "${1:-}" in

  red)
    expected="${2:-}"
    run_tests
    if compile_failed; then
      echo "--- compiler output ---"
      grep -E '^\[ERROR\].*\.java' "$LOG" | head -15
      fail "tests do not compile. A red test must fail on its assertion, not on syntax."
    fi
    run=$(field 'Tests run'); failures=$(field 'Failures'); errors=$(field 'Errors')
    [ -z "${run:-}" ] && fail "no test summary found — surefire did not run"
    total_bad=$(( ${failures:-0} + ${errors:-0} ))
    [ "$total_bad" -eq 0 ] && fail "expected failing tests, got $run passing. Test does not exercise new behaviour."

    excerpt=$(failure_excerpt)
    if [ -n "$expected" ] && ! grep -qF "$expected" <<<"$excerpt"; then
      echo "--- actual failures ---"; echo "$excerpt"
      fail "failing for the wrong reason. Expected to see: $expected"
    fi

    echo "✅ RED — $total_bad of $run tests fail, compile clean, failure reason matches"
    echo "$excerpt"
    ;;

  green)
    before=$(prev_count)
    run_tests
    if compile_failed; then
      echo "--- compiler output ---"
      grep -E '^\[ERROR\].*\.java' "$LOG" | head -15
      fail "production code does not compile"
    fi
    run=$(field 'Tests run'); failures=$(field 'Failures'); errors=$(field 'Errors')
    [ -z "${run:-}" ] && fail "no test summary found — surefire did not run"
    total_bad=$(( ${failures:-0} + ${errors:-0} ))
    if [ "$total_bad" -ne 0 ]; then
      echo "--- still failing ---"; failure_excerpt
      fail "$total_bad of $run tests still failing"
    fi
    [ "$run" -lt "${before:-0}" ] && fail "test count shrank ${before} → ${run}; tests were deleted or silently skipped"

    set_count "$run"
    echo "✅ GREEN — $run/$run pass, 0 failures, 0 errors (was ${before:-0}, +$(( run - ${before:-0} )) new)"
    ;;

  done)
    n="${2:?slice number required}"; files="${3:-}"
    run=$(prev_count)
    title=$(grep "\"n\": $n," "$STATE" | grep -o '"title": "[^"]*"' | head -1 | sed 's/"title": "//;s/"$//')
    tmp=$(mktemp)
    # Mark this slice done without disturbing the others.
    awk -v n="$n" '
      $0 ~ "\"n\": " n "," { inslice=1 }
      inslice && /"done": false/ { sub(/"done": false/, "\"done\": true"); inslice=0 }
      { print }' "$STATE" > "$tmp" && mv "$tmp" "$STATE"
    {
      echo ""
      echo "## Slice $n: $title"
      echo ""
      echo "- **Completed:** $(now)"
      echo "- **Gates:** RED ✅ → GREEN ✅ (both asserted by \`lab/tdd-gate.sh\`, not inferred)"
      echo "- **Suite:** $run/$run passing"
      [ -n "$files" ] && echo "- **Files:** $files"
    } >> "$EVIDENCE"
    echo "✅ Slice $n recorded — suite at $run tests"
    ;;

  reset)
    # Start a fresh run: all slices pending, suite count zero, evidence log truncated
    # back to its template. Idempotent and git-independent.
    tmp=$(mktemp)
    sed -e 's/"done": true/"done": false/g' \
        -e 's/"testCount"[[:space:]]*:[[:space:]]*[0-9]*/"testCount": 0/' "$STATE" > "$tmp" && mv "$tmp" "$STATE"
    if grep -q '^## Execution Log' "$EVIDENCE"; then
      tmp=$(mktemp)
      awk '/^## Execution Log/{print; print ""; print "_Evidence will be appended here as the TDD Goal Loop runs._"; exit} {print}' "$EVIDENCE" > "$tmp" && mv "$tmp" "$EVIDENCE"
    fi
    echo "✅ reset — all slices pending, suite count 0, evidence log cleared"
    ;;

  *) echo "usage: tdd-gate.sh {reset|red \"<expected>\"|green|done <n> \"<files>\"}"; exit 2 ;;
esac
