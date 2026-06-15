---
source: https://api.qapla.dev
synced: 2026-06-15
api_versions: [1.2, 1.3]
---

# Qapla' Shipments API — Integration Reference

Covers four developer-facing surfaces:

1. **pushShipment** — insert shipments for tracking + transactional notifications
2. **getCompanyShipments** — list all company shipments by date
3. **trackingByTimeFrame** — poll for status changes in a time window
4. **Virtual courier** — merchant-owned status events via `POST /1.3/virtual/`

API host: `https://api.qapla.it`

---

## 1. pushShipment

### Purpose

Register shipments in Qapla' tracking without using Qapla' label printing. The merchant supplies their own tracking numbers; Qapla' activates carrier monitoring and transactional notifications (email/SMS) to the recipient.

### Method + Path

```
POST https://api.qapla.it/1.3/pushShipment/
Content-Type: application/json
```

(v1.2 path: `/1.2/pushShipment/` — same business logic, fewer fields; see Differences section.)

### Authentication

Per-channel API key. Pass in one of three ways:

- JSON body field `"apiKey": "<key>"`
- Header `X-API-Key: <key>`
- Query string `?apiKey=<key>`

The key identifies the channel; all inserted shipments are linked to that channel automatically.

### Rate Limiting

Token bucket: 120 tokens max, refills at 2 tokens/second. Each shipment in the batch consumes 1 token. Batch max: 100 shipments. HTTP 429 when exceeded.

### Request Body

```json
{
  "apiKey": "[API_KEY]",
  "pushShipment": [
    {
      "trackingNumber": "123987299",
      "courier": "DHL",
      "shipDate": "2024-08-01"
    },
    {
      "trackingNumber": "1Z0V5V416840696736",
      "courier": "UPS",
      "shipDate": "2024-08-02",
      "reference": "ord. # 1674",
      "orderDate": "2024-07-30",
      "name": "Pepito Sbazzeguti",
      "street": "Via Aieie, 99",
      "city": "Parnazza",
      "ZIP": "12345",
      "state": "MZ",
      "country": "IT",
      "email": "name@domain.ext",
      "telephone": "02342522",
      "amount": 150.00,
      "pod": false,
      "shipping": 8.00,
      "language": "it",
      "deliveryMode": "home",
      "isReturnable": true,
      "tag": "vip-customer",
      "note": "Leave at door",
      "custom1": "value1",
      "custom2": "value2",
      "custom3": "value3",
      "rows": [
        {
          "sku": "BAR-301",
          "name": "Oat bar 120g",
          "qty": 1,
          "price": 6.35,
          "total": 6.35,
          "url": "https://shop.example.com/bar",
          "imageUrl": "https://shop.example.com/bar.jpg"
        }
      ]
    }
  ]
}
```

### Fields

#### Root

| Field | Type | Notes |
|-------|------|-------|
| `apiKey` | string | **Required** |
| `pushShipment` | array | **Required**. Max 100 shipments |
| `source` | string | Optional. Import source tag (e.g. `"magento"`, `"amazon"`). Default: `"pushShipment"` |

#### Per-shipment — Required

| Field | Type | Constraints |
|-------|------|-------------|
| `trackingNumber` | string | Max 50 chars, non-empty |
| `courier` | string | Qapla' courier code (e.g. `"DHL"`, `"GLS-ITA"`, `"BRT"`) |
| `shipDate` | string | `YYYY-MM-DD` |

#### Per-shipment — For transactional notifications

| Field | Type | Notes |
|-------|------|-------|
| `reference` | string | Order reference shown to recipient |
| `name` | string | Recipient full name |
| `email` | string | Recipient email (required for email notifications) |
| `telephone` | string | Recipient phone (required for SMS notifications) |

Without `email` / `telephone` the shipment is still created and tracked; notifications are simply not sent.

#### Per-shipment — Optional

