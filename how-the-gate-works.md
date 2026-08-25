# How the gate works

A walkthrough for someone new to this repo. No prior context needed.

There are two files to understand, and one is the test suite for the other:

| File | Job |
|---|---|
| `lab/tdd_gate.py` | Decides whether the code is in a valid TDD state. Answers with an exit code. |
| `lab/gate_selftest.py` | Checks that the first file's decisions are actually correct. |

Shell versions (`tdd-gate.sh`, `gate-selftest.sh`) exist too — same commands, same exit
codes, with one known divergence documented in [gate-pseudocode.md §9](gate-pseudocode.md).
Read whichever language you prefer; this document explains the Python.

This file explains the *why*. For the compressed *what* — a language-agnostic spec you can
port from, plus the mutation set for validating a port — see
[gate-pseudocode.md](gate-pseudocode.md).

---

## 1. The problem it solves

We're asking an AI agent to build a feature **test-first**: write a failing test, then
write just enough code to pass it. The obvious way to check it obeyed is to ask it:

> "Did the test fail before you wrote the code?"

That doesn't work. An earlier version of this project did exactly that, with dedicated
"verifier" agents whose job was to run the tests and report back. They **invented five
test names that did not exist**. Not maliciously — a language model asked to describe a
test run will produce text that *looks* like a test run, and it has no strong incentive
to distinguish remembering from imagining.

So the rule this repo settled on:

> **Judgement gets an agent. Facts get a script.**

Deciding *which* tests a requirement needs is judgement — an agent does that well.
Checking *whether a test actually failed* is a fact. Facts get a script, because a script
can only report substrings it genuinely found in real output.

---

## 2. What "red" and "green" mean

The TDD cycle for one requirement:

```
RED    write a test. Run the suite. It must FAIL — proving the test
       exercises behaviour that doesn't exist yet.
GREEN  write the minimum code. Run the suite. It must PASS — and the
       tests you already had must still pass.
```

The gate has one command per phase. Each **exits 0 if the phase is genuinely satisfied,
and 1 if not.** That exit code is the entire product. Everything printed is for humans.

Why does RED matter so much? Because a test written *after* the code tends to describe
the code rather than the requirement. If you never watch a test fail, you don't actually
know it can.

---

## 3. The five commands

### `init` — set up a run

```bash
TDD_GOAL="Basket Quote API" ./lab/tdd_gate.py init "Sum item totals" "Reject empty baskets"
```

Writes `lab/state.json`:

```json
{
  "goal": "Basket Quote API",
  "testCount": 0,
  "slices": [
    { "n": 1, "title": "Sum item totals", "done": false },
    { "n": 2, "title": "Reject empty baskets", "done": false }
  ]
}
```

A **slice** is one requirement — one acceptance criterion, built end to end. `testCount`
is how many tests were passing at the last successful GREEN. That number is what makes
"the suite shrank" detectable later.

This file is small and machine-readable *on purpose*. An earlier design kept run state in
a growing markdown document that every agent re-read and re-interpreted, at about 85k
tokens per run. Facts belong in JSON.

### `red` — assert the suite is failing, for the right reason

```bash
./lab/tdd_gate.py red "Status expected:<200> but was:<404>"
```

It runs the tests, then checks four things in order. Order matters — each produces a
different diagnosis:

| Check | Why it exists |
|---|---|
| Does it compile? | A test that fails because of a typo isn't red, it's broken. Different fix. |
| Did a summary appear at all? | If the runner died before running anything, we know nothing. Fail closed. |
| Did at least one test fail? | If everything passes, the test doesn't exercise new behaviour. |
| Is anything skipped? | A skipped test proves nothing. (See §5 — this one was a real bug.) |
| Does the failure text contain your expected substring? | Guards against failing for an *unrelated* reason. |

That last one is the subtle one. Suppose you expected a 404 (no endpoint yet) but actually
got a 500 (null pointer). Both are "failing". Only one means what you think. So the caller
declares the expected reason up front, and the gate holds it to that.

On success it prints the failure excerpt — which is exactly what the code-writing agent
needs as input:

