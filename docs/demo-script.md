# TDD Goal Loop Demo Script

**Total Duration:** ~30 minutes (20 min presentation + 10 min Q&A)

**Audience:** Development team interested in AI-assisted TDD workflow

**Goal:** Demonstrate a working TDD Goal Loop implementation with complete evidence trail

---

## Pre-Demo Checklist

- [ ] Clone repository on demo machine
- [ ] Run `mvn clean test` to verify all tests pass
- [ ] Open VS Code with Claude integration enabled
- [ ] Have [SPEC.md](../SPEC.md), [AGENTS.md](../AGENTS.md), [lab/evidence.md](../lab/evidence.md) open in tabs
- [ ] Have terminal ready with `mvn test` command
- [ ] Prepare screen sharing (hide personal notifications)

---

## Part 1: TDD Goal Loop Concept (5 minutes)

### Talking Points

**The Problem:**
- Traditional TDD requires discipline—easy to skip the "red" phase or write code before tests
- Manual test-first workflow can be slow and inconsistent across team members
- Hard to prove the code was actually built test-first (audit trail missing)

**The Solution: TDD Goal Loop**
- **Agent-orchestrated workflow** enforces Red-Green-Refactor discipline
- **Specialized agents** with strict responsibilities (test-writer can't touch production code, code-writer can't touch tests)
- **Verification agents** confirm red/green state before proceeding
- **Complete audit trail** captured in evidence file

**The Workflow:**
```
Orchestrator → Planner → Test-Writer → Red-Verifier → Code-Writer → Green-Verifier → Slice-Verifier → Goal-Evaluator
```

**Key Benefits:**
- **Enforced TDD discipline** (no shortcuts possible)
- **Incremental delivery** (one acceptance criterion per slice)
- **Proof of test-first development** (evidence trail shows red → green transitions)
- **Reduced cognitive load** (agents handle workflow, you focus on requirements)

### Demo Actions

1. Show [AGENTS.md](../AGENTS.md) orchestration flow diagram (scroll to "Orchestration Flow" section)
2. Emphasize the **Red-Verifier** and **Green-Verifier** checkpoints (these prevent cheating)
3. Highlight the **Goal Loop** (repeat for each acceptance criterion until complete)

---

## Part 2: Documentation Review (3 minutes)

### Talking Points

**Specification ([SPEC.md](../SPEC.md)):**
- Simple Basket Quote API with 3 acceptance criteria
- Each criterion has GIVEN/WHEN/THEN structure
- Example requests and responses for clarity

**Workflow Documentation ([AGENTS.md](../AGENTS.md)):**
- 8 specialized agents with distinct responsibilities
- Agent invocation sequence clearly defined
- Exit conditions for success and failure cases

**Slice Plan ([lab/expected-slices.md](../lab/expected-slices.md)):**
- Predefined slice sequence (Slice 1: sum totals, Slice 2: reject empty, Slice 3: reject invalid)
- Each slice maps to one acceptance criterion
- Test plan expectations documented upfront

### Demo Actions

1. Open [SPEC.md](../SPEC.md) and scroll through the 3 acceptance criteria
2. Show one example request/response (e.g., criterion 1 with multiple items)
3. Open [AGENTS.md](../AGENTS.md) and show agent responsibilities table
4. Briefly mention [lab/expected-slices.md](../lab/expected-slices.md) (predefined plan, not improvised)

---

## Part 3: Evidence Trail Walkthrough (5 minutes)

### Talking Points

**What is the Evidence Trail?**
- Complete record of TDD execution captured in [lab/evidence.md](../lab/evidence.md)
- Shows every agent invocation, verification status, and decision point
- Proves the code was built test-first (red → green transitions visible)

**Structure:**
- Organized by **slice** (one section per acceptance criterion)
- Each agent's output captured with **timestamp** and **status**
- **Red/Green verification** explicitly recorded (❌ → ✅ transitions)

**Why This Matters:**
- **Audit compliance** (provable test-first development)
- **Debugging workflow issues** (see exactly where a slice failed)
- **Team learning** (review evidence to understand TDD decisions)

### Demo Actions

1. Open [lab/evidence.md](../lab/evidence.md)
2. Scroll to **Slice 1** section
3. Point out the **RED ✅ → GREEN ✅** gate line for the slice
4. Stress that both were asserted by `lab/tdd-gate.sh`, not reported by an LLM — the entry
   is written by a shell script that parses real `mvn test` output
5. Point out the **suite count** growing (4 → 6 → 10) — the count is of *executed* tests,
   so the gate catches both deleted tests (count shrinks) and disabled ones (a non-zero
   `Skipped` fails the gate outright)
6. Scroll to **Slice 2** and **Slice 3** to show the pattern repeats
7. Emphasize: "This evidence proves we never wrote code before a failing test existed —
   and the proof is a script's exit code, not a model's summary"

---

## Part 4: Generated Test Code (3 minutes)

### Talking Points

**Test Quality:**
- **BDD structure** with GIVEN/WHEN/THEN comments for readability
- **AssertJ assertions** for fluent, expressive test code
- **MockMvc integration** for testing REST endpoints without starting a server
- **Naming convention:** `should...When` for clear test intent

