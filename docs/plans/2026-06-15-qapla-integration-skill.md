# Qapla' Integration Skill — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the `qapla-integration` Agent Skill — `SKILL.md` + 12 reference files + examples + sync script — documenting Qapla's public API (v1.2/v1.3) and webhooks for external developers.

**Architecture:** Single skill, standard Agent Skills format. `SKILL.md` holds the 3-pillar decision tree, version policy, and authority note. Each `references/*.md` is a self-contained, on-demand file with a `source:`/`synced:` header, distilled ONLY from the public developer contract (no internals). Content is sourced from the Qapla' docs knowledge base (MCP `mcp__docs__search_docs`) cross-checked against live `api.qapla.dev` / `webhook.qapla.dev`.

**Tech Stack:** Markdown + YAML frontmatter. No runtime. `scripts/sync-docs` is a shell helper. Validation is manual (header present, public-only, decision tree resolves).

**Source mapping (docs MCP module -> reference file):**
- concepts.md      <- panoramica-flusso, glossario, tracking (pilastro 1), eventi-transazionali (pilastro 2)
- authentication.md<- api-v13, channel-api-keys, table-api-log
- versioning.md    <- api-v13, api-v2
- orders.md        <- api-pushorder, api-platform-orders, api-detect-order-courier
- shipments.md     <- api-pushshipment, api-getcompanyshipments, api-tracking-by-timeframe, virtual-courier
- labels.md        <- api-createlabel, api-confirm-label, add-parcel, multi-collo, contrassegno, resi
- couriers.md      <- api-getquotes, api-getpudos, detect-courier, pudo
- statuses.md      <- statuses, status-language-message
- webhooks.md      <- webhook-outbound (live: webhook.qapla.dev)
- errors.md        <- api-v13 (error envelope), table-api-log
- checkaddress.md  <- check-address
- migration.md     <- api-v13 (legacy v1.1/v1.0 section), api-v2

**Rule for every file-authoring task:** start the file with
```yaml
---
source: <live URL>
synced: 2026-06-15
api_versions: [..]
---
```
Include ONLY the public contract. Exclude daemons, queues, DB table names, Bifrost, internal pipelines.

---

### Task 1: SKILL.md (skill entry point)

**Files:**
- Create: `skill/qapla-integration/SKILL.md`

- [ ] **Step 1: Write frontmatter + body**

Frontmatter:
```yaml
---
name: qapla-integration
description: Build integrations with the Qapla' shipping & tracking platform — public REST API (api.qapla.dev / api.qapla.it, v1.2 & v1.3) and outbound webhooks (webhook.qapla.dev). Use when integrating shipment tracking, shipping-label generation, courier quotes/pickup-points, or webhook receivers with Qapla', or migrating a legacy Qapla' API integration.
---
```
Body MUST contain:
1. One-paragraph "what Qapla' is" + the public/internal boundary (no internals).
2. **3-pillar decision tree** routing use case -> pillar -> reference file:
   - notify on status change -> Pillar 2 -> `references/webhooks.md` (push) or `references/shipments.md` trackingByTimeFrame (pull)
   - already shipping, want tracking only -> Pillar 1 -> `references/shipments.md` (pushShipment / virtual courier)
   - want Qapla' to make the label -> Pillar 3 -> `references/orders.md` -> `references/couriers.md` (quotes) -> `references/labels.md`
   - quotes / pickup points -> `references/couriers.md`
   - interpret statuses -> `references/statuses.md`
   - on legacy v1.0/v1.1 -> `references/migration.md`
