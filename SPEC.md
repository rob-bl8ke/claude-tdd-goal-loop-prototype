# Basket Quote API Specification

## Endpoint

`POST /api/basket/quote`

## Request Format

```json
{
  "items": [
    {
      "quantity": 2,
      "unitPriceCents": 500
    }
  ],
  "promoCode": null
}
```

## Response Format

```json
{
  "subtotalCents": 1000,
  "discountCents": 0,
  "totalCents": 1000
}
```

## HTTP Status Codes

- `200 OK` — Successful quote calculation
- `400 Bad Request` — Validation failure (empty basket or invalid items)

---

## Acceptance Criteria

### 1. Sum basket item totals

**Given** a basket with one or more valid items  
**When** the quote is calculated  
**Then** the `subtotalCents` must equal the sum of `(quantity × unitPriceCents)` for all items

**Example calculation:**
```
Item 1: 2 × 500 = 1000 cents
Item 2: 3 × 250 = 750 cents
─────────────────────────────
Subtotal: 1750 cents
```

**Request:**
```json
{
  "items": [
    {"quantity": 2, "unitPriceCents": 500},
    {"quantity": 3, "unitPriceCents": 250}
  ],
  "promoCode": null
}
```

**Response:**
```json
{
  "subtotalCents": 1750,
  "discountCents": 0,
  "totalCents": 1750
}
```

**Status:** `200 OK`

---

### 2. Reject empty baskets

**Given** a basket with zero items  
**When** a quote is requested  
**Then** the API must return a validation error

**Request:**
```json
{
  "items": [],
  "promoCode": null
}
```

**Response:**
```json
{
  "error": "Basket cannot be empty"
}
```

**Status:** `400 Bad Request`

---

### 3. Reject items with non-positive quantity or unitPriceCents

**Given** a basket with any item where `quantity ≤ 0` or `unitPriceCents ≤ 0`  
**When** a quote is requested  
**Then** the API must return a validation error

**Example: Invalid quantity**
```json
{
  "items": [
    {"quantity": 0, "unitPriceCents": 500}
  ],
  "promoCode": null
}
```

**Response:**
```json
{
  "error": "Item quantity must be positive"
}
```

**Status:** `400 Bad Request`

**Example: Invalid price**
```json
{
  "items": [
    {"quantity": 2, "unitPriceCents": -100}
  ],
  "promoCode": null
}
```

**Response:**
```json
{
  "error": "Item unitPriceCents must be positive"
}
```

**Status:** `400 Bad Request`

---

## Scope

This specification covers **Criteria 1-3 only** (proof-of-concept).

**Deferred to future:**
- Criteria 4-6 (promo code handling and discount logic)
