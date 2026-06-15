---
source: https://api.qapla.dev
synced: 2026-06-15
api_versions: [1.2, 1.3]
---

# Qapla' API — Orders Reference

Base URL for all requests: `https://api.qapla.it/{version}/{endpoint}/`
Authentication: pass your channel's **API Key** in every request body (field `apiKey`) or, for `updatePlatformOrder`, in the `Q-API-Key` request header.
Rate limit: token-bucket, capacity 120, refill 2 req/s. Exceeding returns HTTP 429.

---

## 1. pushOrder

**Purpose:** Import one or more orders (not yet shipped) so Qapla' can manage label generation and tracking for them.

**Method + path:** `POST /1.3/pushOrder/`

### Upsert semantics

The endpoint is an upsert keyed on `reference`. If an order with the same reference already exists, it is updated only when the incoming `updatedAt` is strictly more recent than the stored value; otherwise the row is counted as `skipped`. The `action` field in each response row reports what happened: `imp` (new), `upd` (updated), `skp` (no change), `ext` (already existing at same timestamp), `del` (soft-deleted), `err` (row-level error).

Maximum 100 orders per request.

### Required fields

| Field | Type | Notes |
|---|---|---|
| `apiKey` | string | Channel API Key |
| `pushOrder` | array | Wraps all order objects |
| `reference` | string | Alphanumeric order identifier; upsert key |
| `createdAt` | `YYYY-MM-DD HH:MM:SS` | Order creation timestamp |
| `updatedAt` | `YYYY-MM-DD HH:MM:SS` | Drives update logic — must be newer to trigger an update |
| `name` | string | Recipient full name |
| `street` | string | Recipient street address |
| `city` | string | Recipient city |
| `state` | string | Province / state |
| `postCode` | string | ZIP / postal code |
| `country` | string | ISO 3166-1 alpha-2 (e.g. `IT`) |

### Commonly used optional fields

| Field | Type | Notes |
|---|---|---|
| `origin` | string | Platform hint: `shopify`, `woocommerce`, `magento2`, `prestashop`, `amazon`, `ebay`, etc. Full list in docs. |
| `orderID` | int | Numeric platform order ID |
| `courier` | string | Qapla' courier code; if omitted, routing rules apply |
| `courierService` | string | Service/contract code; defaults to `'0'` when blank |
| `status` | string | Order status label from your platform |
| `email` | string | Recipient email |
| `telephone` | string | Recipient phone |
| `amount` | float | Order value (dot decimal separator, max 2 d.p.) |
| `currencyCode` | string | ISO 4217 (default `EUR`) |
| `payment` | string | Payment method identifier |
| `isCOD` | boolean | `true` if cash-on-delivery |
| `notes` | string | Free-text order note |
| `weight` | float | Total order weight |
| `parcels` | int | Number of packages |
| `length` / `width` / `height` | float | Package dimensions |
| `isReturnable` | boolean | Whether the entire order can be returned |
| `shippingCODPaymentOption` | string | COD payment option override |
| `shippingInsurance` | float/string | Insured amount or courier-specific code |
| `shippingDeliveryOptions` | string/JSON | Comma-separated delivery flags or JSON object for PTI-style carriers |
| `shippingRequiredDeliveryDate` | `YYYY-MM-DD` | Requested delivery date |
| `pickUpDate` | `YYYY-MM-DD` | Requested courier collection date |
| `custom1` / `custom2` / `custom3` | string | Free-form custom fields |
| `content` | string | Goods description (required for customs) |
| `rows` | array | Line items — see sub-fields below |
| `sender` | object | Override sender address when different from account holder |
| `PUDO` | object | Pick-up / drop-off point — see sub-fields below |
| `invoice` | object | Invoice data for customs / DHL international |

**`rows` sub-fields:** `sku`*, `name`*, `qty`*, `price`*, `total`, `weight`, `url`, `imageUrl`, `isReturnable`, `notes`

**`sender` sub-fields:** `code`, `businessName`, `street`, `city`, `state`, `postCode`, `country`, `email`, `telephone`, `referent`, `isDefault`

**`PUDO` sub-fields:** `id`* (courier PUDO identifier), `type`, `name`, `address`, `city`, `state`, `country`, `postalCode`, `description`; plus carrier-specific extras returned by `getPudos`: `harmonisedId`, `keyword`, `psfKey`, `postnumber` (Packstation only). Always populate PUDO from the `getPudos` response to ensure courier-compatible values.

**`invoice` sub-fields:** `number` (invoice number string — required for DHL and cross-border shipments)

### Compact request example

