---
name: qapla-integration
description: Build integrations with the Qapla' shipping & tracking platform — public REST API (api.qapla.dev / api.qapla.it, v1.2 & v1.3) and outbound webhooks (webhook.qapla.dev). Use when integrating shipment tracking, shipping-label generation, courier quotes / pickup-points, or webhook receivers with Qapla', or when migrating a legacy Qapla' API integration.
license: MIT
---

# Qapla' Integration

[Qapla'](https://www.qapla.it) sits between an e-commerce system and 50+ couriers: it generates
shipping labels, normalizes courier tracking statuses into one canonical model, and drives
post-shipment communication (tracking page, transactional email/SMS, webhooks).

This skill documents the **public developer contract** only — the REST API and outbound
webhooks an external integrator uses. It does **not** cover Qapla' internals (daemons, queues,
database schema, internal pipelines); ignore those even if you know them.

## Source of truth

`https://api.qapla.dev` (REST API) and `https://webhook.qapla.dev` (webhooks) are
**authoritative**. The files in `references/` are a synced working copy — each carries a
`source:` URL and a `synced:` date in its header. If a reference and the live docs disagree,
**the live docs win**; re-check the `source:` URL.

## Decision tree — start here

Identify which of the **3 pillars** the use case touches, then open the mapped reference.

| You want to… | Pillar | Go to |
| --- | --- | --- |
| Be notified when a shipment changes state | **2 — Events** | `references/webhooks.md` (push) — or `references/shipments.md` → `trackingByTimeFrame` (pull) |
| Already ship yourself, just want Qapla' tracking & tracking page | **1 — Tracking** | `references/shipments.md` (`pushShipment`, virtual courier) |
| Have Qapla' generate the shipping label | **3 — Labels** | `references/orders.md` (`pushOrder`) → `references/couriers.md` (`getQuotes` / `detectOrderCourier`) → `references/labels.md` (`createLabel` → `confirmLabel`) |
| Get shipping quotes or pickup points (PUDO) | — | `references/couriers.md` |
| Interpret/normalize courier statuses | — | `references/statuses.md` |
| Validate / geocode an address | — | `references/checkaddress.md` |
| Understand errors, rate limits, idempotency | — | `references/errors.md` |
| Authenticate / use sandbox | — | `references/authentication.md` |
| Move off a legacy v1.0 / v1.1 integration | — | `references/migration.md` |

> The 3 pillars in one line: **(1) Tracking** = states + tracking page · **(2) Events** =
> notifications out (webhook / email / SMS) · **(3) Labels** = Qapla' creates the label.
> Most integration confusion is picking the wrong pillar. See `references/concepts.md`.

## Version policy (read before writing any request)

- **v1.3 and v1.2 are BOTH current.** v1.2 is **not** deprecated — several endpoints exist only
  in v1.2 with no v1.3 equivalent. Each reference states the version to use per endpoint.
- **v2** (`/v2/`) is the new REST architecture: **JWT Bearer** auth, granular scopes, async bulk
  jobs (`jobId`). It coexists with v1.3 — opt-in, not a forced upgrade. See `references/versioning.md`.
- **v1.1 / v1.0 are deprecated.** Covered only in `references/migration.md`.

Base URL pattern (v1.x): `https://api.qapla.it/{version}/{endpoint}` — e.g.
`https://api.qapla.it/1.3/pushShipment/`. Auth is a **per-channel API key** (see
`references/authentication.md`).

## References

| File | Covers |
| --- | --- |
| `references/concepts.md` | 3-pillar model + domain glossary |
| `references/authentication.md` | API key, sandbox, rate limiting (HTTP 429) |
| `references/versioning.md` | v1.2 / v1.3 / v2 matrix, deprecation map |
| `references/orders.md` | `pushOrder`, platform-order bridge, `detectOrderCourier` |
| `references/shipments.md` | `pushShipment`, `getCompanyShipments`, `trackingByTimeFrame`, virtual courier |
| `references/labels.md` | `createLabel`, `confirmLabel`, multi-parcel, COD, customs, returns |
| `references/couriers.md` | `getQuotes`, `getPudos`, courier detection caveats |
| `references/statuses.md` | courier → Qapla' canonical status mapping, multilingual messages |
| `references/webhooks.md` | shipment & return events, payload, response contract, retries |
| `references/errors.md` | error envelope, rate limits, idempotency |
| `references/checkaddress.md` | address validation / geocoding (metered) |
| `references/migration.md` | v1.0 / v1.1 → v1.2 / v1.3 (and notes on v1.x → v2) |

See `examples/` for runnable curl + code snippets.
