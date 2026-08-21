# TDD Goal Loop Prototype

A Spring Boot proof-of-concept demonstrating the TDD Goal Loop pattern using Claude AI agents. This project implements a Basket Quote API through test-driven development orchestrated by specialized agents.

## Purpose

This prototype validates the TDD Goal Loop workflow—a structured, agent-based approach to test-driven development that ensures:

- **Red-Green-Refactor discipline** enforced by verification agents
- **One vertical slice per acceptance criterion** for incremental delivery
- **No code without tests** through strict agent responsibilities
- **Complete audit trail** of the TDD process captured in evidence files

The demo implements a simple Basket Quote API with three acceptance criteria (calculate totals, reject empty baskets, reject invalid items) to showcase the workflow without overwhelming complexity.

## Project Structure

```
.
├── SPEC.md                          # API specification with acceptance criteria
├── AGENTS.md                        # TDD Goal Loop workflow documentation
├── pom.xml                          # Maven project descriptor (Spring Boot 3.5.11, Java 21)
├── docs/
│   ├── demo-script.md               # Presentation flow for team demo
│   └── troubleshooting.md           # Common issues and fixes
├── lab/
│   ├── tdd-gate.sh                  # Deterministic red/green gate (replaces 4 agents)
│   ├── state.json                   # Machine-readable run state
│   ├── expected-slices.md           # Predefined slice sequence (3 slices)
│   └── evidence.md                  # TDD execution audit trail (written by the gate)
├── .claude/agents/                  # TDD Goal Loop agent definitions
│   ├── tdd-goal-coordinator.md      # Driver playbook — the entry point
│   ├── test-writer.md               # Writes failing tests
│   ├── code-writer.md               # Implements minimal production code
│   └── goal-evaluator.md            # Adversarial final audit (runs once)
└── src/
    ├── main/java/com/example/basketquote/
    │   ├── Application.java         # Spring Boot entry point
    │   ├── BasketQuoteController.java
    │   ├── BasketQuoteService.java
    │   ├── BasketQuoteRequest.java
    │   └── BasketQuoteResponse.java
    └── test/java/com/example/basketquote/
        └── BasketQuoteControllerTest.java
```

## Running the Demo

### Prerequisites

- **Java 21** installed (`java -version` should show 21.x)
- **Maven** installed (`mvn -version` should show Maven 3.6+)
- **Claude Code** (VS Code with Claude integration) for agent invocation
- **Git** for version control

### Walkthrough

#### 1. Verify Build

Start by confirming the infrastructure is working:

```bash
mvn clean test
```

All tests should pass (green output). This verifies the Spring Boot setup, test framework, and generated code from the TDD Goal Loop execution.

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

Open [src/test/java/com/example/basketquote/BasketQuoteControllerTest.java](src/test/java/com/example/basketquote/BasketQuoteControllerTest.java) to see:

- **BDD structure** with GIVEN/WHEN/THEN comments
- **AssertJ assertions** for clear, fluent test code
- **MockMvc integration** for API endpoint testing
- **Test naming** following `should...When` convention

#### 6. Inspect Generated Production Code

Open the production code files to see minimal, test-driven implementation:

- [BasketQuoteController.java](src/main/java/com/example/basketquote/BasketQuoteController.java) — REST controller with `POST /api/basket/quote`
- [BasketQuoteService.java](src/main/java/com/example/basketquote/BasketQuoteService.java) — Business logic for calculation and validation
- [BasketQuoteRequest.java](src/main/java/com/example/basketquote/BasketQuoteRequest.java) / [BasketQuoteResponse.java](src/main/java/com/example/basketquote/BasketQuoteResponse.java) — DTOs using Java records

Notice the code is **minimal**—only what's needed to pass the tests, with no speculative abstractions.

#### 7. Re-run Tests to Confirm

```bash
mvn test
```

All tests should pass, confirming the implementation satisfies all three acceptance criteria.

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

**Invocation:** `Invoke @.claude/agents/tdd-goal-coordinator.md @spec.md`

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

`lab/tdd-gate.sh reset | red "<expected>" | green | done <n> "<files>"`

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
