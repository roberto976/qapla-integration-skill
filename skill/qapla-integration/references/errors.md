---
source: https://api.qapla.dev
synced: 2026-06-15
api_versions: [1.2, 1.3]
---

# Error Handling & Response Envelope

## Response envelope

Every Qapla' API response — success or failure — is wrapped in a named object keyed by the endpoint:

```json
{
  "<API_NAME>": {
    "result": "OK",
    "error": null
  }
}
```

| Field | Type | Values |
|-------|------|--------|
| `result` | string | `"OK"` or `"KO"` |
| `error` | string \| null | `null` on success; human-readable message on failure |

**Top-level error** (the whole request was rejected — bad auth, malformed body, rate limit):

```json
{
  "pushShipment": {
    "result": "KO",
    "error": "Invalid API key"
  }
}
```

## Batch endpoints: outer OK ≠ all items OK

`pushShipment` and `pushOrder` are batch endpoints. The **outer** `result` reflects whether the request itself was accepted; each item in the response carries its **own** `result`/`error`.

**You must inspect every item — do not rely only on the outer `result`.**

### pushShipment — mixed batch (one item fails)

```json
{
  "pushShipment": {
    "result": "OK",
    "error": null,
    "count": 2,
    "imported": 1,
    "shipments": [
      {
        "result": "OK",
        "error": null,
        "id": 9999999,
        "courier": "DHL",
        "trackingNumber": "123987299"
      },
      {
        "result": "KO",
        "error": "Invalid courier"
      }
    ]
  }
}
```

The outer `result` is `"OK"` but `imported` is `1`, not `2`. The second shipment silently failed — only visible by iterating `shipments[]`.

### pushOrder — upsert summary

```json
{
  "pushOrder": {
    "result": "OK",
    "error": null,
    "imported": 1,
    "updated": 0
  }
}
```

`pushOrder` does not return a per-item array; use the `imported` / `updated` counters to detect partial failures when sending multiple orders.

---

## HTTP-level errors

| HTTP status | Meaning | Action |
|-------------|---------|--------|
| `200` | Request accepted (check `result` in body) | Inspect body |
| `400` | Malformed request (missing required field, bad JSON) | Fix and resend |
| `401` / `403` | Missing or invalid `apiKey` | Check the key; do not retry automatically |
| `429` | Rate limit exceeded (token bucket exhausted) | Back off — see below |
| `5xx` | Transient server error | Retry with exponential back-off |

### Rate limiting — token bucket

- **Capacity**: 120 tokens
- **Refill rate**: 2 tokens/second
- **Cost**: each item in a batch counts as 1 token (100-shipment batch = 100 tokens)
- **When exhausted**: HTTP `429` with body `"error": "Too Many Requests"`
- **Repeated abuse**: permanent API key ban

**Recommended back-off**: on `429`, wait `ceil((tokens_needed - available) / 2)` seconds (derived from refill rate). A safe default is exponential back-off starting at 5 s, capped at 60 s, with up to 3 retries.

```
429 received → wait 5s → retry → 429 again → wait 10s → retry → give up after 3 attempts
```

---

## Idempotency and deduplication

### pushShipment — deduplicated on (channel × courier × trackingNumber)

Sending the same tracking number on the same channel+courier combination a second time **updates** the existing shipment rather than creating a duplicate. This makes retries safe: if your request succeeds server-side but you never received the response (network timeout), resending will update — not duplicate — the record.

What changes on re-send: any mutable fields you include (e.g. order reference, consignee data) are overwritten. Immutable identity fields (channel, courier, trackingNumber) remain unchanged.

### pushOrder — upsert keyed on `reference`, gated by `updatedAt`

`pushOrder` performs an upsert:

- **Key**: the `reference` field (your order ID)
- **Guard**: the `updatedAt` timestamp — if the incoming `updatedAt` is older than or equal to the stored value, the record is **not** overwritten

This means retries are safe as long as you resend the same `updatedAt`. If the server updated the record between your original send and your retry (e.g. via a platform sync), your older timestamp will be silently ignored — check the `updated` counter in the response.

**Safe retry pattern**:
1. On timeout or `5xx`, resend the identical payload (same `reference`, same `updatedAt`).
2. Check `imported` + `updated` in the response to confirm the record was touched.

---

## Retryable vs fatal errors

| Category | Examples | Retryable? | Action |
|----------|----------|------------|--------|
| Rate limit | HTTP 429, "Too Many Requests" | Yes | Exponential back-off (see above) |
| Transient server error | HTTP 5xx | Yes | Back-off, up to 3 attempts |
| Network timeout | No response received | Yes | Resend identical payload (dedup/upsert protects you) |
| Authentication failure | HTTP 401/403, "Invalid API key" | No | Fix the key; auto-retry will not help |
| Validation error | "Invalid courier", missing required field | No | Fix the request data before resending |
| Permanent abuse ban | Key banned after repeated 429s | No | Contact Qapla' support |

---

## Common errors quick-reference

| Error | Likely cause | Fix |
|-------|-------------|-----|
| `"Invalid courier"` | Courier code not recognised by Qapla' | Use a valid courier code from the `/getCouriers` endpoint or the [Couriers' Codes](https://api.qapla.dev) reference |
| `"Invalid API key"` / HTTP 401-403 | Key missing, wrong, or sent to wrong channel | Retrieve the Private API Key from Control Panel → Settings → Channels → Configure |
| `"Too Many Requests"` / HTTP 429 | Token bucket exhausted | Apply exponential back-off; reduce batch frequency; batch up to 100 items per call to amortise token cost |
| Missing required field | `trackingNumber`, `courier`, or `reference` absent | Review endpoint schema; ensure all required fields are present and non-empty |
| `result: "KO"` on an item inside a batch with outer `result: "OK"` | Individual item validation failed | Iterate every item in `shipments[]`; collect and log per-item errors; do not assume outer OK means full success |
| Shipment not created on re-send | Dedup matched existing record | Expected behaviour — the existing record was updated; verify with `getShipment` |
| Order not updated on re-send | Incoming `updatedAt` ≤ stored value | Resend with the correct (current) `updatedAt` or check whether a later update already superseded yours |
