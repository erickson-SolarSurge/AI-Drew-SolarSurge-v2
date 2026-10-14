# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Solar Surge QLD Academy ("Sales Dojo"): a sales-training LMS for solar energy advisors. It has training modules, an exam, AI roleplay practice calls with a live AI script assist, call-recording QA and coaching forms, live call monitoring for management, and a super-admin control centre.

The app was originally generated with Lovable. **Since 2026-10-07 it no longer uses Lovable**: it runs on its own Supabase project, and every Lovable service (sign-in broker, AI gateway, asset hosting, error reporting) has been removed. Don't reintroduce Lovable services. First-time setup is in `SETUP.md`.

**Version and handoff:** the app version is in `package.json` (2.2.0 = PRD v2.2) and should move with the PRD version. `CHANGELOG.md` is the short developer change log (add an entry when you bump the version); `DEPLOYMENT.md` is the build, deploy and environment guide for the developer handling deployment.

**Product spec:** `PRD/Product Requirement Document (PRD).pdf` is the current PRD. The original v1.0 and the old Library copy are in `PRD/archive/`. `public/guides/Solar-Surge-Sales-Dojo-PRD.pdf` (linked from the Library page) is a copy of the current PRD: copy the PDF over it after each re-export. Emil also keeps a copy in `C:UsersemilhDownloadsSolar Surge` (with the current scripts); refresh it when asked.

**Keep the PRD updated daily.** On any day the app changes (features, fixes, decisions), before finishing:
- Edit `PRD/prd-source.html`. Add a dated entry at the top of section 5 (Change Log), adjust the module text and status badges, update section 6 (Open Decisions), and bump "Version" and "Last updated".
- Re-export the PDF with Edge, then copy it to `public/guides/Solar-Surge-Sales-Dojo-PRD.pdf`: `"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" --headless --disable-gpu --no-pdf-header-footer "--print-to-pdf=C:\AI LMS\PRD\Product Requirement Document (PRD).pdf" "file:///C:/AI%20LMS/PRD/prd-source.html"`
- Write the PRD for leadership (CEO), in plain business language with no code terms. The author is Emil Halili.

## Commands

```sh
npm install
npm run dev          # dev server on :8080 (moves to 8081 if that port is taken)
npm run build        # production build (nitro; Cloudflare is the preset's default target)
npm run lint         # eslint (includes prettier as a lint rule)
npm run typecheck    # tsc --noEmit
npm run format       # prettier --write .
npm run grant-admin -- <email>   # give an existing account super_admin (needs service-role key)
```

There is no test framework or test suite.

**Testing AI prompts and data helpers:** write a throwaway script under `scripts/`, run it, then delete it. Use `npx tsx --env-file=.env scripts/_x.ts`.
- Modules that import `training.ts` pull in `.mp3`/`.png` assets, which Node can't load. Register a small loader hook (`--import` a file that calls `module.register` with a `load` hook) that returns `export default "<url>"` for asset extensions.
- On Windows Git Bash, long heredocs containing apostrophes or `\n` escapes often get mangled, and backticks inside `node -e "…"` are run as shell commands (they silently empty template literals). Write multi-line edit scripts to a file with the Write tool instead.
- `eslint --fix` (prettier) re-indents files after edits, so exact-string replacement scripts written earlier may stop matching. Re-read the file, or match whitespace-tolerantly.

## Build and generated files

- `vite.config.ts` uses the `@lovable.dev/vite-tanstack-config` npm package as a Vite preset. It already includes tanstackStart, React, Tailwind, tsconfig paths, nitro, env injection and the `@` alias. **Do not add these plugins manually**, or they'll be registered twice. The preset needs no Lovable account.
- `src/routeTree.gen.ts` is regenerated from `src/routes/`. Don't edit it.
- `src/integrations/supabase/types.ts` describes the database schema. The installed Supabase CLI generates a newer format that doesn't fit this file, so it is **maintained by hand**: when a migration adds or changes tables or columns, update the `Row`/`Insert`/`Update` types to match.
- `.lovable/plan/*.md` and `roadmap.md` are Lovable-era notes. They help with the intent behind a feature, but their status lines are out of date (for example, they say the live AI assist was removed). Feature status now lives in the PRD.

## Architecture

**Stack:** TanStack Start (SSR React 19), TanStack Router (file-based) and React Query, Tailwind v4 with shadcn/ui ("new-york", in `src/components/ui`), and Supabase for auth, Postgres, storage and RLS. Path alias: `@/*` → `src/*`.

**Request pipeline:**
- `src/server.ts` is the custom server entry, configured in `vite.config.ts`. It wraps TanStack's handler and turns h3-swallowed SSR errors into an HTML error page.
- `src/start.ts` registers the global middleware: an error middleware, CSRF protection on server functions, and `attachSupabaseAuth`. `attachSupabaseAuth` adds the browser's Supabase access token as a Bearer header on every server-function RPC. If you remove it, all authenticated server functions break.

**Routing and auth:**
- `src/routes/__root.tsx` is the only root layout. It provides the QueryClient, head and meta.
- `_authenticated/route.tsx` is a pathless layout with `ssr: false`. It redirects to `/auth` when there is no Supabase session, and renders the sidebar, header and mobile tab bar.
- `_authenticated/admin/route.tsx` gates its pages on the `amISuperAdmin` server function and supplies `AdminContext` (the selected tenant).
- Do not use Next.js conventions (`src/pages`, `server-only`). ESLint bans `server-only`. Server-only modules use the `*.server.ts` suffix.

**Server functions (`src/lib/*.functions.ts`):** The backend is made of `createServerFn` handlers grouped by domain:

| File | Domain |
| --- | --- |
| `admin.functions.ts` | Users, tenants, modules, audit log, module content |
| `qa.functions.ts` | Access/roles, recordings, transcription, AI QA scoring, coaching forms, notifications |
| `roleplay.functions.ts` | AI customer replies, speech-to-text, call scoring, coaching |
| `roof.functions.ts` | Roof insights |
| `dojo.functions.ts` | Sales Dojo: lead tailoring, customer location, call-notes tidy |
| `feedback.functions.ts` | Rep feedback on scripts (submit, list, review) |
| `nav-access.functions.ts` | Module access by role (read for everyone, set by super admins) |
| `field-calendar.functions.ts` | Field rep calendar: read, book, cancel; admin territories, capacity, field reps |
| `leads.functions.ts` | Lead queue: admin load/list/reassign/archive/history; rep queue counts, claim next lead, wrap up |
| `tts.functions.ts` | Text-to-speech |

