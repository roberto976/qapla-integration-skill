---
source: https://api.qapla.dev
synced: 2026-06-15
api_versions: [1.2, 1.3]
---

# Qapla' API — Core Concepts

## The Three-Pillar Mental Model

Qapla' exposes three distinct capabilities. Most integrations use one or two pillars; not every merchant enables all three.

### Pillar 1 — Tracking

Qapla' ingests shipment data (tracking numbers, courier identifiers, order references) and continuously monitors carrier networks for status updates. Each shipment gets a canonical Qapla' status that normalises the courier-specific raw event into a standardised lifecycle state (e.g. `IN_TRANSIT`, `DELIVERED`, `EXCEPTION`).

**When you touch this pillar:** when you push shipment data into Qapla' so it can begin monitoring, or when you query the current status and event history of a shipment, or when you want to surface carrier events to your own systems.

A hosted **tracking page** is automatically available for every monitored shipment. You can link buyers directly to it without building your own tracking UI.

### Pillar 2 — Transactional Events (Notifications Out)

When a shipment status changes, Qapla' can fire outbound notifications: webhooks to your endpoint, and/or customer-facing email and SMS messages. You configure the rules (which status transitions trigger which channel) and Qapla' handles delivery.

**When you touch this pillar:** when you want Qapla' to call your backend on status changes (webhook), or when you want Qapla' to send branded email/SMS notifications to the end recipient on your behalf.

This pillar is decoupled from Pillar 1: you can track shipments without enabling any outbound notifications, and vice versa.

### Pillar 3 — Label Generation

Qapla' can generate shipping labels by communicating with the carrier on your behalf. Once a label is requested via the API, Qapla' negotiates with the carrier and returns label data (typically ZPL or PDF). After a label is created, the associated shipment becomes trackable — Pillar 1 monitoring begins automatically. Note that label data may not be immediately visible in tracking responses; allow a short propagation window after creation.

**When you touch this pillar:** when you want a single API to create labels across multiple carriers without maintaining separate carrier integrations yourself.

---

## Domain Glossary

| Term | Definition |
|------|------------|
| **channel** (*canale*) | A configured connection between a merchant's store or platform (e.g. WooCommerce, Shopify, custom) and Qapla'. Each channel has its own credentials and settings; a single merchant may operate several channels. |
| **shipment** (*spedizione*) | The core trackable entity in Qapla': a physical parcel in transit, identified by a tracking number and associated with a carrier and an order. |
| **order** (*ordine*) | The commercial transaction that originated one or more shipments. Qapla' links orders to shipments so you can query shipment status by your internal order reference. |
| **label** (*etichetta*) | A shipping label generated through Pillar 3. Contains the carrier barcode, recipient address, and service details; delivered by the API as printable data (ZPL or PDF). |
| **courier** (*corriere*) | A carrier (e.g. GLS, BRT, DHL, Poste Italiane, FedEx). Qapla' maintains a registry of supported couriers, each identified by a Qapla' courier code. Do not invent courier codes; always use the codes documented in the Qapla' courier list. |
| **tracking number** | The carrier-assigned identifier for a shipment, used to query the carrier network. Must be combined with a courier code for unambiguous identification. |
| **PUDO** | Pick-Up / Drop-Off point — a third-party collection location (locker, shop) where a parcel can be delivered instead of the recipient's home address. Relevant when creating labels or displaying delivery options. |
| **COD / contrassegno** | Cash-on-delivery: the carrier collects payment from the recipient at the moment of delivery and remits it to the merchant. Relevant when creating labels that include a COD amount. |
| **tracking page** | A hosted, buyer-facing web page provided by Qapla' for each shipment. Shows the shipment's status history and estimated delivery. You can share its URL directly with customers. |
| **status** | A shipment's lifecycle state. Qapla' maps every courier-specific raw event to a **canonical Qapla' status** (a normalised code valid across all carriers). The raw carrier event text is also available but varies by courier and should not be used for programmatic branching. |
