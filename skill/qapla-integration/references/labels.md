---
source: https://api.qapla.dev
synced: 2026-06-15
api_versions: [1.2, 1.3]
---

# Qapla' Labels API Reference

This document covers label generation, confirmation, multi-parcel shipments, COD (contrassegno), returns, and customs for international shipments.

> **Activation note:** The `createLabel` endpoint requires explicit activation. Contact Qapla' Customer Care before integrating.

---

## 1. createLabel — Generate a Shipping Label

**Purpose:** Synchronously generates a shipping label (PDF, JPG, or ZPL) and assigns a tracking number. The label is created and transmitted to the carrier; the shipment appears in tracking shortly after transmission (not instantly).

**Method + path:** `POST https://api.qapla.it/1.3/createLabel/`

### Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `apiKey` | string | Channel API key |
| `reference` | string | Order alphanumeric identifier |
| `courier` | string | Qapla' courier code (e.g. `BRT`, `DHL`, `GLS-ITA`) |
| `courierService` | string | Service/contract code; defaults to `"0"` if omitted |
| `name` | string | Recipient full name |
| `address` | string | Recipient street address |
| `city` | string | Recipient city |
| `state` | string | Recipient province/state |
| `postCode` | string | Recipient postal code |
| `country` | string | ISO 3166-1 alpha-2 (e.g. `IT`) |

### Key Optional Fields

