# TDD Goal Loop Workflow

How this repo implements features test-first. This document is the **what and why**; for the
step-by-step operating procedure — exact commands and prompt templates — see
[`.claude/agents/tdd-goal-coordinator.md`](.claude/agents/tdd-goal-coordinator.md), which is
the entry point for a run.

---

## The model

Work proceeds in **vertical slices**: one slice implements exactly one acceptance criterion
from `spec.md`. Within a slice the cycle is red → green, and neither step is taken on trust.

1. **`test-writer`** (agent) writes failing tests for the criterion. It never writes production code.
2. **`lab/tdd-gate.sh red "<expected>"`** asserts the tests compile, that at least one fails,
   and that it fails *for the stated reason* — so a test failing on a typo instead of on its
   assertion is caught rather than celebrated.
3. **`code-writer`** (agent) writes the minimum production code to pass those failures, and nothing more.
4. **`lab/tdd-gate.sh green`** asserts zero failures and that the suite did not shrink.
5. **`lab/tdd-gate.sh done <n>`** records the slice in `lab/state.json` and `lab/evidence.md`.

After the final slice, **`goal-evaluator`** (agent) runs **once** as an adversarial audit.

**Principles**

- One slice, one acceptance criterion.
- No production code until a failing test exists.
- Verification is deterministic — a shell command and a regex, never an LLM's opinion.
- Judgement gets an agent; facts get a script.
- A failing gate stops the loop for a human. No automatic retries, and never edit a test to make it pass.

---

## Division of labour

### Judgement — these are agents

| Agent | Runs | Responsibility |
|---|---|---|
| `test-writer` | once per slice | Turn one acceptance criterion into failing tests. Never touches production code. |
| `code-writer` | once per slice | Minimum code to pass the supplied failures. Never implements a future slice's concerns. |
| `goal-evaluator` | once per run, at the end | Adversarially audit the implementation against `spec.md`. Verifies by mutation testing, not by reading. |

Context isolation is the point, not a side effect. `test-writer` cannot see production code,
so it cannot write a test that trivially passes. `code-writer` sees only the failure output,
so it cannot over-build. Each agent is given its criterion inline and told not to read
`spec.md`, `AGENTS.md`, `lab/evidence.md` or `lab/expected-slices.md` — which reliably
prevents scope creep.

### Facts — this is a script

[`lab/tdd-gate.sh`](lab/tdd-gate.sh) — `reset | red "<expected>" | green | done <n> "<files>"`

It runs `mvn test`, parses surefire's summary, compares counts, and exits 1 with a reason on
failure. It cannot invent a test name it did not see in real output.

### Orchestration — this is the main context

The driver reads `lab/state.json`, picks the first slice where `done` is `false`, and runs
the five steps. Selecting a slice is `slices.find(s => !s.done)`, not an agent call.

**Do not spawn a coordinator subagent.** A subagent stops at the end of every turn, so it
cannot loop; orchestrating from one costs a full context round-trip per step and buys no
autonomy.

---

## What was removed, and why

Four agents were deleted from this repo: `red-verifier`, `green-verifier`, `slice-verifier`,
`slice-planner`. Each reduced to running `mvn test` and comparing numbers — deterministic
work handed to a non-deterministic component.

Measured on this repo, same spec, same 10 passing tests:

| | 8-agent version | 3-agent + gate version |
|---|---|---|
| verification + orchestration | ~496k tokens | ~2k tokens |
| whole run | **~713k tokens** | **~317k tokens** |
| hallucinated test names | 5 invented | 0 |
| wrong file paths reported | yes | 0 |
| real gaps found | 0 | 3 |

The agent-based verifiers were not merely expensive — they were less accurate than `grep`,
and they rubber-stamped three genuine test-coverage gaps that the single adversarial audit
later caught by mutation testing.

Note that the savings came from **deleting agents doing deterministic work**, not from prompt
engineering. Inlining context made the two productive agents ~11% *more* expensive per run
while cutting their tool calls from 12 to 3–4 and eliminating scope creep. Worth knowing
before optimising prompts in search of the next win.

---

## Conventions

**Tests** — JUnit 5 with MockMvc; `should<Expected>When<Condition>` method naming plus
`@DisplayName`; GIVEN / WHEN / THEN comments in each body. A test must compile before its
production code exists, which is achieved by posting raw JSON string literals and asserting
with `jsonPath` so no production type is referenced.

**Production code** — Java 21, Spring Boot 3.5.11. Records for DTOs, constructor injection,
thin controllers with logic in services, custom exceptions plus `@ExceptionHandler` for
validation errors. `long` for money.

**Build** — always pass `clean` to `mvn`; incremental `test-compile` can report "Nothing to
compile" after a fresh edit due to filesystem timestamp granularity.

---

## State and evidence

- **`lab/state.json`** — machine-readable. Which slices are done, current suite size. This is
  what the driver reads.
- **`lab/evidence.md`** — human-readable append-only audit trail, written by the gate. **No
  agent reads this file.** Keeping narrative out of the control path is deliberate: the
  previous design used a growing prose log as its state machine and paid ~85k tokens per run
  to re-interpret it.
- **`lab/expected-slices.md`** — the predefined slice sequence, used to seed `state.json`.

## Exit conditions

- **Goal met** — every slice `done`, `mvn test` green, and the final audit confirms each
  criterion is exercised by a test that genuinely fails when its production code is broken.
- **Gate failure** — stop, report, wait for a human.
- **Impossible** — a criterion cannot be satisfied as specified. Stop and report; do not
  reinterpret the spec to make it pass.