**Test Coverage:**
- Each acceptance criterion decomposed into 3-7 tests
- Tests written **incrementally** (one at a time, red → green → next test)
- No speculative tests (only tests needed to verify the criterion)

### Demo Actions

1. Open [src/test/java/com/example/basketquote/BasketQuoteControllerTest.java](../src/test/java/com/example/basketquote/BasketQuoteControllerTest.java)
2. Show one complete test method (e.g., `shouldCalculateSubtotalForSingleItem`)
3. Point out:
   - **GIVEN/WHEN/THEN comments** (BDD structure)
   - **AssertJ assertions** (`.isEqualTo()`, `.hasSize()`, etc.)
   - **MockMvc** usage (`.perform(post(...))`, `.andExpect(status().isOk())`)
   - **@DisplayName** annotation (human-readable test description)
4. Scroll through the test file to show the full suite (~6-9 tests)
5. Mention: "These tests were written **before** the production code existed"

---

## Part 5: Generated Production Code (3 minutes)

### Talking Points

**Code Quality:**
- **Minimal implementation** (only what's needed to pass tests)
- **Java 21 idioms** (records for DTOs, clear method names)
- **Spring Boot conventions** (controller annotations, service layer, dependency injection)
- **No premature optimization** (code is simple and focused)

**Code Structure:**
- **Controller** (`BasketQuoteController.java`) — REST endpoint with `@PostMapping`
- **Service** (`BasketQuoteService.java`) — Business logic for calculation and validation
- **DTOs** (`BasketQuoteRequest.java`, `BasketQuoteResponse.java`) — Java records for request/response

### Demo Actions

1. Open [src/main/java/com/example/basketquote/BasketQuoteController.java](../src/main/java/com/example/basketquote/BasketQuoteController.java)
2. Show the `@PostMapping("/api/basket/quote")` endpoint
3. Point out the **controller → service** delegation (clean separation of concerns)
4. Open [src/main/java/com/example/basketquote/BasketQuoteService.java](../src/main/java/com/example/basketquote/BasketQuoteService.java)
5. Show the `calculateQuote` method (sum totals, apply discount)
6. Point out **validation logic** (reject empty baskets, reject invalid items)
7. Mention: "This code was written **after** the tests failed, not before"

---

## Part 6: Run Tests (1 minute)

### Talking Points

**Final Verification:**
- All tests pass (green output)
- Build succeeds (Spring Boot compiles correctly)
- No regressions (all acceptance criteria verified)

### Demo Actions

1. Open terminal in project root
2. Run:
   ```bash
   mvn test
   ```
3. Wait for green output (all tests pass)
4. Point out the test count (should be ~6-9 tests)
5. Mention: "This confirms all 3 acceptance criteria are implemented and verified"

---

## Part 7: Q&A (10 minutes)

### Expected Questions

**Q: How do you invoke the agents?**  
A: Use `@tdd-goal-coordinator` in Claude Code for each slice. Future enhancement: single `/goal` command.

**Q: Can I modify the agents?**  
A: Yes! They're markdown files in `.claude/agents/`. Customize for your team's workflow.

**Q: Does this work with other languages/frameworks?**  
A: Yes! The pattern is language-agnostic. Swap Java/Spring Boot for Python/FastAPI, TypeScript/Express, etc.

**Q: What if a test fails during the workflow?**  
A: The workflow pauses and reports the issue. You fix it manually, then resume.

**Q: How long does it take to implement a slice?**  
A: Depends on complexity. Simple slices: 5-10 minutes. Complex slices: 15-30 minutes.

**Q: Do you need a separate agent per slice?**  
A: No! The same agents handle all slices. They're invoked in a loop until all criteria are complete.

**Q: What about refactoring?**  
A: Future enhancement. Current prototype focuses on Red-Green cycle. Refactoring would be a separate agent invocation.

**Q: Can I use this in production?**  
A: This is a proof-of-concept. Validate on your team's workflow first. Consider integration with CI/CD, code review tools, etc.

### Demo Actions

- Take questions from the audience
- Show relevant files/evidence as needed to answer questions
- Emphasize: "This is a prototype—feedback welcome!"

---

## Post-Demo Actions

- Share repository link with team
- Offer to pair on first team implementation
- Schedule follow-up session for feedback and iteration

---

## Tips for a Smooth Demo

- **Practice the flow** beforehand (know where each file is)
- **Keep explanations concise** (no deep dives unless asked)
- **Focus on the evidence trail** (this is the killer feature)
- **Emphasize agent discipline** (code-writer can't edit tests, test-writer can't edit code)
- **Show, don't tell** (open files, scroll through code, run tests live)
- **Be prepared for skepticism** (have answers ready for "why not just write tests manually?")

**Why TDD Goal Loop is compelling:**
- It **enforces discipline** humans struggle to maintain
- It **provides proof** that TDD was followed (audit trail)
- It **reduces cognitive load** (agents handle workflow, you focus on requirements)
- It **scales to teams** (consistent TDD approach across all developers)
