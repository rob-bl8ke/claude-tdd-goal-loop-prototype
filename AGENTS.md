# TDD Goal Loop Workflow

> **⚠️ The orchestration model below is SUPERSEDED. To run the loop, follow
> `.claude/agents/tdd-goal-coordinator.md`.**
>
> Four agents described here — `red-verifier`, `green-verifier`, `slice-verifier`,
> `slice-planner` — plus the coordinator-as-subagent pattern have been **retired**. They were
> LLMs doing `grep`. Verification is now a deterministic shell gate: `lab/tdd-gate.sh`.
>
> Measured on this repo, same spec and same 10 passing tests: **713k → 317k tokens**, five
> hallucinated test names → zero, and three real gaps found that the agent-based verifiers
> had rubber-stamped.
>
> Still live: `test-writer`, `code-writer`, `goal-evaluator` (the last one runs **once**, at
> the end). Sections 4, 5, 7 and the Planner section below are retained for historical
> reference only and no longer describe how this repo works.

This document defines the complete TDD Goal Loop workflow, agent responsibilities, and orchestration flow for implementing features using test-driven development with AI agents.

---

## Workflow Overview

The TDD Goal Loop is a structured, agent-based workflow that ensures test-driven development discipline is maintained throughout feature implementation. The workflow proceeds through vertical slices, with each slice implementing a single acceptance criterion from the specification.

**Key Principles:**
- One slice implements one acceptance criterion
- Red-Green-Refactor cycle enforced by verification agents
- No code is written until a failing test exists
- No test is written without planning
- Each step must be verified before proceeding

---

## Agent Responsibilities

The workflow involves **8 specialized agents**, each with a distinct responsibility:

### 1. Orchestrator

**Purpose:** Coordinate the overall TDD Goal Loop workflow and ensure proper sequencing

**Responsibilities:**
- Load the specification and determine the slice sequence
- Invoke agents in the correct order
- Manage the goal loop (repeat until all acceptance criteria are implemented)
- Capture execution evidence and audit trail
- Handle errors and workflow deviations

**Invocation:** Entry point for the entire workflow

---

### 2. Planner

**Purpose:** Analyze the current slice's acceptance criterion and create a test plan

**Responsibilities:**
- Read the acceptance criterion from SPEC.md
- Identify test cases needed to fully verify the criterion
- Create a test list (3-7 test cases in plain English)
- Determine the order of test implementation (simplest first)
- Output the test plan for the test-writer

**Invocation:** Called by orchestrator at the start of each slice

**Output Example:**
```
Slice 1 Test Plan (Acceptance Criterion 1: Sum basket item totals)
1. Single item basket calculates correct subtotal
2. Multiple items basket sums all item totals
3. Large quantity values calculate correctly
```

---

### 3. Test-Writer

**Purpose:** Write the next failing test from the planner's test list

**Responsibilities:**
- Take the next test case from the planner's test list
- Write a JUnit test using AssertJ assertions and BDD structure (GIVEN/WHEN/THEN comments)
- Follow `should...When` naming convention and `@DisplayName` annotations
- Ensure the test will fail (expect red)
- Commit only the test code (no production code yet)

**Invocation:** Called by orchestrator after planner, or after green-verifier completes a cycle

**Output:** A single failing test method

**Constraints:**
- Test must compile (may use stubs/mocks for non-existent production code)
- Test must fail when run (verifies red state)
- No production code changes allowed

---

### 4. Red-Verifier

**Purpose:** Confirm the test fails as expected (Red phase)

**Responsibilities:**
- Run the test suite (e.g., `mvn test`)
- Verify the new test fails with the expected failure message
- Confirm existing tests still pass (no regressions)
- Report red status to orchestrator

**Invocation:** Called by orchestrator immediately after test-writer

**Success Criteria:**
- New test fails ❌
- Existing tests pass ✅
- Failure message matches expectation

**Failure Actions:**
- If new test passes: Alert orchestrator (test is not properly written)
- If existing tests fail: Alert orchestrator (regression detected)

---

### 5. Code-Writer

**Purpose:** Write minimal production code to make the failing test pass

**Responsibilities:**
- Analyze the failing test
- Write the simplest production code to pass the test (Fake It, Triangulate, or Obvious Implementation)
- Follow language-specific standards (Java 21, Spring Boot)
- Avoid premature optimization or over-engineering
- Commit production code changes

**Invocation:** Called by orchestrator after red-verifier confirms red state

**Output:** Minimal production code that addresses the failing test

**Constraints:**
- Only write code needed to pass the current failing test
- No "while we're here" changes
- No refactoring (wait for green first)

---

### 6. Green-Verifier

**Purpose:** Confirm all tests pass (Green phase)

