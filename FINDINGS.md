# What this experiment found

A self-contained write-up. No prior context needed.

If you read nothing else: **deleting agents that did deterministic work saved 57% of the
tokens and made the results more trustworthy. Keeping agents for context isolation cost 4×
and bought nothing measurable.** The reusable artifact is the deterministic gate, not the
agent architecture.

> **Continuing this work elsewhere?** [`docs/gate-pseudocode.md`](docs/gate-pseudocode.md)
> is the canonical, language-agnostic specification of the gate and its self-test —
> including the mutation set you must re-run after touching a parser. It is self-contained;
> you can reimplement the whole deterministic part from it without this repo.

---

## 1. The setup

This repo prototypes **test-driven development driven by AI agents**.

The task under test is deliberately small and disposable: a `POST /api/basket/quote`
endpoint with three acceptance criteria — sum the basket items, reject empty baskets, reject
items with non-positive quantity or price. Java 21, Spring Boot, JUnit + MockMvc. The full
requirement is in [`SPEC.md`](SPEC.md).

The API is scaffolding and is **not** committed. The deliverable is the process: a
repeatable, portable way to make an agent build something test-first, where "test-first" is
actually *enforced* rather than merely requested.

---

## 2. First question — why was the naive approach so expensive?

The original design modelled every step of TDD as its own specialised agent: a coordinator,
a slice planner, a test writer, a red verifier, a code writer, a green verifier, a slice
verifier, and a goal evaluator. Eight agents.

One full run cost **713,000 tokens**:

| Layer | Tokens |
|---|---|
| Coordinator + slice planner | 142k |
| Verification (red/green/slice/goal verifiers) | 354k |
| Actually writing tests and production code | 217k |

**Roughly 70% of the spend produced neither a test nor a line of code.** It was agents
managing the workflow and describing it to one another.

It was also unreliable. The verifier agents reported five test names that did not exist, and
cited file paths that did not exist. Asking a language model to run a test command and report
what happened invites it to narrate a plausible outcome instead of reading one.

### The fix

The diagnosis reduces to a single rule:

> **Judgement gets an agent. Facts get a script.**

Confirming that a test failed, that it failed for the stated reason, and that the suite did
not shrink is not judgement — it is a test command and a regex.

So four agents were deleted and replaced by [`lab/tdd-gate.sh`](lab/tdd-gate.sh), a ~180-line
shell script with the commands `init`, `reset`, `red`, `green`, `done`. The coordinator went
too: a subagent cannot loop (it stops at the end of every turn), so driving the loop from one
costs a full context round-trip per step and buys no autonomy. Orchestration moved into the
main context, where selecting the next slice is `slices.find(s => !s.done)` — a file read, not
an agent call.

That left three agents — test-writer, code-writer, and one adversarial evaluator at the very
end — plus the gate.

| | 8 agents | 3 agents + gate |
|---|---|---|
| whole run | 713k | **~310k** |
| verification + orchestration | 496k | ~2k |
| hallucinated test names | 5 | 0 |
| real gaps found | 0 | 3 |

Cheaper *and* more trustworthy. A script cannot invent a test name it never saw, and it exits
non-zero loudly instead of producing a confident paragraph.

### What did not work

Recorded so it is not retried — details in [`docs/reuse.md`](docs/reuse.md):

- **Prompt-engineering the productive agents.** Their cost is dominated by their own system
  prompt and reading existing code. Inlining context made them ~11% *more* expensive, not
  less. It did improve scope discipline.
- **Running the goal evaluator per slice.** Mid-loop it only restates what the state file
  already knows, at ~35k a call.
- **Prose as a state machine.** The original design kept run state in a growing markdown log
  that every agent re-read and re-interpreted, at ~85k per run. State belongs in a small
  `state.json`; narrative belongs in an evidence log that no agent reads.

---

## 3. An interlude that changed how to read all of the above

Auditing the gate *behaviourally* — driving every command through both its pass and fail
paths, rather than reading the script — surfaced a bug that had been live through all three
measured runs.

The `green` gate claimed to catch "tests deleted or silently skipped." It caught deleted. It
did not catch skipped, because Maven's headline count **includes** skipped tests:

```
Tests run: 4, Failures: 0, Errors: 0, Skipped: 3
```

The gate read that as four passing tests. An agent that hit a stubborn failing test and
reached for `@Disabled` would have produced a green gate and a *growing* test count, entirely
invisible in the audit trail. A policy file already forbade `@Disabled` — but policy is not
enforcement, and the agent that breaks a rule is the one not reading it.

