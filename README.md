# Qapla' Integration Skill

> A public, cross-agent **Agent Skill** that helps developers build integrations with the
> [Qapla'](https://www.qapla.it) shipping & tracking platform — its public REST API
> (`api.qapla.dev` / `api.qapla.it`) and outbound webhooks (`webhook.qapla.dev`).

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## What is Qapla'?

Qapla' is a logistics platform that sits between e-commerce systems and 50+ couriers. It
generates shipping labels, normalizes courier tracking statuses into a single canonical model,
and drives post-shipment communication (tracking page, transactional email/SMS, webhooks).

## What is this skill?

This repository packages a **skill** — a structured bundle of instructions and reference docs
that an AI coding agent loads to gain expert knowledge of Qapla's integration surface.

When installed, your agent (Claude Code, Codex, Gemini CLI, GitHub Copilot, or any tool that
supports the [Agent Skills](https://docs.claude.com/en/docs/claude-code/skills) format) can:

- Pick the **right endpoint** for your use case via a built-in decision tree.
- Generate **correct request/response code** against the v1.2 / v1.3 API without you pasting docs.
- Implement and verify **webhook receivers** (payload shape, the `{"result":"OK"}` contract,
  retry & auto-disable behavior).
- Map **courier statuses** to Qapla's canonical states.
- **Migrate** legacy v1.0 / v1.1 integrations to the current API.

It is **not** an internal-engineering tool: it deliberately excludes Qapla' internals (daemons,
queues, database schema, internal pipelines). It documents only the public, developer-facing
contract.

## The 3-Pillar model

Most integration confusion comes from not knowing which "pillar" a use case touches. The skill
routes you to the right one first:

| Pillar | Purpose | Typical endpoints |
| --- | --- | --- |
| **1 — Tracking** | You already ship; you just want Qapla' to track & display status | `pushShipment`, `getCompanyShipments`, `trackingByTimeFrame`, virtual courier |
| **2 — Events** | Get notified when a shipment changes state | Outbound **webhooks**, or pull via `trackingByTimeFrame` |
| **3 — Labels** | Let Qapla' generate the shipping label | `pushOrder` -> `getQuotes` / `detectOrderCourier` -> `createLabel` -> `confirmLabel` |

## What's covered

- **Authentication** — per-channel API key, sandbox mode, rate limiting (token bucket, HTTP 429).
- **Versioning** — v1.3 **and** v1.2 are both active (v1.2 is *not* deprecated; some endpoints
  live only there); v2 (JWT + scopes + async bulk) coexists. v1.0 / v1.1 are deprecated.
- **Orders** — `pushOrder`, platform-order bridge, `detectOrderCourier`.
- **Shipments** — `pushShipment`, `getCompanyShipments`, `trackingByTimeFrame`, virtual
  courier / tracking-only mode, deduplication.
- **Labels** — `createLabel`, `confirmLabel`, multi-parcel / `addParcel`, contrassegno (COD),
  customs, returns.
- **Couriers** — `getQuotes`, `getPudos` (pickup points), courier detection caveats.
- **Statuses** — courier -> Qapla' canonical mapping, multilingual status messages.
- **Webhooks** — shipment & return events, payload structure, response contract, retry policy.
- **Errors** — error envelope, rate-limit signaling, idempotency.
- **Migration** — v1.0 / v1.1 -> v1.2 / v1.3 checklist, and notes on the v1.x -> v2 path.

## What's NOT covered

Internal architecture (daemons, queues, reinoculo mechanics, DB tables, Bifrost, internal
email/SMS pipelines) and Control-Panel UI walkthroughs. For those, see Qapla's internal docs.

## Installation

The skill lives in [`skill/qapla-integration/`](skill/qapla-integration/). Install it by
copying (or symlinking) that directory into your agent's skills folder.

### Claude Code

```bash
git clone https://github.com/roberto976/qapla-intergration-skill.git
# Personal (all projects):
cp -r qapla-intergration-skill/skill/qapla-integration ~/.claude/skills/
# — or project-scoped:
cp -r qapla-intergration-skill/skill/qapla-integration .claude/skills/
```

Then in Claude Code the skill activates automatically when you mention Qapla', or invoke it
explicitly.

### Codex

```bash
cp -r qapla-intergration-skill/skill/qapla-integration ~/.codex/skills/
```

### Gemini CLI

```bash
cp -r qapla-intergration-skill/skill/qapla-integration ~/.gemini/skills/
```

### Any Agent Skills-compatible tool

Point your tool at `skill/qapla-integration/SKILL.md`. The skill is plain Markdown with YAML
frontmatter and an on-demand `references/` folder — no runtime, no dependencies.

## How the skill stays current

`api.qapla.dev` and `webhook.qapla.dev` are the **authoritative source of truth**. The reference
files in this repo are a *synced working copy*: each carries a header with its `source:` URL and
the `synced:` date. When in doubt, the live docs win. `scripts/sync-docs` re-aligns the
references against the live documentation on each API release.

## Contributing

Issues and PRs welcome — especially updates when the API changes, new examples, and
clarifications. Keep the public/internal boundary: only document the public developer contract.

## License

[MIT](LICENSE) © roberto976
