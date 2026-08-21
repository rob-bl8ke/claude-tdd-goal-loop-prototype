Good question — and I have real numbers from this run. Let me verify a few things about the repo structure before I diagnose.

Let me verify one thing I noticed in the agent reports.

I dug into the numbers from this run. Here's what I found.

## What the run actually cost

~713k tokens to produce 10 tests and 9 small Java files:

| Agent | Calls | Tokens | Share |
|---|---|---|---|
| slice-verifier | 3 | 115k | 16% |
| code-writer | 3 | 112k | 16% |
| test-writer | 3 | 105k | 15% |
| red-verifier | 3 | 87k | 12% |
| slice-planner | 3 | 85k | 12% |
| green-verifier | 3 | 78k | 11% |
| goal-evaluator | 2 | 74k | 10% |
| coordinator | 20 turns | 57k | 8% |

**Only 30% went to writing tests and code.** 50% went to verification, 20% to orchestration. Plus an uncounted cost: 14 `SendMessage` round-trips that each re-sent this entire conversation.

## Four root causes, ranked

**1. Half the budget paid LLMs to do `grep` (~354k)**

`red-verifier`, `green-verifier`, `slice-verifier`, and `goal-evaluator` all reduce to: run `mvn test`, parse `Tests run: N, Failures: F`, compare counts. That is a shell command and a regex.

And they got it wrong. The slice-3 red-verifier reported these as passing:

> `shouldApplyPromoCodeDiscount`, `shouldNotApplyInvalidPromoCode`, `shouldReturnOkWhenValidBasketProvided`

None exist — I checked [BasketQuoteControllerTest.java](src/test/java/com/example/basketquote/BasketQuoteControllerTest.java). Promo logic is explicitly out of scope in the spec. It invented five test names. The coordinator's final report also cited `com/example/basket/...` paths that don't exist (actual package is `basketquote`).

You handed the one role where determinism is the entire point to the least deterministic component — and paid a 50% premium for a worse answer.

**2. The coordinator can't loop, so orchestration leaked into my context (~57k + 14 round-trips)**

A subagent stops when its turn ends. So the "loop" was really: coordinator calls one agent → stops → notifies me → I resume it → repeat, 14 times. Each resume re-sent the coordinator's growing context; each notification re-sent mine. The coordinator added a hop without adding autonomy — I was the actual loop.

**3. Every agent cold-started on the same ~28KB (~133k)**

`AGENTS.md` (9.6KB) + `evidence.md` (12.6KB, growing) + `expected-slices.md` (3.7KB) + `spec.md` (2.4KB) ≈ 7k tokens × 19 invocations. By slice 3, seven agents each read 394 lines of evidence.md to extract one fact: which slice is next.

**4. evidence.md is a prose log being used as a state machine (~85k)**

"Pick the next uncompleted slice from a predefined sequence" is `slices.find(s => !s.done)`. It cost 85k because the state lives in prose that must be re-read and re-interpreted every time.

## The fix: gate with code, judge with agents, push context down

```
for each slice:
  agent  test-writer   ← criterion verbatim + file path + conventions (~1k in, not 7k)
  Bash   mvn test      ← assert exit≠0 AND failure matches expected shape
  agent  code-writer   ← the actual failure output, nothing else
  Bash   mvn test      ← assert 0 failures, count increased
  code   append evidence.md
agent  goal-evaluator  ← ONCE, at the end, against the full spec
```

Four changes, in order of payoff:

- **Delete the four verifier agents.** Replace with `mvn test` + assertions in the driver. The one piece of real judgment — *did it fail for the right reason, not a compile error?* — is `assert output contains "expected:<400> but was:<200>"`, not an agent. Saves ~280k.
- **Move the loop into the driver.** Either the main context (where Bash is available) or a `Workflow` script. Note TDD is inherently sequential — red must precede green — so a Workflow's fan-out buys nothing here; its value would be the free control flow. For 3 slices, main-loop + Bash is simpler. Saves ~57k plus the round-trips.
- **Pass context down instead of making agents rediscover it.** The driver extracts each criterion once and inlines it in the prompt. `test-writer` needs ~15 lines of criterion, a file path, and existing test names — not four files. Saves ~100k.
- **Split state from narrative.** `lab/state.json` (machine-readable, 3 lines) for control flow; `lab/evidence.md` stays the human audit trail that *no agent reads*. Deletes `slice-planner` entirely. Saves ~85k.

**Estimate: ~130k vs 713k — roughly 5x.**

## What you keep

The genuine value of the multi-agent structure survives intact, because it was never in the verifiers:

- **Context isolation as a discipline device.** `test-writer` can't see production code, so it can't write a test that trivially passes. `code-writer` sees only the failing test, so it can't over-build. This is the real reason the approach works, and it's fully preserved.
- **Fresh-eyes spec audit.** `goal-evaluator` judging spec-vs-reality without having written either — kept, run once instead of twice.
- **Audit trail.** Improved: deterministic appends don't hallucinate test names.