The lesson generalises well past this one bug:

> Once you delete the LLM verifiers, **all your risk concentrates in the deterministic
> component.** A parser that is subtly wrong produces confident false green, which is worse
> than having no gate at all, because the evidence trail still reads like verification.

So the gate now has its own test suite — [`lab/gate-selftest.sh`](lab/gate-selftest.sh), 35
checks in a throwaway sandbox — and that suite was itself mutation-tested against eight
deliberately broken gates to prove it could fail. Two of its checks exist *only* because a
broken gate survived without them.

Run it before trusting the gate, and after any change to its parsers:

```bash
./lab/gate-selftest.sh
```

---

## 4. Second question — does the remaining architecture buy anything?

After the cuts, the only surviving justification for using multiple agents was **context
isolation**: a test author that cannot see the implementation should write tests describing
the *requirement*, rather than tests that bless whatever the implementer happened to produce.

That claim had never been tested. All three runs used isolation. There was no control.

### Method

Two arms, same spec, same gate, one variable:

| | Arm A — isolated | Arm B — single loop |
|---|---|---|
| agents | 2 fresh subagents per criterion (6 total) | 1 agent for everything |
| test author sees the implementation? | no — forbidden from reading `src/main/` | yes, it wrote it |
| RED / GREEN | `lab/tdd-gate.sh` | `lab/tdd-gate.sh`, run by the agent itself |

Arm B is the conventional lightweight shape: choose a behaviour, write a test, confirm red,
implement, confirm green, repeat.

Both suites were scored by **mutation testing** — break the implementation in a specific way
and check that some test fails. A suite that stays green against a broken implementation is
not testing that behaviour.

Two safeguards did the real work:

1. **The 17 mutants were written and committed before either arm ran** (commit `5bfcb88`,
   which precedes the results commit), so they could not be tuned to favour whichever suite
   was seen first.
2. **Neither arm had its test cases dictated by the driver.** The playbook normally has the
   driver enumerate them — but if the driver picks the cases, isolation cannot possibly
   matter, because the driver is making the exact design decisions isolation is meant to
   protect. Both arms chose their own.

### Results

| | Arm A (isolated) | Arm B (single loop) |
|---|---|---|
| pre-registered mutants killed | **15 / 16** | **15 / 16** |
| tests written | 11 | 6 |
| subagent tokens (measured) | **236,219** | **60,125** |
| agents | 6 | 1 |
| gate calls made by the driver | 7 | 0 |

Every mutant either died against both suites or survived both. **Arm A wrote 83% more tests
to reach an identical score, at 3.9× the cost** — and the true gap is wider, because Arm A
also consumed six prompt constructions and seven gate invocations in the driver's context,
while Arm B needed one prompt and none.

Three details matter:

- **One mutant survived both arms**: deleting `@Service`. Neither arm wrote a test that boots
  the real application, so both suites stay fully green while the app fails to start. That is
  a property of slice-only test suites, not of either architecture. A one-line
  `@SpringBootTest contextLoads()` test closes it.
- **One mutant favoured Arm A, and it is weak evidence.** Arm B lacked a "later item" test
  for the price rule. But that mutant was added *after* seeing Arm B's tests — precisely what
  pre-registration exists to prevent. Suggestive, not confirmatory.
- **One difference the mutants did not score.** Arm A's blind test author asked how "zero
  items" could arrive over the wire and tested a missing `items` field, so Arm A handles it.
  Arm B noticed the same case, judged it out of scope, and left it — so `{"items": null}`
  returns 500 against Arm B and 400 against Arm A. That is a scope-interpretation
  difference, not confirmation bias.

Full detail, including the mutant table and the scoring rule, is in
[`docs/experiment-isolation.md`](docs/experiment-isolation.md). Both test suites, both
implementations, the mutation harness and the complete run log are in
[`docs/experiment-artifacts/`](docs/experiment-artifacts/), so none of this has to be taken
on trust.

---

## 5. Conclusions

**Solid.** Deleting agents that did deterministic work was a large, real win: 713k → ~310k,
with fewer hallucinations and more genuine defects found. Reproduced across two runs.

**Not supported.** Keeping agents for context isolation. On a well-specified feature it cost
4× and bought nothing measurable. On this evidence the default should be the single loop,
with isolation treated as an escalation rather than an architecture.

**The durable artifacts are the mechanical ones.** `tdd-gate.sh` and `gate-selftest.sh` are
stack-agnostic — one config block, plus porting recipes for pytest, jest, go and cargo. Arm B
drove the gate entirely unaided, which is the strongest evidence that this part composes with
any TDD workflow rather than requiring this one.

