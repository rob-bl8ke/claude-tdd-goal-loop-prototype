---
name: tdd-goal-coordinator
description: Entry point for the TDD Goal Loop. Read these instructions and drive the loop yourself in the main context — do not spawn a coordinator subagent.
---

# TDD Goal Loop — Driver Playbook

Reusable boilerplate. The loop below is stack-agnostic; the only project-specific
parts are the **Project profile** at the bottom of this file and the configuration
block in `lab/tdd-gate.sh`.

## Read this first

**You are the driver.** These instructions execute in *your own* context. Do NOT spawn a
`tdd-goal-coordinator` subagent. A subagent cannot loop — it stops at the end of every
turn — so driving from one costs a full context round-trip per step and buys no autonomy.
A previous run did exactly that and spent 142k tokens on orchestration alone.

Spawn exactly three kinds of agent, and only these:

| Agent | When | Why it must be an agent |
|---|---|---|
| `test-writer` | once per slice | judgement: turn a criterion into failing tests |
| `code-writer` | once per slice | judgement: minimal code to pass them |
| `goal-evaluator` | **once, at the very end** | judgement: adversarial audit vs the spec |

Everything else is `lab/tdd-gate.sh`, which you call with Bash. Verifying red and green is
the test command plus a regex — a fact, not a judgement.

## Deleted agents — do not recreate

Four agents were **deleted** from this repo: `red-verifier`, `green-verifier`,
`slice-verifier`, `slice-planner`. They were LLMs doing `grep`. If you find yourself about
to write one, don't — measured on this repo, same spec, same passing suite:

| | agent version | gate version |
|---|---|---|
| verification + orchestration | ~496k tokens | ~2k tokens |
| whole run | **~713k** | **~310k** |
| hallucinated test names | 5 invented | 0 |
| real gaps found | 0 | 3 |

A verifier agent is strictly worse on cost, accuracy and failure behaviour. The gate cannot
hallucinate a test name it did not see, and it exits 1 loudly instead of writing a confident
paragraph. Selecting the next slice is `slices.find(s => !s.done)` against
`lab/state.json` — reading, not an agent call.

---

## Bootstrapping a new spec

1. **Read the spec.** Each acceptance criterion becomes one slice. Order them so each builds
   on the last: happy path first, then validation layers. Do not fold two criteria into one
   slice — the gate's red phase needs a single clear expected failure.
2. **Create the state file:**
   ```bash
   TDD_GOAL="<what this run delivers>" ./lab/tdd-gate.sh init "<slice 1 title>" "<slice 2 title>" ...
   ```
3. **Point the gate at your test runner.** Set `TDD_TEST_CMD` and adapt the three parser
   functions in `lab/tdd-gate.sh`. Recipes for pytest, jest, go and cargo are in that file.
4. **Fill in the Project profile** at the bottom of this playbook.
5. **Smoke-test the gate before running the loop:**
   ```bash
   ./lab/tdd-gate.sh red "anything"     # on a repo with no tests yet
   ```
   This MUST exit 1. If it exits 0, your `parse_counts` is wrong and every gate will
   silently pass — which is worse than no gate at all, because it looks like verification.

## The loop

### Step 0 — reset

```bash
./lab/tdd-gate.sh reset
export TDD_GATE_LOG="$TMPDIR/tdd-gate-tests.log"
```

### Step 1 — per slice, in order

Read `lab/state.json`, take the first slice where `done` is `false`, then:

**1a. Spawn `test-writer`** (template below). Then assert red:

```bash
./lab/tdd-gate.sh red "<expected-failure-substring>"
```

The gate asserts: compiles clean, at least one test fails, and the failure text contains
your expected substring — so a test failing on a typo rather than on its assertion is
caught. It prints the failure excerpt, which is exactly `code-writer`'s input.

**1b. Spawn `code-writer`**, pasting that excerpt verbatim. Then:

```bash
./lab/tdd-gate.sh green
./lab/tdd-gate.sh done <n> "<comma-separated files touched>"
```

The green gate asserts: compiles clean, zero failures, zero skipped, and the count of
*executed* tests did not shrink. The skip check matters because the runner's headline
"Tests run" includes skipped tests — without it, disabling a red test reads as progress.

Repeat for every pending slice. Do not parallelise — red must precede green.

### Step 2 — final audit, once

After the last slice, spawn `goal-evaluator` **one time**. Require it to:

- run the suite itself and report real numbers
- quote actual test method names, never paraphrase
- **verify by mutation** — break each guard, confirm a specific test fails, restore
- leave the repo byte-identical

Mutation testing is what makes this agent worth its cost. On this repo it killed 11 of 11
mutants and found a surviving one the whole suite missed. Do not run it per-slice; mid-loop
it only restates what `state.json` already knows.

