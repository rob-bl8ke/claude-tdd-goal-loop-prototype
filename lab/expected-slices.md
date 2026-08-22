# Expected Slices for TDD Goal Loop

This document defines the predefined slice sequence for implementing the Basket Quote API. Each slice corresponds to one acceptance criterion from SPEC.md and will be implemented in order using the TDD Goal Loop workflow.

---

## Slice 1: Sum basket item totals

**Acceptance Criterion:** 1

**Goal:** Implement the core calculation logic that sums `(quantity × unitPriceCents)` for all basket items

**Entry Condition:** Spring Boot project setup complete, SPEC.md exists

**Test Plan (expected):**
1. Single item basket calculates correct subtotal
2. Multiple items basket sums all item totals
3. Large quantity values calculate correctly
4. Zero discount when no promo code applied

**Deliverables:**
- `BasketQuoteService` (or equivalent) with calculation logic
- `BasketQuoteController` with `POST /api/basket/quote` endpoint
- Request/Response DTOs (`BasketQuoteRequest`, `BasketQuoteResponse`, `BasketItem`)
- Unit tests for calculation logic
- Integration test for happy path (200 OK response)

**Exit Condition:** All tests pass, endpoint returns correct `subtotalCents` and `totalCents` for valid baskets

---

## Slice 2: Reject empty baskets

**Acceptance Criterion:** 2

**Goal:** Add validation to reject baskets with zero items, returning 400 Bad Request

**Entry Condition:** Slice 1 complete (happy path works)

**Test Plan (expected):**
1. Empty basket array returns 400 status
2. Empty basket returns error message "Basket cannot be empty"
3. Existing happy path tests still pass (no regression)

**Deliverables:**
- Validation logic in service or controller
- Exception handling for empty basket
- Error response DTO (if not already created)
- Unit tests for empty basket validation
- Integration test for 400 response with correct error message

**Exit Condition:** All tests pass, endpoint returns 400 for empty baskets, 200 for valid baskets

---

## Slice 3: Reject items with non-positive quantity or unitPriceCents

**Acceptance Criterion:** 3

**Goal:** Add validation to reject basket items with invalid quantity or price, returning 400 Bad Request

**Entry Condition:** Slices 1 and 2 complete (happy path + empty basket validation work)

**Test Plan (expected):**
1. Item with quantity = 0 returns 400 with "quantity must be positive" error
2. Item with quantity < 0 returns 400 with "quantity must be positive" error
3. Item with unitPriceCents = 0 returns 400 with "unitPriceCents must be positive" error
4. Item with unitPriceCents < 0 returns 400 with "unitPriceCents must be positive" error
5. Valid items with positive values still pass (no regression)

**Deliverables:**
- Item validation logic (quantity > 0, unitPriceCents > 0)
- Enhanced error messages for specific validation failures
- Unit tests for item validation edge cases
- Integration tests for various invalid item scenarios

**Exit Condition:** All tests pass, endpoint returns 400 for invalid items, 200 for valid baskets

---

## Workflow Summary

The TDD Goal Loop orchestrator will execute these slices in sequence:

1. **Slice 1** → Implements core functionality (happy path)
2. **Slice 2** → Adds first layer of validation (empty basket)
3. **Slice 3** → Adds second layer of validation (invalid items)

Each slice follows the Red-Green-Refactor cycle enforced by the TDD agents:
- Planner creates test plan
- Test-Writer writes failing tests
- Red-Verifier confirms red
- Code-Writer implements minimal code
- Green-Verifier confirms green
- Slice-Verifier confirms criterion met
- Goal-Evaluator checks if workflow is complete

After Slice 3, all acceptance criteria (1-3) will be implemented and the goal is achieved.
