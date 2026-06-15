---
source: https://api.qapla.dev
synced: 2026-06-15
api_versions: [1.0, 1.1, 1.2, 1.3, 2]
---

# Migration Guide

This document is for developers who have an existing Qapla' API integration and need to understand
which API versions are current, which are deprecated, and how to upgrade.

---

## Quick Decision Guide

| Your current version | Action |
|----------------------|--------|
| **v1.0 or v1.1** | Migrate to v1.3 (and v1.2 for endpoints only documented there). See [v1.0/v1.1 → v1.2/v1.3](#v10v11--v12v13-migration-checklist) below. |
| **v1.2** | You are on a supported, active version. No migration required. Consider v2 only if you need its features. |
| **v1.3** | You are on the primary current version. Consider v2 only if you need its features. |
| **Evaluating v2** | Read [v1.x → v2](#v1x--v2-optional-future) below. v1.3 is not being deprecated soon; this is your choice. |

---

## Deprecation Status

| Version | Status | Notes |
|---------|--------|-------|
| **1.0** | **Deprecated** | No longer recommended. Migrate away. |
| **1.1** | **Deprecated** | No longer recommended. Migrate away. |
| **1.2** | **Current (active)** | Supported. Several endpoints exist *only* at v1.2 and must be called there even if your primary version is v1.3. Not deprecated. |
| **1.3** | **Current (primary)** | The default version for all new integrations. Most endpoints live here. |
| **2** | **Opt-in / GA** | New architecture. Coexists with v1.3. v1.3 is not being deprecated to accommodate v2. |

**Do not abandon v1.2 when moving to v1.3.** The two versions coexist by design: some endpoints
(`trackingByTimeFrame`, `getShipments`, `getOrders`, `detectOrderCourier`, `fetchPlatformOrders`,
`updatePlatformOrder`, `deleteShipment`, `updateShipment`, and others) have no v1.3 equivalent
and must still be called at v1.2. See [versioning.md](versioning.md) for the full endpoint
version matrix.

---

## v1.0/v1.1 → v1.2/v1.3 Migration Checklist

There is no automated migration path. Work through this checklist to update your integration.

### 1. Update the base URL version segment

Find every hardcoded version string in your codebase (`/1.0/` or `/1.1/`) and replace:

```
# Old
https://api.qapla.it/1.0/pushShipment/
https://api.qapla.it/1.1/pushShipment/

# New
https://api.qapla.it/1.3/pushShipment/   ← use 1.3 by default
https://api.qapla.it/1.2/getShipments/   ← use 1.2 where documented
```

Consult the endpoint version matrix in [versioning.md](versioning.md) for per-endpoint targets.

### 2. Authentication: same mechanism, check field position

v1.x authentication has always been a per-channel private API key. The key is passed as:

- `apiKey` field in the JSON body for `POST` requests
- `apiKey` query parameter for `GET` requests

If your v1.0/v1.1 integration was passing the key in a different position or field name,
align it to the pattern above. Obtain your key from:

> Control Panel → Settings > Channels > [your channel] > Configure > Channel > Private API Key

See [authentication.md](authentication.md) for full details including sandbox mode and rate
limiting.

### 3. Diff your request payloads against current endpoint docs

Specific field renames between v1.0/v1.1 and v1.2/v1.3 are not exhaustively documented in a
changelog. The safest approach is to:

1. Open the current endpoint reference at `https://api.qapla.dev`.
2. For each endpoint your integration calls, compare the documented required and optional fields
   against what your code sends.
3. Remove fields that no longer exist; add any required fields your code omits.
4. Pay particular attention to date fields (`shipDate`, `createdAt`, `updatedAt`,
   `orderDate`) — all dates must be in `YYYY-MM-DD HH:MM:SS` format (ISO 8601 with space
   separator, not `T`).
5. Numeric fields like `amount` must use `.` as decimal separator and no thousands separator.
6. Country codes must be ISO 3166-1 alpha-2 (e.g. `IT`, `GB`).
7. Courier codes must match the Qapla' courier code list returned by `getCouriers`. Do not
   invent courier codes — the list is authoritative.

### 4. Check the response envelope

All v1.3/v1.2 responses wrap data in an envelope keyed by the endpoint name:

```json
{
  "pushShipment": {
    "result": "OK",
    "error": null,
    "imported": 1,
    "updated": 0,
    "skipped": 0
  }
}
```

If your v1.0/v1.1 parser was reading a flat response or a differently-named top-level key,
update it to navigate `response["<endpointName>"]` before reading `result`, `error`, and
payload fields.

### 5. Handle `updateOrder` removal

`updateOrder` as a standalone endpoint is removed. Use `pushOrder` instead: include the same
`reference` and supply a `updatedAt` timestamp newer than the record on file. Qapla' will
treat it as an update automatically.

### 6. Verify rate-limit handling

Rate limiting is enforced via a token-bucket algorithm (capacity 120, refill 2/s). Batch
requests consume tokens per-item, not per-call: 100 shipments in one `pushShipment` body
costs 100 tokens. Add HTTP 429 handling with exponential back-off. See
[authentication.md](authentication.md) for the recommended back-off strategy.

### 7. Test in sandbox before going live

Use `"sandbox": true` in the request body (on endpoints that support it) to exercise your
integration without real-world side effects. There is no separate sandbox base URL.

### 8. Run integration tests against staging data

After updating URLs, payloads, and envelope parsing, run your full test suite against a
non-production channel before promoting to production.

---

## v1.x → v2 (Optional, Future)

v2 is an opt-in layer that **coexists** with v1.3. You do not need to migrate to v2 — v1.3
is not being deprecated to accommodate v2. Migrate to v2 only if you need features it
provides that v1.3 does not.

### Key architectural changes in v2

| Aspect | v1.x | v2 |
|--------|------|----|
| **Authentication** | Static per-channel API key (`apiKey` param/field) | JWT Bearer token in `Authorization` header with per-endpoint OAuth-style scopes |
| **Bulk operations** | Synchronous; results returned in the same HTTP response | Asynchronous; response returns a `jobId`; poll a status endpoint for completion |
| **Parcels entity** | Parcels embedded inside shipment/order payloads | First-class entity with its own CRUD endpoints |
| **Sandbox** | Shared flag (`sandbox: true`) in production environment | Dedicated sandbox tenant, fully isolated from production data and courier systems |
| **Adoption** | Default for all existing integrations | Opt-in; requires explicit onboarding and credential issuance |

### Authentication change detail

In v2, static API keys are replaced by **JWT Bearer tokens** with **granular scopes**. Each
integration must request only the scopes it needs (e.g. read-shipments, write-orders). The
token exchange endpoint and the full scope catalog are documented in the v2 section of
`https://api.qapla.dev`. Your v1.x API keys will not work against v2 endpoints.

### Async bulk operations

In v1.x, a `pushShipment` with 100 items blocks until all 100 are processed and returns the
result inline. In v2, large operations return a `jobId` immediately, and you poll a job-status
endpoint until processing is complete. This requires a different flow in your integration
(submit → store jobId → poll → consume result).

### Parcels as a first-class entity

In v1.x, parcel dimensions and weight are fields embedded in shipment/order payloads. In v2,
parcels have their own entity lifecycle. If your integration manages complex multi-parcel
shipments, v2 provides richer modelling; if you have simple single-parcel flows, this adds
complexity without benefit.

### Dedicated sandbox tenant

v2 provides an isolated sandbox tenant separate from production. This is a significant
improvement over the shared `sandbox: true` flag in v1.x, which uses the same infrastructure.
For integrators with strict environment separation requirements, this may be a reason to
adopt v2 ahead of other feature needs.

---

## Related References

- [versioning.md](versioning.md) — version policy, base URL pattern, endpoint version matrix
- [authentication.md](authentication.md) — API key mechanics, sandbox mode, rate limiting
- [shipments.md](shipments.md) — pushShipment, getShipment, updateShipment payload reference
- [orders.md](orders.md) — pushOrder, getOrder, platform order endpoints
