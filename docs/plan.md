# Plan: TDD Goal Loop Prototype for Team Demo

> **Historical.** This is the original build plan for the prototype. The architecture has
> since changed: `slice-planner`, `red-verifier`, `green-verifier` and `slice-verifier` were
> deleted and replaced by `lab/tdd-gate.sh`. See [AGENTS.md](../AGENTS.md) for the current
> workflow. Kept for provenance.


Build a Spring Boot proof-of-concept demonstrating the TDD Goal Loop pattern using Claude agents. Infrastructure setup on personal laptop (4 commits), execution and demo prep on work laptop with demo branch for iterations.

## Implementation Approach

**Why**: Validate TDD Goal Loop workflow before team demo - infrastructure first, execution second, demo refinement on branch.

**How**: 7 tasks across 2 phases. Phase 1 (Tasks 1-4) builds infrastructure on personal laptop with git commits. Phase 2 (Tasks 5-7) verifies and executes on work laptop, creates demo branch for iterations.

**Scope**: 3 acceptance criteria (sum totals, reject empty baskets, reject invalid items) as proof-of-concept. Full 6-criteria implementation excluded. `/goal` command implementation deferred to future branch (instructions in README only).

## Steps

**Phase 1: Infrastructure Setup (Personal Laptop)**

1. **Spring Boot Project Setup** (*commit: "Task 1: Spring Boot scaffold with Maven and Java 21"*)
   - Create `pom.xml` with Spring Boot 3.5.11, Java 21, spring-web dependency, spring-boot-starter-parent
   - Create `src/main/java/com/example/basketquote/Application.java` with `@SpringBootApplication`
   - Create `src/test/java` folder structure
   - Create `.gitignore` for Maven (target/, .mvn/, *.iml, .idea/), IDE, OS files
   - Run `git init`, initial commit
   - Verify: `mvn clean compile` succeeds

2. **Specification & Documentation** (*commit: "Task 2: Project specification and TDD workflow documentation"*)
   - Create `SPEC.md` with 3 acceptance criteria (numbered 1-3), example request/response JSON, HTTP status codes, calculation examples
   - Create `AGENTS.md` documenting TDD Goal Loop workflow, 8 agent responsibilities, orchestration flow
   - Create `lab/expected-slices.md` listing 3 slice sequence matching criteria 1-3
   - Create `lab/evidence.md` empty with header explaining format (structured headers per Q25)
   - Verify: documentation clear, criteria unambiguous

3. **TDD Goal Loop Agents** (*commit: "Task 3: TDD Goal Loop agent framework"*)
   - Create `.claude/agents/tdd-goal-coordinator.md` - orchestrator with simple sequence + error detection (Q41 Option C)
   - Create `.claude/agents/slice-planner.md` - reads expected-slices.md and evidence.md, returns next uncompleted slice
   - Create `.claude/agents/test-writer.md` - writes failing test, DO NOT edit production code rule
   - Create `.claude/agents/red-verifier.md` - confirms compilation succeeds, specific test fails, meaningful failure message
   - Create `.claude/agents/code-writer.md` - implements production code, DO NOT edit tests rule
   - Create `.claude/agents/green-verifier.md` - confirms all tests pass, specific test now green
   - Create `.claude/agents/slice-verifier.md` - re-runs tests, verifies observable API behavior, updates evidence.md
   - Create `.claude/agents/goal-evaluator.md` - reads evidence.md, SPEC.md, runs tests, checks coverage, returns GOAL_MET/NOT_MET/IMPOSSIBLE
   - All agents use YAML frontmatter (name, description) + structured sections (Purpose, Instructions, Rules, Output Format) per Q17
   - Verify: all 8 files have correct structure

4. **Demo Instructions** (*commit: "Task 4: Demo preparation and execution guide"*)
   - Create `README.md` with hybrid structure: Purpose, Project Structure, Running the Demo (prerequisites, walkthrough), Alternative `/goal` Command (future), TDD Goal Loop Agents (descriptions), Acceptance Criteria (link to SPEC.md), Troubleshooting
   - Create `docs/demo-script.md` with step-by-step presentation flow (5 min concept, 3 min docs, 5 min evidence, 3 min tests, 3 min code, 10 min Q&A)
   - Create `docs/troubleshooting.md` with common issues (mvn not found, agents not recognized, test compilation failures) + fixes
   - Verify: someone else could run demo from README

**Phase 2: Execution & Demo (Work Laptop)**

5. **Infrastructure Verification** (*no commit - testing phase*)
   - Clone repo on work laptop
   - Run `mvn clean test` to verify build works
   - Verify Claude Code recognizes `@tdd-goal-coordinator` agent
   - Fix any environment-specific issues
   - Verify: infrastructure ready for execution

