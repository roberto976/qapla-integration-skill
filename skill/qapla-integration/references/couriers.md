---
source: https://api.qapla.dev
synced: 2026-06-15
api_versions: [1.2, 1.3]
---

# Qapla' Courier API Reference

API host: `api.qapla.it`  
All endpoints require a per-channel **API Key** obtained from the Qapla' Customer Care.

---

## 1. getQuotes

### Purpose

Request real-time shipping quotes from one or more couriers simultaneously. Requires the `courier-quotes` (plan 2021) or `quote` (plan 2025) product enabled on the channel — contact Customer Care to activate.

### Method & Path

```
POST https://api.qapla.it/1.3/getQuotes/
```

### Authentication

Pass the API Key via header `X-API-KEY` **or** query string `?apiKey=<key>`.  
Optional: `X-Sandbox: true` header to activate sandbox mode (note: GLS-ITA has no sandbox and always hits production).

### Required Fields

| Field | Type | Notes |
|-------|------|-------|
| `reference` | string | Merchant's unique order reference. Chars: `[a-zA-Z0-9_\-.]`, length 3–255. Echo'd in response. |
| `recipient` | object | Destination address. |
| `recipient.city` | string | City name (English for international). |
| `recipient.country` | string | ISO 3166-1 alpha-2 (e.g. `"IT"`, `"DE"`). |
| `recipient.zipCode` | string | Required for European shipments. |
| `recipient.province` | string | 2-char province code. Required for Italy. |
| `recipient.street` | string | Street and civic number. Recommended. |
| `parcels` | array | At least one parcel object. |
| `parcels[].weight` | float | Weight in kg. Rounded up per-courier if needed. |
| `parcels[].width` | float | Width in cm. |
| `parcels[].height` | float | Height in cm. |
| `parcels[].length` | float | Length in cm. |
| `amountShipment` | float | Merchandise value in `currency`. Format: `#.##`. |

### Optional Fields

| Field | Type | Notes |
|-------|------|-------|
| `currency` | string | ISO 4217 (e.g. `"EUR"`, `"GBP"`). Default: `"EUR"`. No conversion performed. **GLS-ITA and LICCARDI return an error for non-EUR.** |
| `amountCash` | float | Cash-on-delivery value. `0` or absent = no COD. |
| `amountInsurance` | float | Insured value. `0` or absent = no insurance. |
| `couriers` | array | Courier codes to query (e.g. `["DHL","UPS"]`). If omitted or empty, all enabled couriers on the channel are queried. |
| `senderCode` | string | Qapla' sender code. GLS-ITA does not support this field. |

### Compact Request Example

```json
POST https://api.qapla.it/1.3/getQuotes/
X-API-KEY: <your-api-key>

{
  "reference": "ORD-20240620-001",
  "recipient": {
    "street": "Via Roma 1",
    "city": "Milano",
    "province": "MI",
    "zipCode": "20100",
    "country": "IT"
  },
  "parcels": [{ "weight": 2.5, "width": 20.0, "height": 15.0, "length": 30.0 }],
  "amountShipment": 150.00,
  "currency": "EUR",
  "couriers": ["DHL", "UPS"]
}
```

### Response Envelope

```json
{
  "getQuotes": {
    "result": "OK",
    "version": "1.3.2",
    "reference": "ORD-20240620-001",
    "quotationId": "566ef67f-ec5f-4517-ac32-543c69032f5d",
    "startTimestamp": "2024-06-20T13:15:02.408+00:00",
    "endTimestamp": "2024-06-20T13:15:06.208+00:00",
    "couriers": [
      {
        "code": "DHL",
        "quotes": [
          {
            "service": {
              "courierCode": "I",
              "qaplaCode": 4,
              "description": "Domestic Express H 9"
            },
            "currency": "EUR",
            "amount": 57.68,
            "expectedPickupDate": null,
            "expectedDeliveryDate": "2024-06-24T09:00:00",
            "messages": [],
            "deliveryOptions": null
          }
        ],
        "messages": []
      },
      {
        "code": "UPS",
        "quotes": [
          {
            "service": { "courierCode": "11", "qaplaCode": 3, "description": "Standard" },
            "currency": "EUR",
            "amount": 55.25,
            "expectedPickupDate": null,
            "expectedDeliveryDate": null,
            "messages": [
              {
                "type": "message",
                "code": 110920,
                "content": "Ship To Address Classification is changed from Commercial to Residential"
              }
            ],
            "deliveryOptions": null
          }
        ],
        "messages": []
      }
    ]
  }
}
```

