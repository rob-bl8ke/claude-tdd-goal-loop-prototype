# TDD Goal Loop Prototype

An experiment in driving test-driven development with AI agents — how much of the TDD loop
should be an agent, and how much should be a script.

> ### 📊 Start here: [**FINDINGS.md**](FINDINGS.md)
>
> The complete write-up — the questions asked, the method, the measurements, and what held up.
> No prior context needed. Short version: deleting agents that did deterministic work saved
> 57% of the tokens and made the results more trustworthy; keeping agents for *context
> isolation* cost 4× and bought nothing measurable. The reusable artifacts are the two shell
> scripts, not the agent architecture.

## Purpose

This prototype tests a structured approach to agent-driven TDD:

- **Red-Green-Refactor discipline** enforced by a deterministic gate ([`lab/tdd-gate.sh`](lab/tdd-gate.sh)), not by an agent's say-so
- **One vertical slice per acceptance criterion** for incremental delivery
- **No code without tests** — the gate refuses to pass a slice whose test never failed first
- **Complete audit trail** written by the gate from real test output

The demo implements a Basket Quote API with three acceptance criteria (calculate totals,
reject empty baskets, reject invalid items) to exercise the workflow without overwhelming
complexity. The API itself is disposable scaffolding and is not committed — the process is
the deliverable.

> **Reusing the loop?** The machinery is four files plus three agent definitions, and it is
> stack-agnostic. See **[docs/reuse.md](docs/reuse.md)** for what to copy, the three places to
> edit, the mandatory gate smoke test, and what a run costs. Everything under `src/` and
> `SPEC.md` is a worked example, not machinery.

## Project Structure

```
.
├── FINDINGS.md                      # ← START HERE: the whole experiment, self-contained
├── SPEC.md                          # API specification with acceptance criteria
├── AGENTS.md                        # TDD Goal Loop workflow documentation
├── pom.xml                          # Maven project descriptor (Spring Boot 3.5.11, Java 21)
├── docs/
│   ├── reuse.md                     # How to lift this loop into another project
│   ├── how-the-gate-works.md        # Line-by-line walkthrough of the gate (start here to read code)
│   ├── gate-pseudocode.md           # Canonical language-agnostic spec + mutation set (port from this)
│   ├── experiment-isolation.md      # The isolation control experiment, in full
│   ├── experiment-artifacts/        # Raw data: both suites, both services, harness, log
│   ├── demo-script.md               # Presentation flow for team demo
│   └── troubleshooting.md           # Common issues and fixes
├── lab/
│   ├── tdd-gate.sh                  # Deterministic red/green gate (replaces 4 agents)
│   ├── gate-selftest.sh             # Proves the gate's parsers (run before trusting it)
│   ├── tdd_gate.py                  # Python port of the gate — same commands, same exit codes
│   ├── gate_selftest.py             # Python port of the self-test
│   ├── selftest-fixtures/           # Canned runner output for the self-test
│   ├── state.json                   # Machine-readable run state
│   ├── expected-slices.md           # Predefined slice sequence (3 slices)
│   └── evidence.md                  # TDD execution audit trail (written by the gate)
├── .claude/agents/                  # TDD Goal Loop agent definitions
│   ├── tdd-goal-coordinator.md      # Driver playbook — the entry point
│   ├── test-writer.md               # Writes failing tests
│   ├── code-writer.md               # Implements minimal production code
│   └── goal-evaluator.md            # Adversarial final audit (runs once)
└── src/
    └── main/java/com/example/basketquote/
        └── Application.java         # Spring Boot entry point — the only committed source
```

Everything else under `src/` is produced by a run and deliberately **not** committed. The repo
ships as boilerplate so the loop can be re-run from scratch; the process is the deliverable,
not the Basket Quote API.

## Running the Demo

### Prerequisites

- **Java 21** installed (`java -version` should show 21.x)
- **Maven** installed (`mvn -version` should show Maven 3.6+)
- **Claude Code** (VS Code with Claude integration) for agent invocation
- **Git** for version control

### Walkthrough

#### 1. Verify the toolchain and the gate

A fresh clone has no tests yet, so start by proving the build works and — more importantly —
that the gate can actually fail:

```bash
mvn -B clean test-compile
./lab/gate-selftest.sh
```

The self-test drives every gate through both its pass and its fail paths and must report
`0 drift`. This matters more than it sounds: a gate whose parser is subtly wrong reports
confident false green, which is worse than having no gate at all because the audit trail
still reads like verification. See section 3 of [FINDINGS.md](FINDINGS.md).

#### 2. Review Specification

Open [SPEC.md](SPEC.md) to see the three acceptance criteria:

1. **Sum basket item totals** — Calculate `subtotalCents` from `(quantity × unitPriceCents)` for all items
2. **Reject empty baskets** — Return 400 Bad Request when basket has zero items
3. **Reject invalid items** — Return 400 when items have non-positive quantity or unitPriceCents

Each criterion includes example requests, responses, and expected HTTP status codes.

#### 3. Examine TDD Workflow Documentation

Open [AGENTS.md](AGENTS.md) to understand the TDD Goal Loop workflow:

- **3 judgement agents** (Test-Writer, Code-Writer, Goal-Evaluator) plus a deterministic gate
- **Agent responsibilities** (what each does, and why verification is a script rather than an agent)
- **Orchestration flow** (the red → green cycle for each slice, driven from the main context)

#### 4. Review Execution Evidence

Open [lab/evidence.md](lab/evidence.md) to see the complete audit trail:

- **Structured by slice** (one section per acceptance criterion)
- **Agent invocations** with timestamps and outputs
- **Red/Green verification** status for each test cycle
- **Slice completion** confirmations

This evidence demonstrates the TDD process was followed correctly.

