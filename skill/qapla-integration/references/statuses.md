---
source: https://api.qapla.dev
synced: 2026-06-15
api_versions: [1.2, 1.3]
---

# Qapla' Status Model — Developer Reference

## Two-Layer Status Architecture

Every tracking event in Qapla' carries **two status representations simultaneously**:

| Layer | Field | Description |
|---|---|---|
| **Raw courier status** | `courierStatus` | Exact text or code as reported by the carrier — varies by courier, locale, and API version. |
| **Canonical Qapla' status** | `qaplaStatus` object | Normalized, carrier-agnostic status with a stable numeric `id`, human-readable label, color, and optional sub-state detail. |

**Key rule for developers:** always branch your logic on the canonical `qaplaStatus.id` (or `qaplaStatusID` in webhook payloads), never on raw `courierStatus` strings. Raw courier strings are unstable across carriers and carrier API versions. The canonical `id` is the stable, versioned contract.

---

## Canonical Status ID Table

The following table is the authoritative list of Qapla' status IDs. These IDs are permanent and stable across all API versions.

| id | code | Label (IT) | Color | Has sub-states | Notes |
|----|------|-----------|-------|----------------|-------|
| 0 | — | Da tracciare | `#ecf0f1` | no | Shipment queued; carrier has not yet provided a tracking event. |
| 10 | `PICKUP` | Fermo deposito | `#FFDE00` | no | Parcel available for collection at a pickup point. |
| 20 | `PROCESSED` | Preso in carico | `#35495e` | no | Carrier has collected the parcel. |
| 30 | `IN_TRANSIT` | In transito | `#1D76D8` | no | Parcel is moving through the carrier network. |
| 40 | `DELAY` | Ritardo | `#e9be57` | no | Delivery is delayed beyond the estimated date. |
| 50 | `OUT_FOR_DELIVERY` | In consegna | `#376600` | yes | Last-mile delivery in progress. See sub-states below. |
| 60 | `FAILED_ATTEMPT` | Tentativo fallito | `#FF6E00` | no | Carrier attempted delivery; recipient was unavailable. |
| 70 | `EXCEPTION` | Anomalia | `#970D00` | yes | Carrier exception (lost, damaged, customs hold, etc.). See sub-states. |
| 90 | `DEPARTED` | Partita | `#8A2BE2` | no | Legacy: parcel dispatched/departed hub (used by older integrations). |
| 95 | `RETURNED` | Rientrata | `#620000` | no | Parcel is being returned to sender. |
| 99 | `DELIVERED` | Consegnata | `#66cc00` | no | Confirmed delivery to recipient. Primary trigger for review-request flows. |

> Retrieve the live list at any time via `GET /1.3/getQaplaStatus/?apiKey=YOUR_KEY&lang=en`. Pin these IDs at integration time; do not hard-code label strings — they are translated.

### Known Sub-states

For statuses with **Has sub-states = yes**, an optional `detailID` qualifies the status further:

| Parent id | detailID | code | Meaning |
|-----------|----------|------|---------|
| 50 | 1 | `CUSTOMS` | Parcel held in customs. |
| 50 | 3 | — | Out for delivery with delay. |
| 70 | 1 | `STOCK` | Parcel held in carrier depot (giacenza). |
| 70 | 2 | `RETURN` | Parcel being returned to sender. |
| 70 | 3 | `DAMAGED` | Parcel damaged. |
| 70 | 4 | `LOST` | Parcel lost. |
| 70 | 5 | `PARTIAL_DELIVERY` | Partial delivery (multi-collo shipment). |

---

## The `qaplaStatus` Object in API Responses

Wherever the API returns status information — `getShipment`, `getCompanyShipments`, `trackingByTimeFrame` — the canonical status appears as a nested `qaplaStatus` object:

```json
{
  "qaplaStatus": {
    "id": 30,
    "status": "IN TRANSIT",
    "detailID": 0,
    "detail": null,
    "color": "#1D76D8",
    "icon": "https://cdn.qapla.it/status/30.svg"
  }
}
```

| Field | Type | Notes |
|---|---|---|
| `id` | integer | Stable numeric ID — use this for branching logic. |
| `status` | string | Human-readable label in the language selected via `lang`. |
| `detailID` | integer | Sub-classification ID (0 = none). |
| `detail` | string\|null | Sub-state label text, or `null` when `detailID` is 0. |
| `color` | string | Hex color for UI display. |
| `icon` | string | URL to the status icon (`https://cdn.qapla.it/status/{id}.svg`). |

---

## Status Fields in Webhook Payloads

When Qapla' fires a webhook on a status change, the payload includes both layers:

```json
{
  "orderReference": "RIF-12345",
  "trackingNumber": "BRT1234567890",
  "courierCode": "BRT",
  "courierStatus": "CONSEGNATO",
  "statusID": 99,
  "status": "DELIVERED",
  "statusDate": "2026-06-15 10:42:00",
  "trackingPageUrl": "https://mtk.qapla.it/<hash>",
  "history": []
}
```

| Webhook Field | Type | Description |
|---|---|---|
| `courierStatus` | string | Raw status text from the carrier — do not branch on this. |
| `statusID` | integer | **Canonical status ID** — use this for branching. Maps directly to the `id` column in the table above. |
| `status` | string | Human-readable canonical label (language follows workspace settings). |
| `statusDate` | string | Timestamp of the status event (`YYYY-MM-DD HH:MM:SS`). |

> **Important:** branch exclusively on `statusID` (integer). Do not parse or compare `status` label strings, which are locale-dependent and may change.

Webhook delivery is configurable per workspace: a workspace can subscribe only to specific `statusID` values (e.g. only `50` and `99`) via the control panel. Webhooks not matching the configured filter are not delivered.

---

## Multilingual Status Labels

Qapla' returns human-readable status labels in three languages, controlled by the `lang` query parameter:

| Value | Language |
|---|---|
| `it` | Italian (default when omitted) |
| `en` | English |
| `es` | Spanish |

The `lang` parameter is accepted on:

- `GET /1.2/trackingByTimeFrame/`
- `GET /1.3/getShipment/`
- `GET /1.3/getCompanyShipments/`
- `GET /1.3/getQaplaStatus/`

The numeric `id` and `color` are language-independent and never change. Only the `status` label string is affected by `lang`.

**Use case:** pass `lang` matching the end-customer's locale when rendering a tracking page or composing a notification. Store the numeric `id` in your database for business logic — never the translated label.

---

## Recommended Integration Patterns

### Polling (`trackingByTimeFrame`)

```
GET https://api.qapla.it/1.3/trackingByTimeFrame/?apiKey=…&dateFrom=2026-06-15T08:00:00&dateTo=2026-06-15T09:00:00&lang=en
```

Returns all shipments whose status changed within the window (filtered on `dataStatus`). Suitable for near-real-time polling. Rate limit: 120-token bucket, refill 2 tokens/second.

### Branching on canonical ID

```js
// Always compare against the integer id, not the label string.
switch (shipment.qaplaStatus.id) {
  case 99: markDelivered(shipment); break;
  case 95: flagReturned(shipment); break;
  case 60: scheduleRetry(shipment); break;
  case 70: raiseException(shipment, shipment.qaplaStatus.detailID); break;
}
```

### Confirming the full status list

```
GET https://api.qapla.it/1.3/getQaplaStatus/?apiKey=YOUR_KEY&lang=en
```

Run this at integration time to obtain all active status objects with their current metadata. Pin the `id` values; do not pin label strings.