3. **Version policy box:** v1.3 + v1.2 BOTH active (v1.2 not deprecated; some endpoints only there); v2 = JWT/scopes/async, opt-in; v1.1/v1.0 deprecated -> migration.
4. **Authority note:** api.qapla.dev / webhook.qapla.dev are source of truth; references are a synced copy (see each file's `synced:`).
5. Table of references with one-line purpose each.

- [ ] **Step 2: Validate**
Run: `head -5 skill/qapla-integration/SKILL.md` — expect YAML frontmatter with `name:` and `description:`.
Check: decision tree lists every reference file; no internal terms (grep -iE 'daemon|bifrost|queue|reinocul' should return nothing).

- [ ] **Step 3: Commit**
```bash
git add skill/qapla-integration/SKILL.md
git commit -m "feat: add SKILL.md entry point with 3-pillar decision tree"
```

---

### Tasks 2-13: Reference files (one task each)

For EACH reference file below, the steps are identical (substitute file + source modules from the Source mapping):

- [ ] **Step 1:** Read the mapped docs module(s) via `mcp__docs__search_docs` and, where a live page exists, cross-check `api.qapla.dev` / `webhook.qapla.dev` via WebFetch.
- [ ] **Step 2:** Write `skill/qapla-integration/references/<file>` with the required `source:`/`synced:`/`api_versions:` header, then body: purpose (1 line) · per endpoint: name + version + method/path + required fields + request example + response example · gotchas. Public contract ONLY.
- [ ] **Step 3:** Validate: `head -5` shows the header; `grep -iE 'daemon|bifrost|queue|reinocul|_qoreDB|aziendeCanali[A-Z]' <file>` returns nothing (no internal table/daemon leakage).
- [ ] **Step 4:** Commit `feat: add references/<file>`.

- [ ] **Task 2:** `references/concepts.md` — 3 pillars + glossary (channel/canale, shipment, order, label, courier, PUDO, COD, tracking page). api_versions: n/a.
- [ ] **Task 3:** `references/authentication.md` — per-channel API key (where to find it), how it's passed (JSON `apiKey` field / header), sandbox mode, rate limit (token bucket 120 burst / 2 per s, HTTP 429). api_versions: [1.2, 1.3].
- [ ] **Task 4:** `references/versioning.md` — base URLs, v1.3 & v1.2 active matrix (which endpoint lives where), v2 (JWT Bearer, scopes, async jobId), deprecation map (v1.1/v1.0 -> migration). api_versions: [1.2, 1.3, 2].
- [ ] **Task 5:** `references/orders.md` — pushOrder, fetch/updatePlatformOrder, detectOrderCourier. api_versions per endpoint.
- [ ] **Task 6:** `references/shipments.md` — pushShipment (dedup, explicit `courier`), getCompanyShipments, trackingByTimeFrame (pull vs webhook tradeoff), virtual courier / tracking-only.
- [ ] **Task 7:** `references/labels.md` — createLabel (v1.3 sync / v1.4 parcelsTracking), confirmLabel, addParcel (FedEx/UPS/TNT/GLS), multi-collo, contrassegno (COD), customs, returns (isReturn).
- [ ] **Task 8:** `references/couriers.md` — getQuotes (reference key rules, mandatory parcels/amountShipment, currency caveats), getPudos, detect-courier fragility, per-courier PUDO rules.
- [ ] **Task 9:** `references/statuses.md` — courier -> Qapla' canonical status mapping, multilingual status messages, how to consume status codes in webhook/tracking payloads.
- [ ] **Task 10:** `references/webhooks.md` — shipment + return events, payload fields (apiKey, trackingNumber, qaplaStatusID...), the `{"result":"OK"}`/`{"result":"KO"}` contract, retry (2x) + auto-disable after 100 fails, signature/verification, per-channel config. Source: webhook.qapla.dev.
- [ ] **Task 11:** `references/errors.md` — success/error envelope shape, HTTP 429 rate-limit, idempotency & dedup semantics, retryable vs fatal classification.
- [ ] **Task 12:** `references/checkaddress.md` — address validation / geocoding, that it's a metered product, request/response shape.
- [ ] **Task 13:** `references/migration.md` — v1.0/v1.1 -> v1.2/v1.3 diffs + step checklist; note on v1.x -> v2 (auth change API key -> JWT, scopes, async). Source: api.qapla.dev legacy section + api-v2.

---

### Task 14: examples/

**Files:**
- Create: `skill/qapla-integration/examples/push-order.md`, `create-label.md`, `get-quotes.md`, `webhook-receiver.md`

- [ ] **Step 1:** For each, write a runnable `curl` request + one language snippet (Node or PHP) + expected response. Webhook receiver: a minimal endpoint that validates payload and returns `{"result":"OK"}`.
- [ ] **Step 2:** Validate: `bash -n` not applicable; check curl lines parse (no unbalanced quotes) and JSON examples are valid (`python3 -m json.tool` on embedded bodies).
- [ ] **Step 3:** Commit `feat: add integration examples`.

---

### Task 15: scripts/sync-docs

**Files:**
- Create: `skill/qapla-integration/scripts/sync-docs.sh`

- [ ] **Step 1:** Write a shell script that lists each reference file, prints its `source:` and `synced:` header, and reminds the maintainer to re-fetch the live page and bump `synced:`. (No network automation required for v1 — it's a guided checklist runner that greps headers and prints the live URLs to review.)
- [ ] **Step 2:** Validate: `bash -n scripts/sync-docs.sh` exits 0; running it prints one line per reference with source + synced.
- [ ] **Step 3:** Commit `feat: add sync-docs helper`.

---

### Task 16: Final validation pass

- [ ] **Step 1:** `grep -rLiE 'source:' skill/qapla-integration/references/` returns nothing (every reference has the header).
- [ ] **Step 2:** `grep -riE 'daemon|bifrost|reinocul|_qoreDB|ordiniWebHookQueue' skill/qapla-integration/` returns nothing (no internal leakage).
- [ ] **Step 3:** Walk the 4 sample use cases (status notify / tracking-only / generate label / migrate) through SKILL.md's decision tree; each must resolve to the correct reference file.
- [ ] **Step 4:** Update README endpoint matrix if any endpoint name/version drifted from what was authored.
- [ ] **Step 5:** Commit `chore: final validation pass`.

---

## Self-Review

- **Spec coverage:** every reference file in the spec's structure has a task (Tasks 2-13); SKILL.md (Task 1); examples (14); sync script (15); README already done. Concepts/3-pillar, versioning policy, migration, statuses, webhooks all mapped. ✓
- **Placeholders:** none — each task names exact file, source module, header, and validation command.
- **Consistency:** file names match the spec's structure block; endpoint names match the audit (pushOrder/pushShipment/createLabel/confirmLabel/getQuotes/getPudos/detectOrderCourier/trackingByTimeFrame/getCompanyShipments).