6. **Execute TDD Goal Loop** (*commit: "Task 6: TDD Goal Loop execution evidence (3 slices)"*)
   - Invoke `@tdd-goal-coordinator` for slice 1 (sum basket item totals)
   - Invoke `@tdd-goal-coordinator` for slice 2 (reject empty baskets)
   - Invoke `@tdd-goal-coordinator` for slice 3 (reject invalid items - non-positive quantity/price)
   - Verify `lab/evidence.md` contains complete trail with structured headers per Q25 Option A
   - Verify all tests pass (`mvn test`)
   - Commit generated `BasketQuoteController.java`, `BasketQuoteService.java`, `BasketQuoteRequest.java`, `BasketQuoteResponse.java`, `BasketQuoteControllerTest.java`, and `lab/evidence.md`
   - **Create demo branch** for iterations: `git checkout -b demo-refinement`
   - Verify: evidence trail complete, all tests green

7. **Team Demo Execution** (*no commit - presentation only*)
   - Present TDD Goal Loop concept (5 min)
   - Walk through `SPEC.md` and `AGENTS.md` (3 min)
   - Show `lab/evidence.md` trail (5 min)
   - Show generated test code in `BasketQuoteControllerTest.java` (3 min)
   - Show generated production code in controller and service (3 min)
   - Q&A (10 min)

## Relevant Files

**Created in Phase 1 (Personal Laptop):**
- `pom.xml` - Spring Boot 3.5.11, Java 21, Maven project descriptor
- `src/main/java/com/example/basketquote/Application.java` - Spring Boot entry point
- `.gitignore` - Maven, IDE, OS exclusions
- `SPEC.md` - 3 acceptance criteria with examples (criteria 1: sum totals, 2: reject empty, 3: reject invalid items)
- `AGENTS.md` - TDD Goal Loop workflow documentation
- `lab/expected-slices.md` - Predefined slice sequence (3 slices)
- `lab/evidence.md` - Evidence capture file (empty initially)
- `.claude/agents/tdd-goal-coordinator.md` - Main orchestrator (invoked as `@tdd-goal-coordinator`)
- `.claude/agents/slice-planner.md` - Next slice selector
- `.claude/agents/test-writer.md` - Failing test creator
- `.claude/agents/red-verifier.md` - Red confirmation with strict verification (compilation + specific test fails + meaningful message)
- `.claude/agents/code-writer.md` - Production code implementer
- `.claude/agents/green-verifier.md` - Green confirmation with specific test tracking
- `.claude/agents/slice-verifier.md` - Slice completion verifier
- `.claude/agents/goal-evaluator.md` - Goal status evaluator (GOAL_MET/NOT_MET/IMPOSSIBLE)
- `README.md` - Hybrid demo + development guide
- `docs/demo-script.md` - Presentation flow
- `docs/troubleshooting.md` - Common issues + fixes

**Generated in Phase 2 (Work Laptop):**
- `src/main/java/com/example/basketquote/BasketQuoteController.java` - REST controller with `POST /api/basket/quote`
- `src/main/java/com/example/basketquote/BasketQuoteService.java` - Business logic (sum totals, validation, promo codes inline)
- `src/main/java/com/example/basketquote/BasketQuoteRequest.java` - Request DTO: `record BasketQuoteRequest(List<Item> items, String promoCode) { record Item(int quantity, int unitPriceCents) {} }`
- `src/main/java/com/example/basketquote/BasketQuoteResponse.java` - Response DTO: `record BasketQuoteResponse(int subtotalCents, int discountCents, int totalCents) {}`
- `src/test/java/com/example/basketquote/BasketQuoteControllerTest.java` - Single test class with `@WebMvcTest(BasketQuoteController.class)`, ~6-9 tests decomposed from 3 criteria

## Verification

**After Task 1:**
- `mvn clean compile` succeeds
- Git repo initialized with proper `.gitignore`

**After Task 2:**
- `SPEC.md` contains 3 numbered criteria with examples
- `AGENTS.md` documents complete TDD workflow
- `lab/expected-slices.md` lists 3 slices
- `lab/evidence.md` exists with header/instructions

**After Task 3:**
- All 8 agent files exist in `.claude/agents/`
- Each has YAML frontmatter + structured sections
- Instructions reference `SPEC.md`, `AGENTS.md`, `lab/evidence.md`, `lab/expected-slices.md`

**After Task 4:**
- `README.md` covers purpose, structure, demo walkthrough, `/goal` command (future), agents, troubleshooting
- `docs/demo-script.md` has presentation flow
- `docs/troubleshooting.md` has common issues

