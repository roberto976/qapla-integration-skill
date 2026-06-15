# Design — Qapla' Integration Skill

- **Date:** 2026-06-15
- **Status:** Approved (brainstorming)
- **Repo:** https://github.com/roberto976/qapla-intergration-skill (public, MIT)

## Purpose

A **public, cross-agent Agent Skill** that helps developers build integrations against
Qapla's **public API** (`api.qapla.dev` / `api.qapla.it`) and **outbound webhooks**
(`webhook.qapla.dev`). The skill gives an AI coding agent (Claude Code, Codex, Gemini CLI,
Copilot) the workflow, decision tree, and reference detail needed to write correct
integration code autonomously — without the developer hand-feeding API docs.

### Audience

External developers integrating e-commerce / logistics systems with Qapla'. **Not** an
internal-engineering skill: it deliberately excludes Qapla' internals (daemons, queues,
DB table names, Bifrost, internal pipelines).

### Out of scope

- Internal architecture (daemons, queues, reinoculo daemon mechanics, DB schema, Bifrost,
  internal email/SMS pipelines).
- Control-Panel UI walkthroughs (the skill targets API/webhook integration, not CP usage).
- A live MCP server / real API calls (possible future phase 2; this skill is static help).

## Key design decisions

1. **Single skill + `references/`** — one `SKILL.md` (workflow + decision tree + version
   policy) plus a `references/` folder loaded on demand. Standard Agent Skills format →
   portable across Claude/Codex/Gemini/Copilot.
2. **Embedded complete references, anchored to live docs** — each reference file carries the
   full working detail for the stable v1.2/v1.3 surface so an agent can generate correct code
   offline, with zero per-endpoint network round-trips. Staleness is guarded by a header on
   every file: `source:` (live URL) + `synced:` (date), and `SKILL.md` states the live docs
   are the authority. A `scripts/sync-docs` helper re-aligns references on each API release.
3. **Versioning policy:**
   - **v1.3 and v1.2 are BOTH active.** v1.2 is *not* marked deprecated — several endpoints
     live only in v1.2 with no v1.3 alternative. Each endpoint states which version to use.
   - **v1.1 / v1.0 are deprecated** -> covered only in `migration.md`.
   - **v2** (JWT Bearer, scopes, async bulk `jobId`) coexists with v1.3; not a forced upgrade.
4. **Three Pillars as the north star** — Pillar 1 = Tracking, Pillar 2 = Events/notifications,
   Pillar 3 = Label generation. The decision tree routes the developer's use case to the right
   pillar and endpoints first; most integration confusion comes from not knowing which pillar
   a use case touches.

## Repository structure

```
qapla-intergration-skill/
|-- README.md                      # purpose, scope, install (cross-agent)
|-- LICENSE                        # MIT
|-- docs/specs/                    # this design doc
\-- skill/qapla-integration/
    |-- SKILL.md                   # entry: name+description, 3-pillar decision tree,
    |                              #   version policy, "live docs = authority" note
    |-- references/
    |   |-- concepts.md            # 3 pillars mental model + domain glossary
    |   |-- authentication.md      # per-channel API key, sandbox mode, rate limit (120 burst / 2 t/s, HTTP 429)
    |   |-- versioning.md          # v1.3 + v1.2 active (per-endpoint), v2 (JWT/scopes/async), deprecation map
    |   |-- orders.md              # pushOrder, fetch/updatePlatformOrder, detectOrderCourier
    |   |-- shipments.md           # pushShipment, getCompanyShipments, trackingByTimeFrame (pull vs webhook), virtual courier / tracking-only, dedup
    |   |-- labels.md              # createLabel, confirmLabel, add-parcel, multi-collo, contrassegno (COD), customs, returns (isReturn)
    |   |-- couriers.md            # getQuotes, getPudos, detect-courier (fragility), per-courier PUDO rules
    |   |-- statuses.md            # courier -> Qapla' canonical status mapping, multilingual status messages
    |   |-- webhooks.md            # shipment + return events, payload, {"result":"OK"} contract, retry (2x) + auto-disable (100 fail), signature
    |   |-- errors.md              # error envelope, 429 / rate-limit, idempotency & deduplication, retryable vs fatal
    |   |-- checkaddress.md        # address validation / geocoding (metered product)
    |   \-- migration.md           # v1.0 / v1.1 -> v1.2 / v1.3 diffs + checklist; note on v1.x -> v2 path
    |-- examples/                  # runnable curl + language snippets (push order, create label, webhook receiver, getQuotes)
    \-- scripts/
        \-- sync-docs.*            # re-align references from api.qapla.dev / webhook.qapla.dev
```

## SKILL.md content plan

- **Frontmatter:** `name: qapla-integration`, `description:` triggering on "Qapla", "qapla.dev",
  "tracking integration", "shipment API", "shipping label API", webhook, courier integration.
- **Decision tree (the core):** route by use case ->
  - "Notify me when a shipment changes state" -> Pillar 2 -> `webhooks.md` (push) or
    `shipments.md#trackingByTimeFrame` (pull).
  - "I already ship and just want Qapla' tracking" -> Pillar 1 -> `pushShipment` / virtual courier.
  - "I want Qapla' to generate the label" -> Pillar 3 -> `pushOrder` -> `getQuotes`/`detectOrderCourier`
    -> `createLabel` -> `confirmLabel`.
  - "Quotes / pickup points" -> `couriers.md`.
  - "I'm on an old API (v1.0/1.1)" -> `migration.md`.
- **Version policy box:** v1.3 + v1.2 active; pick per endpoint; v2 opt-in.
- **Authority note:** `api.qapla.dev` / `webhook.qapla.dev` are the source of truth; references
  are a synced working copy (`synced:` date in each file).

## Reference file contract

Every `references/*.md` begins with:

```yaml
---
source: https://api.qapla.dev/...      # live authoritative page
synced: 2026-06-15
api_versions: [1.2, 1.3]               # which versions this file documents
---
```

Body: purpose (1 line) - endpoint + version + method/path - required fields - request example -
response example - gotchas (auth, rate limit, sandbox, idempotency, version caveats,
courier-specific quirks).

## README plan (very complete)

Sections: what Qapla' is (1 paragraph) - what the skill does and who it's for - the 3-pillar
model (quick) - what's covered (endpoint matrix) - what's NOT covered (internals) -
**installation per agent** (Claude Code: `~/.claude/skills/` or plugin; Codex: `~/.codex/skills/`;
Gemini CLI; generic Agent Skills path) - how the skill stays current (`source:`/`synced:` +
sync script) - authority/disclaimer (live docs win) - contributing - MIT license.

## Testing / validation

- Skill metadata validates against the Agent Skills schema (frontmatter present, description
  triggers correctly).
- Each reference file has the `source:`/`synced:` header.
- Examples are syntactically runnable (curl parses; snippet compiles where trivial).
- A reviewer (dev unfamiliar with Qapla') can follow the decision tree to the right endpoint
  for 4 sample use cases without reading internals.
