# Example — createLabel + confirmLabel (Pillar 3: generate and transmit a label)

`createLabel` generates the label and a tracking number; `confirmLabel` transmits it to the
carrier (without confirmation the carrier never sees the shipment).

## 1. createLabel (curl)

```bash
curl -sS -X POST 'https://api.qapla.it/1.3/createLabel/' \
  -H 'Content-Type: application/json' \
  -d '{
    "apiKey": "YOUR_CHANNEL_API_KEY",
    "createLabel": {
      "reference": "ORD-2026-1234",
      "courier": "BRT",
      "courierService": "P46",
      "name": "Mario Rossi",
      "address": "Via Garibaldi 10",
      "city": "Bologna", "state": "BO", "postCode": "40121", "country": "IT",
      "weight": 2.5, "parcels": 1, "length": 30, "width": 20, "height": 15
    }
  }'
```

Response contains `id`, `trackingNumber`, and base64 `labels[]`. Store the `id` for confirmation.

## 2. confirmLabel by id (curl)

```bash
curl -sS -X POST 'https://api.qapla.it/1.2/confirmLabel/' \
  -H 'Content-Type: application/json' \
  -d '{
    "apiKey": "YOUR_CHANNEL_API_KEY",
    "confirmLabel": { "courier": "BRT", "labelID": [100042] }
  }'
```

> Testing? Use `"courier": "GENERIC"` with `"sandbox": true` to get a dummy label.
> See `references/labels.md` (COD, multi-collo, returns, customs).