### Key Response Fields

| Field | Type | Description |
|-------|------|-------------|
| `result` | string | `"OK"` if at least one courier succeeded; `"KO"` for global errors. |
| `couriers[].code` | string | Qapla' courier code (e.g. `"DHL"`, `"UPS"`). |
| `couriers[].quotes[].service.description` | string | Human-readable service name (e.g. `"Standard"`, `"Express"`). |
| `couriers[].quotes[].amount` | float | Quote price in `currency`. |
| `couriers[].quotes[].currency` | string | Actual quote currency (may differ from requested). |
| `couriers[].quotes[].expectedDeliveryDate` | string\|null | `yyyy-MM-dd` or RFC 3339; `null` if unavailable. |

### Gotchas

- Couriers are queried **in parallel** — response latency is determined by the slowest courier, not the sum. Use `couriers` to limit scope.
- `result: "OK"` at the top level only means at least one courier succeeded. Individual courier errors appear as `quotes: []` with `messages[].type: "error"`.
- **GLS-ITA and LICCARDI** return an error for any `currency` other than `"EUR"`.
- Rate limit: token bucket per channel — 120 tokens max, refill 2 tokens/second. HTTP 429 on breach.
- Product must be explicitly activated. Without activation the response is `KO`.

### Supported Couriers (quotes)

| Code | VAT in quote |
|------|-------------|
| `DHL` | included |
| `FEDEX` | included |
| `GLS-ITA` | included |
| `UPS` | included |
| `LICCARDI` | excluded |
| `TNT-ITA` | excluded |
| `AMAZON-SHIPPING` | excluded |

---

## 2. getPudos

### Purpose

Search for PUDO (Pick-Up / Drop-Off) points near an address or GPS coordinates. Typically called during checkout so the buyer can choose where to collect the parcel. This is a **billable product** requiring activation by Customer Care.

### Method & Path

```
POST https://api.qapla.it/1.2/getPudos/
```

> The path is **always `/1.2/getPudos/`** regardless of what API version you use for other endpoints. No `/1.3/` alias exists.

E-commerce plugin variant (for native integrations):
```
POST https://api.qapla.it/1.2/getPudos/{plugin}
```
Valid plugin slugs: `bigcommerce`, `commercelayer`, `ecwid`, `magento`, `magento2`, `prestashop`, `shopify`, `shopware6`, `storeden`, `vtex`, `woocommerce`, `edock`, `maxpho`.

### Authentication

Pass the API Key as `apiKey` in the **JSON body** or as a query string parameter `?apiKey=<key>`.

### Request Body (flat JSON object)

The body is a **flat JSON object** — fields are at the top level, not nested in a sub-object.

| Field | Type | Required | Notes |
|-------|------|:--------:|-------|
| `apiKey` | string | Yes | Channel API Key. Alternatively via query string. |
| `postCode` | string | Yes* | Postal code of the search location. Min 3 chars. *Required unless using coordinates. |
| `country` | string | Yes | ISO 3166-1 alpha-2 (e.g. `"IT"`, `"ES"`). Exactly 2 chars. |
| `couriers` | array | No | Qapla' courier codes to query (e.g. `["GLS-ITA","DHL"]`). If **omitted or empty**, all PUDO couriers configured on the channel are queried. |
| `street` | string | No | Street and civic number. Refines geolocation. |
| `city` | string | No | City/municipality. **Required for TIPSA.** |
| `province` | string | No | Province code. |
| `radius` | number | No | Search radius in km. `<= 0` means no limit. Only honoured by couriers that accept it. |
| `limit` | number | No | Max PUDO points per courier. `<= 0` means no limit. |
| `unifiedResults` | bool | No | If `true`, returns a flat list of all PUDOs sorted by distance, each with an added `courier` field. Default: `false`. |
| `lat` | float | No* | Latitude. Alternative to `postCode` (requires `lng` and `country`). |
| `lng` | float | No* | Longitude. Alternative to `postCode` (requires `lat` and `country`). |

### Compact Request Example

```json
POST https://api.qapla.it/1.2/getPudos/
Content-Type: application/json

{
  "apiKey": "[API_KEY]",
  "postCode": "20121",
  "country": "IT",
  "city": "Milano",
  "street": "Via Brera 12",
  "couriers": ["GLS-ITA", "DHL"],
  "radius": 5,
  "limit": 3
}
```

### Response Envelope

