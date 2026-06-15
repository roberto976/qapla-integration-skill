---
source: https://api.qapla.dev
synced: 2026-06-15
api_versions: [1.2, 1.3]
---

# Qapla' API — Shipments Reference

Base URL: `https://api.qapla.it/{version}/`
Auth: private API key per channel, passed as `apiKey` in every request.
Rate limit: token-bucket, capacity 120, refill 2 tokens/second. A batch of N shipments consumes N tokens.

---

## 1. pushShipment — Ingest a shipped parcel

**Purpose:** Register one or more already-shipped parcels that have courier tracking numbers. Once ingested, Qapla' polls the carrier and drives transactional communications (email, SMS) and the tracking portal.

**Method + path:** `POST https://api.qapla.it/1.3/pushShipment/`

**Batch limit:** 100 shipments per request.

### Deduplication key

A shipment is uniquely identified by the composite **(channel x courier x trackingNumber)**. Submitting the same triple again updates the existing record rather than creating a duplicate.

### Required fields (minimum viable push)

| Field | Type | Notes |
|---|---|---|
| `apiKey` | string | Channel private API key |
| `trackingNumber` | string | Carrier waybill / tracking number |
| `courier` | string | Qapla' carrier code (e.g. `"DHL"`, `"GLS-ITA"`) |
| `shipDate` | string | Ship date, `YYYY-MM-DD` |

> **Always pass `courier` explicitly.** Omitting it or passing an unrecognised value returns `"Invalid courier"` at the per-shipment level. Do not rely on auto-detection from the tracking number format — it is fragile and not guaranteed.

### Recommended fields (needed to activate communications)

| Field | Type | Notes |
|---|---|---|
| `reference` | string | Your order reference |
| `name` | string | Recipient full name |
| `email` | string | Recipient email — required for email notifications |
| `telephone` | string | Recipient phone — required for SMS notifications |

### Selected optional fields

| Field | Type | Notes |
|---|---|---|
| `street`, `city`, `ZIP`, `state`, `country` | string | Delivery address; `country` is ISO 3166-1 alpha-2 |
| `orderDate` | string | `YYYY-MM-DD` |
| `language` | string | ISO 639-1; defaults to `it` if absent or unrecognised |
| `amount` | float | Shipment value (e.g. COD amount) |
| `pod` | boolean | `true` for cash-on-delivery shipments |
| `isReturnable` | boolean | `true` marks the entire shipment as eligible for return; can also be set per row item in `rows[]` |
| `tag` | string | Free-text grouping label |
| `custom1`–`custom3` | string | Arbitrary metadata fields |
| `origin` | string | Platform identifier (e.g. `"magento"`, `"woocommerce"`, `"shopify"`) |
| `isTrackingNumber` | boolean | `true` when `trackingNumber` contains the real carrier tracking number; `false` when it is a reference or placeholder |

### Multi-collo (multiple parcels) — `parcels[]`

| Field | Type | Notes |
|---|---|---|
| `weight` | float | Required when `boxCode` is absent |
| `length`, `width`, `height` | float | Required when `boxCode` is absent |
| `boxCode` | string | Pre-configured box reference; dimensions inferred from it |
| `originCountry` | string | ISO 3166-1 alpha-2 |
| `content` | string | Contents description |

### PUDO (pickup/drop-off point) — `pudo` object

| Field | Type | Notes |
|---|---|---|
| `id` | string | **Required** — pickup point identifier |
| `type` | string | Service type |
| `name` | string | Point name |
| `address`, `city`, `state`, `country`, `postalCode` | string | Point location |
| `description` | string | Additional notes |

The response field `deliveryMode` reflects whether the delivery resolved as `"home"` or `"pickup"`.

### JSON request example

```json
{
  "apiKey": "YOUR_CHANNEL_API_KEY",
  "pushShipment": [
    { "trackingNumber": "123987299", "courier": "DHL", "shipDate": "2026-03-15" },
    {
      "trackingNumber": "1Z0V5V416840696736",
      "courier": "UPS",
      "shipDate": "2026-03-15",
      "reference": "ORD-1674",
      "name": "Jane Smith",
      "email": "jane@example.com",
      "telephone": "+393331234567",
      "street": "Via Roma, 10",
      "city": "Milano",
      "ZIP": "20100",
      "state": "MI",
      "country": "IT",
      "language": "it",
      "isReturnable": true,
      "parcels": [
        { "weight": 1.3, "length": 30, "width": 20, "height": 10, "originCountry": "IT" }
      ]
    }
  ]
}
```