| Field | Type | Description |
|-------|------|-------------|
| `origin` | string | Platform source (`shopify`, `woocommerce`, `magento2`, etc.) |
| `orderID` | string | Numeric order reference |
| `email` | string | Recipient email (used for notifications) |
| `telephone` | string | Recipient phone |
| `amount` | float | Shipment value (dot separator, max 2 decimals) |
| `currencyCode` | string | ISO 4217; default `EUR` |
| `isCOD` | boolean | `true` for cash-on-delivery — see [Contrassegno](#4-contrassegno-cod) |
| `payment` | string | Set to `CONTRASSEGNO` only when `isCOD` is `true` |
| `shippingCODPaymentOption` | string | COD payment method variant (carrier-specific) |
| `weight` | float | Shipment weight in kg |
| `parcels` | int | Number of packages (colli) — see [Multi-collo](#3-multi-collo-multiple-parcels) |
| `length` / `width` / `height` | float | Parcel dimensions in cm |
| `notes` | string | Order notes |
| `content` | string | Goods description (printed on label, carrier-dependent) |
| `shippingInsurance` | float \| string | Insurance amount or code — see [Insurance codes](#insurance-codes) |
| `shippingDeliveryOptions` | string \| JSON | Comma-separated delivery preferences (e.g. `"A,P"`) |
| `shippingRequiredDeliveryDate` | string | Requested delivery date, `YYYY-MM-DD` |
| `pickupDate` | string | Collection/pickup date, `YYYY-MM-DD` |
| `sandbox` | boolean | `true` for test mode (no operational effect) |
| `custom1` / `custom2` / `custom3` | string | Custom pass-through fields |

### Object Fields

**`sender`** (optional object) — override the default sender: `code`, `businessName`, `street`, `city`, `state`, `postCode`, `country`, `email`, `telephone`, `referent`, `isDefault`.

**`rows`** (optional array) — product line items:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `sku` | string | yes | Article code |
| `name` | string | yes | Product description |
| `qty` | int | yes | Quantity |
| `price` | float | yes | Unit price |
| `total` | float | no | Line total |
| `weight` | float | no | Item weight |
| `isReturnable` | boolean | no | Return eligibility (defaults `true`) |
| `customsCode` | string | no | HS / Taric code — required for customs |
| `originCountry` | string | no | ISO 3166-1 alpha-2, product origin |

**`PUDO`** (optional object) — pickup/drop-off point; structure varies by carrier (see [PUDO fields](#pudo-carrier-specific-fields)).

**`invoice`** (optional object) — mandatory for DHL international: `{ "number": "FT-2026-001" }`.

**`tradeDocuments`** (optional array) — customs documents (max 5 MB each, base64): `{ "type": "COMMERCIAL_INVOICE", "name": "invoice.pdf", "content": "<base64>" }`. Types include `CERTIFICATE_OF_ORIGIN`, `COMMERCIAL_INVOICE`, `OTHER` (carrier-dependent).

### JSON Request Example

```json
{
  "apiKey": "YOUR_API_KEY",
  "createLabel": {
    "origin": "shopify",
    "reference": "ORD-2026-1234",
    "courier": "BRT",
    "courierService": "P46",
    "name": "Mario Rossi",
    "address": "Via Garibaldi 10",
    "city": "Bologna",
    "state": "BO",
    "postCode": "40121",
    "country": "IT",
    "email": "mario.rossi@example.com",
    "telephone": "3471234567",
    "amount": 89.99,
    "currencyCode": "EUR",
    "weight": 2.5,
    "parcels": 1,
    "length": 30,
    "width": 20,
    "height": 15
  }
}
```

### Response Example

```json
{
  "createLabel": {
    "version": "1.3.x",
    "result": "OK",
    "error": null,
    "isShipped": false,
    "id": 100042,
    "courier": "BRT",
    "trackingNumber": "12345678901",
    "returnTrackingNumber": null,
    "format": "PDF",
    "labels": ["<base64-encoded-PDF>"]
  }
}
```

| Response field | Type | Description |
|----------------|------|-------------|
| `id` | int | Shipment ID — required for `confirmLabel` and `deleteLabel` |
| `trackingNumber` | string | Carrier-assigned tracking number |
| `returnTrackingNumber` | string | Return label tracking number, if applicable |
| `format` | string | `PDF`, `JPG`, or `ZPL` |
| `labels` | array | Base64-encoded label(s) |
| `isShipped` | boolean | `true` if a label already existed for this order |

> **v1.4 note:** A `parcelsTracking` array in the response exposes per-parcel tracking numbers for multi-collo shipments. Not present in v1.3.

### Gotchas

- After a label is created and transmitted, the shipment appears in tracking **shortly after** — not immediately.
- `courierService` defaults to `"0"` if empty; always pass the correct service code to avoid wrong contract selection.
- For integration testing, use courier code `GENERIC` with `sandbox: true`.
- `payment: "CONTRASSEGNO"` must only be set when `isCOD` is also `true`.
- Label format (PDF/JPG/ZPL) is controlled by your channel configuration, not by a request parameter.
- The `id` returned is the Qapla' shipment ID, not the carrier AWB — store it for `confirmLabel` / `deleteLabel`.

---

## 2. confirmLabel — Transmit Labels to Carrier

**Purpose:** Confirms and transmits to the carrier one or more labels previously created with `createLabel`. Returns a loading list (borderò / manifest) in PDF. A label must be confirmed before the carrier will accept the shipment.

**Method + path:** `POST https://api.qapla.it/1.2/confirmLabel/` (also callable at `1.3`).

### Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `apiKey` | string | Channel API key |
| `courier` | string | Qapla' courier code |

### Selection Modes (one required)

| Field | Type | Description |
|-------|------|-------------|
| `labelCreationDate` | string | Confirm all labels created on this date (`YYYY-MM-DD`) |
| `labelID` | array of int | Confirm specific labels by their `id` from `createLabel` |

> Use either `labelCreationDate` **or** `labelID`, not both.

### JSON Request Examples

```json
{ "apiKey": "YOUR_API_KEY", "confirmLabel": { "courier": "DHL", "labelCreationDate": "2026-06-15" } }
```
```json
{ "apiKey": "YOUR_API_KEY", "confirmLabel": { "courier": "BRT", "labelID": [100042, 100043, 100044] } }
```

### Response Example

```json
{
  "confirmLabel": {
    "version": "1.2.9", "result": "OK", "error": null,
    "courier": "BRT", "number": "00017-2026", "date": "2026-06-15 14:30:00",
    "shipments": 3, "manifest": "<base64-encoded-PDF>"
  }
}
```

### Gotchas

- `confirmLabel` is the **transmission step** — without it the carrier is unaware of the shipment.
- Confirm by `labelCreationDate` for end-of-day batch closes; by `labelID` array for real-time/partial closes.
- An already-confirmed label cannot be confirmed again; use `deleteLabel` first if corrections are needed.

---

## 3. Multi-collo (Multiple Parcels)

**Purpose:** Declare a shipment composed of multiple physical packages (colli) under a single order reference.

In `createLabel`, pass `parcels` as an **integer** count of packages. Top-level `weight` and dimensions apply to each package when all are identical.

```json
{
  "apiKey": "YOUR_API_KEY",
  "createLabel": {
    "reference": "ORD-2026-5678", "courier": "GLS-ITA", "courierService": "0",
    "name": "Giulia Bianchi", "address": "Via Nazionale 5", "city": "Roma",
    "state": "RM", "postCode": "00100", "country": "IT",
    "weight": 8.0, "parcels": 3, "length": 40, "width": 30, "height": 25
  }
}
```

When packages differ, use the `rows` array with a `parcelID` field to assign products to specific parcels.

### Carrier Notes

Some carriers (**FedEx**, **UPS**, **TNT**, **GLS-ITA**) generate one label per physical parcel. For these, `createLabel` returns multiple entries in the `labels` array — one per collo — each possibly with a distinct tracking number. Store all returned `labels` and print them in order. Carriers that consolidate multi-collo under a single master label return a single `labels` entry.

### Gotchas

- Validate that your printer workflow handles an **array** of labels; assuming a single label breaks multi-collo.
- For dangerous goods (batteries), each parcel must be declared individually using its parcel index.

---

## 4. Contrassegno (COD — Cash on Delivery)

**Purpose:** Flag a shipment for payment collection at delivery. The COD amount and payment method are transmitted to the carrier on confirmation.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `isCOD` | boolean | yes | `true` to enable cash-on-delivery |
| `amount` | float | yes (if COD) | Amount to collect (dot separator, max 2 decimals) |
| `payment` | string | yes (if COD) | Set to `"CONTRASSEGNO"` |
| `shippingCODPaymentOption` | string | no | COD payment variant (carrier-specific) |

```json
{
  "apiKey": "YOUR_API_KEY",
  "createLabel": {
    "reference": "ORD-COD-999", "courier": "BRT", "courierService": "P46",
    "name": "Luca Ferrari", "address": "Via Manzoni 3", "city": "Torino",
    "state": "TO", "postCode": "10121", "country": "IT",
    "isCOD": true, "payment": "CONTRASSEGNO", "amount": 149.90, "currencyCode": "EUR"
  }
}
```

**Reconciliation:** COD is collected by the carrier at delivery and reconciled afterwards, reported back through Qapla'. Consult Customer Care for the settlement timeline of your carrier contract.

### Gotchas

- `payment: "CONTRASSEGNO"` without `isCOD: true` causes a validation error.
- `shippingCODPaymentOption` values are carrier-specific and must be agreed with Qapla' support.
- Not all carriers support all COD payment variants.

---

## 5. Returns (Resi)

**Purpose:** Generate a return (reverse logistics) label so the end customer can send goods back to the sender. Returns use a dedicated return channel configured in the Control Panel.

A return label is obtained via `createLabel` using a **return-enabled courier service** on the return channel. The response includes a `returnTrackingNumber` when the carrier assigns a separate number for the return leg.

```json
{
  "apiKey": "YOUR_RETURN_CHANNEL_API_KEY",
  "createLabel": {
    "reference": "RET-ORD-2026-1234", "courier": "BRT", "courierService": "P46",
    "name": "Mario Rossi", "address": "Via Garibaldi 10", "city": "Bologna",
    "state": "BO", "postCode": "40121", "country": "IT", "weight": 2.5, "parcels": 1
  }
}
```

> The `sender` object in the return call should contain the **merchant's warehouse address** (return destination), and `name`/`address` the **customer's address** (pickup origin).

Per-item return eligibility is controlled by `isReturnable` (boolean) on each `rows` entry when pushing orders/shipments.

### Key Response Fields for Returns

| Field | Description |
|-------|-------------|
| `returnTrackingNumber` | Tracking number for the return leg (may match outbound or be distinct) |
| `isReturnShipment` | `true` in `getShipment` responses when a shipment is a return |

### Webhooks for Returns

Return-related events are delivered via the **Shipments Return Webhook** (a separate webhook type from the standard tracking webhook). See [webhooks.md](webhooks.md) for the payload schema and response contract. Configure the return webhook endpoint separately in the Control Panel.

### Gotchas

- Return labels require a **dedicated return channel** — the standard outbound channel API key will not produce return labels.
- Not all carriers support automatic return label generation; confirm with Customer Care.
- If `returnTrackingNumber` is `null`, the carrier uses the same tracking number for both legs (carrier-dependent).

---

## Supplementary Topics

### Insurance Codes

Pass `shippingInsurance` as a float (declared value) or as a string code for carriers with fixed tiers. String codes apply to **SDA** and **CRONO-PTI** (e.g. `AS01`..`AS05`, `AS12`..`AS14`). For **BRT**, include `"ALL-IN"` in `shippingDeliveryOptions`. For other carriers, pass a numeric float value. Confirm exact code coverage in the live docs / Control Panel.

### PUDO (Carrier-specific Fields)

| Carrier | Required fields |
|---------|----------------|
| DHL / BRT / INPOST / FedEx | `id` |
| TNT-ITA | `id`, `type` (3=point, 5=locker) |
| GLS-ITA | `id` (SHOP_ID), `type` (PARTNER_SHOP_ID) |
| PTI (Poste Italiane) | `id`, `type` (`ConsegnaPuntoPoste` \| `ConsegnaUfficioPostale` \| `ConsegnaLocker` \| `ConsegnaPUDOUPS`), `name` |
| UPS | `id`, `address`, `city`, `country`, `name`, `postalCode`, `state` |
| SDA | `id`, `address`, `city`, `name`, `postalCode`, `state` |
| DHL-PAKET | `id`, `type` (`locker` \| `postoffice`), `city`, `name`, `country`, `postalCode`; `postnumber` for postoffice |
| DHLPARCEL-ES | `id`, `address`, `city`, `country`, `postalCode`, `harmonisedId`, `keyword`, `psfKey` |

Retrieve available PUDO points via `getPudos` before label creation (see [couriers.md](couriers.md)).

### Customs (International Shipments)

For non-EU or customs-requiring shipments include:

- **Per `rows` item:** `customsCode` (HS / Taric), `originCountry`, `netWeight`, `unitOfMeasurement`
- **`invoice` object:** invoice `number` (mandatory for DHL international)
- **`tradeDocuments` array:** base64 customs documents (max 5 MB each)
- **Recipient identification:** `recipientTin` + `recipientTinType` (`PERSONAL_NATIONAL`, `BUSINESS_NATIONAL`, etc.)
- **FedEx-specific:** `totalCustomsValue`, `customCharges` (duty payer `SENDER` / `RECIPIENT` / `THIRD_PARTY`), `customChargesAccount`, etc.

Carriers enforce different customs requirements; check carrier-specific notes or contact Customer Care before shipping internationally for the first time.
