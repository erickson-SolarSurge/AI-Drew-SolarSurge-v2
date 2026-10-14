# Solar Surge Australia — New Hire LMS Content Package

**Version:** October 2026  
**Prepared for:** Developer handoff  
**Source:** Solar Surge Australia (solarsurge.com.au) + verified 2026 government program data

---

## File Index

| File | Module | Description |
|---|---|---|
| `00_welcome_overview.md` | Module 00 | Orientation, product suite summary, LMS usage guide |
| `01_energy_independence.md` | Module 01 | Flagship solar + battery product (HSEP framework, Export Trap) |
| `02_energy_starter.md` | Module 02 | Entry solar with hybrid-ready inverter |
| `03_energy_upgrade.md` | Module 03 | Battery retrofit for existing solar homeowners |
| `04_commercial_solar.md` | Module 04 | Commercial energy engineering — business customers |
| `05_ev_solutions.md` | Module 05 | Solar-powered EV charging integration |
| `06_qld_government_programs_2026.md` | Module 06 | QLD federal rebates, STC scheme, closed state programs |
| `07_seq_government_programs_2026.md` | Module 07 | SEQ-specific: Solar Sharer Offer, FiT landscape |
| `08_wa_government_programs_2026.md` | Module 08 | WA state + federal stacking, VPP, no-interest loan |

---

## Content Structure Per Module

Each markdown file follows this structure:

```
# Module Title
Metadata block (type, module number, URL/applies-to, date)

## What Is It
Product/program overview

## The Core Problem
Key problem the product/program solves

## Key Components / Features / Programs
Detailed breakdown (tables where appropriate)

## Who Is This For
Qualification criteria — green flags and disqualifiers

## Live Call Scripts
Labelled setter/prospect dialogue blocks

## Objection Handling
Objection → Acknowledge → Reframe/Educate → Advance

## Knowledge Check
Q&A format — 5–6 questions per module
```

---

## Notes for Developer

### Content Formatting
- All scripts use `> **Role:** "Quote"` blockquote format for easy parsing and rendering
- Tables use standard markdown pipe format
- Status badges in program tables use emoji: ✅ ACTIVE / ❌ CLOSED / ⚠️ LEGACY / new label
- Warning/alert callouts use `> ⚠️` blockquote format

### Government Program Accuracy
- All program information verified as of October 2026
- Federal Cheaper Home Batteries Program: rebate steps down every 6 months — January and July
- QLD Battery Booster: confirmed closed May 2024 — do not present as current
- Solar Sharer Offer: launched 1 July 2026 for SEQ, NSW, and SA
- WA Residential Battery Scheme: began 1 July 2025, capped at 100,000 households
- Rebate figures are approximate — exact amounts depend on battery size, STC value at time of install, and network

### Suggested LMS Implementation
- Each `.md` file = one LMS module
- Module order is 00–08 (numeric prefix = display order)
- Knowledge Check Q&A at end of each module can be converted to interactive quiz format
- Call scripts can be highlighted/styled distinctly from instructional content
- Government program tables should be easy to update as rebates change — treat as semi-dynamic content with a review cadence of every 6 months (aligned with STC step-down schedule)

### Content Update Schedule
| Content Type | Suggested Review Frequency |
|---|---|
| Product modules (01–05) | Annually or on product change |
| Government programs (06–08) | Every 6 months — January and July (aligned with STC step-downs) |
| Feed-in tariff rates | Annually — after QCA announcement (1 July) |
| WA rebate amounts | Annually — amounts decrease each year to 2030 |