### Response example

```json
{
  "pushShipment": {
    "result": "OK",
    "error": null,
    "count": 2,
    "imported": 2,
    "shipments": [
      {
        "result": "OK", "error": null, "id": 9999999,
        "trackingNumber": "123987299", "courier": "DHL",
        "url": "https://tracking.qapla.it/27e7cefc788a11e9bfc60cc47acaffd0Q!",
        "hash": "27e7cefc788a11e9bfc60cc47acaffd0Q!"
      }
    ]
  }
}
```

The outer `result` is `"OK"` even when individual shipments fail — always inspect each item's `result`. A per-shipment failure looks like:

```json
{ "result": "KO", "error": "Invalid courier", "courier": "BADCODE", "trackingNumber": "123456" }
```

### Gotchas

- **Batch token cost:** 100 shipments in one call consumes 100 rate-limit tokens.
- **Deduplication is composite:** changing only `reference` or `email` on a re-push updates the record; changing `courier` or `trackingNumber` creates a new one.
- **`isReturnable`** at the shipment level enables the return flow for the whole parcel; set `rows[].isReturnable` for per-item eligibility.
- **`isTrackingNumber: false`** signals the value in `trackingNumber` is a placeholder, not a real carrier code; Qapla' will not poll the carrier until a real tracking number is associated.
- Without `email` and/or `telephone`, transactional communications are not sent regardless of channel settings.

---

## 2. getCompanyShipments — Retrieve all company shipments for a day

**Purpose:** Pull all shipments across every channel of a company for a given calendar day. Useful for daily reconciliation. Unlike per-channel `getShipments`, this uses a company-level API key.

**Method + path:** `GET https://api.qapla.it/1.3/getCompanyShipments/`

### Parameters

| Parameter | Type | Default | Notes |
|---|---|---|---|
| `apiKey` | string | — | **Required.** Company-level API key (not a single-channel key) |
| `shipDate` | string | — | Filter by ship date, `YYYY-MM-DD` |
| `orderDate` | string | — | Filter by order date, `YYYY-MM-DD` |
| `dateIns` | string | today | Filter by import/insertion date, `YYYY-MM-DD` |
| `data` | string | — | Pass `"history"` to include full tracking event history per shipment (expensive) |
| `lang` | string | `"it"` | Status label language: `it`, `en`, `es` |

**Only one date filter is applied per request.** If multiple are supplied, precedence is `shipDate` → `orderDate` → `dateIns`. No pagination parameters are exposed; for incremental pulls prefer `trackingByTimeFrame`.

### Request example

```
GET https://api.qapla.it/1.3/getCompanyShipments/?apiKey=YOUR_COMPANY_KEY&shipDate=2026-03-15&lang=en
```

### Response example

```json
{
  "getCompanyShipments": {
    "result": "OK", "error": null, "count": 1,
    "shipments": [
      {
        "id": "000000000042", "reference": "ORD-1674", "trackingNumber": "123987299",
        "origin": "woocommerce", "isDeleted": false, "isArchived": false,
        "courier": { "code": "DHL", "name": "DHL Express", "icon": "https://cdn.qapla.it/couriers/dhl.png" },
        "statusID": 3, "shipDate": "2026-03-15", "orderDate": "2026-03-12",
        "dateIns": "2026-03-15 09:14:00", "language": "it"
      }
    ]
  }
}
```

With `data=history`, each shipment gains a `trackingHistory` array of `{ date, dateISO, status, place, qaplaStatus }` entries.

### Gotchas

- **Company key vs channel key:** requires a company-scoped key; a single-channel key returns only that channel or an auth error.
- **`data=history` is expensive** — only request it when needed.
- **`isDeleted` / `isArchived`** are present on every record; soft-deleted/archived shipments are included — filter client-side if unwanted.
- No cursor or offset exists — the endpoint always returns the full day.

---

## 3. trackingByTimeFrame — Poll for status changes in a time window

**Purpose:** Retrieve all shipments whose **tracking status changed** within a given date-time range. This is the pull-based alternative to outbound webhooks.

**Method + path:** `GET https://api.qapla.it/1.2/trackingByTimeFrame/`