```json
{
  "getPudos": {
    "result": "OK",
    "error": "",
    "data": [
      {
        "courier": "GLS-ITA",
        "statusCode": 200,
        "error": "",
        "servicePointList": [
          {
            "ID": "42831",
            "partnerID": "GLS000123",
            "name": "Tabaccheria Centrale",
            "type": "SHOPINSHOP",
            "street": "Via Brera 12",
            "postCode": "20121",
            "city": "Milano",
            "province": "MI",
            "country": "IT",
            "coordinates": { "latitude": 45.4654, "longitude": 9.1859 },
            "distance": 0.3,
            "telephone": "0226001234",
            "notes": null,
            "businessDays": [
              {
                "day": 1,
                "dayName": "Monday",
                "dayNameIT": "lunedì",
                "businessHours": [
                  { "open": "08:00", "close": "13:00" },
                  { "open": "15:30", "close": "19:30" }
                ]
              }
            ],
            "availableServices": [
              { "serviceDescription": "parcel:pick-up" },
              { "serviceDescription": "parcel:drop-off" }
            ],
            "courierSpecific": [],
            "holidays": [],
            "pushOrderPUDO": {
              "id": "42831",
              "courierID": "GLS-ITA",
              "type": "GLS000123",
              "name": "Tabaccheria Centrale",
              "address": "Via Brera 12",
              "city": "Milano",
              "state": "MI",
              "country": "IT",
              "postalCode": "20121",
              "description": null,
              "psfKey": null,
              "keyword": null,
              "postnumber": null,
              "harmonisedId": null
            }
          }
        ]
      }
    ]
  }
}
```

### Per-Courier `statusCode` Values

| Code | Meaning |
|------|---------|
| `200` | OK — search completed successfully |
| `404` | NOT FOUND — no PUDOs in the area |
| `408` | TIMEOUT — courier webservice did not respond in time |
| `500` | GENERIC ERROR |
| `501` | EMPTY RESPONSE |
| `522` | UNPROCESSABLE RESPONSE — invalid JSON/XML from courier |
| `599` | CUSTOM ERROR — courier-specific; see per-entry `error` field |

### ServicePoint Object Fields

| Field | Type | Description |
|-------|------|-------------|
| `ID` | string | Point identifier in the courier's network. |
| `partnerID` | string\|null | Optional secondary identifier (not all couriers provide this). |
| `name` | string | Name of the shop, locker, or post office. |
| `type` | string | `SHOP`, `LOCKER`, `POSTOFFICE`, `SHOPINSHOP`, or `UNKNOWN`. |
| `street`, `postCode`, `city`, `province`, `country` | string | Address fields. |
| `coordinates` | object | `{"latitude": float, "longitude": float}`. |
| `distance` | float | Distance in km from the search location. |
| `businessDays` | array | Opening hours per weekday (ISO day 1=Monday–7=Sunday). |
| `availableServices` | array | `[{"serviceCode": string, "serviceDescription": string}]`. |
| `courierSpecific` | array | Courier-specific fields as `[{"name": string, "value": string}]`. E.g. `harmonisedId`, `psfKey`, `keyword` for DHLPARCEL-ES. |
| `holidays` | array | `[{"startDate": "yyyy-mm-dd", "endDate": "yyyy-mm-dd"}]`. |
| `pushOrderPUDO` | object | PUDO payload ready to pass directly to `pushOrder`/`createLabel` (see below). |

### `pushOrderPUDO` — Required Fields per Courier

Use the `pushOrderPUDO` object from each `ServicePoint` as the `PUDO` node in your `pushOrder` or `createLabel` call. Required fields vary by courier:

| Courier(s) | Required fields in `pushOrderPUDO` |
|------------|-------------------------------------|
| DHL, BRT, FEDEX, INPOST-GROUP, SENDING, MONDIALRELAY | `id` |
| GLS-ITA, TNT-ITA | `id`, `type` |
| PTI | `id`, `type`, `name` |
| DHL-PAKET | `id`, `type`, `name`, `city`, `country`, `postalCode` |
| SDA, UPS | `id`, `type`, `name`, `address`, `city`, `country`, `postalCode`, `state` |
| DHLPARCEL-ES | `id`, `harmonisedId`, `address`, `city`, `country`, `postalCode`, `psfKey`, `keyword`, `postnumber` |

> **PTI note**: PTI uses string type values (`ConsegnaLocker`, `ConsegnaPuntoPoste`, `ConsegnaUfficioPostale`, `ConsegnaPUDOUPS`) — not numeric.