**After Task 5:**
- `mvn clean test` works on work laptop
- Claude recognizes `@tdd-goal-coordinator`

**After Task 6:**
- `lab/evidence.md` contains structured entries for 3 slices (each with timestamp, agent, status, details per Q25)
- `mvn test` shows all tests passing
- Generated Java files exist and compile
- `BasketQuoteControllerTest.java` uses MockMvc with Spring assertions (no extra dependencies per Q7)
- Demo branch `demo-refinement` created for iterations

**After Task 7:**
- Team has seen working TDD Goal Loop demonstration
- Evidence trail shows red→green→slice→goal cycle for each slice

## Decisions

**Technology Stack:**
- Java 21, Spring Boot 3.5.11, Maven (per java-21-springboot-standards skill)
- Group ID: `com.example`, Artifact ID: `basket-quote-api`
- Package: `com.example.basketquote` (flat structure per Q8)
- Test framework: JUnit 5, MockMvc, Spring built-in assertions only (Q7)
- Build command: `mvn test` (Q13 modified - mvn installed, not wrapper)

**Scope Boundaries:**
- **Included**: 3 acceptance criteria (sum totals, reject empty, reject invalid items), 8 agents, evidence trail, documentation
- **Excluded**: Criteria 4-6 (promo codes), `/goal` command implementation (instructions only), persistence, security, external services
- **Deferred to demo branch**: Demo refinements, presentation polish, Q&A preparation

**TDD Workflow:**
- Slice sequence: Predefined in `lab/expected-slices.md`, strictly followed (Q5)
- Agent invocation: Manual via `@tdd-goal-coordinator` (Q36 Option B)
- Coordinator behavior: Single slice per invocation (Q37, Q41 Option C)
- Evidence format: Structured headers with timestamp, agent, status, details (Q25 Option A)
- Error handling: Write ERROR to evidence.md, coordinator stops, user debugs (Q23, Q41)
- Verification strictness: Red verifier checks compilation + specific test fails + meaningful message; green verifier checks all pass + specific test now green (Q10)
- Test organization: Single `BasketQuoteControllerTest` class, ~6-9 tests decomposed from criteria (Q11, Q22)

**Agent Design:**
- File format: YAML frontmatter (name, description) + sections (Purpose, Instructions, Rules, Output Format) per Q17
- Tool permissions: All agents have standard tools, instruction-only enforcement of "DO NOT edit production code" / "DO NOT edit tests" (Q9)
- Coordinator sophistication: Simple sequence with basic error detection, no automatic retry (Q41 Option C)
- Planner: Reads `lab/expected-slices.md` and `lab/evidence.md`, returns next uncompleted slice from predefined list (Q5)
- Test writer: Cannot edit production code (instruction-based rule)
- Code writer: Cannot edit tests (instruction-based rule)
- Red verifier: Confirms (1) compilation succeeds, (2) specific new test fails, (3) failure message indicates missing implementation (Q10)
- Green verifier: Confirms (1) all tests pass, (2) specific test that was red is now green (Q10)
- Slice verifier: (1) re-runs `mvn test`, (2) verifies observable API behavior, (3) updates evidence.md with slice summary (Q14)
- Goal evaluator: (1) reads evidence.md, (2) reads SPEC.md, (3) runs `mvn test`, (4) checks test code coverage, returns GOAL_MET/NOT_MET/IMPOSSIBLE (Q15)

**Implementation Details:**
- Request DTO: `List<Item> items` + `String promoCode`, Item has `int quantity` + `int unitPriceCents` (Q20 Option A)
- Response DTO: `int subtotalCents` + `int discountCents` + `int totalCents` (Q21 Option A)
- Promo code logic: Inline in `BasketQuoteService` initially, extract private method if needed (Q24)
- Domain model: DTOs only, no separate domain classes (Q12)

**Demo Strategy:**
- Scope: 3 criteria as proof-of-concept (Q33 Option B, Q39 Option A)
- Evidence: Clean slate committed, execute on work laptop, commit results (Q40 Option B)
- Demo branch: Created after Task 6 for iterations (Q40 modification)
- Presentation: Pre-generated evidence walkthrough (Q35 Option B)
- README: Hybrid structure serving demo and development (Q42 Option C)
- `/goal` command: Instructions in README for future branch, not implemented (Q36 modification)

**Task Ordering:**
- Spec before agents (Q43 Option A) - SPEC.md defines requirements, agents reference them
- 4 infrastructure commits on personal laptop before work laptop execution
- Demo branch created after successful Task 6 execution

## Further Considerations

None - frontier empty, plan complete and ready for execution.