```json
{
  "apiKey": "YOUR_API_KEY",
  "origin": "woocommerce",
  "pushOrder": [
    {
      "reference": "WC-10042",
      "createdAt": "2026-06-01 09:15:00",
      "updatedAt": "2026-06-01 09:20:00",
      "name": "Jane Doe",
      "street": "Via Roma 12",
      "city": "Milano",
      "state": "MI",
      "postCode": "20121",
      "country": "IT",
      "email": "jane@example.com",
      "amount": 89.90,
      "isCOD": false,
      "weight": 1.2,
      "parcels": 1,
      "rows": [
        { "sku": "TSHIRT-M", "name": "Blue T-Shirt M", "qty": 2, "price": 44.95 }
      ]
    }
  ]
}
```

### Compact response example

```json
{
  "pushOrder": {
    "version": "1.3.x",
    "result": "OK",
    "error": null,
    "count": 1,
    "orders": [
      { "row": 1, "reference": "WC-10042", "orderID": null, "action": "imp", "error": null }
    ],
    "imported": 1,
    "updated": 0,
    "deleted": 0,
    "skipped": 0,
    "existing": 0
  }
}
```

### Gotchas

- `updatedAt` is the update gate. Sending the same order twice with the same `updatedAt` results in `action: "ext"` (no change). Always pass the real platform timestamp.
- `courier` and `courierService` are optional at import time; if omitted, Qapla' applies channel routing rules. You can also call `detectOrderCourier` beforehand to resolve them.
- `shippingDeliveryOptions` format is carrier-specific: a comma-separated string for most couriers, a JSON object for PTI-family carriers.
- For PUDO deliveries, populate the `PUDO` object using values returned by `getPudos` — do not construct PUDO fields manually, as carriers require exact codes.
- Cross-border shipments (non-EU destination) should include `content` and `invoice.number`; DHL international requires `invoice.number`.
- `origin` controls how the platform logo appears in the Qapla' Control Panel and may affect import normalization. Use the exact slug from the documented list.

---

## 2. fetchPlatformOrders / updatePlatformOrder

**Purpose:** Marketplace bridge. `fetchPlatformOrders` pulls orders directly from a connected marketplace in real time; `updatePlatformOrder` pushes tracking/status feedback back to that same marketplace.

### 2a. fetchPlatformOrders

**Method + path:** `GET /1.2/fetchPlatformOrders/`

Parameters are passed as query-string.

#### Required fields

| Field | Type | Notes |
|---|---|---|
| `apiKey` | string | Channel API Key |
| `platform` | string | Marketplace slug (see list below). Optional only if the channel has exactly one platform configured — otherwise mandatory. |

#### Optional fields

| Field | Type | Notes |
|---|---|---|
| `dateFrom` | `YYYY-MM-DD HH:MM:SS` | Filter start (order creation/update timestamp) |
| `dateTo` | `YYYY-MM-DD HH:MM:SS` | Filter end |
| `orderFormat` | string | Pass `qapla` to normalize output to Qapla' order schema; omit for the platform's native format |
| `skip` | string | Comma-separated order statuses to exclude from results |

#### Supported platforms (fetch)

`amazon`, `aliexpress`, `allegro`, `bigcommerce`, `carrefour`, `cdiscount`, `commercelayer`, `ebay`, `ecwid`, `eprice`, `greenweez`, `ibs`, `leroymerlin`, `magento`, `magento2`, `maisondumonde`, `manomano`, `mediamarkt`, `prestashop`, `privalia`, `shopify`, `shopware6`, `spartoo`, `sprinter`, `storeden`, `tiktokshop`, `vtex`, `woocommerce`, `worten`

#### Compact request example

```
GET /1.2/fetchPlatformOrders/?apiKey=YOUR_API_KEY&platform=shopify&dateFrom=2026-06-01+00:00:00&dateTo=2026-06-01+23:59:59&orderFormat=qapla
```

#### Compact response example

```json
{
  "fetchPlatformOrders": {
    "version": "1.2.34",
    "result": "OK",
    "error": null,
    "platform": "shopify",
    "format": "qapla",
    "count": 1,
    "orders": [
      {
        "source": "shopify",
        "reference": "SH-5001",
        "orderID": 5001,
        "status": "PENDING",
        "createdAt": "2026-06-01 10:22:00",
        "updatedAt": "2026-06-01 10:25:00",
        "name": "John Smith",
        "address": "Baker Street 221B",
        "city": "London",
        "state": "ENG",
        "postCode": "NW1 6XE",
        "country": "GB",
        "email": "john@example.com",
        "amount": "GBP 49.00",
        "isCOD": false,
        "rows": [
          { "sku": "WIDGET-1", "name": "Widget", "qty": 1, "price": 49.00, "total": 49.00 }
        ]
      }
    ]
  }
}
```