#### 5. Inspect Generated Tests

A run generates `src/test/java/com/example/basketquote/BasketQuoteControllerTest.java`. It is
not committed — the implementation is disposable scaffolding, so the repo ships as boilerplate
ready to run. Open the generated file to see:

- **BDD structure** with GIVEN/WHEN/THEN comments
- **MockMvc integration** for API endpoint testing
- **Test naming** following the `should<Expected>When<Condition>` convention

For suites produced by real runs without running one yourself, see
[docs/experiment-artifacts/](docs/experiment-artifacts/) — two complete suites from the
isolation experiment, with the mutation scores they earned.

#### 6. Inspect Generated Production Code

A run generates these under `src/main/java/com/example/basketquote/`, none of them committed:

- `BasketQuoteController.java` — REST controller with `POST /api/basket/quote`
- `BasketQuoteService.java` — calculation and validation
- `BasketQuoteRequest.java` / `BasketQuoteResponse.java` — DTOs using Java records

Two services from real runs are preserved in
[docs/experiment-artifacts/](docs/experiment-artifacts/) if you want to read one without
running the loop.

Notice the code is **minimal**—only what's needed to pass the tests, with no speculative abstractions.

#### 7. Re-run Tests to Confirm

```bash
mvn test
```

After a run, all tests should pass, confirming the implementation satisfies all three
acceptance criteria. Note that green alone is weak evidence — see the mutation-testing
results in [FINDINGS.md](FINDINGS.md) for why the final audit breaks each guard on purpose.

## Alternative: `/goal` Command (Future Enhancement)

In future iterations, the TDD Goal Loop could be invoked with a single command:

```
/goal Implement SPEC.md criteria 1-3 using TDD Goal Loop
```

This would automatically:
- Read [SPEC.md](SPEC.md) to extract acceptance criteria
- Invoke `@tdd-goal-coordinator` for each slice
- Execute the full Red-Green-Refactor cycle
- Capture evidence in [lab/evidence.md](lab/evidence.md)
- Report completion status

**Current approach:** Manually invoke `@tdd-goal-coordinator` for each slice (as shown in the demo walkthrough above).

**Future approach:** Single `/goal` command orchestrates the entire workflow.

This enhancement is deferred to a future branch (not part of the current prototype).

## TDD Goal Loop Agents

Three agents do judgement work. Verification is a shell script, not an agent — see
[AGENTS.md](AGENTS.md) for why, and
[.claude/agents/tdd-goal-coordinator.md](.claude/agents/tdd-goal-coordinator.md) for the
operating procedure.

### Driver (`@tdd-goal-coordinator`)

The entry point. Its instructions run **in the main context** — it is a playbook, not a
subagent to be spawned. It reads `lab/state.json`, picks the next pending slice, and runs
the red/green cycle.

**Invocation:** `Invoke @.claude/agents/tdd-goal-coordinator.md @SPEC.md`

### Test-Writer (`test-writer`)

Writes the failing tests for one acceptance criterion, using BDD structure and
`should<Expected>When<Condition>` naming. **RULE: DO NOT touch production code.**

### Code-Writer (`code-writer`)

Implements the minimum production code to pass the supplied failures (Fake It, Triangulate,
or Obvious Implementation). **RULE: DO NOT edit tests, and do not implement a later slice's
concerns.**

### Goal-Evaluator (`goal-evaluator`)

Runs **once**, after the final slice. Adversarially audits the implementation against the
spec, verifying by mutation testing rather than by reading. Returns `GOAL_MET` or `NOT_MET`
plus any gaps found.

### The gate (not an agent)

`lab/tdd-gate.sh init | reset | red "<expected>" | green | done <n> "<files>"`

Verify it with `./lab/gate-selftest.sh` before any run, and after any change to its parsers.

Available in two languages — `tdd-gate.sh` / `gate-selftest.sh` and `tdd_gate.py` /
`gate_selftest.py`. Both pass the same 35 self-test checks, with one known divergence
(spec §9). For a guided walkthrough of what the code does and why each guard exists, see
**[docs/how-the-gate-works.md](docs/how-the-gate-works.md)**. To reimplement it in another
language, or to re-validate it after changing a parser, use the canonical spec:
**[docs/gate-pseudocode.md](docs/gate-pseudocode.md)**.

Runs `mvn test`, parses the summary, asserts red or green, and exits 1 with a reason on
failure. Replaced four former agents (`red-verifier`, `green-verifier`, `slice-verifier`,
`slice-planner`) at roughly 1/250th of the token cost, with no ability to hallucinate a test
name it did not see.

## Acceptance Criteria

See [SPEC.md](SPEC.md) for full details:

1. **Sum basket item totals** — Calculate `subtotalCents` from item quantities and prices
2. **Reject empty baskets** — Return 400 with error message for zero-item baskets
3. **Reject invalid items** — Return 400 for non-positive quantity or unitPriceCents

Each criterion includes:
- GIVEN/WHEN/THEN specification
- Example request and response JSON
- Expected HTTP status codes

## Troubleshooting

For common issues (Maven not found, agents not recognized, test compilation failures), see [docs/troubleshooting.md](docs/troubleshooting.md).

## Technology Stack

- **Java 21** — Modern Java with records, pattern matching, virtual threads
- **Spring Boot 3.5.11** — Auto-configuration, dependency injection, REST controllers
- **Maven** — Build and dependency management
- **JUnit 5** — Test framework
- **AssertJ** — Fluent assertions for clear test code
- **MockMvc** — Spring integration testing for REST endpoints

## Demo Script

For a structured presentation flow (5 min concept, 3 min docs, 5 min evidence, 3 min tests, 3 min code, 10 min Q&A), see [docs/demo-script.md](docs/demo-script.md).
