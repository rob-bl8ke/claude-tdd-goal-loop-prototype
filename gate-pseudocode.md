# The deterministic gate — language-agnostic specification

This is the **canonical definition** of the TDD gate and its self-test, written as
pseudocode so it can be reimplemented in any language. Two reference implementations ship
with this repo (`lab/tdd-gate.sh` and `lab/tdd_gate.py`); where they disagree with this
document, **this document is correct** — see §9.

If you are reading the code for the first time, start with
[how-the-gate-works.md](how-the-gate-works.md), which explains the *why*. This file is the
*what*, compressed enough to port from.

---

## 1. What the gate is for

An AI agent is asked to build a feature test-first. The obvious way to check it obeyed is
to ask it — which does not work: an earlier version of this project used verifier agents
for exactly that, and they reported five test names that did not exist. A model asked to
describe a test run will produce text that *looks* like a test run.

> **Judgement gets an agent. Facts get a script.**

Which tests a requirement needs is judgement. Whether a test actually failed is a fact.

**The exit code is the entire product.** Printed text is for humans. Every failure path
exits non-zero. There is deliberately no "warn and continue".

---

## 2. Data model

```
STATE = {
    goal:      string
    testCount: int      # executed tests at the last successful GREEN
    slices:    [ { n: int, title: string, done: bool } ]
}

COUNTS = {
    executed: int       # skipped tests EXCLUDED — see §4
    failed:   int       # assertion failures + errors, summed
    skipped:  int
}
```

Two files, deliberately separated:

| File | Audience | Rule |
|---|---|---|
| `state.json` | machines | Small, structured. Agents act on this. |
| `evidence.md` | humans | Narrative audit trail. **No agent ever reads it.** |

An earlier design kept run state in a growing markdown log that every agent re-read and
re-interpreted, at ~85k tokens per run. Keep them separate.

---

## 3. Configuration — the only stack-specific part

```
TEST_COMMAND        = "mvn -B clean test"
COMPILE_ERROR_MATCH = /COMPILATION ERROR|cannot find symbol/

STATE_FILE    = lab/state.json        # override: TDD_STATE
EVIDENCE_FILE = lab/evidence.md       # override: TDD_EVIDENCE
LOG_FILE      = <tmp>/tdd-gate-tests.log   # override: TDD_GATE_LOG
```

`clean` is load-bearing. Without it an incremental compile can report "Nothing to compile"
after a fresh edit because of filesystem timestamp granularity, and the gate would then
grade the **previous** build's output.

| Env var | Effect |
|---|---|
| `TDD_TEST_CMD` | Override the test command |
| `TDD_COMPILE_ERROR_RE` | Override the compile-failure pattern |
| `TDD_ALLOW_SKIPPED` | Tolerate skipped tests. Off by default. Leave it off. |
| `TDD_GOAL` | Goal string recorded by `init` |

---

## 4. Helpers

```
FUNCTION fail(message):                       # never returns
    PRINT "GATE FAILED — " + message
    PRINT "full log: " + LOG_FILE
    EXIT 1


FUNCTION run_tests() -> text:
    output = execute TEST_COMMAND via a shell, capturing stdout AND stderr
    write output to LOG_FILE
    RETURN output


FUNCTION parse_counts(log) -> COUNTS or NOTHING:
    matches = find ALL runner summary lines in log
    IF none:
        RETURN NOTHING          # "the suite did not run". NOT zero. NOT success.
    take the LAST match         # earlier lines are per-class; the last is the run total
    RETURN COUNTS {
        executed = reported_total - skipped,
        failed   = failures + errors,
        skipped  = skipped
    }


FUNCTION parse_failures(log) -> text:
    RETURN up to 20 failing-assertion lines, prefixes stripped
    # Fed VERBATIM to the code-writing agent. Keep terse.


FUNCTION parse_compile_errors(log) -> text:
    RETURN up to 15 compiler diagnostic lines
```

### The subtraction is the whole ballgame

Runners report a headline total that **includes** skipped tests:

```
Tests run: 4, Failures: 0, Errors: 0, Skipped: 3
```

Only one test executed. Report the headline raw and three `@Disabled` out of four reads as
a growing, all-green suite. This was a live bug in this repo for three full runs.