> **Note:** This endpoint is on API version `1.2`, not `1.3`.

### Pull vs push — choosing the right approach

| | trackingByTimeFrame (pull) | Webhook (push) |
|---|---|---|
| Trigger | Your scheduler calls the API | Qapla' calls your endpoint on each event |
| Latency | Up to your poll interval | Near real-time |
| Infrastructure | None beyond a cron/scheduler | You must expose a public HTTPS endpoint |
| Rate cost | Counts against token bucket | No API calls on your side |
| Reliability | You control retry logic | Qapla' retries on failure |

Use **webhooks** (see [webhooks.md](webhooks.md)) for near real-time updates with a stable endpoint. Use **trackingByTimeFrame** for batch reconciliation or where inbound webhooks are not feasible.

### Parameters

| Parameter | Type | Default | Notes |
|---|---|---|---|
| `apiKey` | string | — | **Required.** Channel API key |
| `dateFrom` | string | 1 hour ago | Start of status-change window, `YYYY-MM-DD HH:MM:SS` |
| `dateTo` | string | now | End of status-change window, `YYYY-MM-DD HH:MM:SS` |
| `lang` | string | `"it"` | Status label language: `it`, `en`, `es` |

**The date range filters on the status-change timestamp, not on order date or ship date.** A shipment created months ago appears if its status changed within the window.

### Request example

```
GET https://api.qapla.it/1.2/trackingByTimeFrame/?apiKey=YOUR_KEY&dateFrom=2026-03-15%2008:00:00&dateTo=2026-03-15%2009:00:00&lang=en
```

### Response example

```json
{
  "trackingByTimeFrame": {
    "result": "OK", "error": null, "version": "1.2.4", "count": 1,
    "shipments": [
      {
        "id": "000000000042", "reference": "ORD-1674", "trackingNumber": "123987299",
        "origin": "woocommerce", "courier": "DHL",
        "status": {
          "dateISO": "2026-03-15 08:30:00", "status": "IN TRANSIT", "place": "BOLOGNA",
          "qaplaStatus": { "id": 3, "status": "IN TRANSIT", "color": "#1D76D8" }
        },
        "dateUpd": "2026-03-15 08:31:07"
      }
    ]
  }
}
```

The response contains the **most recent status** at the time of the update, not the full history.

### Gotchas

- **Filter semantics:** `dateFrom`/`dateTo` bound when Qapla' recorded the status change (`dateUpd`), not ship/order date.
- **Rate limit:** each call costs one token. Polling every 30 s against a 120-token bucket (2/s refill) is sustainable; leave headroom.
- **No pagination:** keep windows short (≤ 1 hour) for high-volume channels.
- **Overlap your windows slightly** (e.g. subtract 60 s from `dateFrom` vs the previous `dateTo`) to guard against gaps from clock skew.
- **Channel-scoped:** returns only shipments for the channel of the supplied key; call once per channel.

---

## 4. Virtual courier — tracking-only mode for merchant-generated labels

**Purpose:** Enables merchants/integrators who generate their own labels (outside Qapla') to still benefit from Qapla' tracking, communications, and analytics without using Qapla' label generation.

### Concept

The virtual courier pattern decouples label generation from tracking:

1. Your system (or a third-party tool) generates the label and obtains a tracking number from the carrier.
2. You push that tracking number to Qapla' via `pushShipment`, passing the real carrier code in `courier`.
3. Qapla' treats the record as tracking-only: it polls the carrier, updates statuses, fires transactional communications, and exposes the tracking page — without having created the label.

This is the core pattern for platforms with existing carrier contracts that only want to delegate post-shipment tracking and customer communications to Qapla'.

### How to implement it

- Use `pushShipment` with a real `trackingNumber` and a real `courier` code.
- Set `isTrackingNumber: true` to signal the value is a genuine carrier tracking number ready to poll.
- Omit label-generation calls (`createLabel`, `confirmLabel`) entirely.
- Provide `email` / `telephone` to enable the transactional communications that are the primary value-add.

### Gotchas

- The virtual courier pattern is a **usage pattern of `pushShipment`**, not a separate endpoint. The `courier` code must be a valid Qapla' carrier code.
- If the tracking number is not yet available at order time, push with `isTrackingNumber: false` as a placeholder and update later once the real number is known.
- Standard `pushShipment` deduplication rules apply (channel x courier x trackingNumber).