### What remains genuinely unknown

- **n = 1.** One spec, one model, one run per arm. Variance is unmeasured.
- **The spec was the best possible case for the cheap arm.** `SPEC.md` supplies worked
  examples, exact error strings, and an explicit "any item" quantifier. There is very little
  room to reverse-engineer a test from an implementation when the requirement is already
  pinned that precisely. **Isolation should pay where a criterion is ambiguous — and that is
  the condition this experiment did not test.** It is the only remaining scenario in which
  the 4× cost could still be justified, and it is the obvious next experiment: same design,
  but with a deliberately vague criterion — no worked example, no exact error strings, the
  quantifier left implicit.
- **Three criteria is too small** to test whether one long-lived context eventually becomes
  *more* expensive than fresh subagents as a spec grows. Arm B's context never exceeded 60k.

### Methodological notes worth carrying to the next experiment

1. **Pre-register the mutants and commit them first.** The one difference found between the
   arms came from a post-hoc mutant, and that is exactly why it cannot be reported as a
   result.
2. **Do not let the driver make the decision under test.** Had the driver enumerated the test
   cases, both arms would have converged by construction and the experiment would have
   measured nothing.
3. **Verify the verifier.** The gate bug survived three runs and several careful readings of
   a 180-line script. It was found by mutation-testing the gate itself. Reviewing
   verification infrastructure by reading it does not work.

---

## 6. What auditing the gate itself taught us

The findings above are about the *architecture*. These are about the one component that
survived it — and they were found after the sections above were written, by auditing the
gate rather than the agents.

**The gate is where the risk concentrates now.** Once the LLM verifiers were gone, every
remaining way to get a false result ran through one 180-line script. Its parsers had a bug
that credited skipped tests as passing (§3), and that bug survived three full runs and
several careful readings.

**Reading it is not auditing it.** The skipped-test bug was found by driving every command
through its pass *and* fail paths, not by inspection. A later side-by-side reading of the
two implementations then found a second defect neither self-test covers: the shell `done`
command accepts a slice number that does not exist, exits 0, and appends an evidence entry
with a blank title claiming the gates asserted it. Everything else in the gate fails
closed; this one fails **open into the audit log**. Full detail in
[gate-pseudocode.md §9](docs/gate-pseudocode.md).

**A self-test needs its own adversarial validation.** `gate-selftest.sh` was mutation-tested
against eight deliberately broken gates. Two of its 35 checks exist *only* because a mutant
survived without them — dropping red's "must have a failure" check is masked by the marker
check unless the marker is omitted, and disabling the compile check is invisible unless you
assert the *message* rather than just the exit code. The mutation set is now recorded in
[gate-pseudocode.md §7](docs/gate-pseudocode.md) so it can be re-run after any parser
change; previously it existed only as ad-hoc scratch work and was lost between sessions.

**The rule that generalises:** an untested guard is decoration — in both directions. A
guard the harness never exercises may not work, and a *missing* guard the harness never
looks for will not be noticed. Both happened here.

## 7. What to reuse

| File | Why |
|---|---|
| **[`docs/gate-pseudocode.md`](docs/gate-pseudocode.md)** | **Canonical language-agnostic spec.** Reimplement the gate in any language from this alone, and validate it with the mutation set in §7. Start here if you are porting. |
| [`lab/tdd-gate.sh`](lab/tdd-gate.sh) | The deterministic gate. Portable; one config block. |
| [`lab/gate-selftest.sh`](lab/gate-selftest.sh) | Proves the gate's parsers before you trust them. Run it first. |
| [`lab/tdd_gate.py`](lab/tdd_gate.py) / [`lab/gate_selftest.py`](lab/gate_selftest.py) | Python ports. Same 35 checks; one known behavioural divergence from the shell pair, see spec §9. Copy one pair, not both. |
| [`docs/how-the-gate-works.md`](docs/how-the-gate-works.md) | Guided walkthrough of the gate for someone new to it. |
| [`docs/reuse.md`](docs/reuse.md) | Lift-and-shift guide: what to copy, what to edit, what it costs. |
| [`docs/experiment-isolation.md`](docs/experiment-isolation.md) | The control experiment in full. |
| [`docs/experiment-artifacts/`](docs/experiment-artifacts/) | Raw data — both suites, both services, the harness, the log. |

The agent definitions in `.claude/agents/` and the driver playbook are kept as the
*measured* architecture, not as a recommendation. Read section 5 before adopting them.
