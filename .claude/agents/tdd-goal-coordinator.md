---
name: tdd-goal-coordinator
description: Entry point for the TDD Goal Loop. Read these instructions and drive the loop yourself in the main context — do not spawn a coordinator subagent.
---

# TDD Goal Loop — Driver Playbook

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

Everything else is `lab/tdd-gate.sh`, a shell script you call with Bash. Verifying red and
green is `mvn test` plus a regex — a fact, not a judgement.

## Deleted agents — do not recreate

Four agents were **deleted** from this repo: `red-verifier`, `green-verifier`,
`slice-verifier` and `slice-planner`. They were LLMs doing `grep`. If you find yourself
about to write one, don't — measured on this repo, same spec, same 10 passing tests:

| | agent version | gate version |
|---|---|---|
| verification + orchestration cost | ~496k tokens | ~2k tokens |
| hallucinated test names | 5 invented | 0 — greps real surefire output |
| wrong file paths reported | yes | 0 |
| real gaps found | 0 | 3 |
| **whole-run total** | **~713k** | **~317k** |

A verifier agent is strictly worse than the gate on every axis: cost, accuracy, and
failure behaviour. The gate cannot hallucinate a test name it did not see, and it exits 1
loudly instead of writing a confident paragraph. Selecting the next slice is
`slices.find(s => !s.done)` against `lab/state.json` — reading, not an agent call.

## The loop

### Step 0 — reset

```bash
./lab/tdd-gate.sh reset
```

Clears `lab/state.json` to all-pending and truncates `lab/evidence.md` to its template.
Confirm `src/test/` and the generated production classes are absent for a from-scratch run.

If `lab/state.json` does not exist, create it from `lab/expected-slices.md`: one entry per
slice with `n`, `title`, `done: false`, plus a top-level `testCount: 0`.

### Step 1 — per slice, in order

Read `lab/state.json` for the first slice where `done` is `false`. Selecting it is
`slices.find(s => !s.done)` — plain reading, not an agent call. Then, three actions:

**1a. Spawn `test-writer`** using the template below. Then:

```bash
export TDD_GATE_LOG="$TMPDIR/tdd-gate-mvn.log"
./lab/tdd-gate.sh red "<expected-failure-substring>"
```

The gate asserts: compiles clean, at least one test fails, and the failure text contains
your expected substring — so a test that fails on a typo instead of on the assertion is
caught. It prints the failure excerpt, which is exactly `code-writer`'s input.

**1b. Spawn `code-writer`**, pasting that excerpt verbatim. Then:

```bash
./lab/tdd-gate.sh green
./lab/tdd-gate.sh done <n> "<comma-separated files touched>"
```

`green` asserts zero failures and that the suite did not shrink. `done` marks the slice
complete and appends a structured evidence entry.

Repeat for every pending slice. Do not parallelise — red must precede green.

### Step 2 — final audit, once

After the last slice, spawn `goal-evaluator` **one time**. Instruct it to be adversarial,
to verify by mutation testing rather than by reading, and to quote actual test method names
rather than paraphrasing. Do not run it per-slice; mid-loop it only restates what
`state.json` already knows.

## Prompt templates

Push context **down**. Inline the criterion; forbid the agent from reading `spec.md`,
`AGENTS.md`, `lab/evidence.md` and `lab/expected-slices.md`. This does not save many
tokens on its own — measured at +11% versus terse prompts — but it reliably prevents scope
creep, and it cut `test-writer` tool calls from 12 to 3–4.

### test-writer

> Write failing tests ONLY. Do not create or modify any production code — another agent
> does that. Everything you need is below; do not read `spec.md`, `AGENTS.md`,
> `lab/evidence.md` or `lab/expected-slices.md`.
>
> **Acceptance criterion N — \<title\>**: \<GIVEN/WHEN/THEN, verbatim from spec.md, plus the
> example request/response JSON and status code\>
>
> **Write exactly these K tests**: \<numbered list with concrete values and expected results\>
>
> **File**: \<path\>, package `com.example.basketquote`. \<On slices after the first, list the
> existing test method names and say to leave them untouched.\>
>
> **Conventions**: JUnit 5 + MockMvc, `should<Expected>When<Condition>` naming plus
> `@DisplayName`, GIVEN/WHEN/THEN comments, Java 21, Spring Boot 3.5.11.
>
> **Critical**: the file MUST COMPILE before any production code exists. Post the request as
> a **raw JSON string literal** and assert with `jsonPath`, so the test references no
> production types.
>
> **Expected failure**: \<e.g. `Status expected:<200> but was:<404>`\>
>
> Do NOT run `mvn test` — a deterministic gate verifies red. Confirm with
> `mvn -B clean test-compile` and report the test method names you wrote.

Note: `mvn -B test-compile` without `clean` can report "Nothing to compile" after a fresh
edit due to timestamp granularity. Always pass `clean`.

### code-writer

> Write the minimum production code to make these failing tests pass, without breaking the
> ones that already pass. Everything you need is below; do not read `spec.md`, `AGENTS.md`,
> `lab/evidence.md` or `lab/expected-slices.md`.
>
> **Current failures (from `mvn test`)**: \<paste the gate's excerpt verbatim\>
>
> **Required behaviour — criterion N only**: \<the behaviour, exact error strings, status codes\>
>
> **Scope discipline**: implement ONLY the above. Name the later slices' concerns explicitly
> and forbid them — later slices drive those with their own failing tests.
>
> **Existing production code**: \<list the classes; tell it to read the relevant ones first\>
>
> **Conventions**: Java 21 records for DTOs, constructor injection, thin controller with
> logic in the service, custom exception plus `@ExceptionHandler` for validation errors.
>
> Do NOT run `mvn test` — a deterministic gate verifies green. Report the files you touched.

## When a gate fails

The gate exits 1 and prints why. **Stop the loop and report to the user.** Do not retry
automatically and do not patch the test to make it pass. A red gate that fails on a
compile error means the test-writer referenced a type that does not exist yet; a green gate
that still shows failures means the implementation is incomplete or a regression landed.

## Known open issue

Tests currently use plain `@WebMvcTest`, which excludes `@Service` beans from scanning, so
`BasketQuoteService` ends up wired as a `@Bean` on `Application`. That works and all tests
pass, but production wiring is being shaped by a test-slice constraint, and no test boots
the real application context. The fix — `@Service` plus either
`@WebMvcTest(Controller.class) @Import(Service.class)` or `@SpringBootTest` — is a pending
follow-up, deliberately not folded into this playbook so that re-runs reproduce the
measured result.

## Reporting

When every slice is done and the final audit is in, report: slices completed, real
`mvn test` numbers, any gaps the audit found, and the run's token cost. Never claim a test
name or file path you have not seen in actual command output.