```
✅ RED — 3 of 3 tests fail, compile clean, failure reason matches
BasketQuoteControllerTest.shouldReturnSubtotal:49 Status expected:<200> but was:<404>
```

### `green` — assert it passes, and didn't cheat

```bash
./lab/tdd_gate.py green
```

Same idea, opposite direction, with guards against the ways "make the tests pass" can be
satisfied dishonestly:

| Check | The cheat it blocks |
|---|---|
| Compiles | — |
| Summary present | Runner died; we know nothing |
| **Executed count > 0** | A green run with zero tests is vacuous |
| Zero failures | The actual requirement |
| **Zero skipped** | Disabling a failing test is not making it pass |
| **Count didn't shrink** | Deleting a failing test is not making it pass |

On success it updates `testCount` in the state file, so the next slice has a baseline to
compare against.

### `done` — record the slice

```bash
./lab/tdd_gate.py done 1 "BasketQuoteService.java, BasketQuoteController.java"
```

Marks slice 1 `done: true` and appends an entry to `lab/evidence.md`, a human-readable
audit trail. **No agent ever reads `evidence.md`** — that's deliberate. It's for you.
State that agents act on lives in `state.json`; narrative for humans lives in evidence.
Mixing the two is what made the old design expensive.

### `reset` — start over

Sets every slice back to `done: false`, zeroes `testCount`, and truncates the evidence log.

---

## 4. The heart of it: reading test output

Everything above depends on three small functions that turn a wall of Maven output into
facts. This is where all the risk lives.

```python
_SUMMARY_RE = re.compile(
    r"Tests run: (\d+), Failures: (\d+), Errors: (\d+)(?:, Skipped: (\d+))?"
)
```

Maven prints a line like:

```
[INFO] Tests run: 12, Failures: 0, Errors: 0, Skipped: 0
```

`parse_counts` finds every such line and **takes the last one**, because earlier ones are
per-test-class and the final one is the run total. It returns a small object:

```python
@dataclass(frozen=True)
class TestCounts:
    executed: int   # skipped tests EXCLUDED — see below
    failed: int     # failures + errors, which are different things to Maven
    skipped: int
```

Two details worth internalising:

**Returning `None` is a decision, not an absence.** If no summary line exists, the function
returns `None`, and both gates treat that as a hard failure — "the suite did not run". The
tempting alternative (return zeros) would mean a build that died before running anything
reads as "zero failures", which is *green*. Failing closed is the whole game.

**`failed` combines failures and errors.** Maven distinguishes an assertion failing from an
exception being thrown. For our purposes both mean "not green", so they're summed.

The other two parsers just pull out human-readable lines: `parse_failures` for the failing
assertions (fed to the code-writing agent verbatim), and `parse_compile_errors` for
compiler diagnostics.

---

## 5. A worked example of why this is subtle

The gate had a bug that survived three full runs and several careful readings.

`green` claimed to catch "tests deleted or silently skipped". It caught deleted. It did
**not** catch skipped. Here's why — this is real Maven output from a class with 4 tests
where 3 are annotated `@Disabled`:

```
[WARNING] Tests run: 4, Failures: 0, Errors: 0, Skipped: 3
```

Read that headline number carefully. **`Tests run: 4` includes the 3 that were skipped.**
Only one test actually executed. The old parser reported `run=4, failed=0` — so the gate
said green, and recorded a suite of 4 tests.

Now picture the failure mode. An agent hits a test it can't make pass, adds `@Disabled`,
and the gate reports a *growing, all-green suite*. Nothing in the audit trail looks wrong.

The fix is the subtraction in `parse_counts`:

```python
executed=int(run) - skipped_n
```

plus an explicit guard in both gates that refuses any non-zero skip count. There's an
escape hatch, `TDD_ALLOW_SKIPPED=1`, for projects that skip legitimately (platform-specific
tests, say) — but it is off by default, because the agent that would break the rule is the
one not reading the policy that forbids it.

**The general lesson:** once you replace AI verification with a script, *all* your risk
moves into that script. A parser that's subtly wrong produces confident false green, which
is worse than having no gate at all — because the evidence trail still reads like
verification.

---

## 6. Why the checker has its own test suite