| Field | Type | Notes |
|-------|------|-------|
| `orderDate` | string | `YYYY-MM-DD` |
| `street` | string | Delivery address |
| `city` | string | Delivery city |
| `ZIP` | string | Delivery postal code |
| `state` | string | Province/state code |
| `country` | string | ISO 3166-1 alpha-2 (default: `"IT"`) |
| `agent` | string | Merchant commercial contact email |
| `amount` | float | Cash-on-delivery amount |
| `pod` | bool | `true` = cash on delivery |
| `shipping` | float | Shipping cost |
| `language` | string | ISO 639-1 (e.g. `"it"`, `"en"`, `"fr"`). Default: `"it"` |
| `deliveryMode` | string | `"home"` (default) or `"pickup"` — use `"pickup"` for PUDO/collection-point shipments |
| `isReturnable` | bool | Eligible for return. Default: `true` |
| `isTrackingNumber` | bool | `false` if the value is an internal reference that may be replaced by the carrier. Default: `true` |
| `platformOrderID` | string | Order ID on the external platform |
| `tag` | string | Free label for grouping shipments |
| `note` | string | Free note, max 255 chars |
| `custom1`–`custom3` | string | Free custom fields |
| `deliveryDate` | string | Requested delivery date, `YYYY-MM-DD` |
| `latestShipDate` | string | Latest allowed ship date (Amazon), `YYYY-MM-DD` |
| `latestDeliveryDate` | string | Latest allowed delivery date (Amazon), `YYYY-MM-DD` |
| `parcels` | int or array | Number of parcels (int) or per-parcel dimensions (array of objects — see below) |
| `origin` | string | Marketplace origin (e.g. `"amazon"`, `"ebay"`) |
| `rows` | array | Order line items (see below) |

**PUDO / pickup-point delivery**: set `deliveryMode = "pickup"`. There is no separate top-level `pudo` object. The recipient postal code for the pickup point is the standard `ZIP` field.

#### `parcels` as array (multi-parcel, v1.3 only)

```json
"parcels": [
  { "weight": 2.5, "length": 40, "width": 30, "height": 20 },
  { "weight": 1.0, "length": 20, "width": 20, "height": 15 }
]
```

| Field | Type | Notes |
|-------|------|-------|
| `weight` | float | Required when `boxCode` is absent |
| `length` | float | Required when `boxCode` is absent |
| `width` | float | Required when `boxCode` is absent |
| `height` | float | Required when `boxCode` is absent |
| `boxCode` | string | Pre-configured box code; dimensions are read from the box registry |
| `content` | string | Description of parcel contents |
| `originCountry` | string | ISO 3166-1 alpha-2 |

#### `rows` — order line items

| Field | Type | Notes |
|-------|------|-------|
| `sku` | string | Required per row (rows without sku are ignored) |
| `name` | string | Item description |
| `qty` | int | Quantity |
| `price` | float | Unit price |
| `total` | float | Line total |
| `url` | string | Product URL |
| `imageUrl` | string | Image URL |
| `weight` | float | Item weight |
| `isReturnable` | bool | Default: `true` |
| `customsCode` | string | HS/TARIC code |
| `originCountry` | string | ISO 3166-1 alpha-2 |
| `netWeight` | float | Net weight |
| `unitOfMeasurement` | string | Unit of measure |
| `parcelID` | int | Sequential parcel number this item belongs to |
| `transparencyCodes` | array | Amazon Transparency codes (array of strings) |
| `custom1`–`custom5` | string | Custom fields |

### Courier Resolution

The `courier` field is resolved in priority order:

1. Channel-specific transcodification code (merchant's internal code mapped to a Qapla' courier)
2. Official Qapla' courier code (e.g. `"DHL"`, `"GLS-ITA"`, `"BRT"`, `"VIRTUAL"`)
3. Courier full name

If unresolvable → `"Invalid courier"` error for that row.

Courier variants (sub-codes under a parent courier) must be explicitly enabled per channel, or the request returns `"Courier '<code>' is not configured for this channel"`.

### Deduplication

Before inserting, Qapla' checks whether the combination of channel + courier + tracking number already exists. If the shipment already exists, that row returns:

```json
{
  "result": "KO",
  "error": "shipment already exists",
  "trackingNumber": "123987299",
  "courier": "DHL"
}
```

The duplicate is **not** silently updated or merged — it is rejected for that row. The existing shipment is unchanged. Other rows in the same batch continue to be processed.

### Response