`parse_counts` returning `NOTHING` is likewise a **decision**, not an absence. The tempting
alternative — return zeros — means a build that died before running anything reads as "zero
failures", which is *green*.

---

## 5. Commands

### `init "<slice 1>" "<slice 2>" ...`

```
IF no titles: PRINT usage; EXIT 2
WRITE STATE_FILE {
    goal      = env TDD_GOAL, else "see SPEC.md",
    testCount = 0,
    slices    = one per title, numbered from 1, all done = false
}
```

### `reset`

```
state = READ STATE_FILE
state.testCount = 0
FOR each slice: slice.done = false
WRITE state

IF EVIDENCE_FILE exists:
    keep every line up to and including "## Execution Log"
    append a blank line and a placeholder
    discard the remainder
```

### `red "<expected-failure-substring>"`

Check order matters: each yields a **different diagnosis**, and the caller reacts
differently to each.

```
log = run_tests()

# 1. Broken is not the same as red.
IF log matches COMPILE_ERROR_MATCH:
    PRINT parse_compile_errors(log)
    fail("tests do not compile. A red test must fail on its assertion, not on syntax.")

# 2. Fail closed: nothing reported means we know nothing.
counts = parse_counts(log)
IF counts is NOTHING:
    fail("no test summary found — the suite did not run")

# 3. All-passing means the test does not exercise new behaviour.
IF counts.failed == 0:
    fail("expected failing tests, got <executed> passing")

# 4. A skipped test proves nothing.
IF counts.skipped > 0 AND NOT TDD_ALLOW_SKIPPED:
    fail("<n> test(s) skipped — remove @Disabled/@Ignore")

# 5. Failing is not enough. It must fail for the reason intended.
#    You expected 404 (no endpoint); you got 500 (null pointer). Both "fail".
#    Only one means what you think.
excerpt = parse_failures(log)
IF expected_substring given AND NOT contained in excerpt:
    PRINT excerpt
    fail("failing for the wrong reason. Expected to see: " + expected_substring)

PRINT "RED — <failed> of <executed> fail, compile clean, reason matches"
PRINT excerpt                      # this is the code-writer's input
EXIT 0
```

### `green`

Each guard blocks one way of satisfying "make the tests pass" **dishonestly**.

```
before = READ STATE_FILE.testCount
log    = run_tests()

IF log matches COMPILE_ERROR_MATCH:
    PRINT parse_compile_errors(log)
    fail("production code does not compile")

counts = parse_counts(log)
IF counts is NOTHING:
    fail("no test summary found — the suite did not run")

# Defence in depth. parse_counts should already have bailed, but a badly ported
# parser reporting success with zero tests would otherwise sail through slice 1,
# where there is no previous count to shrink from.
IF counts.executed == 0:
    fail("0 tests executed — green on an empty suite proves nothing")

IF counts.failed != 0:
    PRINT parse_failures(log)
    fail("<failed> of <executed> tests still failing")

# Disabling a failing test is not making it pass.
IF counts.skipped > 0 AND NOT TDD_ALLOW_SKIPPED:
    fail("<n> test(s) skipped — disabling a test is not making it pass")

# Deleting a failing test is not making it pass.
IF counts.executed < before:
    fail("executed count shrank <before> → <executed>; tests were deleted")

STATE_FILE.testCount = counts.executed     # new baseline for the next slice
PRINT "GREEN — <executed> pass, 0 failures, <skipped> skipped"
EXIT 0
```

### `done <n> "<files touched>"`

```
state = READ STATE_FILE
total = state.testCount

find the slice whose n matches:
    set done = true
    remember title
IF no such slice:
    fail("no slice numbered <n>")       # ← see §9: the shell version omits this

WRITE state

APPEND to EVIDENCE_FILE:
    "## Slice <n>: <title>"
    "- Completed: <UTC ISO-8601 timestamp>"
    "- Gates: RED → GREEN (asserted by the gate, not inferred)"
    "- Suite: <total>/<total> passing"
    "- Files: <files>"                  (omit the line if none given)
```

### Exit-code contract

