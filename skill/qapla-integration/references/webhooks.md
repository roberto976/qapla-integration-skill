---
source: https://webhook.qapla.dev
synced: 2026-06-15
api_versions: [1.2, 1.3]
---

# Qapla' Webhooks — Receiver Reference

Qapla' webhooks are **outbound HTTP POST callbacks** that Qapla' sends to your server when events occur on a shipment or order. You configure a URL; Qapla' calls it. Your job is to expose an HTTPS endpoint, validate the payload, and respond with the correct JSON body.

---

## Event types

| Type | Trigger |
|------|---------|
| **Shipments** | Every carrier status change on a tracked shipment |
| **Shipments Return** | Customer return request (requires the *Resi automatici* add-on service; may need a separate endpoint) |
| **Orders** | Shipment creation or first transmission to the carrier |

---

## Configuration

1. In the Qapla' Control Panel go to **Settings → Channels → [your channel] → Configure → Channel**.
2. Set your webhook URL and copy the **Private API Key** shown there.
3. (Optional) Enable the **enhanced payload (v1.3)** to receive product line items, parcel dimensions, and recipient details in addition to the core tracking fields.
4. Return webhooks require the *Resi automatici* service to be active on the channel.

---

## Payload structure

All webhooks are sent as `Content-Type: application/json` HTTP POST requests.

### Shipment status event (v1.2 core fields)

```json
{
  "apiKey": "YOUR_CHANNEL_PRIVATE_KEY",
  "trackingNumber": "XX580104809",
  "courier": "GLS-ITA",
  "reference": "ORDER-51704",
  "date": "2024-03-15 10:22:00",
  "courierStatus": "delivered",
  "place": "Milan, IT",
  "qaplaStatusID": 10,
  "qaplaStatus": "Delivered",
  "statusDetails": [
    { "id": 1, "detail": "Delivered to recipient" }
  ],
  "return": 0,
  "hasChildren": 0,
  "isChild": 0,
  "custom1": "",
  "custom2": "",
  "custom3": ""
}
```

Key fields:

| Field | Description |
|-------|-------------|
| `apiKey` | Your channel's private key — **always verify this matches your stored key** |
| `trackingNumber` | Carrier tracking number |
| `courier` | Qapla' courier code (e.g. `GLS-ITA`, `DHL-EXP`) |
| `reference` | Your order reference |
| `qaplaStatusID` | Canonical Qapla' status integer (0–99) |
| `qaplaStatus` | Human-readable status label |
| `courierStatus` | Raw status code from the carrier |
| `date` | Timestamp of the status event |
| `return` / `hasChildren` / `isChild` | Boolean flags (0 or 1) for return shipments and multi-parcel groups |
| `custom1–3` | Merchant-defined metadata fields |

### v1.3 enhanced payload — additional objects

When the enhanced payload is enabled, three extra objects are included:

```json
{
  "rows": [
    {
      "id": 1,
      "sku": "WIDGET-42",
      "name": "Widget",
      "price": 9.99,
      "total": 19.98,
      "qty": 2,
      "weight": 0.3,
      "url": "https://store.example.com/widget",
      "imageUrl": "https://cdn.example.com/widget.jpg",
      "isReturnable": true,
      "customsCode": "9503.00",
      "originCountry": "IT",
      "parcelID": 1
    }
  ],
  "parcels": [
    {
      "boxCode": "BOX-M",
      "weight": 1.2,
      "length": 30,
      "width": 20,
      "height": 15,
      "originCountry": "IT",
      "content": "Electronics"
    }
  ],
  "consignee": {
    "name": "Jane Doe",
    "address": "Via Roma 1",
    "city": "Milan",
    "state": "MI",
    "postCode": "20100",
    "country": "IT",
    "email": "jane@example.com",
    "phone": "+39 02 1234567"
  }
}
```

### Orders event

Sent when a shipment is created or transmitted to the carrier. The `orders` array may contain one or more entries.

```json
{
  "apiKey": "YOUR_CHANNEL_PRIVATE_KEY",
  "orders": [
    {
      "reference": "ORDER-51704",
      "orderDate": "2024-03-14 09:00:00",
      "shipDate": "2024-03-15 08:30:00",
      "courier": "GLS-ITA",
      "trackingNumber": "XX580104809",
      "return": null,
      "returnTrackingNumber": null,
      "weight": 1.2,
      "parcels": 1,
      "length": 30,
      "width": 20,
      "height": 15,
      "amount": "€ 28.74",
      "isPOD": false,
      "customerName": "Jane Doe",
      "customerAddress": "Via Roma 1",
      "customerCity": "Milan",
      "customerState": "MI",
      "customerZip": "20100",
      "customerCountry": "IT",
      "customerTelephone": "+39 02 1234567",
      "customerEmail": "jane@example.com",
      "notes": ""
    }
  ]
}
```

---

## Response contract

Your endpoint **must** reply with one of these two exact JSON bodies:

| Outcome | Response body |
|---------|--------------|
| Success | `{"result":"OK"}` |
| Failure | `{"result":"KO"}` |

Any other body — including an empty response, HTML error page, or non-2xx HTTP status — is treated as a failure and triggers retry logic.

Minimal PHP example:

```php
const CHANNEL_API_KEY = 'YOUR_CHANNEL_PRIVATE_KEY';

$payload = json_decode(file_get_contents('php://input'));
if (!$payload || $payload->apiKey !== CHANNEL_API_KEY) {
    http_response_code(200); // still 200; body signals the rejection
    exit('{"result":"KO"}');
}

// queue async processing here — do NOT block

echo '{"result":"OK"}';
```

---

## Retry and auto-disable

- **Retries**: if your endpoint returns `{"result":"KO"}` or a malformed/missing response, Qapla' automatically retries the delivery **2 more times** over the following hours (3 total attempts per event).
- **Auto-disable**: after **100 consecutive failed deliveries** (KO or non-conforming responses) the webhook is automatically deactivated on the channel. You must re-enable it in the Control Panel.

---

## Security and operational guidance

1. **Verify `apiKey`** — check the `apiKey` field in every incoming payload against your stored channel private key before processing anything. Reject with `{"result":"KO"}` if it does not match.
2. **Use HTTPS** — Qapla' sends webhooks over HTTPS. Plain HTTP endpoints are not recommended.
3. **Respond fast** — return `{"result":"OK"}` as quickly as possible (aim for < 2 s). Offload any database writes, email sends, or downstream API calls to a background queue or job worker.
4. **Idempotency** — the same event may be delivered more than once (network retries, re-processing). Use `trackingNumber` + `qaplaStatusID` + `date` as a deduplication key.
5. **Keep the API Key secret** — treat it like a password; do not commit it to version control.

---

## Webhooks vs. pull API

Webhooks are the **push** model: Qapla' calls you when something changes, with no polling overhead. If you need to query status for a batch of shipments on your own schedule, use the `trackingByTimeFrame` pull endpoint instead — see [shipments.md](./shipments.md) for details.