That's the reason `gate_selftest.py` exists. It runs 35 checks, driving every command
through both its success path and each of its failure paths.

The clever bit is how it fakes a test run. The gate runs whatever `TDD_TEST_CMD` contains,
through a shell. So the self-test sets:

```python
env["TDD_TEST_CMD"] = f"cat {fixture}.log"
```

Now "running the tests" just prints a canned file. The gate can't tell the difference — it
runs a command and parses the output, exactly as in real life. That lets us test situations
you can't easily produce on demand, like "the build died before printing a summary."

The fixtures live in `lab/selftest-fixtures/maven/` and are **captured from real runs**,
never hand-written. If you hand-write them you encode your *assumption* about your runner's
output — and the skipped-test bug was exactly a wrong assumption.

Each check asserts an exit code:

```python
r.check("everything passing -> 1", 1, r.gate_run("green1", "red", "anything"))
#        what we're testing        ^  ^ expected exit    ^ actual run
```

Read that as: "when `red` is given a suite where everything passes, it must exit 1."

Everything runs in a throwaway temp directory, so the self-test never touches your real
`state.json` or `evidence.md`.

### Testing the tester

A test suite that can't fail is worse than none — it's false confidence with a green tick.
So the self-test was validated by **mutation testing**: deliberately break the gate in a
specific way, and confirm the self-test notices.

Eight broken gates were tried. All eight were caught. Two of the 35 checks exist *only*
because a broken gate slipped past without them:

- Removing `red`'s "must have a failure" check was invisible, because the
  expected-substring check masked it — but only when a substring was supplied. Omit it and
  an all-green suite would be certified RED.
- Disabling the compile check was invisible while only the exit code was asserted, because
  a compile failure also produces no summary, so the gate still failed — just with the
  wrong diagnosis. There's now a check on the *message*, not only the code.

If you add a check to the self-test, break the corresponding guard and confirm it fails.
An untested check is decoration.

---

## 7. Running it

```bash
./lab/gate_selftest.py
```

Must print `0 drift`. Run it before trusting the gate, and after any change to a parser.

There's a second, cruder check worth knowing about — on a repo with **no tests at all**,
`red` must still exit 1:

```bash
./lab/tdd_gate.py red "anything"; echo "exit=$?"
```

If that exits 0, `parse_counts` is wrong and every gate will silently pass.

---

## 8. Porting to another language

Only two things are stack-specific:

1. **`TEST_CMD`** — your test command. Default is `mvn -B clean test`. The `clean` is
   deliberate: without it, an incremental compile can report "Nothing to compile" after a
   fresh edit because of filesystem timestamp granularity, and the gate would grade the
   *previous* build's output.
2. **The three parsers.** Recipes for pytest, jest, go and cargo are in comments right
   below the configuration block.

Then capture eight fixtures from real runs of your test command and run the self-test.
The contract for each fixture is at the top of `gate_selftest.py`.

Watch for the skipped-test trap in your own runner — jest's `total` includes skipped and
todo tests, and cargo reports `ignored` separately. Whatever the format, `executed` must
come out with skips already subtracted.

---

## 9. Cheat sheet

```bash
# set up
TDD_GOAL="what this delivers" ./lab/tdd_gate.py init "slice 1" "slice 2"

# prove the gate works before trusting it
./lab/gate_selftest.py

# per slice
./lab/tdd_gate.py red "expected failure substring"   # must exit 0
./lab/tdd_gate.py green                              # must exit 0
./lab/tdd_gate.py done 1 "files, you, touched"

# start over
./lab/tdd_gate.py reset
```

| Env var | Purpose |
|---|---|
| `TDD_TEST_CMD` | Override the test command |
| `TDD_GATE_LOG` | Where raw test output is written |
| `TDD_STATE` / `TDD_EVIDENCE` | Relocate the state and evidence files |
| `TDD_ALLOW_SKIPPED` | Tolerate skipped tests (off by default, and you should leave it off) |
| `TDD_GOAL` | Goal string recorded by `init` |
| `TDD_SELFTEST_FIXTURES` | Point the self-test at another stack's fixtures |

**Exit codes:** `0` gate passed · `1` gate failed, stop and get a human · `2` you called it
with bad arguments.