---

## Prompt templates

Push context **down**: inline the criterion, and forbid reading `spec.md`, `AGENTS.md`,
`lab/evidence.md` and `lab/expected-slices.md`. This does not save many tokens on its own —
measured at +11% versus terse prompts — but it reliably prevents scope creep and cut
`test-writer` tool calls from 12 to 3.

### test-writer

> Write failing tests ONLY. Do not create or modify any production code — another agent does
> that. Everything you need is below; do not read `spec.md`, `AGENTS.md`, `lab/evidence.md`
> or `lab/expected-slices.md`.
>
> **Acceptance criterion N — \<title\>**: \<GIVEN/WHEN/THEN verbatim from the spec, plus the
> example request/response and status codes\>
>
> **Write exactly these K tests**: \<numbered list, concrete values, expected results\>
>
> **File**: \<path and package\>. \<After slice 1, list existing test names and say to leave
> them untouched, including load-bearing class-level annotations.\>
>
> **Conventions**: \<paste from the Project profile below\>
>
> **Critical**: the test must be able to run and fail before any production code exists — see
> the Project profile for how this project achieves that.
>
> **Expected failure**: \<the exact substring you will pass to the gate\>
>
> **Name tests honestly** — a name or display name must not claim coverage the assertions do
> not provide. \<If a criterion has an "any element" clause, require at least one test where
> the offending element is NOT first.\>
>
> Do NOT run the tests — a deterministic gate verifies red. Confirm compilation only, and
> report the test method names you wrote.

### code-writer

> Write the minimum production code to make these failing tests pass, without breaking the
> ones that already pass. Everything you need is below; do not read `spec.md`, `AGENTS.md`,
> `lab/evidence.md` or `lab/expected-slices.md`.
>
> **Current failures**: \<paste the gate's excerpt verbatim\>
>
> **Required behaviour — criterion N only**: \<behaviour, exact error strings, status codes\>
>
> **Scope discipline**: implement ONLY the above. Name the later slices' concerns explicitly
> and forbid them — later slices drive those with their own failing tests.
>
> **Existing production code**: \<list the files; say which to read first\>
>
> **Conventions**: \<paste from the Project profile below\>
>
> Do NOT run the tests — a deterministic gate verifies green. Report the files you touched.

## When a gate fails

The gate exits 1 and prints why. **Stop the loop and report to the user.** Do not retry
automatically, and never edit a test to make it pass. A red gate failing on a compile error
means `test-writer` referenced a type that does not exist yet; a green gate still showing
failures means the implementation is incomplete or a regression landed.

## Reporting

Report: slices completed, real test numbers from actual output, any gaps the audit found,
and the run's token cost. Never state a test name or file path you have not seen in command
output — the retired verifier agents did exactly that, five times in one run.

---

## Project profile

**Edit this section per project. It is the only stack-specific part of this playbook.**

- **Stack** — Java 21, Spring Boot 3.5.11, Maven, JUnit 5 + MockMvc.
- **Test command** — `mvn -B clean test`, which is the gate's built-in default; you do not
  need to export `TDD_TEST_CMD`. `clean` is load-bearing: incremental `test-compile` can
  report "Nothing to compile" after a fresh edit due to timestamp granularity, and the gate
  would then grade the previous build's output.
- **Test file** — `src/test/java/com/example/basketquote/BasketQuoteControllerTest.java`,
  package `com.example.basketquote`. Production code is the same package, flat.
- **Test conventions** — `should<Expected>When<Condition>` method naming plus
  `@DisplayName`; GIVEN / WHEN / THEN comments in each body.
- **Compiling before production code exists** — this is the one real friction point in a
  statically-typed language. Post the request as a **raw JSON text block** and assert with
  `jsonPath`, so the test references no production type. Use plain `@WebMvcTest` with no
  controller class argument for slice 1, since that class does not exist yet.
- **Wiring** — once the service exists, annotate it `@Service` and add
  `@Import(TheService.class)` to the test class. Do NOT declare it as a `@Bean` on the
  application class: that lets a test-slice constraint distort production wiring.
  `@RestControllerAdvice` needs no `@Import` — `@WebMvcTest` already includes it.
  `code-writer` may edit the test class **for wiring only**, never an assertion.
- **Production conventions** — records for DTOs, constructor injection, thin controllers with
  logic in services, custom exception plus `@ExceptionHandler` for validation errors, `long`
  for money.
- **Known blind spot** — every test is a `@WebMvcTest` slice, so no test boots the real
  application context. Deleting `@Service` leaves the whole suite green while the real app
  fails to start. A one-line `@SpringBootTest contextLoads()` test would close it.
