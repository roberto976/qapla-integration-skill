# Example — getQuotes (multi-courier shipping quotes)

Returns real-time quotes across one or more couriers for a parcel.

## curl

```bash
curl -sS -X POST 'https://api.qapla.it/1.3/getQuotes/' \
  -H 'Content-Type: application/json' \
  -d '{
    "apiKey": "YOUR_CHANNEL_API_KEY",
    "getQuotes": {
      "reference": "QUOTE-2026-0001",
      "country": "IT",
      "zipCode": "00100",
      "state": "RM",
      "city": "Roma",
      "amountShipment": 89.90,
      "currency": "EUR",
      "parcels": [
        { "weight": 2.5, "width": 20, "height": 15, "length": 30 }
      ]
    }
  }'
```

Gotchas: `reference` must be unique (alphanumeric + `-_.`); every parcel needs weight + all
three dimensions; `amountShipment` is mandatory; GLS-ITA & LICCARDI reject non-EUR.

> See `references/couriers.md`.
