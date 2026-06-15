---
source: https://api.qapla.dev
synced: 2026-06-15
api_versions: [1.2, 1.3]
---

# CheckAddress

## Purpose

CheckAddress validates, standardizes, and geocodes a recipient address before label creation. Use it to catch malformed or undeliverable addresses at order time rather than discovering the problem when the carrier rejects the shipment or charges an address-correction fee.

> **Version note:** CheckAddress is documented under API v1.3. No equivalent endpoint exists in v1.2.

## Invocation model

CheckAddress is a **callable POST endpoint** — it is not an automatic step during order import. You call it explicitly whenever you want to validate an address (e.g., at checkout, before calling `addOrders`, or in a nightly batch).

**Endpoint:** `POST https://api.qapla.it/1.3/checkAddress/`

**Authentication:** Pass your channel `apiKey` in the request body.

**Metered / requires activation:** Every call is counted and billed. The service must be enabled for your account — contact Qapla' Customer Care before using it in production.

## Request

```json
{
  "apiKey": "YOUR_CHANNEL_API_KEY",
  "checkAddress": {
    "street":     "Via Aldo Moro 4",
    "city":       "Marciano Della Chiana",
    "postalCode": "52047",
    "province":   "AR",
    "country":    "IT"
  }
}
```

| Field                      | Required | Type   | Notes                                              |
|----------------------------|----------|--------|----------------------------------------------------|
| `apiKey`                   | Yes      | string | Channel API key                                    |
| `checkAddress.street`      | Yes      | string | Street name and civic number                       |
| `checkAddress.city`        | Yes      | string | Destination city                                   |
| `checkAddress.country`     | Yes      | string | ISO 3166-1 alpha-2 (e.g. `IT`, `GB`, `FR`)        |
| `checkAddress.postalCode`  | No       | string | Postal / ZIP code                                  |
| `checkAddress.province`    | No       | string | Province or state abbreviation                     |

## Response

```json
{
  "version": "1.3.2",
  "result": "OK",
  "error": null,
  "elapsedTime": 0.3169,
  "checkAddress": {
    "formatted": "Via del Foro Boario, 4, 52045 Foiano della Chiana AR, Italia",
    "components": {
      "street":    "Via del Foro Boario, 4",
      "city":      "Foiano della Chiana",
      "postCode":  "52045",
      "province":  "AR",
      "country":   "IT",
      "region":    null
    },
    "coordinates": {
      "latitude":  43.24952,
      "longitude": 11.81943
    },
    "match": {
      "partial":    true,
      "status":     "NONE",
      "confidence": 77.67
    }
  }
}
```

### Key response fields

| Field                          | Type    | Description                                                                 |
|--------------------------------|---------|-----------------------------------------------------------------------------|
| `result`                       | string  | `"OK"` on success; `"KO"` on failure                                        |
| `error`                        | string  | `null` on success; error description on failure                             |
| `checkAddress.formatted`       | string  | Full address standardized to destination-country conventions                |
| `checkAddress.components.*`    | object  | Corrected individual fields: `street`, `city`, `postCode`, `province`, `country`, `region` |
| `checkAddress.coordinates`     | object  | Geocoded position: `latitude` and `longitude` (float)                      |
| `match.status`                 | string  | Correspondence level: `FULL`, `WARNING`, or `NONE`                         |
| `match.confidence`             | float   | Match percentage 0.0–100.0 — higher is better                              |
| `match.partial`                | boolean | `true` when only part of the submitted address could be matched             |

### Interpreting `match.status`

| Status    | Meaning                                                              |
|-----------|----------------------------------------------------------------------|
| `FULL`    | Submitted address matched the standardized record completely         |
| `WARNING` | Address was matched but differences were found; review `components` |
| `NONE`    | No confident match; corrected fields and coordinates may differ significantly from input — inspect before using |

A low `confidence` score (or `status: NONE`) does **not** mean the call failed (`result` will still be `OK`); it means the geocoding engine made its best guess. Always check both `status` and `confidence` before passing the corrected address downstream.

## Integration tips

- **Call before `addOrders`:** Validate addresses at the earliest opportunity (ideally at checkout) to avoid carrier rejection fees.
- **Use `components` for label data:** Prefer the corrected `components` fields over your original input when constructing the shipment payload.
- **Log `confidence` and `match.status`:** A `WARNING` or `NONE` with low confidence is a signal to queue the order for human review rather than auto-creating the label.
- **Metering:** Each HTTP call to this endpoint is one billable check, regardless of the outcome. Do not call it in speculative loops.

## Live documentation

See the full, authoritative reference at [https://api.qapla.dev](https://api.qapla.dev).
