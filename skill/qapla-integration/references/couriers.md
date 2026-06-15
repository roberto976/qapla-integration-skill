---
source: https://api.qapla.dev
synced: 2026-06-15
api_versions: [1.2, 1.3]
---

# Qapla' API — Couriers Reference

Base URL for all requests: `https://api.qapla.it/{version}/{endpoint}/`
Authentication: pass your channel's **API Key** in every request body (field `apiKey`).
Rate limit: token-bucket, capacity 120, refill 2 req/s. Exceeding returns HTTP 429.

This file covers three courier-facing utilities:

| Endpoint | Version | Method |
|---|---|---|
| `getQuotes` | 1.3 | POST |
| `getPudos` | 1.3 | POST |
| `detectCourier` | 1.3 | GET |

---

## 1. getQuotes

**Purpose:** Request real-time shipping price quotes from multiple couriers simultaneously for a given shipment, before committing to a label.

**Method + path:** `POST /1.3/getQuotes/`

### Required fields

| Field | Type | Notes |
|---|---|---|
| `apiKey` | string | Channel API key |
| `getQuotes.reference` | string | Unique identifier for this quote request. Alphanumeric plus `-`, `_`, `.`; 3–255 characters. Must be unique per call — reuse may cause deduplication surprises. |
| `getQuotes.recipient.zipCode` | string | Mandatory for all EU destinations. |
| `getQuotes.recipient.province` | string | Mandatory for Italian (`IT`) destinations. |
| `getQuotes.recipient.country` | string | ISO 3166-1 alpha-2 (e.g. `IT`, `DE`, `FR`). |
| `getQuotes.parcels` | array | At least one parcel object required. |
| `getQuotes.parcels[].weight` | float | Weight in kg. Required per parcel. |
| `getQuotes.parcels[].width` | float | Width in cm. Required per parcel. |
| `getQuotes.parcels[].height` | float | Height in cm. Required per parcel. |
| `getQuotes.parcels[].length` | float | Length in cm. Required per parcel. |
| `getQuotes.amountShipment` | float | Declared shipment value. Mandatory. |

### Optional fields

| Field | Type | Notes |
|---|---|---|
| `getQuotes.recipient.address` | string | Street address; improves zone matching. |
| `getQuotes.recipient.city` | string | City name. |
| `getQuotes.amountCash` | float | Cash-on-delivery (COD) amount. Triggers COD service quotes. |
| `getQuotes.amountInsurance` | float | Insured value, if requesting insurance add-on quotes. |
| `getQuotes.currency` | string | ISO 4217 currency code. Defaults to `EUR`. |
| `getQuotes.couriers` | array of strings | Restrict results to a specific subset of courier codes (e.g. `["GLS-ITA", "DHL"]`). Omit to get all available quotes. |

### Compact request example

```json
POST /1.3/getQuotes/
{
  "apiKey": "YOUR_API_KEY",
  "getQuotes": {
    "reference": "QUOTE-2026-001",
    "recipient": {
      "country": "IT",
      "zipCode": "20121",
      "province": "MI"
    },
    "parcels": [
      { "weight": 1.5, "width": 20, "height": 15, "length": 30 }
    ],
    "amountShipment": 49.90,
    "amountCash": 0,
    "currency": "EUR"
  }
}
```

### Compact response example

```json
{
  "response": {
    "getQuotes": [
      {
        "courierCode": "GLS-ITA",
        "courierName": "GLS Italy",
        "serviceCode": "COURIER",
        "serviceName": "GLS Courier",
        "price": 5.80,
        "currency": "EUR",
        "deliveryDays": 1
      },
      {
        "courierCode": "DHL",
        "courierName": "DHL Express",
        "serviceCode": "EXPRESS",
        "serviceName": "DHL Express",
        "price": 12.40,
        "currency": "EUR",
        "deliveryDays": 1
      }
    ]
  }
}
```

### Gotchas

- **Every call is metered.** Each `getQuotes` invocation consumes API credits and counts against the rate limit. Avoid polling or speculative calls in bulk loops.
- **`reference` must be unique per request.** It is not an order reference — it is a quote-session identifier. Re-using a reference within a short window may return cached or deduplicated results.
- **`zipCode` is mandatory for EU**, `province` is additionally required for Italy. Missing either will cause courier-specific validation errors.
- **All four parcel dimension fields are required** (weight, width, height, length). Omitting any one causes the parcel to be rejected.
- **`amountShipment` is always required**, even when zero. Pass `0` explicitly rather than omitting the field.
- **GLS-ITA and LICCARDI reject non-EUR currency.** If you pass a non-EUR `currency`, those couriers will be absent from the response without an explicit error.
- **GLS-ITA ignores `senderCode`.** Do not rely on sender-code overrides for GLS-ITA in quote requests; they are silently disregarded.
- **Restricting via `couriers` array** limits which couriers compute a quote — useful when you already know the desired carrier and want to avoid billing for unused quotes.

---

## 2. getPudos

**Purpose:** Search for pickup/drop-off points (PUDO — Pick Up / Drop Off) supported by a given courier near a recipient address. Used before label creation when the shipment will be delivered to a collection point rather than a home address.

**Method + path:** `POST /1.3/getPudos/`

### Required fields

