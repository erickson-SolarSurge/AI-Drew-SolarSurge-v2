# Changelog

Version numbers follow the PRD (`PRD/Product Requirement Document (PRD).pdf`), which has the full business-language change log. This file is the short developer version.

## 2.2.0 — 14 Oct 2026

- **14 Oct 2026 Setter and Confirm scripts** (`Appointment Setter Script_Updated 10142026.md`, `Confirm Script — Solar Surge_updated 10142026.md`) replace Framework V3 and the July Confirm Script, word for word. Data: `src/data/setter-playbook.ts`, `src/data/confirm-script.ts`.
- Six qualifiers with a three-tier rule (pass / flag / fail / hold) decided in code (`qualificationFor`, `outcomeBlock` in `src/data/call-notes.ts`). Setters can't book and confirmers can't confirm unless the answers allow it.
- New confirmer outcome **Holding: flagged to manager** (becomes a call back). `wrapLead` sends `managerFlags`; `notifyManagers()` notifies everyone with management access. Flagged badge in Admin → Leads.
- Q3 asks the **year of birth** (`BirthYearInput`, `ageYearBrackets()`); the pension question is removed.
- Reps ask each qualifier straight; the reason is a small "If they ask why" line (`Qualifier.ifAsked`, `{ ifAsked }` script lines).
- QA checks, AI prompts (live coach, AI customer, flyby, roof, lead tailoring) and the knowledge base follow the new scripts.
- Roof inspector readout moved to the fast AI route (Claude Sonnet first).
- Help & guides rewritten (24 sections, new screenshots); `npm run guide:pdf` rebuilds the how-to guide PDF. Roof quick-pick suburbs limited to our territories.

## 2.1.0 — 13 Oct 2026

- Lead queue: Admin → Leads (CSV/paste import, even split to reps, reassign/archive/return to queue); reps work leads in AI Drew. Migration `20261013100000_lead_queue.sql`.
- Each lead is dialled once (no answer finishes it). Manual calls auto-save as the rep's own leads; My leads dialog.
- Call-back notifications and reminders in the bell (Call backs tab, desktop alerts).
- Setter / Confirmer role in AI Drew (`profiles.call_role`, migration `20261013090000_call_role.sql`).
- Mission Brief rebuilt as the new hire course from `KB_NH/*.md`.
- Battery talking points for solar-without-battery leads; WA territory support; automatic territory detection; roof pre-load.
- Objection log; "why both home" rebuttal; territory length fix.

## 2.0.0 — 12 Oct 2026

- Field rep booking calendar (migration `20261012130000_field_calendar.sql`), Admin → Field reps.
- Module access by role (migration `20261012120000_nav_visibility.sql`).
- Live-call tool renamed AI Drew; Roof Inspector in a global dock (Map button, M key).
- Disqualification reasons (Zoho list), call disposition cards, QLD-time appointment picker.

## 1.3 – 1.9 — 8–9 Oct 2026

- Setter Playbook as the single source of truth; Rebuttals finder (R key); practice calls and AI coaches on the playbook.
- Sales Dojo live-call page with lead tailoring, address lookup, standard Aircall/Zoho notes, rep feedback on scripts (migration `20261009120000_script_feedback.sql`), Setter/Confirmer QA scoring (migration `20261009130000_coaching_rep_type.sql`).
- Faster live script assist (Claude Sonnet first); flyby coaching; QLD Government address lookup for the roof inspector.

## 1.1 — 7 Oct 2026

- Moved off Lovable onto Solar Surge's own Supabase project; Claude added as AI backup; assets bundled locally; keys server-side only.
- QA framework, document uploads, manual QA agents (migrations `20261007*`).

## 1.0

- Original Lovable-generated platform (see `PRD/archive/`).