| Code | Meaning |
|---|---|
| 0 | Gate passed |
| 1 | Gate failed — stop the loop, get a human |
| 2 | Called with bad arguments |

---

## 6. The self-test

The gate's value rests entirely on `parse_counts`. A parser that is subtly wrong produces
**confident false green** — worse than no gate, because the audit trail still reads like
verification. So the checker gets its own checker.

### The trick

```
# The gate runs whatever TEST_COMMAND holds, through a shell. So a fake test run is:
TEST_COMMAND = "cat some-fixture.log"
```

The gate cannot tell the difference. This is what lets you test states you cannot produce
on demand — "the build died before printing a summary".

### Fixture contract

Capture each ONCE from a real run of your own test command. **Do not hand-write them** —
you would encode your assumption instead of your runner's behaviour, which is precisely the
mistake that caused the skipped-test bug.

| Fixture | Must represent |
|---|---|
| `red.log` | 1 test, 1 failing, 0 skipped; failure text names a known method |
| `green1.log` | 1 test, 0 failing, 0 skipped |
| `green4.log` | 4 tests, 0 failing, 0 skipped |
| `shrank.log` | 2 tests, 0 failing, 0 skipped |
| `skipped.log` | 4 reported, only 1 executed, 3 skipped |
| `grewskips.log` | 5 reported, only 2 executed, 3 skipped — suite **grows** while hiding skips |
| `compile.log` | a compile/syntax error, no summary printed |
| `nosummary.log` | died before any summary |

### Harness

```
sandbox = throwaway temp directory        # NEVER touch the real state.json
copy the gate into sandbox
write a placeholder evidence file containing "## Execution Log"

FUNCTION gate(fixture, args...) -> exit_code:
    TEST_COMMAND = "cat <fixtures>/<fixture>.log"
    LOG_FILE     = sandbox/tests.log
    clear TDD_ALLOW_SKIPPED unless this call opts in
    RUN the sandboxed gate; RETURN exit code

check(label, expected_exit, actual_exit)
check_count(label, expected)      # assert persisted testCount
check_said(label, needle)         # assert the MESSAGE, not just the code
```

### Checks

```
INIT
    init exits 0
    state parses; testCount 0; slices numbered 1..n; all done = false

RED
    real failure, marker matches            -> 0
    real failure, marker does NOT match     -> 1
    everything passing                      -> 1
    compile error                           -> 1
    no summary                              -> 1
    no marker given, real failure           -> 0
    no marker given, everything passing     -> 1     [note A]
    a skipped test present                  -> 1
    compile-error MESSAGE says "do not compile", not "no summary"   [note B]

GREEN
    all passing                             -> 0   then testCount == 1
    failures remain                         -> 1
    compile error                           -> 1
    no summary                              -> 1
    suite grew 1 -> 4                       -> 0   then testCount == 4
    suite SHRANK 4 -> 2                     -> 1   then testCount STILL 4
    3 of 4 skipped                          -> 1   then testCount STILL 4
    grew 1 -> 2 but 3 skipped               -> 1     [note C]

DONE
    exits 0; marks slice 1; leaves slice 2 pending; evidence heading clean
    unknown slice number                    -> 1     [not yet in either harness — §9]

RESET
    testCount 0; every slice pending; evidence log cleared

FAIL-CLOSED ON A FRESH STATE                         [note D]
    green, no summary,    fresh state       -> 1
    green, compile error, fresh state       -> 1
    red,   no summary,    fresh state       -> 1

ESCAPE HATCH
    TDD_ALLOW_SKIPPED set, skipped suite    -> 0
    but testCount records EXECUTED only, not the reported total

IF any drift: PRINT "do NOT trust the gate"; EXIT 1
ELSE EXIT 0
```

Both shipped implementations run 35 checks (the `done` unknown-slice case is specified
above but not yet implemented in either harness).

### Why four of those checks exist

Each was added **only** after a deliberately broken gate slipped past without it.

- **A** — Dropping red's "must have a failure" check is invisible while a marker is
  supplied, because the marker check catches it anyway. Omit the marker and an all-green
  suite gets certified RED.
- **B** — Disabling the compile check is invisible if you assert only exit codes: a compile
  failure also produces no summary, so the gate still fails — with the wrong diagnosis. The
  caller's recovery differs, so assert the message too.