Handlers follow one pattern:
1. Use `.middleware([requireSupabaseAuth])`. It verifies the bearer JWT and puts an RLS-scoped `context.supabase` and `context.userId` on the context.
2. Validate input with zod.
3. Check privileges with the DB RPCs `has_role(_user_id, 'super_admin')` and `has_management_access(_user_id)`.
4. For RLS-bypassing work, lazy-load the service-role client with `await import("@/integrations/supabase/client.server")`. **Never import it at top level** from a `.functions.ts` or route file: those ship to the client bundle.
5. Record super-admin mutations with `writeAudit` to `audit_logs`.

Client code calls server functions through `useServerFn` plus React Query (see `src/hooks/useAccess.ts`). Some simple per-user reads, such as `useProgress`, query Supabase directly from the browser and rely on RLS.

**AI and voice providers:**
- All text AI goes through `src/lib/ai.server.ts`. `askAi()` tries the Gemini models in turn, then falls back to Claude (`claude-opus-5-5` via `@anthropic-ai/sdk`, with server-side refusal fallback on). Live call turns use Claude effort `low`; QA and post-call scoring use `medium`.
- Exception: `fast: true` reverses the order to **Claude Sonnet first** (`claude-sonnet-5-5`, effort `low`, 4k `max_tokens`) with Gemini as the backup. It is used wherever a rep is waiting (the live AI assist `coachNextLine`, Sales Dojo lead tailoring and notes tidy), because Gemini took 18–94 s per suggestion. Sonnet rejects non-default `temperature`, so don't send one to Claude. Without `ANTHROPIC_API_KEY`, the `fast` route just uses Gemini.
- Load `ai.server.ts` lazily inside handlers (`await import("@/lib/ai.server")`) so the SDK and keys stay out of the client bundle.
- Speech-to-text uses ElevenLabs. QA transcription falls back to Gemini audio (`transcribeWithGemini`).
- Secret keys are read only from `process.env` in server code: `GOOGLE_API_KEY`, `ANTHROPIC_API_KEY`, `ELEVENLABS_API_KEY`, `SUPABASE_SERVICE_ROLE_KEY`. TanStack Start loads all of `.env` into `process.env` in dev and build; in production they must be set on the host.
- Never hardcode a fallback key, and never give a secret a `VITE_` name: every `VITE_*` entry in `.env` is exposed to browser code as `import.meta.env.*`. Only the Supabase URL and publishable key are meant to be public.

**Practice call and AI assist (`src/components/PracticeCall.tsx`):** The rep's mic is segmented by a client-side voice-activity detector (or push-to-talk). Each clip goes through `transcribeTurn`, then `customerReply` voices the AI homeowner via `speakText`. After every customer line, `coachNextLine` runs in parallel to suggest the rep's next line; `coachSeqRef` discards stale replies. The rep can switch it off (`ss_ai_assist` in localStorage). `speakAndWait` only resolves after the line's own "started" speech event, because `speakText` fires a "stopped" event first.

**Flyby coaching (`FlybyCoaching.tsx`, `flybyCoach` in `roleplay.functions.ts`):**
- When the rep presses End call, `PracticeCall` hands the transcript up through `onCallEnd`. `flybyCoach` then scores it on the same QA framework as QA (`frameworkRubric`, `companyKnowledge`, `humanise` from `qa-framework.ts`) plus `playbookForAi()` and the persona's scenario.
- It returns a /100 total plus a win, a focus, four "try this" lines (Acknowledge, Reframe, Ask, Advance) and a next-run challenge.
- Its prompt is built by `flybySystemPrompt()`. The live coach's prompt is built by `liveCoachPrompt()`. Both are exported so they can be run outside a request (see Testing AI prompts).
- It follows the same human coaching voice as the QA form: pillar names and scores are never shown.
- Nothing is saved. The card clears on the next call or a persona change.
- "Hear your coach" reads the card aloud via `speakText`.
- The old ElevenLabs agent embed (`ConvaiWidget`) was removed; this card replaces it.

**QA scoring and coaching (`src/data/qa-framework.ts`, `evaluateRecording` in `qa.functions.ts`):**
- The built-in "AI QA Coach Framework (ARM Edition 2.0)" is fixed in code. It sets four pillars of 25 points each, which add up to `qaScore`, plus company knowledge from `src/data/knowledge.ts`.
  - The pillars' method is aligned with the 14 Oct 2026 scripts: Discovery means the six qualifiers asked in order, straight (the reason only if the customer asks why), Navigation means Acknowledge → Reframe → Ask → Advance, and Resolution means booking only when the six pass, then locking it in (confirmers: the holding line on any Flag or Don't-book answer).
  - The prompt includes `playbookForAi()`.
- The AI also reads reference text from three sources: per-call documents sent in the request, documents attached to the form (`coaching_form_attachments`), and the campaign library (`campaign_documents`), within a character budget.
- **Coaching must read like a person wrote it.** The framework steers the content, but its labels (ARM, pillar names) never appear in the form text. `humanise()` strips any that slip through. The Sharon practice sign-off (`PRACTICE_SIGN_OFF`) is appended in code, not by the model.
- **Rep type:** the coach picks **Appointment Setter** or **Confirmer** (`RepTypeSelect`; remembered in `ss_qa_rep_type`). It's stored on `coaching_forms.rep_type` and passed to `evaluateRecording`.
  - Setters are judged by the Appointment Setter Scripts (14 Oct). Their `PROTOCOL_CHECKS`: opener, Q1 highest bill, the pitch, Q2 both decision-makers, Q3 year of birth (asked as a year), Q4 moving plans, Q5 employment, Q6 roof and renovations, reason when asked, one specific time, lock-in, and the polite exit without the reason. Q1–Q4 and Q6 are qualifying.
  - Confirmers are judged by the Confirm Script (14 Oct, `src/data/confirm-script.ts`, word for word from the repo-root .md): the same six again, plus "holding line on a Flag or Don't-book answer" and never calling attendance a legal or rebate requirement.
  - `pillarsFor(repType)` swaps the pillar wording but keeps the keys, so the score is still /100.