### Supported Couriers (PUDO search)

`UPS`, `BRT`, `GLS`, `GLS-ITA`, `GLS-SPAIN`, `GLS-AT`, `DHL`, `PTI`, `INPOST-GROUP`, `INPOST-GROUP-V3`, `FEDEX`, `DHLPARCEL-ES`, `CORREOS`, `SEUR`, `TIPSA`, `MRW-ES`, `NACEX-ES`, `CORREOS-EXPRESS`, `SENDING`, `DHL-PAKET`, `SPRING-GDS`, `TNT-ITA`, `MONDIALRELAY`

> `INPOST` and `INPOST_PL` are deprecated — use `INPOST-GROUP` or `INPOST-GROUP-V3`.

### Gotchas

- The `couriers` filter is **optional and plural (array)**. If omitted, all PUDO couriers configured on the channel are queried automatically.
- There is **no request `type` filter** — type filtering is done client-side on the response.
- Use `street` (not `address`) in the request body for address refinement.
- Response envelope wraps everything in `{"getPudos": {...}}`.
- `result: "OK"` at the top level means at least one courier responded with HTTP 200. Check each courier's `statusCode` for per-courier status.
- Passing a courier not configured on the channel returns `result: KO`.
- Rate limit: same token bucket as other API v1.3 endpoints (120 tokens max, 2 tokens/second).
- Billable product: calls beyond the channel's free monthly quota are invoiced.

---

## 3. detectCourier

### Purpose

Infer the courier from a tracking number alone using regex/length/prefix pattern matching. Returns all plausible matches — the result is **not authoritative** and should be treated as a hint, not a guarantee.

### Method & Path

```
GET https://api.qapla.it/1.3/detectCourier/?trackingNumber=<tn>
```

Alias: `?t=<tn>`.

### Authentication

API Key via `X-API-KEY` header or `?apiKey=<key>` query string.

### Parameters

| Param | Type | Required | Notes |
|-------|------|:--------:|-------|
| `trackingNumber` | string | Yes | The tracking number to identify. Normalised to uppercase internally; pass a clean value (no leading/trailing spaces). |

### Compact Request Example

```
GET https://api.qapla.it/1.3/detectCourier/?trackingNumber=1Z9999999999999999
X-API-KEY: <your-api-key>
```

### Response Envelope

Returns all candidate couriers. May return zero, one, or multiple matches.

```json
{
  "detectCourier": {
    "result": "OK",
    "couriers": [
      {
        "code": "UPS",
        "name": "UPS",
        "country": "US",
        "trackingUrl": "https://www.ups.com/track?tracknum=1Z9999999999999999",
        "hasWebService": true,
        "hasPickUpPoint": false,
        "hasGetPudos": false,
        "icon": "https://cdn.qapla.it/couriers/ups.svg"
      }
    ]
  }
}
```

### Known Pattern Table

| Courier | Pattern |
|---------|---------|
| SDA | Alphanumeric, at least one digit, length 9–13 |
| BRT | 12 digits or 19 digits |
| GLS-ITA | `^[A-Z][A-Z0-9][0-9]{9}$` (e.g. `E2540359550`) |
| GLS | `^[0-9]{11}$` |
| PTI | `^[0-9]{12}$` (overlaps with BRT — both returned) |
| PTI-PACCOCELERE | `^[A-Z]{2}[0-9]{9}[A-Z]{2}$` (UPU format) |
| TNT-ITA | `^[A-Z]{2}[0-9]{8}$` or `^[A-Z]{2}[0-9]{9}$` |
| UPS | Prefix `1Z` |
| DHL | `^[0-9]{10}$` |
| FEDEX | Digits only, length ≥ 12 |
| NEXIVE | Prefix `STCPA` or `^[A-Z]{5}[0-9]{15}$` |
| CAQ-ITA | `^[0-9]{6}$` |

### Gotchas

- **Not authoritative**: patterns are empirically derived. Non-standard tracking numbers or courier format changes can produce false positives/negatives.
- Multiple matches are intentional: BRT and PTI both match `^[0-9]{12}$`. The response returns both — your application must resolve the ambiguity.
- Many couriers integrated with Qapla' (Amazon, Poste Italiane, most international carriers) have **no pattern** in `detectCourier`. Always allow the merchant to specify the courier explicitly in `pushShipment` via the `courier` field.
- The variant `POST /1.3/detectOrderCourier/` applies channel-specific routing rules to return a single courier for an existing order — it is order-aware and not a general-purpose lookup.