| Field | Type | Notes |
|---|---|---|
| `apiKey` | string | Channel API key. |
| `getPudos.courier` | string | Courier code (e.g. `GLS-ITA`, `DHL`, `TNT`). Not all couriers support PUDO — validate against your account's `getCouriers` response. |
| `getPudos.country` | string | ISO 3166-1 alpha-2. |
| `getPudos.zipCode` | string | Postal code of the search area. Required unless `city` alone is accepted by the courier. |

### Optional fields

| Field | Type | Notes |
|---|---|---|
| `getPudos.address` | string | Street address to narrow proximity search. |
| `getPudos.city` | string | City name. |
| `getPudos.type` | string | Filter by point type. Accepted values vary by courier (e.g. `LOCKER`, `POINT`). Omit to return all types. |

### Compact request example

```json
POST /1.3/getPudos/
{
  "apiKey": "YOUR_API_KEY",
  "getPudos": {
    "courier": "GLS-ITA",
    "country": "IT",
    "zipCode": "20121",
    "city": "Milano"
  }
}
```

### Compact response example

```json
{
  "response": {
    "getPudos": [
      {
        "id": "123456",
        "name": "Tabaccheria Rossi",
        "address": "Via Roma 10",
        "city": "Milano",
        "zipCode": "20121",
        "country": "IT",
        "type": "POINT",
        "SHOP_ID": "GLS_SHOP_123456",
        "PARTNER_SHOP_ID": "P123456"
      }
    ]
  }
}
```

### Gotchas

- **Not all couriers support PUDO.** Calling `getPudos` for an unsupported courier returns an error or empty list. Check the courier's capabilities via `getCouriers` first.
- **Per-courier field names differ significantly.** The identifiers returned in the PUDO objects must be passed verbatim into the subsequent `pushOrder` or `createLabel` PUDO sub-object. Field mapping by courier:
  - **GLS-ITA:** use `SHOP_ID` and `PARTNER_SHOP_ID`
  - **DHL:** use `harmonisedId`, `keyword`, `psfKey`
  - **TNT:** use `id` and `type` (numeric: `3` = point, `5` = locker)
  - **Poste Italiane (PTI):** `type` must be the exact string `ConsegnaPuntoPoste`
- **Do not transform or cache PUDO ids.** Pass them back exactly as received; couriers validate the raw values server-side.
- **This call is metered.** Each `getPudos` request consumes API credits and rate-limit tokens.
- **`type` filter semantics are courier-specific.** Passing an unsupported type string may silently return zero results rather than an error. Test per courier.

---

## 3. detectCourier

**Purpose:** Infer which courier matches a tracking number from its format alone (pattern, length, prefix). Useful for display or triage when only a tracking code is available and no order context exists.

**Method + path:** `GET /1.3/detectCourier/`

> **Note:** There is also a `detectOrderCourier` endpoint (documented in `orders.md`) that applies your account's rules-based routing logic to pick the best courier for a *new* shipment. These are distinct operations — `detectCourier` identifies an *existing* tracking number; `detectOrderCourier` selects a courier for a *future* shipment.

### Required fields (query parameters)

| Field | Type | Notes |
|---|---|---|
| `apiKey` | string | Channel API key. |
| `trackingNumber` | string | The tracking code to identify. |

### Compact request example

```
GET /1.3/detectCourier/?apiKey=YOUR_API_KEY&trackingNumber=1Z999AA10123456784
```

### Compact response example

```json
{
  "response": {
    "detectCourier": {
      "courierCode": "UPS",
      "courierName": "UPS"
    }
  }
}
```

### Gotchas

- **FRAGILE and ambiguous by design.** Tracking number formats are not globally unique. Multiple couriers can share patterns of the same length and character set. A confident-looking single match may still be wrong.
- **Prefer explicit courier context when available.** If you created the shipment via Qapla' or know the carrier from the order, pass `courierCode` explicitly in downstream calls rather than relying on detection.
- **No match ≠ unsupported courier.** A non-match may mean the pattern database doesn't cover that courier's format in your region, not that Qapla' cannot track that carrier.
- **Contrast with `detectOrderCourier`** (in `orders.md`): that endpoint applies your configured routing rules (weight/COD/geography) to choose a courier for a new shipment — it is rules-based, not pattern-matching.
- **Version note:** The API portal previously served this endpoint at `/1.2/detectCourier/`; the canonical current version is `/1.3/detectCourier/`. Use 1.3 for all new integrations.

---

## Common notes for all three endpoints

- **Authentication:** All requests require `apiKey` in the request body (POST) or as a query parameter (GET). See `authentication.md` for channel vs. platform key distinctions.
- **Rate limiting:** Token-bucket, capacity 120, refill 2 tokens/second. HTTP 429 is returned when exceeded. Repeated violations risk API key suspension.
- **Sandbox mode:** Add `"sandbox": true` to the request body (POST endpoints) to test without operational effects. Sandbox responses are simulated and do not consume credits.
- **Country codes:** Always ISO 3166-1 alpha-2. Passing full country names or 3-letter codes will cause validation errors.
- **Currency codes:** Always ISO 4217 (`EUR`, `GBP`, `USD`). Default is `EUR`; non-EUR values are rejected by some couriers silently.