- **C** — Removing green's skip guard is masked by the shrink guard in the obvious case.
  Only a suite that **grows while hiding skips** isolates it.
- **D** — On slice 1 there is no earlier count, so the shrink guard cannot help. A parser
  wrongly returning "0 executed, 0 failed, success" survives every other check.

---

## 7. Validating a port: the mutation set

**This is the part to run after any parser change.** Break the gate in each way below and
confirm the self-test fails. A self-test that cannot fail is false confidence with a green
tick.

| # | Mutation | Killed by |
|---|---|---|
| A | `parse_counts` does not subtract skipped | *still records EXECUTED only, not reported total* |
| B | Remove green's skip guard | *grew 1 → 2 but 3 SKIPPED* |
| C | Remove green's shrink guard | *suite SHRANK 4 → 2* (+2 more) |
| D | `parse_counts` returns zeros instead of NOTHING | **survives — equivalent**, see below |
| D2 | As D, **and** remove the empty-suite guard | *green, no summary, fresh state* |
| E | `red` ignores the expected marker | *failing for WRONG reason* |
| F | `red` no longer requires a failure | *no marker given, all passing* |
| G | Disable the compile check | *compile failure named as such* |
| H | `done` marks every slice, not just slice n | *leaves slice 2 pending* |

**D survives legitimately.** The empty-suite guard in `green` catches the zero case
regardless of what `parse_counts` returns, so the mutation produces no observable
difference. That is an *equivalent mutant*, not a coverage gap — D2 exists to prove the
guard is what saves it.

Two cautions learned the hard way:

1. **Mutate cleanly.** A first attempt at H removed a loop's `break`, which also tripped
   the language's `for/else` and made the gate fail for an unrelated reason. It was
   "caught", but not by the check that should catch it. Re-run any mutant that fails with
   the wrong message.
2. **A mutant caught incidentally proves nothing** about the check you care about.

---

## 8. Implementation checklist for a new language

1. Implement §4 helpers. `parse_counts` **must** subtract skipped and **must** be able to
   return NOTHING.
2. Implement §5 commands, preserving check order and the exit-code contract.
3. Capture the eight §6 fixtures from real runs of your test command.
4. Implement the §6 harness and checks.
5. Confirm the self-test passes.
6. **Run the §7 mutation set.** Every mutant except D must be caught.
7. Smoke test: on a repo with no tests at all, `red` must exit 1.

Step 6 is the one people skip. It is the one that matters.

---

## 9. Known deviations in the shipped implementations

| Behaviour | `tdd_gate.py` | `tdd-gate.sh` | Spec says |
|---|---|---|---|
| `done` with an unknown slice number | exits 1 | **exits 0**, appends a blank-titled entry | 1 |
| `done` with no slice number at all | exits 2 | exits 1 (bash `${2:?}` semantics) | 2 |
| `init` default goal string | `see SPEC.md` | `see spec.md` | `see SPEC.md` |

Verified by running both, not by reading:

```
arg-error exit codes:      shell   python
  []                         2        2
  [bogus]                    2        2
  [init]                     2        2
  [done]                     1        2      ← diverges
```

The `done` divergence is the one that matters, and it is the only place the gate can write
something **false** into the evidence trail rather than merely failing to catch something.
Everything else fails closed; this fails open into the audit log. Observed:

```
$ ./lab/tdd-gate.sh done 99 "x.java"
✅ Slice 99 recorded — suite at 0 tests          # exit 0

## Slice 99:
- **Completed:** 2026-08-25T11:21:40Z
- **Gates:** RED ✅ → GREEN ✅ (asserted by `lab/tdd-gate.sh`, not inferred)
```

A fabricated slice, a blank title, and a line claiming the gates asserted it. The shell's
`awk` marks nothing, so state and evidence silently disagree.

Neither self-test covers this, which is why both score 35/35 while disagreeing. It was found
by reading the two implementations side by side, not by either harness — a reminder that
**an untested guard is decoration**, in both directions.

To close it: make the shell `done` fail when no slice matches, and add the
`done <unknown> -> 1` check to both harnesses (36 checks).
