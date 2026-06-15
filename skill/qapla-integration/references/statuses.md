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
| **Raw courier status** | `courierStatus` | Exact text or code as reported by the carrier — varies by courier, locale, and integration. |
| **Canonical Qapla' status** | `qaplaStatus` object | Normalized, carrier-agnostic status with a numeric `id`, label, color, and icon. |

**Key rule for developers:** always branch your logic on the canonical `qaplaStatus.id` (or `qaplaStatusID` in webhook payloads), never on raw `courierStatus` strings. Raw courier strings are unstable across carriers and carrier API versions. The canonical status is the stable, versioned contract.

---

## The `qaplaStatus` Object

Wherever the API returns status information — `getShipment`, `getCompanyShipments`, `trackingByTimeFrame`, history arrays — the canonical status appears as a nested `qaplaStatus` object:

```json
{
  "qaplaStatus": {
    "id": 3,
    "status": "IN TRANSIT",
    "detailID": 0,
    "detail": null,
    "color": "#1D76D8",
    "icon": "https://cdn.qapla.it/status/3.svg"
  }
}
```

| Field | Type | Notes |
|---|---|---|
| `id` | integer | Stable numeric ID — use this for branching. |
| `status` | string | Human-readable label in the language selected via `lang`. |
| `detailID` | integer | Optional sub-classification (0 = none). |
| `detail` | string\|null | Optional detail text (e.g. `"GIACENZA"` for storage hold). |
| `color` | string | Hex color for UI display. |
| `icon` | string | URL to SVG icon (`https://cdn.qapla.it/status/{id}.svg`). |

---

## Canonical Status Lifecycle

The table below shows the main lifecycle states. **IDs listed here are confirmed from the live API documentation**; always cross-check against the live status list (call `GET /getQaplaStatus/` with your API key) as Qapla' may add sub-states over time.

| Canonical State | Confirmed ID(s) | Typical `color` | Meaning |
|---|---|---|---|
| Order received / pending | ~0–1 | grey | Order known to Qapla', shipment not yet booked or tracking not yet active. Confirm exact IDs via `/getQaplaStatus/`. |
| Shipment created / info received | ~2 | grey/blue | Label created; carrier has not scanned the parcel yet. |
| In transit | **3** | `#1D76D8` (blue) | Parcel moving through the carrier network. |
| Departed (hub/sort) | **20** | `#8A2BE2` (purple) | Parcel departed from a logistics hub. |
| Out for delivery | **4** | orange | Last-mile delivery attempt in progress. |
| Delivered | **99** | `#66CC00` (green) | Confirmed delivery to recipient. |
| Exception / failed delivery | ~6 | red | Delivery attempt failed, address issue, or carrier exception. Confirm ID via `/getQaplaStatus/`. |
| In storage / giacenza | sub-state of exception | red/amber | Parcel held at carrier depot (appears as `detail: "GIACENZA"` in `statusDetails`). |
| Returned to sender | ~95 | dark red | Carrier is returning the parcel. Confirm ID via `/getQaplaStatus/`. |

> **Note:** IDs 3, 4, 20, and 99 are confirmed from the API. IDs for pending, exception, returned, and storage states are approximate — verify them by calling `GET /1.2/getQaplaStatus/` or `GET /1.3/getQaplaStatus/` with a valid API key.

### `statusDetails` sub-states

Some canonical statuses carry an optional `statusDetails` array with additional granularity:

```json
"statusDetails": [
  { "id": 12, "detail": "GIACENZA" }
]
```

Use `statusDetails[].detail` to differentiate sub-cases (e.g. storage hold vs. generic exception) without parsing free-text courier strings.

---

## Multilingual Status Messages

Qapla' provides human-readable status labels in three languages, selected via the `lang` query parameter:

| Value | Language |
|---|---|
| `it` | Italian (default when omitted) |
| `en` | English |
| `es` | Spanish |

The `lang` parameter is supported on:

- `GET /1.2/getShipment/` — single shipment lookup
- `GET /1.2/getCompanyShipments/` (v1.3 cross-channel variant)
- `GET /1.2/trackingByTimeFrame/` — bulk status-change polling
- `GET /1.3/getCompanyShipment/` and `GET /1.3/getCompanyShipments/`

When `lang=en` is set, the `qaplaStatus.status` field returns English text (e.g. `"IN TRANSIT"` instead of `"IN TRANSITO"`). The numeric `id` and `color` are language-independent and always stable.

**Use case:** pass `lang` matching the end-customer's locale when rendering a tracking page or composing a notification; store the numeric `id` in your database for logic, not the translated label.

---

## Status Fields in Webhook Payloads

When Qapla' fires a webhook on a status change, the payload includes both layers:

```json
{
  "courierStatus": "CONSEGNATO",
  "qaplaStatusID": "99",
  "qaplaStatus": "DELIVERED",
  "place": "MILANO MI",
  "date": "2026-06-15 10:42:00",
  "statusDetails": []
}
```

| Webhook Field | Type | Description |
|---|---|---|
| `courierStatus` | string | Raw status text from the carrier — do not branch on this. |
| `qaplaStatusID` | string | Numeric canonical status ID as a string — cast to int for comparison. |
| `qaplaStatus` | string | Human-readable canonical label (language depends on workspace settings). |
| `place` | string | Location reported by the carrier, if available. |
| `date` | string | Status timestamp as reported by the carrier (`YYYY-MM-DD HH:MM:SS`). |
| `statusDetails` | array | Optional sub-state objects with `id` and `detail`. |

> **Important:** `qaplaStatusID` arrives as a **string** in webhook payloads (e.g. `"99"`). Cast it to an integer before comparing to the numeric IDs in the table above.

---

## Status Fields in API Responses

For `trackingByTimeFrame` and `getCompanyShipments`, each shipment object in the `shipments[]` array contains the `qaplaStatus` nested object (see structure above). When `data=history` is requested on `getCompanyShipments`, the `trackingHistory[]` array contains one entry per event, each with its own `qaplaStatus` object and `courierStatus` string.

### Polling pattern: `trackingByTimeFrame`

```
GET /1.2/trackingByTimeFrame/?apiKey=…&dateFrom=2026-06-15T08:00:00&dateTo=2026-06-15T09:00:00&lang=en
```

Returns all shipments whose status changed within the window. Suitable for near-real-time polling. Rate limit: 120-token bucket, refill 2 tokens/second; batch calls consuming 100 tokens count as 100 requests.

---

## Confirming the Full Status List

To retrieve the authoritative, up-to-date list of all canonical status IDs and their metadata for your integration:

```
GET https://api.qapla.dev/1.2/getQaplaStatus/?apiKey=YOUR_API_KEY&lang=en
```

This returns all active `qaplaStatus` objects. Run this at integration time (and pin the results) rather than hard-coding IDs from documentation alone.
