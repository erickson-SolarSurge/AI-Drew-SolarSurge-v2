# Deployment and handoff

Solar Surge Sales Dojo **v2.2.0** (14 Oct 2026). Product owner: Emil Halili (emil@solarsurge.com.au).

Start with `README.md`, then `CLAUDE.md`, which is the detailed architecture guide (it's kept up to date and written for whoever works on the code next). `CHANGELOG.md` lists what changed by version. `SETUP.md` covers a from-scratch setup, which you don't need for the existing project.

## State at handoff

- **Checks:** `npm run typecheck` and `npm run build` pass. `npm run lint` is down to 107 errors and 12 warnings, all in older code: 106 `@typescript-eslint/no-explicit-any`, 1 `no-unused-expressions` (`PracticeCall.tsx`), plus `react-refresh` warnings. Formatting is clean. There is no automated test suite.
- **Database:** Supabase project `qnbrxdlmprmxtydfbpkw` (region ap-south-1, Mumbai). Every migration in `supabase/migrations/` is already applied, up to `20261013100000_lead_queue.sql`. Nothing is pending.
- **Hosting:** the app has only run locally so far (`npm run dev` on port 8080). This is its first production deployment.
- **Not in this package:** `.env` (secrets), `node_modules`, build output, and call recordings or transcripts with customer details. Get the keys from Emil over a secure channel.

## Build

```sh
npm ci
npm run build        # writes .output/
```

The build is TanStack Start on Nitro. The Vite preset (`@lovable.dev/vite-tanstack-config`, an npm package that needs no Lovable account) targets **Cloudflare Workers** by default: `.output/nitro.json` says `"preset": "cloudflare-module"`, and the build generates `.output/server/wrangler.json` (`nodejs_compat`, static assets from `.output/public`). The Worker name comes from `package.json` (`solar-surge-sales-dojo`).

### Deploy to Cloudflare Workers (default target)

```sh
npx wrangler login
npx wrangler --cwd .output deploy
```

Then set the runtime secrets on the Worker. Each command prompts for the value:

```sh
cd .output
npx wrangler secret put SUPABASE_URL
npx wrangler secret put SUPABASE_PUBLISHABLE_KEY
npx wrangler secret put SUPABASE_SERVICE_ROLE_KEY
npx wrangler secret put GOOGLE_API_KEY
npx wrangler secret put ANTHROPIC_API_KEY
npx wrangler secret put ELEVENLABS_API_KEY
```

Server code reads these from `process.env["X"]`. With `nodejs_compat` and a compatibility date after April 2025, Cloudflare fills `process.env` from the Worker's vars and secrets. **Check this on the first preview deploy**: sign in, open AI Drew, press "Tailor my script" (AI), search an address in the roof inspector, and run a practice call (voice). If those fail with "missing key" errors, the secrets aren't reaching `process.env`.

### Other hosts

Nitro can also build for a plain Node server or other platforms by changing the preset (for example `NITRO_PRESET=node-server npm run build`, then `node .output/server/index.mjs`). This hasn't been tried with this project's Vite preset, so test it before relying on it. Whatever the host, set the same six server variables.

## Environment variables

| Variable | When | Notes |
| --- | --- | --- |
| `VITE_SUPABASE_URL`, `VITE_SUPABASE_PUBLISHABLE_KEY` | **Build time** | Inlined into the browser bundle. Public by design. Have them in `.env` (or the CI environment) when you run `npm run build`. |
| `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY` | Runtime | Same values as the `VITE_` pair, for server code. |
| `SUPABASE_SERVICE_ROLE_KEY` | Runtime, secret | Bypasses row-level security. Server only. |
| `GOOGLE_API_KEY` | Runtime, secret | Gemini (main AI, QA transcription fallback). |
| `ANTHROPIC_API_KEY` | Runtime, secret | Claude: the fast route for live features (script assist, lead tailoring, roof readout, notes tidy) and the backup for everything else. |
| `ELEVENLABS_API_KEY` | Runtime, secret | Text-to-speech and speech-to-text. |

Never give a secret a `VITE_` name: anything with that prefix is shipped to the browser.

## Supabase settings for the live address

In the Supabase dashboard for project `qnbrxdlmprmxtydfbpkw`:

1. **Authentication → URL Configuration:** set **Site URL** to the production address, and add `https://<production-domain>/auth` to **Redirect URLs**. Keep `http://localhost:8080/auth` for local development.
2. **Google sign-in:** in Google Cloud Console, make sure the OAuth client's authorised redirect URI is `https://qnbrxdlmprmxtydfbpkw.supabase.co/auth/v1/callback` (unchanged by the deploy). Email and password sign-in also works.
3. **Migrations later:** the direct database host is IPv6-only. Push through the session pooler, as in `CLAUDE.md` → "Roles and data model". Get the database password from Emil; it isn't stored anywhere in the repo. When a migration changes tables, also update `src/integrations/supabase/types.ts` by hand (also in `CLAUDE.md`).

## After the first deploy

- Sign in as a super admin and click through: Dashboard, AI Drew (Setter and Confirmer), Admin → Leads, Admin → Field reps, QA & coaching, Help & guides.
- The first admin on a fresh database comes from `npm run grant-admin -- <email>`. The existing project already has super admins.
- **Call-back reminders** run in the browser (there's no server scheduler), so they only fire while a rep has the app open. A scheduled job (for example a Cloudflare Cron Trigger) would be a later improvement.
- **Live monitoring** uses WebRTC between browsers, with signalling through Supabase tables. Corporate networks that block peer-to-peer traffic may need a TURN server.

## Repository layout notes

- `src/`: the app. See `CLAUDE.md` for the architecture.
- `supabase/migrations/`: schema history (all applied).
- `KB_NH/`: the new hire course content (Markdown), bundled at build time. Keep it.
- `PRD/`: the product requirements document (`prd-source.html` → PDF) and its archive.
- `public/guides/`: Help & guides screenshots, the how-to guide PDF (`npm run guide:pdf`, needs Windows Edge) and a copy of the PRD.
- Root `*.md` and `*.pdf` files (the setter and confirm scripts, Framework V3, the Setter Playbook PDF, the QA framework PDF, `AI LMS Leads Header V1 - Sheet1.csv`) are source documents the app was built from. The app's copies live in `src/data/`; the root files are reference only and aren't loaded at runtime.
- `.lovable/` and `roadmap.md` are Lovable-era notes, kept for history.

## Open business decisions

These are listed in PRD section 6 ("Open Decisions & Next Steps"). They're content and policy questions for Emil, not deployment blockers. Examples: compliance sign-off on the age rules, approval of draft content, and rotating the database password.
