---
source: https://api.qapla.dev
synced: 2026-06-15
api_versions: [1.2, 1.3, 2]
---

# API Versioning

## Base URL Pattern

All v1.x requests target:

```
https://api.qapla.it/{version}/{endpoint}/
```

Examples:

```
https://api.qapla.it/1.3/pushShipment/
https://api.qapla.it/1.2/fetchPlatformOrders/
```

The v2 base path is:

```
https://api.qapla.it/v2/{endpoint}
```

---

## Version Policy

| Version | Status | Notes |
|---------|--------|-------|
| **1.3** | **Current** | Primary version for most endpoints. Use by default unless the endpoint is documented only in 1.2. |
| **1.2** | **Current (active)** | Not deprecated. Several endpoints have no 1.3 equivalent and must be called at 1.2. |
| 1.1 | Deprecated | See [migration.md](migration.md). |
| 1.0 | Deprecated | See [migration.md](migration.md). |

**Important:** v1.2 is an active, supported version — not a legacy fallback. The API documentation explicitly states that not all endpoints have been migrated to v1.3. Callers must target the version where the endpoint is documented; there is no automatic forwarding between minor versions.

---

## Endpoint Version Matrix

| Endpoint | Method | Recommended version | Notes |
|----------|--------|---------------------|-------|
| `pushShipment` | POST | 1.3 | |
| `pushOrder` | POST | 1.3 | |
| `createLabel` | POST | 1.3 | |
| `confirmLabel` | POST | 1.2 | Also callable at 1.3. |
| `getQuotes` | POST | 1.3 | |
| `getPudos` | POST | 1.3 | |
| `detectCourier` | GET | 1.3 | Infers courier from a tracking number. |
| `getCompanyShipments` | GET | 1.3 | |
| `detectOrderCourier` | POST | 1.2 | No 1.3 equivalent documented. |
| `trackingByTimeFrame` | GET | 1.2 | No 1.3 equivalent documented. |
| `fetchPlatformOrders` | GET | 1.2 | No 1.3 equivalent documented. |
| `updatePlatformOrder` | PUT | 1.2 | No 1.3 equivalent documented. |

For any endpoint not listed above, consult the official documentation at `https://api.qapla.dev`. When in doubt, try 1.3 first; if the endpoint is absent, fall back to 1.2.

---

## Authentication (v1.x)

All v1.x requests authenticate via a per-channel private API key passed as a query parameter (GET) or request body field `apiKey` (POST). See [authentication.md](authentication.md) for full details, sandbox mode, and rate limiting (token bucket, 120 capacity, 2/s refill, HTTP 429 on exhaustion).

---

## v2 Overview

v2 is an opt-in, next-generation layer that **coexists** with v1.3. v1.3 is not being deprecated imminently; existing integrations do not need to migrate.

Key differences from v1.x:

| Aspect | v1.x | v2 |
|--------|------|----|
| Authentication | Static per-channel API key | JWT Bearer token with granular per-endpoint scopes |
| Bulk operations | Synchronous (max 100 items/request) | Async via `jobId`; poll for completion |
| Parcels entity | Embedded in shipment payload | First-class native entity |
| Sandbox | Shared environment | Dedicated sandbox tenant, isolated from production data |
| Adoption | Default for all existing integrations | Opt-in; requires explicit onboarding |

Because v2 uses **scope-based JWT auth**, each integration must request only the scopes it needs. The token exchange endpoint and scope catalog are documented in the v2 section of `https://api.qapla.dev`.
