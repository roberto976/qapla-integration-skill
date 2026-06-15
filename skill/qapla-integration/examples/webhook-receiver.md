# Example — Webhook receiver (Pillar 2: react to status changes)

Qapla' POSTs a JSON event to your endpoint on each shipment status change. Your endpoint MUST
reply `{"result":"OK"}` (or `{"result":"KO"}` on failure). After 2 failed retries per event and
100 consecutive failures the webhook is auto-disabled.

## Node / Express

```js
import express from "express";
const app = express();
app.use(express.json());

const QAPLA_API_KEY = process.env.QAPLA_API_KEY;

app.post("/qapla/webhook", (req, res) => {
  const e = req.body;

  // 1. Authenticate the sender: the payload carries your channel's apiKey.
  if (e.apiKey !== QAPLA_API_KEY) {
    return res.status(401).json({ result: "KO" });
  }

  // 2. Acknowledge FAST, then process asynchronously.
  //    Branch on the canonical Qapla' status id, not raw courier text.
  queueForProcessing({
    trackingNumber: e.trackingNumber,
    courier: e.courier,
    reference: e.reference,
    qaplaStatusID: e.qaplaStatusID
  });

  // 3. Required response contract.
  return res.json({ result: "OK" });
});

app.listen(3000);
```

## PHP

```php
<?php
$payload = json_decode(file_get_contents("php://input"), true);

if (($payload["apiKey"] ?? null) !== getenv("QAPLA_API_KEY")) {
    http_response_code(401);
    echo json_encode(["result" => "KO"]);
    exit;
}

// process async (enqueue), then acknowledge
echo json_encode(["result" => "OK"]);
```

> Serve over HTTPS, respond within a couple of seconds, do heavy work async.
> See `references/webhooks.md` (payload fields, event types, returns webhook) and
> `references/statuses.md` (status ids).