**Responsibilities:**
- Run the full test suite (e.g., `mvn test`)
- Verify all tests pass, including the new one
- Confirm build succeeds
- Report green status to orchestrator

**Invocation:** Called by orchestrator after code-writer

**Success Criteria:**
- All tests pass ✅
- Build succeeds ✅

**Failure Actions:**
- If tests fail: Alert orchestrator (code-writer must fix)
- If build fails: Alert orchestrator (compilation error)

**Next Step:**
- If more tests remain in the test plan: Return to test-writer for next test (Red-Green-Refactor loop)
- If all tests for the slice are complete: Proceed to slice-verifier

---

### 7. Slice-Verifier

**Purpose:** Confirm the acceptance criterion for the current slice is fully implemented

**Responsibilities:**
- Review the acceptance criterion from SPEC.md
- Verify all test cases from the planner's test list are implemented
- Run integration checks if needed (e.g., API endpoint exists, returns correct status codes)
- Confirm slice deliverables are complete
- Report slice completion to orchestrator

**Invocation:** Called by orchestrator after green-verifier when all tests for a slice are complete

**Success Criteria:**
- All planned tests implemented ✅
- All tests pass ✅
- Acceptance criterion verified ✅

**Failure Actions:**
- If criterion not fully verified: Report missing coverage to orchestrator

---

### 8. Goal-Evaluator

**Purpose:** Determine if all acceptance criteria are implemented or if more slices are needed

**Responsibilities:**
- Review the full specification (SPEC.md)
- Check which acceptance criteria are complete
- Determine if the goal (implement all criteria 1-3) is achieved
- Report final status to orchestrator

**Invocation:** Called by orchestrator after slice-verifier completes a slice

**Decision:**
- If all criteria complete: Workflow ends (goal achieved) ✅
- If criteria remain: Orchestrator proceeds to next slice ➡️

**Output:** Final completion report with summary of implemented criteria

---

## Orchestration Flow

```
START
  ↓
[Orchestrator] Load SPEC.md, determine slices
  ↓
┌─────────────────────────────────────────┐
│ GOAL LOOP (repeat for each slice)      │
│                                         │
│  [Planner] Create test plan for slice  │
│     ↓                                   │
│  ┌────────────────────────────────┐    │
│  │ TDD CYCLE (for each test)      │    │
│  │                                 │    │
│  │  [Test-Writer] Write test      │    │
│  │     ↓                           │    │
│  │  [Red-Verifier] Confirm red ❌ │    │
│  │     ↓                           │    │
│  │  [Code-Writer] Write code      │    │
│  │     ↓                           │    │
│  │  [Green-Verifier] Confirm ✅   │    │
│  │     ↓                           │    │
│  │  More tests? → loop back        │    │
│  └────────────────────────────────┘    │
│     ↓                                   │
│  [Slice-Verifier] Verify criterion ✅  │
│     ↓                                   │
│  [Goal-Evaluator] All done?            │
│     ↓                                   │
│  No → next slice, loop back            │
│  Yes → END ✅                           │
└─────────────────────────────────────────┘
```

---

## Invocation Instructions

### For Manual Execution

1. **Start the workflow:**
   ```
   Invoke orchestrator with: "Implement basket quote API per SPEC.md using TDD Goal Loop"
   ```

2. **Orchestrator will:**
   - Read SPEC.md
   - Read lab/expected-slices.md to determine slice sequence
   - Begin Slice 1 (Criterion 1) by invoking planner

3. **Each agent will:**
   - Execute its responsibility
   - Report status/output to orchestrator
   - Wait for orchestrator to invoke the next agent

4. **Evidence capture:**
   - Orchestrator logs each agent invocation, output, and verification result to `lab/evidence.md`
   - Format: `## Slice N: [Title]` with subsections for each agent call

### For Automated Execution

Use the orchestrator agent with the TDD Goal Loop skill:
```bash
# Invoke via agent framework
invoke-agent orchestrator --goal "Implement SPEC.md criteria 1-3 with TDD Goal Loop"
```

---

## Exit Conditions

**Success:** All acceptance criteria (1-3) from SPEC.md are implemented, all tests pass, goal-evaluator reports completion

**Failure/Pause:**
- Red-verifier detects test passes when it should fail
- Green-verifier detects tests fail after code-writer
- Slice-verifier detects criterion not fully covered
- Any agent encounters an error (compilation failure, missing file, etc.)

In all failure cases, orchestrator pauses and reports the issue for manual intervention.

---

## Evidence Audit Trail

All workflow execution is captured in `lab/evidence.md` with structured format:
- Timestamp of each agent invocation
- Agent name and input
- Agent output/decision
- Verification status (✅ or ❌)

This provides a complete audit trail of the TDD process for team review and demonstration.
