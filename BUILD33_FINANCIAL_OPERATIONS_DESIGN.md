# Build 33 — Financial Operations and Living Time

## Canonical meanings

- **Cash** is spendable money and is the `CompanyFinance` ledger balance.
- **Capital Raised** is cumulative external financing. It increases cash but never revenue.
- **Revenue** is customer income. The ledger retains today, sprint, and lifetime totals.
- **Net Burn** is recent operating expenses minus revenue. Runway is a derived cash estimate; cash-flow-positive companies show that state instead of an absurd duration.
- `FounderStats.capital` remains a compatibility projection of cash for established systems. It is not a second balance.

## Daily closeout

Committing a sprint advances the operating calendar by seven days. Each day records AI workforce plans, hosting/storage/Company Server, and essential operations under stable day-based transaction IDs. The Loft lease is applied when any crossed day reaches the 30-day boundary, so a seven-day sprint can never skip the monthly obligation.

## Charging policy

Meaningful assignments preview their estimated AI cost, then create one stable ledger expense when they begin. Repeated taps, reconstructed views, saves, and replay cannot apply the same ID twice. Verification and cross-check costs remain explicit future extensions; legacy in-progress work is never back-charged.

## Headquarters

The Founder Loft uses a $7,500 move-in cash commitment ($3,000 deposit, $3,000 first month, $1,500 setup) and records $3,400 monthly rent/utilities on Day 30 boundaries. It is a continuing operating commitment, not a permanently owned $4,000 asset.

## Compatibility

Save v19 adds `finance` and `operatingCalendar`. Missing fields migrate by seeding cash and capital raised from legacy spendable `capital`, lifetime revenue from legacy `revenue`, and Day 1 at 09:00. No old assignment is charged during migration.