One cheap fix worth applying regardless of the above: give every remaining agent a **structured output schema** instead of letting it return prose. `{status, testsRun, failures, failingTests[]}` would have cut report sizes ~10x *and* made the hallucinated test names impossible.

Want me to rebuild the loop this way and re-run it against the same spec so you get a real before/after number?

---

Yes

---

Let me check what state the repo is in now.

Clean revert — only `Application.java` remains. Let me read what I need to build the new driver.

Everything I need. Now let me build the new architecture. First, the deterministic gate that replaces four agents:

Gate is live. Now the loop — Slice 1, test-writer with context pushed down (criterion inlined, no repo reading):

Now the RED gate — deterministic, ~500 tokens instead of a 29k agent:

RED gate passed for ~400 tokens (vs 29,394 for the red-verifier agent). Now code-writer, fed the actual failure output:

Slice 1 done. Slice 2 — note I now pass the *existing* test names down so the agent doesn't need to read the file to avoid collisions:

Slice 3 — last one:

All three slices green. Now the one genuine judgment call — a single adversarial audit against the spec:

That audit earned its keep — it ran mutation testing and found three real gaps. It also caught a bug in my gate script. Let me look:

Confirmed — my `grep -A1` pulled the following slice's title in. Fixing both the script and the emitted file:

Rebuilt and re-run from scratch. Same spec, same outcome (10/10 green), and here is the honest accounting.

## Before / after

| Layer | Before | After | Change |
|---|---|---|---|
| Orchestration — coordinator + slice-planner | 142k | ~0 | **eliminated** |
| Verification — red, green, slice, goal | 354k | 77k | **−78%** |
| Productive — test-writer + code-writer | 217k | 240k | **+11%** |
| **Total** | **713k** | **~317k** | **−55% (2.2×)** |

**I predicted 5×. I got 2.2×.** Worth being precise about where I was wrong: I claimed pushing context down would cut the productive agents' cost. It didn't — it went *up* 11%. My inlined criteria run 700–900 tokens per prompt, replacing file reads that were cheaper than I estimated; the agents still must read the existing test file and production code (the dominant, irreducible read); and each agent's own `.md` system prompt is ~4k of fixed overhead I never touched.

What push-down *did* buy, measurably: test-writer tool calls dropped 12 → 4/4/3, and every code-writer explicitly refused to implement later slices' validation. Zero scope creep.

**The real lesson: the savings came from deleting agents that were doing deterministic work, not from prompt engineering.** Six agent roles collapsed into [lab/tdd-gate.sh](lab/tdd-gate.sh) — ~400 tokens per gate instead of ~30k.

## Quality went up, which matters more

| | Before | After |
|---|---|---|
| Hallucinated test names | 5 invented | 0 — the gate greps real surefire output |
| Wrong paths in reports | yes (`com/example/basket/`) | 0 |
| Real gaps found | 0 | 3 |

The single surviving expensive agent (74k) audited by **mutation testing** rather than by reading, and found three things that 354k of previous verification agents rubber-stamped:

1. **Multi-item validation is untested.** Mutating the loop to validate only the first item leaves all 10 tests green. Code is correct; nothing locks it in.
2. **`shouldReturnAccurateSubtotalWhenQuantitiesAreLarge` doesn't test what its name says.** 10,999,000 fits in an `int`; switching to `int` keeps all 10 green. Real overflow silently returns 200 with `subtotalCents: 0`.
3. **The spec's own criterion-1 example is never fully asserted** — the 1750 test checks only `subtotalCents`.

It also caught a genuine bug in my gate script (`grep -A1` bled the next slice's title into each evidence heading — fixed) and flagged that **port 8080 on this machine is held by an unrelated process** that answers every request with a `correlationId` envelope. `docs/demo-script.md` will silently hit the wrong server. I didn't touch that process.

## Architecture now

```
main loop (driver, Bash available)
  per slice:  test-writer agent → tdd-gate.sh red "<expected>" → code-writer agent → tdd-gate.sh green → done
  once:       goal-evaluator agent (adversarial, mutation-tested)
```

Context isolation is fully preserved — test-writer never sees production code, code-writer sees only the failure output. That was always the real value; it was never in the verifiers.

New artifacts: [lab/tdd-gate.sh](lab/tdd-gate.sh), [lab/state.json](lab/state.json). Five agent definitions are now dead code: `red-verifier`, `green-verifier`, `slice-verifier`, `slice-planner`, `tdd-goal-coordinator`.

Three follow-ups, in the order I'd do them — say which you want:

- **Close the 3 gaps** as a proper slice 4 (multi-item validation test, honest overflow test, full spec-example assertion)
- **Delete the 5 dead agent definitions** and rewrite `AGENTS.md` to document the gate-based loop
- **Fix the `@Service` wiring** — production wiring is currently shaped by a `@WebMvcTest` constraint, which also means no test boots the real context

---