### 2b. updatePlatformOrder

**Purpose:** Push shipment tracking number and/or status (shipped/delivered) back to the originating marketplace.

**Method + path:** `PUT /1.2/updatePlatformOrder/`

**Authentication:** API Key is passed in the **request header** (`Q-API-Key: YOUR_API_KEY`), not in the body.

#### Required fields

| Field | Type | Notes |
|---|---|---|
| `Q-API-Key` *(header)* | string | Channel API Key |
| `platform` | string | Marketplace slug |
| `courier` | string | Qapla' courier code |
| `trackingNumber` | string | Shipment tracking number |

Either `reference` or `orderID` must also be present (which one is accepted depends on the platform).

#### Optional fields

| Field | Type | Notes |
|---|---|---|
| `reference` | string | Alphanumeric order reference |
| `orderID` | int | Numeric order ID |
| `setShipped` | boolean | Mark order as shipped on the platform |
| `setDelivered` | boolean | Mark order as delivered on the platform |
| `storeCountry` | string | ISO 3166-1 alpha-2 marketplace country (required by some multi-country platforms) |
| `trackingUrl` | string | Custom tracking page URL |

#### Compact request example

```json
{
  "platform": "shopify",
  "reference": "SH-5001",
  "courier": "UPS",
  "trackingNumber": "1Z0V5V416840696736",
  "setShipped": true,
  "setDelivered": false
}
```
*(Header: `Q-API-Key: YOUR_API_KEY`)*

#### Compact response example

```json
{
  "updatePlatformOrder": {
    "result": "OK",
    "error": null
  }
}
```

### Gotchas (both endpoints)

- Each channel must have the target platform **configured in the Qapla' Control Panel** before these endpoints will work. The integration is per-channel, not per-account.
- `fetchPlatformOrders` communicates directly with the marketplace API — orders retrieved here have not been imported into Qapla' yet; pass them through `pushOrder` to create them.
- Without `orderFormat=qapla`, the response schema mirrors the platform's native structure and varies significantly between marketplaces.
- `updatePlatformOrder` uses header-based auth (`Q-API-Key`), unlike all other endpoints which use a body field `apiKey`.
- Whether `reference` or `orderID` is required in `updatePlatformOrder` depends on the specific marketplace.
- Platform support is **not identical** between fetch and update — verify per marketplace before building your integration.

---

## 3. detectOrderCourier

**Purpose:** Given an order's attributes (destination country, weight, COD amount, postal code), returns the courier and routing rule that Qapla' would apply based on the channel's pre-configured shipping rules.

**Method + path:** `POST /1.2/detectOrderCourier/`

> **Contrast with `detectCourier`** (see [couriers.md](couriers.md)): `detectCourier` infers the courier from a tracking number already assigned to a shipment. `detectOrderCourier` operates *before* shipment creation — it evaluates your channel's shipping rules against order attributes to recommend which courier to use.

**Prerequisite:** This endpoint must be enabled by Qapla' Customer Care for your account.

### Required fields

| Field | Type | Notes |
|---|---|---|
| `apiKey` | string | Channel API Key |
| `country` | string | Destination country, ISO 3166-1 alpha-2 |
| `weight` | float | Order weight |

### Optional fields

| Field | Type | Notes |
|---|---|---|
| `cod` | float | Cash-on-delivery amount (used to match COD-specific rules) |
| `postCode` | string | Destination postal code (used for geographic routing rules) |

### Compact request example

```json
{
  "apiKey": "YOUR_API_KEY",
  "detectOrderCourier": {
    "country": "IT",
    "weight": 3.1,
    "cod": 199.99,
    "postCode": "21100"
  }
}
```

### Compact response example

```json
{
  "detectOrderCourier": {
    "version": "1.2.8",
    "result": "OK",
    "error": null,
    "request": { "country": "IT", "weight": 3.1, "cod": 199.99, "postCode": "21100" },
    "courier": { "id": "6", "code": "GLS-ITA", "name": "GLS" },
    "rule": { "id": "3", "name": "Nord" }
  }
}
```

### Gotchas

- Rules are evaluated in the order configured in the Control Panel. The first matching rule wins; if no rule matches, the endpoint returns `KO` with an explanatory error.
- The three rule dimensions are **weight**, **COD amount**, and **destination postal code**. Rules that omit a dimension match any value for that dimension.
- This endpoint operates on the shipping rules of the specific channel identified by `apiKey`. Different channels may return different couriers for identical order attributes.
- Use `courier.code` from the response directly as the `courier` field in `pushOrder` or `createLabel`.