- **Qualification:** `src/data/coaching-protocols.ts` lists every question each rep type must ask (`PROTOCOL_CHECKS`).
  - The AI marks each check pass/fail/missed/na with a quote.
  - `verdictFor()` decides the verdict **in code**: any qualifying fail → Not qualified; any missed → Not verified; otherwise Qualified.
  - `readChecks()` treats a check the model left out as missed.
  - Missed checks are added to deviations by code as "Didn't ask or confirm: …"; the prompt tells the model not to list them itself.
  - The result is stored in `coaching_forms.qualification` (jsonb) and shown by `QualificationPanel` (form page, rep's records, PDF).
- Document text is extracted in the browser (`extractDocumentText` in `qa-uploads.ts`: pdfjs-dist for PDF, mammoth for .docx). Scanned or image-only PDFs yield no text.

**Roles and data model (`supabase/migrations/`):**
- There are two role layers:
  - `user_roles` (`app_role`, e.g. `super_admin`): platform control.
  - `profiles.platform_role` (Manager / Supervisor / Trainer / Representative), together with `access_level` (View/Read/Write) and `campaigns`: QA and coaching visibility.
- Multi-tenancy uses the `tenants`, `user_tenants` and `module_tenants` tables.
- **Manual agents (`qa_agents`)** are agents added by name in QA, with no email or login. Recordings and coaching forms point to either `agent_id` (a user) or `qa_agent_id` (a manual agent); a check constraint requires one of them on forms.
  - The API exposes a single `agentId`. `splitAgent()` in `qa.functions.ts` decides which column it goes in; `useAgentOptions()` merges both kinds for dropdowns.
  - Manual agents get no notifications and can't sign their forms. Those forms are shared as PDFs.
- RLS policies enforce "management sees all, reps see their own" on `call_recordings`, `coaching_forms`, storage objects and live sessions.
- Schema changes go in new migration files under `supabase/migrations/`, then update `types.ts` by hand.
  - The project's direct database host is IPv6-only and can't be reached from this machine, so push through the session pooler (Mumbai region): `echo y | npx supabase db push --db-url "postgresql://postgres.qnbrxdlmprmxtydfbpkw:<db-password>@aws-0-ap-south-1.pooler.supabase.com:5432/postgres"`.
  - Ask the user for the database password; it isn't stored in the repo, and never write it to a file. Percent-encode special characters in the URL (`#` → `%23`). Right after a password reset the pooler can reject the new password for about a minute ("password authentication failed"); wait and retry once before asking again.
  - All migrations up to `20261013100000_lead_queue.sql` are pushed (2026-10-13).
- Storage buckets (`call-recordings`, `campaign-docs`, `module-media`) are private; the app serves files through signed URLs.
- Super admins can't be granted from the app's own UI on a fresh database. Use `npm run grant-admin -- <email>` after the person has signed in once.

**Roof inspector:** the tool is `src/components/roof/RoofInspector.tsx` (a Google Maps satellite iframe with draggable % panel overlays, type-ahead search and AI insights from `roofInsights`). Module 3 (`roof.tsx`) wraps it in `ModuleShell` with the suburb chips; everywhere else it opens in the global `RoofDock` (the floating Map button, see AI Drew below). Its layout uses container queries, so it stacks in narrow spaces. Out-of-area addresses get the same warning as the AI Drew address card (`serviceAreaFlag()` in `location-response.ts`, built on `placeCustomer`/`locationScript`), shown above the map. **Our territories are SEQ and WA** (2026-10-13): `placeCustomer` puts any point west of 129°E in WA (`territory: "WA"`, region "Perth" within 150 km, else "Western Australia", in area); otherwise the SEQ regions decide (`territory: "SEQ"`). Anything else is flagged "outside our territories (South East Queensland and Western Australia)". `locationScript` has a WA answer (draft). The readout runs on the **fast AI route** (Sonnet first, since 2026-10-14; Gemini-first took ~90 s per address and looked broken). The roof readout prompt (`buildRoofPrompt`) uses WA rules for WA properties (no Queensland programs; eligibility "check") and Queensland rules otherwise.

**Roof inspector address lookup (`src/lib/geocode.server.ts`):**
- Sources, in order: the Queensland Government ArcGIS locator (exact property points, needs no key), then the Esri World geocoder (covers NSW border areas), then OpenStreetMap Nominatim, which usually only finds the street.
- `splitUnit()` removes "Unit 4" or "4/" from the front before the lookup, because the locators match the land parcel, not the unit. The unit goes back into the label and the AI prompt.
- Each result carries a `precision` (exact/approximate/street/area), which sets the map zoom and the warning badge.
- Type-ahead suggestions use the QLD locator's `suggest` endpoint, through `suggestRoofAddresses`.

**Age rule (14 Oct 2026 scripts):** Q3 asks the **year of birth, never the age**. Born under 65: book. 65 to 70: book, write "AGE REVIEW" and flag to the manager (confirmers: don't confirm; holding line). Over 70: don't book (polite exit, never the reason). A year alone allows two ages; someone turning 71 this year (`needsBirthday`) stays pending until "have you had your birthday yet this year?" is answered (`NoteEntry.hadBirthday`; not yet = still 70 = flag). The brackets come from `ageYearBrackets()` in `setter-playbook.ts` (the current Brisbane year; the scripts give 2026's and say to update them each January), with `ageFromBirthYear()` in `call-notes.ts`. `AGE_RULE` is in `playbookForAi()`, so every AI follows it. Never tell a customer they "should be fine" or quote another cutoff.

**Setter Playbook (`src/data/setter-playbook.ts`)** is the single source of truth for the call method.
- **The call flow is the Appointment Setter Scripts of 14 Oct 2026** (`Appointment Setter Script_Updated 10142026.md`, repo root), followed strictly and word for word, with one deliberate change (Emil, 14 Oct): **reps ask each qualifier straight**. Each question's "why" sentence was moved out of `ask`/`confirmAsk` into `Qualifier.ifAsked`, a `{ ifAsked }` script line (and `DialogueTurn`) rendered small under the question as "If they ask why:" (`IfAskedLine` in dojo.tsx, `ScriptLines`, /calling); it's said only when the customer asks. QA's "Reason when asked" check is n/a unless the customer asked. Use `scriptLineText()` for the text of any line. It replaced Framework V3 (12 Oct). The only wording swaps are listed in the file header ("Liam" → [your name], "(D2D team member name)" → [D2D rep name], "He/she" → [He/She], the D2D sample "about 5 years" → "about [X] years").
  - Flow (`CALL_FLOW`): 1 `opener` → 2 `bridge` (Q1 the highest bill in the last 12 months, "Still a high bill…", D2D's rebates question) → 3 `value` (the assessment pitch + the 45 minutes line) → 4 `qualify` (the qualifying block: intro + Q2–Q6) → 5 `appointment` (the "over the street" line, with a note to say it only when true, Emil's decision) → 6 `close` (lock in: both for the full hour, the summer bill handy) → 7 `log` (`BOOKING_LOG`). Steps 1–3 differ by lead source (`bySource`); always read lines through `flowSections(step, source)`.
  - `MINDSET` holds the scripts' "Why we qualify this strictly", "What and why" and "Book, flag or don't book". `POLITE_EXITS` (not-fit, major-work, partner) replace the old DISQUALIFY exits. `BILL_PLACEHOLDER` is still used by the `cant-afford` rebuttal.
- `QUALIFIERS`: the six in order, `bill` (Q1), `owners` (Q2 both decision-makers), `age` (Q3 year of birth), `selling` (Q4 moving plans), `work` (Q5 employment, record only), `roof` (Q6 roof, repairs, renovations). Ids were kept where the meaning maps, so stored notes and QA ids still work. Each has the setter `ask` and `coach` note, the Confirm Script's `confirmAsk`/`confirmCoach`, and `rule` (`book` / `flag` / `dontBook`, the quick-reference table). `QUALIFIER_FOOTNOTE` is the 70/71 birthday note.
- It also holds the rebuttal library (the playbook's 13, V3's `age-eligibility`, `selling-soon` and softened `cant-afford`, Emil's `why-both-home`), corrected to the 14 Oct rules (ask the year; moving within 3 years = polite exit). Their `step` numbers follow the new steps (1 opener … 5 booking). The method is **Acknowledge → Reframe → Ask → Advance**, used at most twice.
- Every consumer reads from it:
  - the /calling page (with the Book / Flag / Don't book table);
  - `ScriptAssistPanel` (auto-pins the matched rebuttal; also shows the qualifier checklist and step tracker, from `STEP_CUES`/`QUALIFIER_CUES`);
  - `RebuttalFinder` (mounted on every page; press R; other components open it with `openRebuttals(id)` from `src/lib/rebuttal-finder.ts`);
  - the command palette;
  - `playbookForAi()` in every AI prompt (live coach, AI customer, flyby, QA, roof, lead tailoring).
- It is fixed in code and is not admin-editable. Never reintroduce weekday pattern interrupts, other bill bands, or any price, ballpark or savings figure in rep-facing lines.

**Sales Dojo (`/dojo`): the setters' and confirmers' live-call tool.** Since 2026-10-12 reps see it as **"AI Drew"** (sidebar, mobile menu, command palette, page title, feedback admin); the code and these docs still call it the Sales Dojo, and "Sales Dojo" is also the platform's own name, so don't rename it elsewhere. The Roof Inspector (module 3) is linked directly under AI Drew in the sidebar and mobile menu, not in the module list, but it is still module 3 for progress. Its route file is large (`src/routes/_authenticated/dojo.tsx`). It's a search across every rebuttal, plus a step-by-step call that also produces the Aircall/Zoho note.

*Setter or Confirmer (2026-10-13):* the header's "I'm calling as" dropdown (`RolePicker`) picks the script. `useCallRole()` (`src/hooks/useCallRole.ts`) returns the role: the rep's own pick (localStorage `ss_dojo_role`, kept for the Brisbane day) or else the default a super admin set in Admin → People (`profiles.call_role`, read on its own query so a missing column just means "not set"). With neither, `RoleGate` asks before showing any steps. Switching remounts `StepGuide` (key `role-callKey`), keeps the customer, and clears an outcome the new role can't use.
- **Confirmer steps** are `CONFIRM_STEPS` in `sales-dojo.ts`, pulled from `CONFIRM_SCRIPT` (`confirm-script.ts`, the 14 Oct Confirm Script, word for word; `Confirm Script — Solar Surge_updated 10142026.md`) by section title with count checks (`confirmSays`). Steps: Opening (`{ kind: "on-file" }` + the script's opening lines), Re-jog (+ battery), Confirm the details, Qualifying questions Q1–Q6 (the confirmer wording), Lock it in with the **holding line** block (`{ kind: "holding" }`, `HoldingBlock`: highlighted with a one-tap Holding outcome whenever an answer is a Flag or Don't book). `CONFIRM_RULES` holds the "why strict" and "never a legal or rebate requirement" rules. `appointmentFill` (confirmers only) fills [day]/[time]/[consultant]; `peopleFill` fills [customer name], [partner name] and [name] (the rep).
- **Per-role data** lives in `call-notes.ts`: `CALL_ROLES`, `ROLE_OUTCOMES` (confirmers: confirmed, **holding**, rescheduled, cancelled, no-answer, callback), `NoteField.roles` with `fieldsFor(role)` (the six qualifiers for both roles; `solar` setter-only), and `qualificationFor(…, role)` / `formatCallNotes({ role })`. For confirmers, `appointment*` is the appointment on file and `reschedule*` the new time (reschedule, call back or the holding call back). Cancelled reuses `dqReason` (same Zoho list) and skips the verdict.

*Script data:*
- `DOJO_STEPS` (`src/data/sales-dojo.ts`) pulls its lines from `CALL_FLOW` (`flowLines`, `sourced`, `says`) and the qualifier cards from `QUALIFIERS` (`qualifierCard`, which shows the rule chips via the dialogue block's `rule`). These throw at import if a step id or line count changes (`says("appointment", 1)`, `says("close", 3)`, `confirmSays` per section), so never copy script wording into it. Steps: Opener (+ "Solar & FIT" notes), Q1 highest bill, The assessment, Qualifying block (Q2–Q6 cards, polite exits, objection log), Book the time (calendar, outcome), Lock it in, Log.
- Content not in the official scripts (e.g. the "Where are you located?" answer) is marked `draft: true` or as a draft note, and is listed in `OPEN_ITEMS` until Emil approves it.

*Layout:*
- At `2xl` there are three columns: customer, script and notes. The customer and notes columns are sticky.
- At `xl` there are two columns: customer above the script, notes on the right. Below that the sections stack.
- The customer column uses container queries (`@container`, `@lg:`).

*State:*
- One `LeadState` per call lives in `sessionStorage` (`ss_dojo_lead`) and is **never saved to the DB**. `readLead()` merges stored data over `EMPTY_LEAD`.
- "Next call" resets to `EMPTY_LEAD`, keeping the lead source, and remounts `StepGuide` via `callKey`. It asks for confirmation if the note wasn't copied, or changed since it was copied (the Date line is ignored).
- **Gotcha:** when you add a `LeadState` field, give it a default in `EMPTY_LEAD` *and* read it defensively (`lead.x ?? ""`). An open tab keeps its old in-memory state through a hot reload, and that has crashed the page twice.

*Column 1, customer:*
- **Lead tailoring.** The rep pastes the vendor's lead notes in any format. The scripts are strict, so the AI only fills placeholders ([He/She] is left for the rep, and code restores it if the AI fills it). `tailorScript` (`dojo.functions.ts`, fast/Sonnet route; prompt and rules in `src/lib/lead-tailoring.ts`) returns facts, contact details, a per-qualifier vendor status, watch-outs and tailored lines.
  - Lines are keyed by `lineId` ids from `dojoScriptLines()`, the same ids the renderer uses. They're applied through `TailorContext`, with a "Show playbook wording" toggle.
  - `finishTailoring()` enforces three things in code: `meetsBillMinimum()` decides the bill, unknown ids are dropped, and any line with a `$` figure other than the homeowner's bill is rejected.
  - Lines containing playbook sample details are flagged MUST REWRITE.
- **Address.** `locateCustomer` geocodes the address. `placeCustomer()` (`src/data/location-response.ts`) picks the SEQ region and the distance from Coomera HQ. `locationScript()` builds the "Where are you located?" answer in code, with no AI. It only mentions the distance under 50 km, and includes an honesty note. The same answer shows in search when `isLocationQuestion` matches.
- **Roof Inspector.** The address card's "Inspect roof" button calls `openRoofInspector(address)` (`src/lib/roof-dock.ts`). The panel itself is the global `RoofDock` (mounted in `_authenticated/route.tsx` next to `RebuttalFinder`): a floating **Map** button above Rebuttals, or press M, on every page. Closing the sheet minimises it with a "genie" animation into the Map button (Web Animations API in `RoofDock`; opening grows out of the button; skipped for prefers-reduced-motion). Every close path (Minimise, X, Escape, overlay) goes through `minimise()`; the address and last result live in sessionStorage (`ss_roof_dock`, never saved), so reopening is instant. `clearRoofDock()` runs on Next call and on Clear lead. Hidden if the role can't see `roof`.
- **Customer name** (`CustomerNameCard`): customer and partner boxes, pasted from Zoho. `peopleOf()` reads the boxes first, then the AI's `contact`, for the script, the lead header and the note.
- **Auto-fill from the lead notes** (`autofillFromLead()`): after tailoring, the AI's name and bill (`bill`, or `billAmount` when the lead gives no period) are put into the name and bill boxes, but only if the box is empty or still auto-filled (`nameFromLead`/`billFromLead`). Typing in a box clears the flag, so a re-tailor never overwrites the rep's edit. The bill line in the note says "(lead notes)" or "(Zoho)" accordingly.
- **Bill on file (Zoho).** `parseBillText()` reads the pasted bill and asks Month or Quarter if that's unclear. `billSpoken()` fills the script's bill lines, and the bill answer offers "Use the bill on file".

*Placeholder fills (`FillContext`, applied to every spoken line, tailored or not):*
- `peopleFill`: [Name] becomes the customer's first name; [partner] and [suburb] come from the lead or address; [address] is the matched address (or what was pasted); [your name] is the rep's first name from their profile. Don't rely on the AI for names, because it only returns the lines it changed.
- `billFill`.
- `d2dFill`: [D2D rep name], and the D2D bridge line's [He/She] becomes the pronoun the rep picked (He/She/They), or the D2D rep's first name if none is picked. **Never infer gender from a name.** The D2D name and territory boxes show in step 1 for D2D leads only.

*Column 2, all input happens in the script:*
- `{ kind: "notes" }` blocks (`NotesBlock`) sit in their steps: objections in the qualifying block, outcome in Book the time, consultant and personal detail in Lock it in.
- The "objections" item renders `ObjectionLog` (2026-10-13), not a tick box: one or more entries, each a dropdown of every `OBJECTIONS` label plus "other", a "what they said" box (required for other), a result (`OBJECTION_RESULTS`: overcome / still hesitant / not overcome), a "how you handled it" box. Picking an objection opens its full script inline (`InlineRebuttal`, which reuses `BigRebuttal`, so placeholders fill and the feedback buttons show); "other" shows the method strip instead. Stored in `CallNotesDraft.objectionLog`; `objectionLines()` prints them under DETAILS → Objections. Tidy wording doesn't touch these boxes.
- Qualifier cards hold `QualifierInput`; detail cards use `extraNotes` (solar & FIT in the opener; address for confirmers).
- The polite exits (`DisqualifyBlock`, opened automatically when an answer says don't book): "Mark as disqualified" pre-picks the Zoho reason of the failed qualifier (`DQ_REASON_FOR`), and major work offers Call back (within 3 weeks) or Future contact (longer).
- Everything goes through `NotesContext`.
- Booked and call-back times use `QldTimePicker`: a calendar plus a time list (7am–8pm, 15-minute steps). They're **always Queensland time**, whatever the rep's computer clock says (`qldToday()` uses `Australia/Brisbane`). Reps in Manila (UTC+8) see their own time beside each option. A pick writes `appointmentDate`/`appointmentTime` and the note text, e.g. "Thu 15 Oct 2026, 4:30pm QLD time".
- `QualifierInput` (`src/data/call-notes.ts` types):
  - Q2 decision-makers is Yes/No, worded so that **Yes = meets the qualifier** (`YES_NO_QUESTION`); No = rebook.
  - Q4 moving, Q5 employment and Q6 roof pick an option (`QUALIFIER_CHOICES`), each option with a `tier` (pass / flag / fail / hold), `says` text and `needsDetails` (minor repairs, major work and "other" need the details box).
  - Q1 bill is an amount plus Monthly/Quarterly, converted both ways by `billBoth()`.
  - Q3 is the **year of birth** (`BirthYearInput`: the age shows at once, "AGE REVIEW" for 65–70, "don't book" over 70; `NoteEntry.birthYear`, with `age` (the band) derived from it). The band buttons stay as a fallback under "Won't give their year?". The pension question was removed (not in the 14 Oct scripts).
  - Each question has a details box.

*Verdict (`qualifierAnswer()` / `qualificationFor()`, all in code; the AI never judges qualification here):*
- Each answer lands on a **tier** from the scripts' quick reference: pass, **flag** (book, flag to manager: 65–70, minor roof repairs), **fail** (don't book: bill under $450/qtr or $150/mth, over 70, moving within 3 years) or **hold** (don't book now: only one decision-maker → rebook; major work → call back).
- Status: **not-qualified** (any fail) > **hold** > **pending** (any of the six unanswered or incomplete, never failed for a question not asked yet) > **flagged** (all answered, with flags) > **qualified**.
- **Enforced in code (`outcomeBlock`)**: a setter can only pick Booked (outcome choices, wrap-up, and the field calendar's Open button) when qualified or flagged; a confirmer can only pick Confirmed when qualified, otherwise the holding line and **Holding: flagged to manager**. The blocked reason shows under the outcome choices and as a toast.
- The note prints "FLAG TO MANAGER: AGE REVIEW (Born 1958, 67 or 68)" / "MINOR ROOF REPAIRS - <details>", "DON'T BOOK YET: …", and ACTION lines for holding and flagged bookings.
- "Not interested", "No answer" and "Do not call" (`SKIPS_QUALIFICATION`) bypass the verdict entirely and print "NOT ASSESSED". "Do not call" also prints an ACTION line telling whoever reads the note to mark the customer Do Not Call in Zoho.
- The outcome starts as `null`.
- **Disqualified needs a reason** (`DQ_REASONS` in `call-notes.ts`, Zoho's list): `DqReasonPicker` shows under the Disqualified card and the step outcome. The polite exit button pre-picks the failed qualifier's reason (`DQ_REASON_FOR`). The note prints "DISQUALIFIED - <reason>" or "REASON NOT SET". Out-of-area reasons (`needsLocation`) add the customer's area (`areaOf(lead)`), or "location: NOT SET".

*Column 3, notes (`CallNotesPanel`), a live read-only draft:*
- `formatCallNotes()` builds the **standard Aircall/Zoho layout in code**. Change the format there, not in the AI prompt.
- The header shows customer, lead source, D2D rep and territory, bill on file and address. Then come the outcome, the verdict, any flags, the bill and six qualifiers (unanswered ones print "NOT ASKED"), the details, and ADDITIONAL NOTES (the rep's free `extra` box).
- "Tidy wording" (`tidyCallNotes`, fast route; prompt in `src/lib/call-notes-ai.ts`) only fixes the wording of the details text and `extra`. It works field by field: shorthand, typos, third person, and relative dates resolved to Brisbane dates. It never adds facts.
- `TidyCache`/`currentWording()` show tidied text only while the raw text is unchanged.
- The column also has "Copy for Aircall", the **Call disposition** cards (`DispositionCards`: Do not call, Future contact, Disqualified, Not interested, No answer, Call back; pressing a picked card clears it) and "Next call". Call back and Future contact open the QLD time picker.

*Removed on purpose (don't reintroduce):*
- The pre-call text, removed 2026-10-09.
- The 9 Oct "Before I lock that in" step and weekday pattern interrupts. (The "over the street" line is back word for word in the 14 Oct script, with the only-if-true note.)
- Weekday pattern interrupts.

**Rep feedback on scripts (`script_feedback` table, `feedback.functions.ts`):**
- `RebuttalFeedback` ("Did this help? Yes / No / Suggest a change") renders inside `ObjectionDetail` whenever a `surface` prop is passed. Surfaces: dojo, finder, calling, practice.
- It's asked once per script per rep per Brisbane day (localStorage key).
- Super admins review it at `/admin/feedback`: per-script % helpful (weakest first), the suggestions list with a status (new/reviewed/actioned, audited) and admin note, and CSV export.
- RLS: reps insert and read only their own rows.

**Training content:**
- `src/data/training.ts` holds the shipped defaults for modules 1, 3, 4, 5 and 6: value props, personas, exam questions and similar.
  - Personas are the practice-call scenarios. Each has a `leadSource`, `vendorNotes`, the playbook `objections` it raises, and the right `outcome` (`book` or `disqualify`).
  - `scenarioFor(persona)` packages these for the AI customer and coaches.
- Admins can override any module's text through the `module_content` table, edited in `/admin/modules`.
- `useModuleContent(key)` merges the stored row over the defaults with `mergeModuleContent` (`src/data/module-content.ts`), so pages always render complete content. When you add editable copy, add it to both the defaults and the merge types.

**Mission Brief = the new hire course (module 1, `/mission`, 2026-10-13):** Emil's KB package, nine markdown modules in `KB_NH/` (`00_welcome_overview.md` … `08_wa_government_programs_2026.md`; see its README), is the source. The trainer edits the .md files at each Jan/Jul review, and the page follows on the next build.
- Loading: `src/data/new-hire-content.ts` bundles them with `import.meta.glob` (`?raw`; a same-named file in `KB_Newhire/` overrides). `src/data/new-hire.ts` (pure, so a script can run it) parses each file with `marked`'s lexer into a `Lesson`: metadata, sections by h2 (`learn` / `scripts` / `objections` / `check`), and blocks. `> **Setter:**` / `> **Prospect:**` become chat bubbles; `**Acknowledge:**`-style lines under an objection's h3 become reveal steps; a bold label followed by a list becomes stat tiles or green/red flag lists; Knowledge Check Q&As become flip cards. Keep the KB's formatting conventions, or the parser misses things. Inline text renders through `marked.parseInline` and DOMPurify (`Md` in `LessonBlocks.tsx`).
- **Compliance in code:** the KB scripts quote figures, which the playbook bans. `hasCallFigure()` tags those script and objection lines **"Not for calls: no figures"** (Emil: teach the facts, flag the scripts), and facts and tables keep their numbers. Where the KB disagrees with the app, `correctionsFor()` adds a "Solar Surge update" note (Emil: the app is right): territories are SEQ + WA (the KB lists Toowoomba, Dalby and NSW), head office is Coomera (the KB says Burleigh Heads), and each call also confirms the bill and age. The KB's "say around 30%" advice gets the no-figures note.
- UI is in `src/components/mission/`:
  - **Hub** (`MissionHub`): a sun progress ring "X/9", Continue, three tracks (Start here / Products / Government programs), badges (Product Pro, Rebate Ranger, Mission Ready), and the admin-editable value props folded into a "Hooks cheat sheet".
  - **Module** (`/mission?m=03`, `MissionLesson`): a step rail Learn → Scripts ("Your turn" blurs the setter lines until tapped; Hear it) → Objections (reveal one step at a time; link to the matching AI Drew rebuttal via `playbookObjectionFor`) → Flip cards (`FlipDeck`, 3D `.flip-*` utilities in `styles.css`) → Quick check (`QuickQuiz`).
- Quiz: `src/data/new-hire-quiz.ts`, 4 questions per module, pass with `QUIZ_PASS_MARK` (3). Options are shuffled every attempt. These are drafts (`OPEN_ITEMS`).
- Progress: a pass upserts `module_progress` key `mission:<key>` (not in `MODULES`, so the dashboard counts don't change). Passing all nine also marks `mission` complete. Flip-card "known" and "started" state are localStorage only (`ss_mission_cards`, `ss_mission_started`). No migration was needed.
- The KB facts are **not** in any AI prompt (they contain figures); the AIs keep using the playbook and `knowledge.ts`.

**Module access by role (`nav_visibility` table, Admin → Module access, 2026-10-12):** super admins switch any menu item off for a platform role (Representative / Trainer / Supervisor / Manager). The hideable items are listed in `src/data/nav-items.ts` (`NAV_ITEMS`: AI Drew, the six modules, library, QA, live simulations, guides, my coaching records); the dashboard and admin can't be hidden. `useNavAccess().canSee(key)` filters the sidebar, mobile menu and bottom bar, command palette and dashboard cards, and `NavAccessGate` in `_authenticated/route.tsx` blocks a hidden page opened by link ("Not available for your role"). Super admins always see everything. No row = visible to all, and if the table is missing (migration not pushed) everything stays visible. When you add a page to the menu, add it to `NAV_ITEMS` too.

**Field rep booking calendar (2026-10-12; tables `territories`, `territory_capacity`, `field_reps`, `field_bookings`):**
- Field reps are the consultants who visit the house. Intervals are 10am, 2pm, 4pm, 6pm and 8pm, Monday to Saturday, in the **territory's own local time** (SEQ = Brisbane, WA = Perth). Non-QLD territories also show the QLD and Manila times.
- Pure logic is in `src/data/field-calendar.ts`: `nextDays` (today + 6, Sundays dropped), `isPast`, `convert`/`otherZones` (via `Intl`, so daylight-saving zones work), `slotState` and `appointmentText`.
- A slot is full when its bookings reach the territory's capacity for that interval (admin sets 3–5; default 4) **or** no rostered field rep is free. A field rep takes one appointment per interval.
- Bookings go through the SQL function `book_field_slot` (service role only). It takes an advisory lock per territory/date/time and checks the roster, capacity and clashes. A partial unique index also blocks double-booking a rep.
- `getFieldCalendar` returns the next ~7 days and hides other setters' customer details unless the viewer has management access. Only the setter who booked, or a super admin, can cancel.
- **AI Drew:** `{ kind: "calendar" }` in the Appointment setting step shows a summary card with an **Open calendar** button; the calendar itself (`src/components/dojo/FieldCalendar.tsx`, `large` mode) pops up in a wide `Dialog` (max-w-6xl) with a Close button. It has "By time slot" and "By field rep" views and refreshes every 20 s. Booking fills the notes (outcome booked, appointment text, QLD-equivalent `appointmentDate`/`appointmentTime`, consultant = field rep) and `LeadState.fieldBooking`. Cancelling clears those. It's wired through `NotesContext.call`, saving via a `leadRef`.
- **Admin → Field reps** (`admin/field-reps.tsx`): territories (name, time zone, active, capacity per interval), field reps (territory, phone, active, roster grid), and upcoming bookings with cancel. Changes are audited.
- The migration seeds SEQ and WA plus five example reps (Ben Carter, Mia Thompson, Josh Nguyen in SEQ; Hannah Walsh, Ryan Patel in WA). If the tables are ever missing, the calendar shows "not set up yet" and setters fall back to the QLD time picker.

**Lead queue (2026-10-13; tables `lead_batches`, `leads`, `lead_attempts`):** super admins load leads in **Admin → Leads** (`admin/leads.tsx`) and assign them to reps; reps work them in AI Drew.
- Loading: a CSV upload (Emil's sheet: `AI LMS Leads Header V1 - Sheet1.csv` in the repo root, columns Customer Name, Lead Details, Lead Source, Address, Phone Number, Territory), rows pasted from the sheet (tab-separated), or "Customer Name: …" blocks. Pure logic in `src/data/lead-import.ts`: `parseLeads` (blocks or CSV/TSV, quoted multi-line cells; lead details keep their line breaks), `auPhone` (any Australian format, incl. a missing leading 0 and "(041) 223-4269" → display "0412 234 269", dial "+61412234269"), `leadSourceFrom` (CC / Lead AX / D2D, else null), `checkLeads` (errors: no name, details or valid phone; warnings: no address/territory, unknown source, duplicate phone in the batch or already queued), `splitEvenly`, `followUpAt`. Unknown vendor sources (e.g. "GB") are mapped per batch in the preview, and the raw value is kept in `lead_source_raw`. A batch is "Setter leads" or "Confirm calls" (`call_role`).
- Working: AI Drew shows `LeadQueueBar` when the rep has leads (`useLeadQueue`, `src/hooks/useLeadQueue.ts`). `claimNextLead` → SQL `claim_next_lead` (service role; resumes an `in_progress` lead, then due follow-ups, then the queue, `for update skip locked`). Loading sets `LeadState.queueLeadId`, phone, territory (also the D2D territory), name, address and a `leadText`, with `autoStart` so `LeadPanel` tailors and `AddressCard` locates on mount. Those replies merge onto `latestLead()` (a ref in `SalesDojo`), not the render-time lead, because both land around the same time. A confirm-calls batch switches the role.
- Wrap-up: with a queue lead loaded, "Next call" becomes **Wrap up & next lead**. It requires an outcome the verdict allows (`outcomeBlock`), a reason for disqualified/cancelled, and a QLD time for call back/future contact/holding. `wrapLead` saves a `lead_attempts` row plus the lead's latest outcome and the exact `formatCallNotes` text. Call back / future contact / holding → `follow_up` at that time. Everything else, **including no answer, → done: each lead is dialled once and the queue never cycles** (Emil, 2026-10-13; an admin can "Return to queue" for another pass). **Manager flags (14 Oct):** a booking with flags, or a confirmer's holding call, sends `managerFlags` and `notifyManagers()` puts a bell notification for everyone with management access (super admins + Manager/Supervisor/Trainer, like `has_management_access`; linked to /admin/leads). Admin → Leads shows a **Flagged** badge (outcome holding, or "FLAG TO MANAGER" in the note). When nothing is left, `LeadQueueBar` says all assigned leads are dialled and AI Drew carries on for manual leads. This is the one place AI Drew call data is saved.
- **Manual leads (2026-10-13):** a hand-typed call in AI Drew saves itself as one of the rep's own leads once it has a customer name and a valid AU phone (debounced effect in `SalesDojo` → `saveManualLead`). It goes into a per-rep batch `Manual leads · <name>` (`MANUAL_BATCH_PREFIX`; `QueueLead.manual`; `lead_source_raw` "Manual (typed in by the rep)"), with status `in_progress`. That sets `LeadState.queueLeadId` + `manualLead`, and later edits (name, phone, notes, source, territory, address) keep saving. A phone already in the rep's leads reuses that lead (no duplicate). Wrap-up works as for queue leads ("Wrap up & save"), but afterwards starts a clean call instead of claiming the next lead. **My leads** (`MyLeadsDialog`, button in `LeadQueueBar`; `listMyLeads`) lists all the rep's non-archived leads with status, last note, Call and Open (`openMyLead` → `in_progress`). Only one lead is `in_progress` per rep (`releaseOthers` puts any other back to `queued`). "Not now" (`releaseMyLead`) clears the screen and keeps the lead as `queued` to call later. Admins see manual leads in Admin → Leads like any other batch. No migration.
- **Call-back notifications (2026-10-13):** `wrapLead` with call back / future contact inserts a bell notification ("Call back set: <name>", link `/dojo?lead=<id>`). `NotificationBell` (header) has a **Call backs** tab (`myCallbacks`: the rep's `follow_up` leads, soonest first, grouped Due now or late / Later today / Coming up, with Call and open) and "Show all call backs" (`/dojo?callbacks=1` opens My leads filtered to call backs). `useCallbackReminders` (in the bell, so on every page) polls every minute, and 5 minutes before a call back is due shows a toast with Open, a desktop notification if the rep allowed it ("Turn on desktop alerts" in the tab), and `notifyCallbackDue` adds a "Call back due" bell row (deduped by title + message). Announced keys are kept in localStorage `ss_callback_alerted`; overdue ones older than 2 h are listed, not announced. There's no server scheduler, so reminders only fire while the rep has the app open. AI Drew's `validateSearch` takes `lead` (opens it via `openLead`) and `callbacks`, then clears the search.
- The customer card shows the phone big with Copy and Call (`tel:`), plus phone/territory boxes; both go in the note header. The field rep calendar opens on the lead's territory when it matches a territory name (`preferTerritory`).
- **Territory is worked out** when the lead doesn't give one (`src/data/territory.ts`): `guessTerritory` reads the state from the address (state word or abbreviation, else the last 4-digit postcode; the geocoded `location.matched` first), else from a landline's area code (07 → QLD; 08 → WA, noted as possibly SA/NT; mobiles say nothing). SEQ means **South East Queensland**, not all of QLD: a Queensland address is SEQ only if AI Drew's address lookup says it's in the service area (`location.inArea`, the same regions as the address card), or, before a lookup, its postcode is in `SEQ_POSTCODES` (Brisbane, Logan, Redlands, Gold Coast, Scenic Rim, Ipswich, Lockyer Valley, Moreton Bay, Sunshine Coast; Toowoomba 4350, Gympie 4570 and the rest of QLD are out). Landlines: 07 3/07 5 → SEQ, 07 4 → regional QLD (outside), 08 → WA. WA is the whole state (`TERRITORY_BY_STATE`). Everything else is "outside our territories". AI Drew uses `territoryOf(lead)` everywhere (note, calendar, queue bar) and shows `TerritoryBadge` (warns on outside or a clash with the address). Admin → Leads fills blank territories in the preview (`fillTerritory`, marked "auto") and warns when the sheet's territory disagrees with the address.
- **Roof pre-load:** when AI Drew finds the address (queue lead or typed), `prefetchRoof()` (`roof-dock.ts`) runs `roofInsights` in the background and saves the result in the dock, so the Map opens already loaded (the Map button shows a spinner meanwhile; the dock shows "Loading the roof…" instead of starting a second search). Late results for an old address are dropped, and `pending` is reset on reload.

**Battery talking points (2026-10-13; `src/data/battery-guide.ts`):** for leads that already have solar but no battery. The pack is fixed in code and marked draft (`OPEN_ITEMS`): how a battery works, how it saves money (no figures), government help (federal Cheaper Home Batteries Program for everyone; for QLD "Battery Booster closed in 2024, no state rebate now"; the WA Residential Battery Scheme for WA leads), and Acknowledge→Reframe→Ask→Advance answers to their questions (`BATTERY_QUESTIONS`). Facts are dated (`BATTERY_FACTS_CHECKED`) with sources; **re-check every January and July**, when the federal discount steps down.
- Detection is in code: `hasSolarNoBattery()` reads the lead text and the solar note. The rep can override it ("Not a battery lead", `LeadState.batteryLead`).
- AI Drew shows `BatteryLeadCard` (customer column) and `{ kind: "battery" }` (setter value step, confirmer re-jog step), both opening `BatteryDialog`. Search for battery questions (`isBatteryQuestion`) shows the same content inline.
- Lead tailoring adds 2–3 `batteryPoints` for battery leads, from `batteryGuideForAi(territory)` only. `finishTailoring` drops any with a $, %, saving, payback or rebate figure or an unknown program (`isSafeBatteryPoint`). `neutralPronouns()` turns he/she into they in battery points and watch-outs, because the model guesses gender from names even when told not to.
- `BATTERY_NOTE` is in `playbookForAi()`, and `battery-programs-2026` is in the knowledge base, so every AI knows there's no current QLD battery rebate.

**Help & guides (`/guides`, management only):** the walkthrough is `GUIDE_SECTIONS` in `src/data/guide-sections.ts` (one screenshot + steps per page, grouped Rep / Manager / Admin, plus troubleshooting and `GUIDE_UPDATED`). Screenshots are `public/guides/*.jpg` at 1600×1000, taken from the running dev server signed in as a super admin (headless Edge via playwright-core, outside the repo), with a fictional demo customer in AI Drew and real customer or staff details blurred; never ship a screenshot with real customer details. `npm run guide:pdf` (`scripts/build-how-to-guide.ts`) rebuilds `public/guides/Solar-Surge-Sales-Dojo-How-To-Guide.pdf` from the same data. When a feature changes, update its section (and the screenshot if the screen changed), bump `GUIDE_UPDATED`, and rebuild the PDF. Old screenshots and the old guide are in `PRD/archive/`.

**Global floating widgets (mounted in `_authenticated/route.tsx`):** `RebuttalFinder` (Rebuttals button, press R, `openRebuttals(id)`) and `RoofDock` (Map button above it, press M, `openRoofInspector(address)`). Both ignore their key while the user is typing or another dialog is open. `NavAccessGate` wraps the page outlet.

**Live monitoring:** Management can listen silently to active roleplay sessions over WebRTC. Signalling runs through the `live_roleplay_sessions` and `live_roleplay_signals` tables (`src/lib/live-roleplay.ts`, `LiveRoleplayBroadcast.tsx`, `/live-monitoring`). By design, nothing is recorded or persisted.

## Conventions

- Prettier: 100-column lines, double quotes, semicolons, trailing commas.
- TypeScript is very strict (`noUncheckedIndexedAccess`, `exactOptionalPropertyTypes`, `noPropertyAccessFromIndexSignature`). Read env vars as `process.env["X"]`, not `process.env.X`.
- Styling uses the semantic tokens defined in `src/styles.css`. Besides the shadcn tokens there are brand tokens: `surge-amber`, `surge-gold`, `signal`, `alert`, `glass`, `hud`, and fonts `font-display`, `font-hero`, `font-mono`. Don't use raw colour values. Brand assets and the call-vault recordings live in `src/assets/` and are imported directly (the import gives a URL).
- Time shown to users uses Brisbane time (`Australia/Brisbane`, UTC+10, no DST), for example `BrisbaneClock` and the admin audit log.