HTTP 200 always (including per-row errors). The outer `result` is `"KO"` only for global failures (invalid JSON, invalid API key).

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
        "url": "https://tracking.qapla.it/27e7cefc788a11e9bfc60cc47acaffd0Q!",
        "hash": "27e7cefc788a11e9bfc60cc47acaffd0Q!",
        "courier": "DHL",
        "trackingNumber": "123987299"
      },
      {
        "result": "KO",
        "error": "shipment already exists",
        "courier": "UPS",
        "trackingNumber": "1Z0V5V416840696736",
        "reference": "ord. # 1674"
      }
    ]
  }
}
```

| Field | Type | Notes |
|-------|------|-------|
| `result` (root) | string | `"OK"` / `"KO"` — `"KO"` only on global errors |
| `count` | int | Shipments submitted |
| `imported` | int | Shipments successfully inserted |
| `shipments[].result` | string | `"OK"` or `"KO"` per row |
| `shipments[].id` | int | Internal shipment ID (on success) |
| `shipments[].url` | string | Public tracking page URL |
| `shipments[].hash` | string | Shipment hash identifier |

### Validation Errors (per row)

| Condition | Error message |
|-----------|--------------|
| `trackingNumber` empty | `"Tracking Number is empty"` |
| `trackingNumber` > 50 chars | `"Tracking Number > 50 char"` |
| `courier` empty | `"Courier is empty"` |
| `courier` not found | `"Invalid courier"` |
| Courier variant not enabled on channel | `"Courier '<code>' is not configured for this channel"` |
| `shipDate` missing | `"shipDate field is null"` |
| `shipDate` wrong format | `"invalid shipDate format: <value>"` |
| `orderDate` wrong format | `"invalid orderDate format: <value>"` |
| Duplicate shipment | `"shipment already exists"` |
| `source` value not in allowed list | `"invalid origin: <value>"` |

### v1.2 vs v1.3 differences

| Aspect | v1.2 | v1.3 |
|--------|------|------|
| Multi-parcel `parcels` array | Not supported | Supported |
| `rows` customs fields | Not supported | `customsCode`, `originCountry`, `netWeight`, `unitOfMeasurement`, `parcelID`, `custom1`–`custom5`, `transparencyCodes` |
| `source` normalisation | Standard | `"teamsystemcommerce"` → `"storeden"` |

### Gotchas

- Tracking activation is asynchronous — carrier polling begins at the next scheduler cycle after insert (typically seconds to a few minutes).
- With `source = "amazon"`, Qapla' triggers an immediate "shipment received" notification (status 1) to the recipient. All other sources trigger the first notification only on the first real carrier status change.
- Shipments inserted with courier `VIRTUAL` follow a different tracking path — see section 4.

---

## 2. getCompanyShipments

### Purpose

List shipments across **all channels belonging to the same company** (azienda) for a given date. Useful for multi-channel merchants who want a single call instead of iterating per channel.

### Method + Path

```
GET https://api.qapla.it/1.3/getCompanyShipments/
```

### Authentication

Per-channel API key. The filter, however, applies to the **company** (azienda) that owns the channel identified by the key — not just that single channel. There is no separate company-level key; any active channel key from the company works.

### Parameters

| Param | Notes |
|-------|-------|
| `dateIns` | Filter by insertion date |
| `shipDate` | Filter by ship date |
| `orderDate` | Filter by order date |
| `lang` | Language code for translated status labels |
| `data=history` | Include full tracking history per shipment |

Use only one date filter per request. If none is provided, defaults to today.

### Response

Envelope with `count` and `shipments[]`. Each shipment object includes a `getCompanyShipment` link to the single-shipment detail endpoint. With `data=history`, each object also contains the full tracking history.

### When to Use

- Reconcile all shipments created across multiple storefronts/channels in a single API call for a specific date.
- For **status-change polling** (what changed since last check), use `trackingByTimeFrame` instead — `getCompanyShipments` filters by a fixed date field, not by recency of status update.

### Gotchas

- The date filter is **inclusive for the whole day** when only a date is passed (no time component).
- The endpoint filters for active shipments only; archived/soft-deleted records are excluded.

---

## 3. trackingByTimeFrame

### Purpose

Return all shipments in the channel whose tracking **status changed** within a time window. This is the pull-based alternative to outbound webhooks for integrators who prefer polling.

### Method + Path

```
GET https://api.qapla.it/1.2/trackingByTimeFrame/
```

### Authentication

Per-channel API key.

### Parameters

| Param | Default | Format | Notes |
|-------|---------|--------|-------|
| `dateFrom` | now − 1 hour | `YYYY-MM-DD HH:MM:SS` or `YYYY-MM-DD` | If date-only, extended to `00:00:00` |
| `dateTo` | today `23:59:59` | `YYYY-MM-DD HH:MM:SS` | |
| `lang` | — | ISO 639-1 | Language for Qapla' status label translation |

Invalid date formats return an explicit error (`"invalid dateFrom"` / `"invalid dateTo"`).

### How the Filter Works

The window applies to `dateUpd` — the timestamp of the **last status change** recorded by Qapla'. This is exposed in the response as `dateUpd`. The filter is **not** on ship date, insertion date, or order date.

Only active shipments that have not been manually closed/verified by the merchant are returned.

Each shipment object includes:

- `reference`, `trackingNumber`, `courier`, `origin`
- `shipDate`, `orderDate`, `dateIns`, `dateUpd`
- `status` object: raw carrier status, Qapla' normalised status (id, name, detail, colour), and relevant timestamps

### Recommended Polling Pattern

```
dateFrom = <timestamp of previous poll>
dateTo   = <now>
```

Store `dateTo` from each successful response as `dateFrom` for the next call. With a 1-hour cron, omitting `dateFrom` returns the last hour of changes by default.

### Gotchas

- A shipment appears in the response **every time its status changes**, not just once. If you poll frequently, deduplicate on `trackingNumber` + `dateUpd`.
- Delivered/final-state shipments that the merchant has marked as closed (`verificato = 1`) are excluded even if their `dateUpd` falls within the window.
- `trackingByTimeFrame` reads Qapla'-computed statuses, not live carrier data — there is a small lag between carrier events and Qapla' processing.

---

## 4. Virtual Courier

### What It Is

**VIRTUAL** is a real Qapla' courier (`courier code: VIRTUAL`, internal id: 217). It is designed for merchants who manage their own fulfilment logistics and push status events directly to Qapla' via API, rather than having Qapla' poll a carrier.

Qapla' does **not** contact any carrier for VIRTUAL shipments. The tracking page and transactional notifications (email/SMS) work exactly as they do for carrier-integrated shipments — the only difference is the data source for status events.

### Typical Use Case

A merchant with proprietary last-mile logistics:

1. Registers a shipment via `POST /1.3/pushShipment/` using `"courier": "VIRTUAL"`.
2. At each logistics event (picked up, in transit, delivered, etc.), calls `POST /1.3/virtual/` to push a status event.
3. Qapla' updates the tracking page and triggers transactional notifications to the recipient.

### Registering a VIRTUAL Shipment

Use `pushShipment` exactly as for any other courier:

```json
{
  "apiKey": "[API_KEY]",
  "pushShipment": [
    {
      "trackingNumber": "SP000000000001",
      "courier": "VIRTUAL",
      "shipDate": "2024-08-01",
      "name": "Recipient Name",
      "email": "recipient@example.com",
      "reference": "ORD-5001"
    }
  ]
}
```

### Pushing Status Events

```
POST https://api.qapla.it/1.3/virtual/
Content-Type: application/json
```

```json
{
  "apiKey": "[API_KEY]",
  "virtual": [
    {
      "trackingNumber": "SP000000000001",
      "statusID": 20,
      "statusDetailID": 0,
      "status": "In delivery",
      "place": "Milan (MI)",
      "date": "2024-08-02 09:30:00",
      "note": "Out for morning delivery"
    }
  ]
}
```

Max 100 events per request.

#### Event Fields

| Field | Type | Notes |
|-------|------|-------|
| `trackingNumber` | string | **Required**. Must match a shipment registered via pushShipment |
| `statusID` | int | **Required**. Qapla' status ID (see status reference) |
| `statusDetailID` | int | Optional detail/sub-status ID |
| `status` | string | Human-readable status label (displayed on tracking page) |
| `place` | string | Location of the event |
| `date` | string | Event timestamp `YYYY-MM-DD HH:MM:SS` |
| `note` | string | Free note |

Each pushed event is appended to the shipment's tracking history. Qapla' updates the shipment's current status and triggers transactional notifications (email/SMS/webhook) exactly as it would for a carrier-integrated shipment.

### Authentication

Per-channel API key (same as pushShipment).

### How VIRTUAL Differs from Regular Couriers

| Aspect | Regular courier | VIRTUAL |
|--------|----------------|---------|
| Carrier polling | Qapla' polls carrier API/scraping | **Never** — no external call |
| Status source | Carrier response | Merchant pushes via `POST /1.3/virtual/` |
| pushShipment | Registers shipment + activates carrier polling | Registers shipment only |
| Tracking page & notifications | Populated by Qapla' tracking | Populated by merchant event pushes |
| Courier code | e.g. `"DHL"`, `"GLS-ITA"` | `"VIRTUAL"` |

### Gotchas

- VIRTUAL must be enabled as a courier on the channel before use, like any other courier.
- If a VIRTUAL shipment has been registered but no events pushed yet, the tracking page shows a synthetic "waiting" entry so recipients always see something.
- The `statusID` values are Qapla' normalised status IDs, not carrier-specific codes. Consult the Qapla' status reference for the correct IDs for delivered, in-transit, exception, etc.
- VIRTUAL shipments are excluded from Qapla' carrier polling queues — do not expect automatic status updates.
