# The experiment, from scratch

## What this repo is

A prototype for running **test-driven development with AI agents**. The task under test is deliberately small and disposable: a `POST /api/basket/quote` endpoint with three acceptance criteria — sum the basket items, reject empty baskets, reject items with non-positive quantity or price. Spring Boot, Java 21, JUnit + MockMvc.

The API is scaffolding. **The deliverable is the process**: a repeatable, portable way to make an agent build something test-first, where "test-first" is actually enforced rather than merely requested.

## Question 1 — Why was the first attempt so expensive?

The original design modelled every step of TDD as its own specialised agent: a coordinator, a slice planner, a test writer, a red verifier, a code writer, a green verifier, a slice verifier, and a goal evaluator. Eight agents.

One full run cost **713,000 tokens**. Broken down:

| Layer | Tokens |
|---|---|
| Coordinator + slice planner | 142k |
| Verification (red/green/slice/goal verifiers) | 354k |
| Actually writing tests and code | 217k |

**About 70% of the spend produced no tests and no code.** It was agents managing and describing the workflow to each other.

Worse, it wasn't even reliable. The verifier agents reported five test names that did not exist, and cited file paths that did not exist. Asking a language model to run a test command and report the result invites it to narrate a plausible outcome instead.

### The fix

The diagnosis was a one-liner: **judgement gets an agent; facts get a script.**

Checking that a test failed, that it failed for the stated reason, and that the suite didn't shrink is not a judgement — it's a test command and a regex. So four agents were deleted and replaced by a ~180-line shell script, `lab/tdd-gate.sh`, with three commands: `red`, `green`, `done`. The coordinator was deleted too; a subagent can't loop, so orchestration moved into the main context where it costs almost nothing.

That left three agents — test-writer, code-writer, and a single adversarial evaluator at the very end — plus the gate.

| | 8 agents | 3 agents + gate |
|---|---|---|
| whole run | 713k | **~310k** |
| verification + orchestration | 496k | ~2k |
| hallucinated test names | 5 | 0 |
| real gaps found | 0 | 3 |

Cheaper *and* more trustworthy. A script can't invent a test name it never saw, and it exits non-zero loudly instead of writing a confident paragraph.

## An interlude that changed how I read all of the above

Auditing the gate behaviourally — not by reading it — turned up a bug that had been live through all three runs. Its `green` check claimed to catch "tests deleted or silently skipped." It caught deleted. It did not catch skipped, because Maven's headline count *includes* skipped tests:

```
Tests run: 4, Failures: 0, Errors: 0, Skipped: 3
```

The gate read that as four passing tests. An agent that hit a stubborn failing test and reached for `@Disabled` would have produced a green gate and a *growing* test count, invisible in the audit trail.

The lesson generalises past this bug: once you delete the LLM verifiers, **all your risk concentrates in the deterministic component**. So the gate now has its own test suite (`lab/gate-selftest.sh`, 35 checks), and that suite was itself mutation-tested against eight deliberately broken gates to prove it could fail.

## Question 2 — Does the remaining architecture actually buy anything?

After the cuts, the only surviving justification for using agents at all was **context isolation**: a test writer that cannot see the implementation should write tests that describe the *requirement*, rather than tests that bless whatever the implementer happened to produce.

That claim had never been tested. All three runs used isolation. There was no control.

### Method

Two arms, same spec, same gate, one variable:

- **Arm A — isolated.** Two fresh subagents per criterion. The test author is forbidden from reading `src/main/`. Six agents total.
- **Arm B — single loop.** One agent does everything: choose a behaviour, write a test, confirm red, implement, confirm green, repeat. It sees its own implementation the whole time. This is the lightweight, conventional shape.

Both were scored by **mutation testing**: deliberately break the implementation in a specific way, and see whether some test fails. A suite that stays green against a broken implementation isn't testing that behaviour.

Two safeguards mattered:

1. **The 17 mutants were written and committed *before* either arm ran**, so they couldn't be tuned to favour whichever suite I saw first. That's a separate, earlier commit in the history.
2. **Neither arm had its test cases dictated by me.** The playbook normally has the driver enumerate them — but if the driver picks the cases, isolation can't possibly matter, because the driver is making the exact decisions isolation is meant to protect. Both arms chose their own cases.

### Results

| | Arm A (isolated) | Arm B (single loop) |
|---|---|---|
| pre-registered mutants killed | **15 / 16** | **15 / 16** |
| tests written | 11 | 6 |
| subagent tokens | **236,219** | **60,125** |
| agents | 6 | 1 |

Every mutant either died against both suites or survived both. **Arm A wrote 83% more tests to reach an identical score, at 3.9× the cost** — and the real gap is wider, because Arm A also consumed six prompt constructions and seven gate invocations in the driver's context, while Arm B ran the gate itself and needed none.

Three details:

- **One mutant survived both arms**: deleting `@Service`. Neither wrote a test that boots the real application, so both suites stay green while the app fails to start. That's a property of slice-only test suites, not of either architecture.
- **One mutant favoured Arm A, and it's weak evidence.** Arm B lacked a "later item" test for the price rule. But I only found that with a mutant added *after* seeing Arm B's tests — precisely what pre-registration exists to prevent. Suggestive, not confirmatory.
- **One difference the mutants didn't score.** Arm A's blind test author asked how "zero items" could arrive over the wire and tested a missing `items` field; Arm A therefore handles it. Arm B noticed the same case, judged it out of scope, and left it — so `{"items": null}` returns 500 on Arm B and 400 on Arm A. That's a scope-interpretation difference, not confirmation bias.

## Conclusion

**Deleting agents that did deterministic work was a large, real win.** 713k → 310k, with fewer hallucinations and more genuine defects found. That result is solid.

**Keeping agents for context isolation was not.** On a well-specified feature it cost 4× and bought nothing measurable. The default should be the single loop; isolation is an escalation, not an architecture.

**The durable artifacts are the mechanical ones** — `tdd-gate.sh` and `gate-selftest.sh`. They're stack-agnostic (config block plus recipes for pytest/jest/go/cargo), and Arm B drove the gate entirely unaided, which is the strongest evidence that this part composes with any TDD workflow rather than requiring this one.

### What remains genuinely unknown

- **n = 1.** One spec, one model, one run per arm. Variance unmeasured.
- **The spec was the best possible case for the cheap arm.** Worked examples, exact error strings, an explicit "any item" quantifier. There's little room to reverse-engineer a test from an implementation when the requirement is already pinned that precisely. **Isolation should pay where a criterion is *ambiguous* — and that's the condition not tested.** It's the only remaining scenario where the 4× cost could be defensible, and it's the obvious next experiment.
- **Three criteria is too small** to test whether one long-lived context eventually becomes *more* expensive than fresh subagents. Arm B's context never exceeded 60k.

Raw data for all of the above — both test suites, both implementations, the mutation harness, the full run log — is in `docs/experiment-artifacts/`, so none of it has to be taken on trust.

---

Want me to commit this as a top-level write-up? Right now the narrative is spread across `docs/experiment-isolation.md`, `docs/reuse.md` and the commit messages; a newcomer has no single entry point.
