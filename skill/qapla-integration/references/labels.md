---
source: https://api.qapla.dev
synced: 2026-06-15
api_versions: [1.2, 1.3]
---

# Qapla' Label API — Integration Reference

API host: `api.qapla.it` (docs site: `https://api.qapla.dev`)

Covered: createLabel, confirmLabel, multi-collo, COD, returns, customs, insurance, PUDO fields.

---

## Authentication

Pass the channel API key in **one** of three ways:

| Method | Format |
|--------|--------|
| HTTP header | `X-API-Key: <key>` |
| Query string | `?apiKey=<key>` |
| JSON body top-level | `"apiKey": "<key>"` |

The key identifies the channel; all created/updated resources are automatically scoped to it.

**Rate limit**: 120 tokens per channel, refilled at 2 tokens/second. Excess returns HTTP 429.

---

## createLabel

Generates a carrier label synchronously. The response always contains the label; there is no polling step.

### Endpoints

```
POST https://api.qapla.it/1.3/createLabel/
POST https://api.qapla.it/1.4/createLabel/
```

v1.4 is a superset of v1.3: the only addition is `parcelsTracking` in the response. Request parameters are identical across both versions. **Use v1.4** if you handle multi-collo and need per-parcel tracking numbers.

### Request structure

```json
{
  "apiKey": "<channel-api-key>",
  "sandbox": true,
  "createLabel": {
    "reference": "ORD-2024-001",
    "courier": "GLS-ITA",
    "courierService": "0",
    "name": "Mario Rossi",
    "address": "Via Roma 1",
    "city": "Milano",
    "state": "MI",
    "postCode": "20100",
    "country": "IT",
    "weight": 2.5
  }
}
```

### Top-level fields (siblings of `createLabel`, not inside it)

| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| `apiKey` | string | yes | Channel API key |
| `sandbox` | boolean | no | Activates carrier sandbox mode. Must already be configured on the channel. Set automatically when `courier: "GENERIC"`. **This is a top-level field, not inside `createLabel`.** |
| `includeExtShipmentID` | boolean | no | If `true`, adds `extShipmentID` to the response (e.g. DHL Express booking code). Default: `false`. |

### Fields inside `createLabel`

#### Routing

| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| `reference` | string | **yes** | Alphanumeric order reference. Acts as idempotency key: if an order with the same reference already exists on the channel, it is updated (or the existing label is returned if already generated with `isShipped: true`). |
| `orderID` | string | no | Additional numeric reference (e.g. CMS internal ID). |
| `courier` | string | **yes** | Qapla' courier code (e.g. `GLS-ITA`, `BRT`, `CRONO-PTI`, `DHL`). Special values: `GENERIC` (dummy label for testing, no real carrier needed), `AUTO` / `DETECT` (automatic selection via channel rules). Also accepts variant codes (e.g. `BRT-V1`) if configured on the channel. |
| `courierService` | string | **yes** | Carrier service code (e.g. GLS contract code, BRT service type). **Required field — pass `"0"` as default if not applicable.** If absent, Qapla' defaults to `'0'`. |
| `costCenterCode` | string | no | Cost centre code. Active for PTI only; falls back to channel default if missing or invalid. |
| `origin` | string | no | Order origin (e.g. `magento`, `woocommerce`, `amazon`, `api`). Defaults to `createLabel`. |

#### Recipient

| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| `name` | string | **yes** | Recipient name |
| `address` | string | **yes** | Recipient address |
| `city` | string | **yes** | City |
| `state` | string | **yes** | Province/state |
| `postCode` | string | **yes** | Postal code |
| `country` | string | **yes** | ISO 3166-1 alpha-2 country code (e.g. `IT`) |
| `email` | string | no | Recipient email |
| `telephone` | string | no | Recipient phone |
| `recipientTin` | string | no | Tax Identification Number |
| `recipientTinType` | string | no | TIN type. FedEx values: `PERSONAL_NATIONAL`, `PERSONAL_STATE`, `FEDERAL`, `BUSINESS_NATIONAL`, `BUSINESS_STATE`, `BUSINESS_UNION`. |

#### Amounts

| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| `amount` | float | no | Order amount (e.g. `109.25`). Decimal separator: dot; no thousands separator; max 2 decimal places. |
| `shippingCost` | float | no | Shipping cost. Same format rules as `amount`. |
| `currencyCode` | string | no | ISO 4217 currency code. Default: `EUR`. |
| `isCOD` | boolean | no | `true` for cash-on-delivery. |
| `payment` | string | no | Payment method. Can be `CONTRASSEGNO` only when `isCOD` is also `true`. |

#### Dimensions and parcels

| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| `parcels` | int \| array | no | Number of parcels (integer) **or** array of parcel objects for multi-collo with per-parcel dimensions (see [Multi-collo](#multi-collo) section). If array, the channel must have multi-collo enabled. Default: `1`. |
| `weight` | float | no | Total weight in kg. Ignored if `parcels` is an array. |
| `length` | float | no | Length in cm. Ignored if `parcels` is an array. |
| `width` | float | no | Depth in cm. Ignored if `parcels` is an array. |
| `height` | float | no | Height in cm. Ignored if `parcels` is an array. |

#### Shipping services

| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| `shippingInsurance` | float \| string | no | Insurance amount or code. See [Insurance codes](#insurance-codes) section. |
| `shippingDeliveryOptions` | string \| JSON | no | Additional delivery options, comma-separated (e.g. `"A,P"`, `"22,07"`). PTI: structured JSON. GLS-ITA: pass `"ALLIN"` here to activate comprehensive insurance. BRT Fresh: pass `FRESH_YYYY-MM-DD` (expiry date of refrigerated product; date portion is optional). |
| `shippingCODPaymentOption` | string | no | COD payment mode override (confirm with support). |
| `shippingRequiredDeliveryDate` | string (YYYY-MM-DD) | no | Required delivery date. **Mandatory for PAACK.** |
| `shippingRequiredDeliveryTimeSlot` | string (HS-HE) | no | Delivery time window (e.g. `"8-21"`). **Mandatory for PAACK**; HS and HE must be between 0 and 23. |
| `latestShipDate` | string (YYYY-MM-DD) | no | Latest ship date. |
| `latestDeliveryDate` | string (YYYY-MM-DD) | no | Latest delivery date. |
| `pickupDate` | string (YYYY-MM-DD) | no | Requested pickup date. For SDA: if not specified, the next working day is assigned automatically at transmission. |
| `numberOfPallets` | int | no | Number of pallets (carrier-dependent). |

#### Direct printing

| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| `printNodePrinterID` | int \| string | no | PrintNode printer ID or name. If set, label is sent directly to the printer. |
| `gSpedPrinterID` | int | no | Gsped Labeling Machine printer ID. |
| `forceReprint` | int | no | `1` to force re-print via PrintNode of an already-generated label (requires `printNodePrinterID`). |
| `forceLabelsOutput` | int | no | `1` to include label base64 in response even when PrintNode/GLM is used. Default: `0`. |

#### Other fields

| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| `notes` | string | no | Order notes |
| `content` | string | no | Goods description (may appear on label, carrier-dependent) |
| `custom1`–`custom3` | string | no | Custom fields 1–3 |
| `tag` | string | no | Coloured tag visible in CP. Values: `green`, `yellow`, `orange`, `blue`, `cyan`, `red`. |
| `goodsCode` | string | no | Goods code. FERCAM: `BANC` (pallet pricing). |
| `forceRowsUpdate` | int | no | `1` to overwrite all order line items. No effect if labels already generated. |

#### Alternative sender (`sender`)

If the sender differs from the contract holder. Pass the code string if already configured:

```json
"sender": "my-sender-code"
```

Or pass the full object:

| Field | Type | Required |
|-------|------|:--------:|
| `code` | string | **yes** |
| `businessName`, `street`, `city`, `state`, `postCode`, `country` | string | no |
| `email`, `telephone`, `referent` | string | no |
| `isDefault` | bool | no |

#### Invoice (`invoice`)

Required for DHL international shipments. Useful for any cross-border customs clearance.

```json
"invoice": {
  "number": "A00012345/2024",
  "date": "2024-03-15"
}
```

| Field | Type | Required |
|-------|------|:--------:|
| `number` | string | **yes** (for DHL) |
| `date` | string (YYYY-MM-DD) | no |

#### Trade documents (`tradeDocuments`)

Array of electronic documents to transmit to the carrier (DHL, FedEx, UPS). Max file size: 5 MB each. Each element:

| Field | Type | Description |
|-------|------|-------------|
| `type` | string | Document type (see table below) |
| `name` | string | File name |
| `content` | string | File content in **base64** |

Supported document types by carrier:

| Type | FedEx | DHL | UPS |
|------|:-----:|:---:|:---:|
| `AUTHORIZATION_FORM` | | yes | yes |
| `CERTIFICATE_OF_ORIGIN` | yes | yes | yes |
| `COMMERCIAL_INVOICE` | yes | yes | yes |
| `DECLARATION` | | yes | yes |
| `EXPORT_ACCOMPANYING_DOCUMENT` | | yes | yes |
| `EXPORT_LICENSE` | | yes | yes |
| `IMPORT_PERMIT` | | yes | yes |
| `NAFTA_CERTIFICATE_OF_ORIGIN` | yes | yes | |
| `ONE_TIME_NAFTA` | | yes | yes |
| `OTHER` | yes | yes | yes |
| `OTHER_DOCUMENT` | | yes | yes |
| `PACKING_LIST` | | yes | yes |
| `POWER_OF_ATTORNEY` | | yes | yes |
| `PRO_FORMA_INVOICE` | yes | yes | |
| `SED_DOCUMENT` | | yes | yes |
| `SHIPPER_LETTER_OF_INSTRUCTION` | | yes | yes |

#### FedEx customs fields

| Field | Type | Description |
|-------|------|-------------|
| `shippingCharge` | string | Who pays shipping: `SENDER`, `RECIPIENT`, `THIRD_PARTY`. If not `SENDER`, also specify `shippingChargeAccount`. |
| `shippingChargeAccount` | string | Account for shipping charge billing. |
| `pickupType` | string | FedEx pickup type: `USE_SCHEDULED_PICKUP`, `CONTACT_FEDEX_TO_SCHEDULE`, `DROPOFF_AT_FEDEX_LOCATION`. |
| `signatureRequired` | string | FedEx signature: `ADULT`, `DIRECT`, `INDIRECT`, `NO_SIGNATURE_REQUIRED`, `SERVICE_DEFAULT`. |
| `customCharges` | string | Who pays customs: `SENDER`, `RECIPIENT`, `THIRD_PARTY`. |
| `customChargesAccount` | string | Account for customs charge billing. |
| `customsChargesBroker` | string | Broker code for customs clearance (contact support to configure). |
| `customsRecipientIDType` | string | Recipient ID document type: `COMPANY`, `INDIVIDUAL`, `PASSPORT`. |
| `customsRecipientID` | string | Recipient ID document number (requires `customsRecipientIDType`). |
| `totalCustomsValue` | float | Total declared customs value. |
| `dangerousGoods` | JSON array | Dangerous goods (FedEx only). Each item: `parcel` (parcel number string), `type` (`battery`, `dangerous_goods`, `dry_ice`, `alcohol`), plus type-specific attributes. Batteries: `batteryPackingType` (`CONTAINED_IN_EQUIPMENT` \| `PACKED_WITH_EQUIPMENT`), `batteryMaterialType` (`LITHIUM_METAL` \| `LITHIUM_ION`). |

#### Order line items (`rows`)

Optional array. `sku` is the discriminant; rows without `sku` are ignored.

| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| `sku` | string | **yes** | Item SKU |
| `name` | string | **yes** | Item description |
| `qty` | int | **yes** | Quantity |
| `price` | float | **yes** | Unit price |
| `total` | float | no | Line total (calculated as `price × qty` if absent) |
| `weight` | float | no | Item weight |
| `url`, `imageUrl` | string | no | Product URL / image URL |
| `notes` | string | no | Item notes |
| `isReturnable` | bool | no | Eligible for return. Default: `true`. |
| `customsCode` | string | no | Customs/HS/TARIC code |
| `originCountry` | string | no | Country of origin (ISO 3166-1 alpha-2) |
| `netWeight` | float | no | Net weight |
| `unitOfMeasurement` | string | no | Unit of measurement |
| `parcelID` | int | no | Parcel number this item ships in (multi-collo). If used, must be set on all rows; distinct `parcelID` count must match parcel count. |
| `transparencyCodes` | string[] | no | Amazon Transparency Codes |
| `custom1`–`custom5` | string | no | Custom fields 1–5 |

### Response (200 OK)

```json
{
  "createLabel": {
    "version": "1.3.32",
    "result": "OK",
    "error": null,
    "isShipped": false,
    "id": 45231,
    "courier": "CRONO-PTI",
    "courierService": "P46",
    "trackingNumber": "F000538025683",
    "returnTrackingNumber": null,
    "format": "PDF",
    "labels": ["JVBERi0xLjQK..."]
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `result` | string | `OK` on success, `KO` on error |
| `error` | string \| null | Error description (only present when `result: KO`) |
| `isShipped` | boolean | `true` if order was already labelled; existing label returned without regeneration |
| `id` | int | Shipment ID in the label table. Use with `getLabel`, `updateShipment`, `confirmLabel`. |
| `courier` | string | Courier code used (useful with `AUTO`/`DETECT`) |
| `courierService` | string \| null | Carrier service code actually applied |
| `trackingNumber` | string | Shipment tracking number |
| `returnTrackingNumber` | string \| null | Return tracking number if one was generated alongside the outbound label. Otherwise `null`. This is a standard createLabel response field — it can be null for most shipments. |
| `format` | string | Label format: `PDF` (base64), `JPG` (base64), `ZPL` |
| `labels` | array \| string | Array of base64-encoded label(s); multiple elements for multi-collo, or when a return label is included. ZPL is returned as a string. If direct printing (PrintNode/GLM) was used without `forceLabelsOutput: 1`, contains `"Label sent to PrintNode"` or `"Label sent to Gsped Labeling Machine"`. |
| `extShipmentID` | string | Carrier-assigned alternate ID. Present only if `includeExtShipmentID: true` in request. |
| `parcelsTracking` | array \| null | **(v1.4 only)** Array of `{"trackingNumber": "..."}` objects, one per parcel. `null` if the carrier does not assign per-parcel tracking numbers. |

### Error response

```json
{
  "createLabel": {
    "result": "KO",
    "error": "Mandatory field `name` is empty"
  }
}
```

Common errors:

| Error | Cause |
|-------|-------|
| `Mandatory field 'X' is empty` | Missing required field |
| `Invalid courier XXX` | Courier code not recognised or label-generation not supported |
| `Courier setup not purchased` | Carrier product not active for this channel |
| `Country must be in ISO 3166-1 alpha-2 format` | Invalid `country` code |
| `Currency code must be in ISO 4217 format` | Invalid `currencyCode` |
| `parcels: Cannot send json object if multiparcels isn't active` | Array `parcels` sent but multi-collo not enabled on the channel |
| `weight, width, length, height: mandatory fields when boxCode is not sent` | Parcel object missing required dimensions |
| `Could not found matching rules for order` | `AUTO`/`DETECT` courier with no matching rules |

### Gotchas

- **Idempotency**: sending a second call with the same `reference` returns the existing label with `isShipped: true`. Use distinct references.
- **`GENERIC` courier**: always activates sandbox automatically. Generates a dummy label with no real carrier configuration required — ideal for integration testing.
- **`AUTO`/`DETECT`**: uses channel shipping rules. Returns `KO` if no rule matches.
- **PrintNode**: label is sent to the printer in background after the response is returned. Use `forceLabelsOutput: 1` to also get the base64 in the response.
- **Tracking activation**: after label creation the shipment is NOT yet in tracking. It only enters tracking after transmission (`confirmLabel`) the tracking number appears in the tracking system shortly after transmission is confirmed.

---

## confirmLabel

Transmits already-generated labels to the carrier, marking them as shipped. This is the step that activates tracking (pillar 1) and transactional events (pillar 2).

### Endpoint

```
POST https://api.qapla.it/1.2/confirmLabel/
POST https://api.qapla.it/1.3/confirmLabel/
```

### Request

Confirmation is **per (channel, courier)**; you cannot confirm labels from different carriers in one call.

```json
{
  "apiKey": "<channel-api-key>",
  "confirmLabel": {
    "courier": "GLS-ITA",
    "shipmentIDs": [12345, 12346, 12347]
  }
}
```

Two mutually exclusive selection modes:

| Mode | Field | Selects |
|------|-------|---------|
| By ID list | `shipmentIDs` | Array of shipment `id` values (the `id` returned by `createLabel`) |
| By creation date | `labelCreationDate` | All unshipped labels for that courier on that date (`YYYY-MM-DD`). Caution: confirms everything not yet transmitted for that day. |

### Response

```json
{
  "confirmLabel": {
    "result": "OK",
    "error": null,
    "transmitted": 3,
    "errors": []
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `result` | string | `OK` if at least one label was transmitted; `KO` if all failed |
| `error` | string \| null | Error description if `result: KO` |
| `transmitted` | int | Number of labels successfully transmitted |
| `errors` | array | Transmission errors for individual labels (carrier API rejections) |

**Note**: the `shipmentIDs` field is the correct selector for per-ID confirmation. There is no `labelID` field. The response does not contain a `manifest` or `number` field.

### What happens after confirmLabel

After transmission the shipment moves into the tracking system automatically and the tracking number becomes visible shortly after. This activation is asynchronous — do not poll confirmLabel repeatedly.

### Gotchas

- For carriers that do not support a sandbox (e.g. GLS-ITA), every transmission creates a real carrier entry. Confirm only labels you intend to ship.
- Some carriers (e.g. BRT) return a `parcelID` at label-creation time that is NOT the final tracking number. The real tracking number is resolved asynchronously after transmission.
- Slow carrier APIs can delay the `confirmLabel` response — implement a reasonable HTTP timeout (30–60 s) on your client.

---

## Multi-collo

A multi-parcel shipment is an order split across multiple physical boxes, each potentially with its own tracking number.

### Enabling multi-collo

The channel must have multi-collo enabled. Sending an array `parcels` without this enabled returns an error.

### `parcels` field — two forms

**Form 1 — integer count** (uniform parcels):

```json
"parcels": 3,
"weight": 4.5
```

Three parcels of equal weight (4.5 kg total divided evenly). No per-parcel dimension detail.

**Form 2 — array of parcel objects** (per-parcel dimensions):

```json
"parcels": [
  {"weight": 1.3, "length": 30, "width": 20, "height": 15},
  {"weight": 0.8, "length": 20, "width": 15, "height": 10}
],
```

When using the array form, the top-level `weight`, `length`, `width`, `height` fields are ignored. The total weight is calculated as the sum of parcel weights.

### Per-parcel object fields

| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| `weight` | float | **yes** (unless `boxCode` set) | Parcel weight in kg |
| `length` | float | **yes** (unless `boxCode` set) | Length in cm |
| `width` | float | **yes** (unless `boxCode` set) | Depth in cm |
| `height` | float | **yes** (unless `boxCode` set) | Height in cm |
| `boxCode` | string | no | Box code from channel box registry. If set, dimensions are read from the registry; `weight` is still required. |
| `originCountry` | string | no | Country of origin of this parcel's contents (ISO 3166-1 alpha-2) |
| `content` | string | no | Content description for this parcel |

### Per-parcel tracking (v1.4)

With v1.4, the response includes `parcelsTracking`:

```json
"parcelsTracking": [
  {"trackingNumber": "12345678"},
  {"trackingNumber": "12345679"}
]
```

`null` if the carrier does not assign distinct tracking numbers per parcel.

### Assigning line items to parcels

Use `parcelID` in the `rows` array to indicate which parcel each item ships in. If used, `parcelID` must be set on **all** row items; the number of distinct `parcelID` values must equal the number of parcels.

### Gotchas

- GLS-ITA: maximum 99 parcels per shipment.
- When parcels is an integer and the carrier requires per-parcel weights, the total weight is divided evenly; the remainder is added to the last parcel.
- BRT Fresh service (`FRESH_YYYY-MM-DD`) forces ZPL label format.

---

## COD (Cash on Delivery / Contrassegno)

### Activating COD

Set both fields in the `createLabel` body:

```json
"isCOD": true,
"payment": "CONTRASSEGNO",
"amount": 109.25
```

The `amount` field is the COD amount to collect. The carrier API receives this value and prints it on the label.

### COD payment mode

`shippingCODPaymentOption` overrides the default COD collection mode configured on the channel. Contact support for available values per carrier.

### Carrier notes

| Carrier | Notes |
|---------|-------|
| SDA | Payment type via `codTipoPagamento`; value `CONT` is normalised to `CON` internally. Default: `VAR`. |
| TWS | Maximum COD amount: 999.00 EUR. |
| BRT DPD Direct Infeed | COD not available; returns an error. |
| GLS-ITA | COD amount can be modified or cancelled after transmission via the release (svincolo) function in CP. |

### Reconciliation

After delivery is confirmed by tracking, COD shipments appear in the CP Contrassegni section. Reconciliation (marking as collected) is manual — either individually in the Control Panel or by uploading a carrier-provided CSV.

---

## Returns

### How returns work

Qapla' does not have a separate `createReturnLabel` API endpoint (it is disabled in v1.3). Returns are created via the standard `createLabel` flow:

1. Use a return-capable courier (e.g. CRONO_REVERSE, a DHL Returns service) as the `courier` value.
2. Configure the recipient as the merchant (the goods travel back to the sender).
3. The `returnTrackingNumber` field in a standard createLabel response is a companion return tracking number generated alongside the outbound label — it is `null` when no return label was requested or when the carrier does not support it.

### Return label in the tracking system

A return shipment appears in tracking just like an outbound shipment. There is no special `isReturnShipment` field in the getShipment response; return shipments are identified by the courier's `isReturn` flag in the courier registry and the channel configuration.

### Failed delivery vs. return shipment

These are two distinct concepts:

- **Failed delivery (rientro)**: an outbound shipment that the carrier could not deliver and sent back. Tracked on the original shipment record; status becomes RETURNED (95) when detected.
- **Return shipment**: a new outbound-in-reverse shipment created explicitly by the merchant or customer. It has its own tracking number and is a separate entity.

### Return flow via tracking page

If the merchant has a return channel configured, customers can initiate a return from the Qapla' tracking page (whitelabel). Qapla' then generates the return label automatically on the configured return carrier.

---

## Insurance

### Insurance by carrier

| Carrier | How to activate | Codes / values |
|---------|-----------------|----------------|
| **SDA** | Set `shippingInsurance` to a string code | `AS01`, `AS02`, `AS03`, `AS04`, `AS05`, `AS12`, `AS13`. Also `ASPERC` (percentage, only for services S09 and S24). |
| **CRONO-PTI** | Same as SDA | All SDA codes above plus `AS14`. |
| **GLS-ITA** | Set `shippingDeliveryOptions: "ALLIN"` | `ALLIN` (no hyphen) activates comprehensive insurance (`AssicurazioneIntegrativa`). Do not use `shippingInsurance` for GLS-ITA. |
| **BRT Fresh** | Set `shippingDeliveryOptions` to `FRESH_YYYY-MM-DD` | This activates the B20 Fresh service (refrigerated); it is not an insurance product. BRT does not use SDA-style insurance codes or the `ALLIN` flag. |
| **SDA S34 (Road Europe)** | `shippingInsurance: "AS12"` | AS12 is specific to the S34 service. |

**Do not** pass `ALLIN` to BRT. **Do not** attribute GLS-ITA insurance to BRT. These are distinct fields and carriers.

---

## PUDO (Pick-Up / Drop-Off Points)

### Finding PUDO points

Use the `getPudos` endpoint to search for nearby collection points:

```
POST https://api.qapla.it/1.2/getPudos/
```

The response includes a `pushOrderPUDO` node ready to pass directly to `createLabel`.

### Setting a PUDO in createLabel

Add a `PUDO` object inside `createLabel`:

```json
"PUDO": {
  "id": "1234",
  "type": "ConsegnaLocker",
  "name": "Locker Stazione Centrale",
  "address": "Piazza Duca d'Aosta 1",
  "city": "Milano",
  "state": "MI",
  "country": "IT",
  "postalCode": "20124"
}
```

The fields `name`, `address`, `city`, `state`, `country`, `postalCode` are used to populate transactional emails to the recipient with the collection point address. Omit them only if email display is not needed.

### Required PUDO fields by carrier

| Carrier | Required fields |
|---------|----------------|
| DHL, BRT, INPOST, FedEx, MRW, SENDING, MONDIALRELAY | `id` |
| TNT-ITA | `id`, `type` (`3` = TNT point, `5` = Locker) |
| GLS-ITA | `id` (SHOP_ID), `type` (PARTNER_SHOP_ID) |
| LICCARDI | `id` (collection point code), `type` (network code, default: `GEL`) |
| PTI (Poste Italiane) | `id`, `type` (`ConsegnaPuntoPoste` \| `ConsegnaUfficioPostale` \| `ConsegnaLocker` \| `ConsegnaPUDOUPS`), `name`, `address`, `postalCode`, `city`, `province`, `country` |
| UPS | `id`, `address`, `city`, `country`, `name`, `postalCode`, `state` |
| SDA | `id`, `address`, `city`, `name`, `postalCode`, `state` |
| DHL-PAKET | `id`, `type` (`locker` \| `postoffice`), `city`, `name`, `country`, `postalCode`. Also `postnumber` (required when `type = postoffice`). |
| DHLPARCEL-ES | `id`, `address`, `city`, `country`, `postalCode`, `harmonisedId`, `keyword`, `psfKey` |
| GLS-SPAIN | `id`, `name`, `address`, `city`, `country`, `postalCode` |
| CORREOS-EXPRESS | `id`, `address`, `city`, `country`, `postalCode` |
| SEUR | `id` |
| TIPSA | `id`, `address`, `city`, `name`, `postalCode` |

### PUDO storage

PUDO data is stored as JSON alongside the shipment and propagated through the label and tracking flows. It is not stored in a separate PUDO registry table.

---

## Customs (International Shipments)

### Line item customs fields (in `rows`)

For international shipments requiring customs declarations, populate these fields on each row item:

| Field | Description |
|-------|-------------|
| `customsCode` | HS/TARIC customs tariff code |
| `originCountry` | Country of manufacture (ISO 3166-1 alpha-2) |
| `netWeight` | Net weight of the item |
| `unitOfMeasurement` | Unit of measurement |

### Invoice

For DHL international shipments, the `invoice` object is required:

```json
"invoice": {
  "number": "INV-2024-001",
  "date": "2024-03-15"
}
```

### Trade documents

Attach scanned/electronic commercial documents via `tradeDocuments`. See the full type list in the createLabel section above. Support varies: DHL supports the widest range (~16 types), FedEx and UPS support a subset.

### FedEx-specific customs

FedEx international shipments support additional customs control via the FedEx customs fields listed in the createLabel section: `shippingCharge`, `customCharges`, `customsRecipientIDType`, `totalCustomsValue`, `dangerousGoods`, etc.

### SDA P48 (Crono Internazionale)

Uses dedicated customs handling. Requires items with `customsCode` and `originCountry` per parcel. The channel must have a default customs code and manufacture countries configured as fallback defaults in the Control Panel.

---

## Complete Request Example

```json
{
  "apiKey": "my-channel-api-key",
  "sandbox": true,
  "createLabel": {
    "reference": "BAT-234241299",
    "courier": "CRONO-PTI",
    "courierService": "P46",
    "name": "Barbara Gordon",
    "address": "Via Manin 8",
    "city": "Vigonza",
    "state": "PD",
    "postCode": "35010",
    "country": "IT",
    "email": "batgirl@yahoo.it",
    "telephone": "3473425220",
    "isCOD": false,
    "amount": 109.25,
    "shippingCost": 9.35,
    "currencyCode": "EUR",
    "parcels": [
      {"weight": 1.3, "length": 10, "width": 15, "height": 5},
      {"weight": 0.8, "length": 8, "width": 12, "height": 4}
    ],
    "shippingInsurance": "AS01",
    "PUDO": {
      "id": "1234",
      "type": "ConsegnaLocker",
      "name": "Locker Stazione Centrale",
      "address": "Piazza Duca d'Aosta 1",
      "city": "Milano",
      "state": "MI",
      "country": "IT",
      "postalCode": "20124"
    },
    "invoice": {
      "number": "A00012345/2024",
      "date": "2024-03-15"
    },
    "rows": [
      {
        "sku": "PROD-001",
        "name": "Gadget Tecnologico",
        "qty": 1,
        "price": 109.25,
        "parcelID": 1
      }
    ]
  }
}
```

### v1.4 multi-collo response

```json
{
  "createLabel": {
    "version": "1.4.0",
    "result": "OK",
    "error": null,
    "isShipped": false,
    "id": 45231,
    "courier": "GLS-ITA",
    "courierService": "0",
    "trackingNumber": "MI12345678",
    "returnTrackingNumber": null,
    "format": "PDF",
    "labels": ["JVBERi0xLjQK...", "JVBERi0xLjQL..."],
    "parcelsTracking": [
      {"trackingNumber": "MI12345678"},
      {"trackingNumber": "MI12345679"}
    ]
  }
}
```
