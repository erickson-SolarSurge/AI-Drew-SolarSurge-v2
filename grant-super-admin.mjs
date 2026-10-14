// Grants the super_admin role to an existing account.
// Usage: npm run grant-admin -- someone@example.com
// The person must have signed in (or signed up) at least once first.
// Needs SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY in .env.
import { createClient } from "@supabase/supabase-js";

const email = process.argv[2]?.trim().toLowerCase();
if (!email) {
  console.error("Usage: npm run grant-admin -- someone@example.com");
  process.exit(1);
}

const url = process.env.SUPABASE_URL;
const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
if (!url || !serviceKey) {
  console.error("SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set in .env");
  process.exit(1);
}

const db = createClient(url, serviceKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});

let user;
for (let page = 1; !user; page++) {
  const { data, error } = await db.auth.admin.listUsers({ page, perPage: 200 });
  if (error) throw error;
  user = data.users.find((u) => u.email?.toLowerCase() === email);
  if (data.users.length < 200) break;
}

if (!user) {
  console.error(`No account for ${email}. Sign in to the app once, then run this again.`);
  process.exit(1);
}

const { error } = await db
  .from("user_roles")
  .upsert({ user_id: user.id, role: "super_admin" }, { onConflict: "user_id,role" });
if (error) throw error;

console.log(`${email} is now a super admin.`);
