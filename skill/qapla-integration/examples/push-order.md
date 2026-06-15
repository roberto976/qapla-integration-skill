# Example — pushOrder (Pillar 3: import an order for label generation)

Imports an order so Qapla' can later generate the label. Upsert keyed on `reference`.

## curl

```bash
curl -sS -X POST 'https://api.qapla.it/1.3/pushOrder/' \
  -H 'Content-Type: application/json' \
  -d '{
    "apiKey": "YOUR_CHANNEL_API_KEY",
    "origin": "woocommerce",
    "pushOrder": [{
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
      "weight": 1.2,
      "parcels": 1
    }]
  }'
```

## Node (fetch)

```js
const res = await fetch("https://api.qapla.it/1.3/pushOrder/", {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({
    apiKey: process.env.QAPLA_API_KEY,
    origin: "woocommerce",
    pushOrder: [{
      reference: "WC-10042",
      createdAt: "2026-06-01 09:15:00",
      updatedAt: "2026-06-01 09:20:00",
      name: "Jane Doe", street: "Via Roma 12", city: "Milano",
      state: "MI", postCode: "20121", country: "IT",
      email: "jane@example.com", amount: 89.90, weight: 1.2, parcels: 1
    }]
  })
});
const data = await res.json();
// Inspect data.pushOrder.orders[].action: imp | upd | skp | ext | del | err
console.log(data.pushOrder.orders);
```

> See `references/orders.md` for all fields and upsert semantics.
