---
source: https://api.qapla.dev
synced: 2026-06-15
api_versions: [1.2, 1.3]
---

# Qapla' API — Orders Reference

Base URL for all requests: `https://api.qapla.it/{version}/{endpoint}/`
Authentication: pass your channel's **API Key** as the `apiKey` field in every JSON request body.
Rate limit: token-bucket, capacity 120, refill 2 req/s. Exceeding returns HTTP 429.

---

## 1. pushOrder

**Purpose:** Import one or more orders (not yet shipped) so Qapla' can manage label generation and tracking for them.

**Method + path:** `POST /1.3/pushOrder/`

### Upsert semantics

The endpoint is an upsert keyed on `reference`. If an order with the same reference already exists, it is updated only when the incoming `updatedAt` is strictly more recent than the stored value; otherwise the row is counted as skipped. The `action` field in each response row reports what happened: `imp` (new), `upd` (updated), `skp` (no change), `ext` (already existing at same timestamp), `del` (soft-deleted), `err` (row-level error).

Maximum 100 orders per request.

### Top-level request fields

| Field | Type | Required | Notes |
|---|---|:---:|---|
| `apiKey` | string | yes | Channel API Key |
| `origin` | string | no | Platform hint: `shopify`, `woocommerce`, `magento2`, `prestashop`, `amazon`, `ebay`, etc. Also accepted as `source`. Defaults to `API`. |
| `pushOrder` | array | yes | Array of order objects (max 100) |

### Order object fields

#### Identity and timestamps

| Field | Type | Required | Notes |
|---|---|:---:|---|
| `reference` | string | yes | Alphanumeric order identifier; upsert key |
| `orderID` | int | no | Numeric platform order ID |
| `status` | string | no | Order status label from your platform |
| `createdAt` | `YYYY-MM-DD HH:MM:SS` | yes | Order creation timestamp |
| `updatedAt` | `YYYY-MM-DD HH:MM:SS` | yes | Drives update logic — must be newer to trigger an update |

#### Courier and service

| Field | Type | Required | Notes |
|---|---|:---:|---|
| `courier` | string | no | Qapla' courier code (e.g. `GLS-ITA`, `BRT`). If omitted, channel routing rules apply. Courier variant codes accepted if configured on the channel. |
| `courierService` | string | no | Service/contract code; defaults to `'0'` when blank |

#### Recipient

| Field | Type | Required | Notes |
|---|---|:---:|---|
| `name` | string | yes | Recipient full name |
| `street` | string | yes | Street address |
| `city` | string | yes | City |
| `state` | string | yes | Province / state |
| `postCode` | string | yes | ZIP / postal code |
| `country` | string | yes | ISO 3166-1 alpha-2 (e.g. `IT`) |
| `email` | string | no | Recipient email |
| `telephone` | string | no | Recipient phone |

#### Amounts and payment

| Field | Type | Required | Notes |
|---|---|:---:|---|
| `amount` | float | no | Order value (dot decimal, max 2 d.p., e.g. `2340.23`) |
| `shippingCost` | float | no | Shipping cost (same format as `amount`) |
| `currencyCode` | string | no | ISO 4217 (default `EUR`) |
| `payment` | string | no | Payment method identifier |
| `isCOD` | boolean | no | `true` if cash-on-delivery |
| `shippingCODPaymentOption` | string | no | COD payment option override |

#### Shipping options

| Field | Type | Required | Notes |
|---|---|:---:|---|
| `shippingInsurance` | float/string | no | Insured amount, or courier-specific code (e.g. `AS01`–`AS13` for SDA/CRONO PTI) |
| `shippingDeliveryOptions` | string/JSON | no | Comma-separated delivery flags (e.g. `A,P`) or JSON object for PTI-style carriers |
| `shippingRequiredDeliveryDate` | `YYYY-MM-DD` | no | Requested delivery date |
| `latestShipDate` | `YYYY-MM-DD` | no | Ship by date |
| `latestDeliveryDate` | `YYYY-MM-DD` | no | Deliver by date |
| `pickUpDate` | `YYYY-MM-DD` | no | Requested courier collection date |
| `pickupPoint` | string | no | Pickup point code |
| `content` | string | no | Goods description (may appear on label; required for some customs flows) |
| `isReturnable` | boolean | no | Whether the entire order can be returned |

#### Extra fields

| Field | Type | Required | Notes |
|---|---|:---:|---|
| `notes` | string | no | Free-text order note |
| `tag` | string | no | CP colour tag: `green`, `yellow`, `orange`, `blue`, `cyan`, `red` |
| `custom1` / `custom2` / `custom3` | string | no | Free-form custom fields |

---

### Sub-object `parcels[]`

Array of package objects. If omitted, dimensions can be set from channel defaults or entered manually in the CP at label-generation time. Weights and dimensions go here — **not** as flat order-level fields.

