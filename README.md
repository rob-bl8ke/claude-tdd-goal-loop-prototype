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
│   ├── expected-slices.md           # Predefined slice sequence (3 slices)
│   └── evidence.md                  # TDD execution audit trail
├── .claude/agents/                  # TDD Goal Loop agent definitions
│   ├── tdd-goal-coordinator.md      # Main orchestrator (invoke as @tdd-goal-coordinator)
│   ├── slice-planner.md             # Selects next uncompleted slice
│   ├── test-writer.md               # Writes failing tests
│   ├── red-verifier.md              # Confirms test fails as expected
│   ├── code-writer.md               # Implements minimal production code
│   ├── green-verifier.md            # Confirms all tests pass
│   ├── slice-verifier.md            # Verifies acceptance criterion met
│   └── goal-evaluator.md            # Checks if all criteria complete
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

- **8 specialized agents** (Orchestrator, Planner, Test-Writer, Red-Verifier, Code-Writer, Green-Verifier, Slice-Verifier, Goal-Evaluator)
- **Agent responsibilities** (what each agent does and when it's invoked)
- **Orchestration flow** (the complete Red-Green-Refactor cycle for each slice)

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

### Orchestrator (`@tdd-goal-coordinator`)

Coordinates the overall workflow, invoking agents in sequence and capturing evidence.

**Invocation:** `@tdd-goal-coordinator` for each slice (manually invoked per slice in current prototype)

### Planner (`slice-planner`)

Reads the acceptance criterion and creates a test plan (3-7 test cases in plain English).

### Test-Writer (`test-writer`)

Writes the next failing JUnit test using AssertJ assertions and BDD structure. **RULE: DO NOT edit production code.**

### Red-Verifier (`red-verifier`)

Confirms the new test fails as expected (red phase). Verifies compilation succeeds, specific test fails, and failure message is meaningful.

### Code-Writer (`code-writer`)

Implements minimal production code to make the failing test pass (Fake It, Triangulate, or Obvious Implementation). **RULE: DO NOT edit tests.**

### Green-Verifier (`green-verifier`)

Confirms all tests pass, including the new one (green phase). Verifies build succeeds and no regressions occurred.

### Slice-Verifier (`slice-verifier`)

Verifies the acceptance criterion is fully implemented by re-running tests and checking observable API behavior. Updates [lab/evidence.md](lab/evidence.md).

### Goal-Evaluator (`goal-evaluator`)

Checks if all acceptance criteria (1-3) are complete. Returns `GOAL_MET` when the workflow is finished.

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
