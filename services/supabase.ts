import * as SecureStore from "expo-secure-store";

const MGMT_API = "https://api.supabase.com/v1";

async function getManagementToken(): Promise<string> {
  const token = await SecureStore.getItemAsync("SUPABASE_ACCESS_TOKEN");
  if (!token) {
    throw new Error(
      "SUPABASE_ACCESS_TOKEN missing. This is a Personal Access Token from supabase.com → Account → Access Tokens (different from the project's anon key)."
    );
  }
  return token;
}

async function getProjectRef(): Promise<string> {
  const ref = await SecureStore.getItemAsync("SUPABASE_PROJECT_REF");
  if (!ref) {
    throw new Error("SUPABASE_PROJECT_REF missing. Set it in Settings (the short ID in your project URL).");
  }
  return ref;
}

export async function testSupabaseConnection(): Promise<{ name: string; status: string }> {
  const token = await getManagementToken();
  const ref = await getProjectRef();

  const res = await fetch(`${MGMT_API}/projects/${ref}`, {
    headers: { Authorization: `Bearer ${token}` },
  });

  if (!res.ok) {
    throw new Error(`Supabase auth failed (${res.status}): ${await res.text()}`);
  }
  const data = await res.json();
  return { name: data.name, status: data.status };
}

export async function runSql(query: string): Promise<any> {
  const token = await getManagementToken();
  const ref = await getProjectRef();

  const res = await fetch(`${MGMT_API}/projects/${ref}/database/query`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ query }),
  });

  if (!res.ok) {
    throw new Error(`SQL execution failed (${res.status}): ${await res.text()}`);
  }
  return res.json();
}

export async function getSupabaseClientInfo(): Promise<{ url: string; anonKey: string }> {
  const token = await getManagementToken();
  const ref = await getProjectRef();

  const res = await fetch(`${MGMT_API}/projects/${ref}/api-keys`, {
    headers: { Authorization: `Bearer ${token}` },
  });

  if (!res.ok) {
    throw new Error(`Fetching Supabase keys failed (${res.status}): ${await res.text()}`);
  }

  const keys = await res.json();
  const list: any[] = Array.isArray(keys) ? keys : [];
  const key =
    list.find((k) => k.name === "anon") ||
    list.find((k) => k.type === "publishable");

  if (!key || !key.api_key) {
    throw new Error("ما لقيت مفتاح anon أو publishable للمشروع.");
  }

  return { url: `https://${ref}.supabase.co`, anonKey: key.api_key };
}
