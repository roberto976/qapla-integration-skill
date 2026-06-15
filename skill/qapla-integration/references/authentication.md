---
source: https://api.qapla.dev
synced: 2026-06-15
api_versions: [1.2, 1.3]
---

# Authentication

This document covers how to authenticate requests against the Qapla' API (v1.2 and v1.3).
For v2 authentication (JWT Bearer tokens and scopes), see [versioning.md](versioning.md).

---

## Per-Channel API Key

Every Qapla' **channel** has its own private API key. A channel represents a single merchant
sales channel (e.g. a WooCommerce store, a Shopify store, a marketplace integration) configured
inside the Qapla' Control Panel.

**Where to find it:**

> Control Panel → **Settings > Channels > [your channel] > Configure > Channel > Private API Key**

The key is unique to that channel and must be kept strictly secret. Do not expose it in
client-side code, public repositories, or logs.

---

## Passing the API Key in Requests

### POST requests — JSON body

For all `POST` endpoints the key is included as the `apiKey` field at the top level of the
JSON body:

```json
POST https://api.qapla.it/1.3/pushShipment/
Content-Type: application/json

{
  "apiKey": "YOUR_PRIVATE_API_KEY",
  "pushShipment": [
    { }
  ]
}
```

### GET requests — query parameter

For `GET` endpoints the key is passed as the `apiKey` query parameter:

```
GET https://api.qapla.it/1.3/getShipment/?apiKey=YOUR_PRIVATE_API_KEY&trackingNumber=TRACK123
```

There is no alternative header-based form documented for v1.2/v1.3; always use the patterns
above for these versions. (Exception: `updatePlatformOrder` accepts the key in a `Q-API-Key`
header — see [orders.md](orders.md).)

---

## Multiple API Keys Per Channel

Each channel is issued its own API key. If your organisation operates **multiple channels**
(e.g. separate stores or marketplaces), each channel has a distinct key and must be
authenticated independently. There is no shared or organisation-wide key in v1.x.

---

## Sandbox Mode

There is no separate sandbox base URL. To test without operational impact (no real courier
pickups, no costs), include the `sandbox` field in the API call body on endpoints that support
it:

```json
{
  "apiKey": "YOUR_PRIVATE_API_KEY",
  "sandbox": true,
  "pushShipment": [
    { }
  ]
}
```

When `sandbox` is `true`, the request is processed against Qapla's test infrastructure and
produces no real-world side effects. Check individual endpoint documentation for confirmation
that an endpoint honours the `sandbox` flag. For label testing, the `GENERIC` courier code with
`sandbox: true` produces dummy labels.

---

## Rate Limiting

Qapla' enforces rate limits using a **token-bucket** algorithm applied per API key.

| Parameter | Value |
|-----------|-------|
| Bucket capacity (burst) | 120 tokens |
| Refill rate | 2 tokens / second |

**Important:** batch calls are not counted as a single token. A `pushShipment` body
containing 100 shipments consumes **100 tokens**, not 1. Size your batches accordingly.

When the bucket is exhausted the API returns:

```
HTTP 429 Too Many Requests
```

**Recommended back-off strategy:**

1. On receiving a `429`, stop sending requests immediately.
2. Wait at least **1 second per token** you need to recover (e.g. wait 10 s to recover
   20 tokens at 2 tokens/s).
3. Retry with exponential back-off if `429` responses persist.
4. Do not hammer the endpoint in a tight retry loop — repeated abuse can result in a
   permanent ban of the API key.

---

## Security Checklist

- Store the API key in an environment variable or secrets manager; never hard-code it.
- Rotate the key immediately if it is accidentally exposed.
- Restrict server-side outbound calls to `api.qapla.it` so the key never leaves your backend.

---

## v2 Note

Qapla' API v2 replaces per-channel API keys with **JWT Bearer tokens and OAuth-style scopes**.
If you are targeting v2, do not use the patterns described here. See
[versioning.md](versioning.md) for details.