| Field | Type | Required | Notes |
|---|---|:---:|---|
| `weight` | float | yes* | Package weight in kg. Required if `boxCode` is absent. |
| `length` | float | yes* | Length in cm. Required if `boxCode` is absent. |
| `width` | float | yes* | Width in cm. Required if `boxCode` is absent. |
| `height` | float | yes* | Height in cm. Required if `boxCode` is absent. |
| `boxCode` | string | no | Predefined box code; dimensions are read from the saved box profile |
| `originCountry` | string | no | ISO 3166-1 alpha-2 origin country of the parcel |
| `content` | string | no | Contents description for this parcel |

---

### Sub-object `rows[]`

Line items (products). If the array is present, `sku`, `name`, `qty`, and `price` are required within each element.

| Field | Type | Required | Notes |
|---|---|:---:|---|
| `sku` | string | yes | Product code |
| `name` | string | yes | Product description |
| `qty` | int | yes | Quantity |
| `price` | float | yes | Unit price |
| `total` | float | no | Line total |
| `weight` | float | no | Product weight |
| `url` | string | no | Product page URL |
| `imageUrl` | string | no | Product image URL |
| `isReturnable` | boolean | no | Per-item returnability (default `true`) |
| `customsCode` | string | no | HS / Taric customs code |
| `originCountry` | string | no | ISO 3166-1 alpha-2 origin country |
| `parcelID` | int | no | 1-based index into `parcels[]` indicating which package contains this item |
| `custom1`–`custom5` | string | no | Free-form custom fields |

---

### Sub-object `sender`

Override sender address when different from the account holder.

| Field | Type | Required | Notes |
|---|---|:---:|---|
| `code` | string | yes | Sender identifier code |
| `businessName` | string | no | Company / business name |
| `street` / `city` / `state` / `postCode` / `country` | string | no | Address fields |
| `email` / `telephone` / `referent` | string | no | Contact fields |
| `isDefault` | boolean | no | If `true`, saves this sender as the channel default for subsequent shipments |

---

### Sub-object `PUDO`

Pick-up / drop-off point.

| Field | Type | Required | Notes |
|---|---|:---:|---|
| `id` | string | yes | Carrier PUDO identifier |
| `type` | string | no* | Required for TNT ITA, GLS-ITA, PTI, DHL-PAKET |
| `name` | string | no* | Required for PTI, GLS-SPAIN, TIPSA, UPS, SDA |
| `address` / `city` / `state` / `country` / `postalCode` | string | no | Include for transactional email accuracy |
| `description` | string | no | Free-text description |
| `postnumber` | string | no | DHL-PAKET Packstation personal post number |

Always populate PUDO from the `getPudos` response — do not construct codes manually.

---

### Sub-object `invoice`

Required for DHL international and cross-border customs shipments.

| Field | Type | Required | Notes |
|---|---|:---:|---|
| `number` | string | yes | Invoice number |
| `date` | `YYYY-MM-DD` | no | Invoice date |

---

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
      "parcels": [
        { "weight": 1.2, "length": 30, "width": 20, "height": 10 }
      ],
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
    "version": "1.3.14",
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
- Weight, dimensions, and parcel count go inside `parcels[]` objects — they are **not** flat order-level fields.
- `courier` and `courierService` are optional at import time; if omitted, Qapla' applies channel routing rules. You can also call `detectOrderCourier` beforehand to resolve them.
- `shippingDeliveryOptions` format is carrier-specific: a comma-separated string for most couriers, a JSON object for PTI-family carriers.
- Cross-border shipments (non-EU destination) should include `content` and `invoice.number`; DHL international requires `invoice.number`.
- `origin` controls how the platform logo appears in the Control Panel and may affect import normalization. Use the exact slug from the documented list.

---

## 2. fetchPlatformOrders / updatePlatformOrder

**Purpose:** Marketplace bridge. `fetchPlatformOrders` pulls orders directly from a connected marketplace in real time; `updatePlatformOrder` pushes tracking/status feedback back to that same marketplace.

### 2a. fetchPlatformOrders

**Method + path:** `POST /1.2/fetchPlatformOrders/`

Parameters are passed as a JSON body.

#### Fields

| Field | Type | Required | Notes |
|---|---|:---:|---|
| `apiKey` | string | yes | Channel API Key |
| `platform` | string | no* | Marketplace slug. Optional only if the channel has exactly one platform configured — otherwise required. |
| `dateFrom` | `YYYY-MM-DD HH:MM:SS` | no | Filter start (order creation/update timestamp) |
| `dateTo` | `YYYY-MM-DD HH:MM:SS` | no | Filter end |
| `orderFormat` | string | no | Pass `qapla` to normalize output to Qapla' order schema; omit for the platform's native format |
| `skip` | string | no | Comma-separated order statuses to exclude from results |

#### Supported platforms (fetch)

