# Build 14 — Product Type Content Design

Product type is a persisted company identity, not a balance lever. The setup screen defaults to B2B SaaS so existing and new players retain the original game unless they choose otherwise.

## Classification

Pass A reviewed 100 existing tasks: 31 universal operating/founder tasks and 69 SaaS-specific tasks (41 base, 28 empire). All 12 existing dilemmas are SaaS-specific because their customer, agent, and scale framing assumes the original subscription-software company.

Pass B supplies 69 matching specific opportunities for each of Consumer App, Hardware, and Marketplace: 41 at base and 28 at empire scale, retaining the source role/category/urgency/impact shape. Each type receives 12 matching dilemmas. Empire content remains gated at combination time.

Product eligibility is centralized in `ContentLibrary`; `nil` eligibility is universal and non-nil sets are explicit. Drafting, backfill, and dilemmas all filter against the active saved product type.
