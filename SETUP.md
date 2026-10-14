# Setting up Solar Surge Sales Dojo

How to connect the app to a brand-new Supabase project and run it locally. You only do this once.

> **Deploying the existing app?** You don't need this file: the live Supabase project is already set up and every migration is applied. See [DEPLOYMENT.md](DEPLOYMENT.md).

## 1. Create the Supabase project

1. Sign in at [supabase.com](https://supabase.com) and create a new project. Pick the **Sydney** region so it's close to Queensland. Save the database password somewhere safe.
2. When the project is ready, open **Project Settings → API** and copy:
   - **Project URL**, for example `https://abcdefgh.supabase.co`. The part before `.supabase.co` is your **project ref**.
   - The **publishable** key (`sb_publishable_…`, or the older `anon` key).
   - The **secret / service-role** key. Keep it private: it bypasses all security rules.

## 2. Fill in `.env`

Copy `.env.example` to `.env` (or edit your existing `.env`) and fill in every line:

| Setting | Where it comes from |
| --- | --- |
| `SUPABASE_URL` and `VITE_SUPABASE_URL` | Project URL (same value in both) |
| `SUPABASE_PUBLISHABLE_KEY` and `VITE_SUPABASE_PUBLISHABLE_KEY` | Publishable key (same value in both) |
| `SUPABASE_SERVICE_ROLE_KEY` | Service-role key |
| `GOOGLE_API_KEY` | A **new** key from [Google AI Studio](https://aistudio.google.com/apikey). The old one was exposed in the code. |
| `ANTHROPIC_API_KEY` | [console.anthropic.com](https://console.anthropic.com) → API keys. This is the backup AI when Gemini is busy. |
| `ELEVENLABS_API_KEY` | A **new** key from ElevenLabs. The old one was exposed in the code. |

Also replace `REPLACE_WITH_NEW_PROJECT_REF` in `supabase/config.toml` with your project ref.

## 3. Create the database

From the project folder:

```sh
npx supabase login
npx supabase link --project-ref <your-project-ref>
npx supabase db push
```

`db push` asks for the database password from step 1. It creates every table, security rule and storage bucket from `supabase/migrations/`.

## 4. Turn on Google sign-in

1. In [Google Cloud Console](https://console.cloud.google.com) → **APIs & Services → Credentials**, create an **OAuth client ID** of type **Web application**.
   - Under **Authorized redirect URIs**, add `https://<your-project-ref>.supabase.co/auth/v1/callback`.
   - If asked, set up the OAuth consent screen first; "Internal" is fine for a Google Workspace domain.
2. In Supabase → **Authentication → Sign In / Providers → Google**, turn it on and paste the client ID and secret.
3. In Supabase → **Authentication → URL Configuration**:
   - **Site URL**: `http://localhost:8080` for now. Change it to the live address when you deploy.
   - **Redirect URLs**: add `http://localhost:8080/auth`, and later your live address followed by `/auth`.

## 5. Run the app and make yourself super admin

```sh
npm install
npm run dev
```

1. Open http://localhost:8080 and sign in with Google.
2. In a second terminal, run:

```sh
npm run grant-admin -- emil@solarsurge.com.au
```

3. Refresh the page. The **Admin** area is now available. Add other staff and set their roles from **Admin → People**.

## Notes

- **Restart after editing `.env`.** Stop `npm run dev` and start it again so it picks up the change.
- **Existing users and data stay in the old project.** Accounts, coaching forms, recordings and edited module content from the old Lovable-hosted project don't carry over.
- **Saved database types** are in `src/integrations/supabase/types.ts`. They already match the migrations. If you change the database later, regenerate them with `npx supabase gen types typescript --linked > src/integrations/supabase/types.ts`.
