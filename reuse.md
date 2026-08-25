# Reusing the TDD Goal Loop on another project

The loop is four files plus three agent definitions. Nothing else in this repo is
machinery — `src/`, `SPEC.md` and `lab/expected-slices.md` are a worked example.

## What to copy

```
lab/tdd-gate.sh                          # the deterministic gate
lab/gate-selftest.sh                     # proves the gate's parsers before you trust them
lab/tdd_gate.py                          # ...or the Python port of both, if you prefer
lab/gate_selftest.py                     #    (identical behaviour; copy one pair, not both)
lab/selftest-fixtures/maven/             # canned runner output; add a dir for your stack
lab/evidence.md                          # audit-trail template (keep the "## Execution Log" heading)
.claude/agents/tdd-goal-coordinator.md   # the driver playbook — your entry point
.claude/agents/test-writer.md
.claude/agents/code-writer.md
.claude/agents/goal-evaluator.md
```

`lab/state.json` is generated — do not copy it, run `init` instead.

## What to edit — three places

New to the gate? [how-the-gate-works.md](how-the-gate-works.md) walks through every command
and guard before you start editing. Porting it to a language other than bash or Python, or
changing a parser? [gate-pseudocode.md](gate-pseudocode.md) is the canonical spec, and its
§7 mutation set is what you run afterwards to prove the self-test still has teeth.

**1. `lab/tdd-gate.sh`** (or `lab/tdd_gate.py`) — the fenced `PROJECT CONFIGURATION` block. Set `TEST_CMD` and
adapt the three parser functions (`parse_counts`, `parse_failures`, `parse_compile_errors`).
Recipes for pytest, jest, go and cargo are in comments directly below it.

**2. `.claude/agents/tdd-goal-coordinator.md`** — the `Project profile` section at the
bottom. Stack, test command, file paths, naming conventions, and how a test can fail before
its production code exists.

**3. `.claude/agents/test-writer.md` and `code-writer.md`** — replace any Java/Spring
specifics with your stack's.

## Then run it

```bash
# 1. one slice per acceptance criterion, in build order
TDD_GOAL="<what this run delivers>" ./lab/tdd-gate.sh init "<slice 1>" "<slice 2>" "<slice 3>"

# 2. MANDATORY — prove the gate's parsers against canned runner output
./lab/gate-selftest.sh

# 3. MANDATORY smoke test — on a repo with no tests yet, this must exit 1
./lab/tdd-gate.sh red "anything"; echo "exit=$?"
```

If either check passes when it should fail, your `parse_counts` is wrong and every gate will
silently pass. That is worse than having no gate, because it looks like verification. Fix the
parser before going further.

The self-test is the higher-value of the two, because it exercises the fail paths a live
smoke test cannot reach. Porting to another stack means capturing eight fixtures once from
real runs of your test command — the contract is documented at the top of
`lab/gate-selftest.sh` — then:

```bash
TDD_SELFTEST_FIXTURES=lab/selftest-fixtures/pytest ./lab/gate-selftest.sh
```

Capture those fixtures; do not hand-write them. `skipped.log` in particular encodes a fact
about your runner that is easy to get wrong from memory — see "What did not work" below.

Then tell Claude:

```
Invoke @.claude/agents/tdd-goal-coordinator.md @SPEC.md
```

## What it costs

Measured on this repo — 3 acceptance criteria, 12 tests, a small Spring Boot service:

| | 8-agent version | 3-agent + gate |
|---|---|---|
| whole run | ~713k tokens | **~310k tokens** |
| verification + orchestration | ~496k | ~2k |
| hallucinated test names | 5 | 0 |
| real gaps found | 0 | 3 |

Two consecutive runs of the gate version came in at 317k and 310k, so budget roughly
**100k tokens per acceptance criterion**, plus ~75k for the final audit. Most of the
remaining cost is the two productive agents, and that part is close to irreducible.

## The five rules that make it efficient

These are the whole result. Erode any one and the cost goes back up.

1. **Never spawn a coordinator subagent.** A subagent stops at the end of each turn, so it
   cannot loop. Orchestration belongs in the main context, where Bash is available. This
   alone was 142k tokens.
2. **Verification is a script, not an agent.** Running the suite and comparing counts is a
   fact. Four agents doing it cost ~496k and were *less accurate* than `grep` — they
   invented five test names that did not exist.
3. **Judgement gets an agent; facts get a script.** Writing tests, writing code, and
   auditing against a spec are judgement. Everything else is not.
4. **The final audit runs once, and verifies by mutation.** Break each guard, confirm a
   specific test fails, restore. This is the only reliable way to tell a real test from a
   test-shaped string, and it is what found every genuine gap.
5. **Push context down, but do not expect it to save tokens.** Inlining each criterion made
   the productive agents ~11% *more* expensive while cutting their tool calls from 12 to 3
   and eliminating scope creep. Do it for correctness, not for cost.

## What did not work

Worth recording so it is not retried:

- **Prompt engineering the productive agents.** Their cost is dominated by their own system
  prompt, reading existing code, and multi-turn reasoning. Inlining context made them
  slightly more expensive, not cheaper.
- **Running the goal evaluator per slice.** Mid-loop it only restates what `state.json`
  already knows. It cost ~35k per call to do so.
- **Prose as a state machine.** The original design kept run state in a growing markdown log
  that every agent re-read and re-interpreted, at ~85k tokens per run. State belongs in
  `state.json`; narrative belongs in `evidence.md`, which no agent reads.
- **Trusting the runner's headline test count.** The gate reported Surefire's `Tests run`,
  which *includes* skipped tests. Three `@Disabled` out of four therefore read as a growing,
  all-green suite: `Tests run: 4, Failures: 0, Errors: 0, Skipped: 3`. `test-writer.md`
  already forbade `@Disabled`, but that was policy with no enforcement behind it — and the
  agent that would break the rule is the one not reading the policy. `parse_counts` must
  subtract skipped, and both gates must fail on a non-zero skip count.
- **Reviewing the gate by reading it.** The bug above survived several careful readings of a
  184-line script and three full runs. It was found by mutation-testing the gate itself, and
  that is what `lab/gate-selftest.sh` now automates. When adding a check to it, verify the
  check has teeth by breaking the corresponding guard and confirming the self-test fails —
  two of its checks exist solely because a mutant survived without them.