`aliexpress`, `allegro`, `amazon`, `bigcommerce`, `carrefour`, `cdiscount`, `commercelayer`, `decathlon`, `ebay`, `ecwid`, `eprice`, `etsy`, `greenweez`, `ibs`, `leroymerlin`, `magento`, `magento2`, `maisondumonde`, `manomano`, `mediamarkt`, `miravia`, `prestashop`, `shopify`, `shopware6`, `spartoo`, `sprinter`, `storeden`, `temu`, `tiktok`, `vtex`, `woocommerce`, `worten`

#### Compact request example

```json
{
  "apiKey": "YOUR_API_KEY",
  "platform": "shopify",
  "dateFrom": "2026-06-01 00:00:00",
  "dateTo": "2026-06-01 23:59:59",
  "orderFormat": "qapla"
}
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
        "street": "Baker Street 221B",
        "city": "London",
        "state": "ENG",
        "postCode": "NW1 6XE",
        "country": "GB",
        "email": "john@example.com",
        "amount": 49.00,
        "isCOD": false,
        "rows": [
          { "sku": "WIDGET-1", "name": "Widget", "qty": 1, "price": 49.00, "total": 49.00 }
        ]
      }
    ]
  }
}
```

---

### 2b. updatePlatformOrder

**Purpose:** Push shipment tracking number and/or status (shipped/delivered) back to the originating marketplace.

**Method + path:** `PUT /1.2/updatePlatformOrder/`

**Authentication:** API Key passed as `apiKey` in the JSON body (same as all other endpoints).

#### Fields

| Field | Type | Required | Notes |
|---|---|:---:|---|
| `apiKey` | string | yes | Channel API Key |
| `platform` | string | yes | Marketplace slug |
| `courier` | string | yes | Qapla' courier code |
| `trackingNumber` | string | yes | Shipment tracking number |
| `reference` | string | no* | Alphanumeric order reference. At least one of `reference` / `orderID` required. |
| `orderID` | int | no* | Numeric order ID. At least one of `reference` / `orderID` required. |
| `setShipped` | boolean | no | Mark order as shipped on the platform |
| `setDelivered` | boolean | no | Mark order as delivered on the platform |
| `trackingUrl` | string | no | Custom tracking page URL |

#### Compact request example

```json
{
  "apiKey": "YOUR_API_KEY",
  "platform": "shopify",
  "reference": "SH-5001",
  "courier": "UPS",
  "trackingNumber": "1Z0V5V416840696736",
  "setShipped": true,
  "setDelivered": false
}
```

#### Compact response example

```json
{
  "updatePlatformOrder": {
    "result": "OK",
    "error": null
  }
}
```

---

### Gotchas (both endpoints)

- Each channel must have the target platform **configured in the Qapla' Control Panel** before these endpoints will work. The integration is per-channel, not per-account.
- `fetchPlatformOrders` communicates directly with the marketplace API — orders retrieved are not yet stored in Qapla'. Pass them through `pushOrder` if you want to import them.
- Without `orderFormat=qapla`, the response schema mirrors the platform's native structure and varies between marketplaces.
- Whether `reference` or `orderID` is required in `updatePlatformOrder` depends on the specific marketplace.
- Platform support is **not identical** between fetch and update — verify per marketplace before building your integration.

---

## 3. detectOrderCourier

**Purpose:** Given an order's attributes (destination country, weight, COD amount, address), returns the courier and routing rule that Qapla' would apply based on the channel's pre-configured shipping rules.

**Method + path:** `POST /1.2/detectOrderCourier/`

> **Contrast with `detectCourier`** (see [couriers.md](couriers.md)): `detectCourier` infers the courier from a tracking number already assigned to a shipment. `detectOrderCourier` operates *before* shipment creation — it evaluates your channel's shipping rules against order attributes to recommend which courier to use.

### Fields

| Field | Type | Required | Notes |
|---|---|:---:|---|
| `apiKey` | string | yes | Channel API Key |
| `country` | string | yes | Destination country, ISO 3166-1 alpha-2. Defaults to `IT` if omitted. |
| `weight` | float | yes | Order / parcel weight in kg |
| `address` | string | no | Street address (used for geographic rule matching) |
| `city` | string | no | Destination city |
| `state` | string | no | Province / state |
| `postCode` | string | no | Destination postal code (used for geographic routing rules) |
| `cod` | float | no | Cash-on-delivery amount (used to match COD-specific rules) |

### Compact request example

```json
{
  "apiKey": "YOUR_API_KEY",
  "detectOrderCourier": {
    "country": "IT",
    "weight": 3.1,
    "postCode": "21100",
    "cod": 199.99
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
- Rule dimensions are **weight**, **COD amount**, **destination country**, and **postal code**. Rules that omit a dimension match any value for that dimension.
- This endpoint operates on the shipping rules of the specific channel identified by `apiKey`. Different channels may return different couriers for identical order attributes.
- Use `courier.code` from the response directly as the `courier` field in `pushOrder` or `createLabel`.
