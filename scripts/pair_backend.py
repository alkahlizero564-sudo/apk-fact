"""Supabase backend for a pair of connected apps (customer + admin).

Everything for pair <p> is prefixed with <p>_ so several pairs can share one Supabase project:
  <p>_profiles        one row per user, role 'customer' | 'admin' (users cannot change their own role)
  <p>_admins          emails that become admins when they sign up (or right away if they already exist)
  <p>_device_tokens   FCM tokens, registered with rpc <p>_register_device(token, app)
  <p>_notifications   a row = a notification to one user (to_user) or to every admin / customer (to_role);
                      with push enabled, a trigger calls the <p>-push Edge Function which sends it with FCM
  <p>_is_admin()      helper for row level security policies
Business tables are designed by the AI on top of these (see pair.py).
"""
import json
import os
import re
import time
import urllib.error
import urllib.request

API = "https://api.supabase.com/v1"


def prefix_of(base):
    return re.sub(r"[^a-z0-9_]", "_", base.lower())


def admin_pin_sql(p):
    """Admin PIN support (scripts/templates/admin_pin.sql); APK Fact reads the same file to set a PIN."""
    from pathlib import Path
    return (Path(__file__).resolve().parent / "templates" / "admin_pin.sql").read_text(encoding="utf-8").replace("{p}", p)


def set_pin_sql(p, pin):
    if not re.fullmatch(r"[A-Za-z0-9]{4,12}", pin or ""):
        raise ValueError("PIN: 4-12 letters or digits")
    return (f"insert into public.{p}_admin_secret (id, pin_hash) values (1, extensions.crypt('{pin}', extensions.gen_salt('bf'))) "
            f"on conflict (id) do update set pin_hash = excluded.pin_hash, updated_at = now();")


def base_sql(p, admin_emails=()):
    return _base_sql(p, admin_emails) + "\n" + admin_pin_sql(p)


def _base_sql(p, admin_emails=()):
    admins = ",".join("('" + e.strip().lower().replace("'", "''") + "')" for e in admin_emails if e.strip())
    return f"""
-- APK Fact pair "{p}": accounts, roles, devices and notifications
create table if not exists public.{p}_admins (email text primary key);
{"insert into public." + p + "_admins(email) values " + admins + " on conflict do nothing;" if admins else ""}

create table if not exists public.{p}_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  full_name text,
  phone text,
  role text not null default 'customer' check (role in ('customer', 'admin')),
  created_at timestamptz not null default now()
);

create or replace function public.{p}_is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.{p}_profiles where id = auth.uid() and role = 'admin')
$$;

create or replace function public.{p}_role_for(mail text) returns text
language sql stable security definer set search_path = public as $$
  select case when exists (select 1 from public.{p}_admins a where lower(a.email) = lower(mail)) then 'admin' else 'customer' end
$$;

create or replace function public.{p}_handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  -- Name and phone come from the sign-up (user metadata); phone accounts have a hidden email (…@phone.<p>.app).
  insert into public.{p}_profiles (id, email, full_name, phone, role)
  values (new.id,
          case when new.email like '%@phone.%.app' then null else new.email end,
          nullif(new.raw_user_meta_data->>'full_name', ''),
          nullif(new.raw_user_meta_data->>'phone', ''),
          public.{p}_role_for(new.email))
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists {p}_on_auth_user_created on auth.users;
create trigger {p}_on_auth_user_created after insert on auth.users
  for each row execute function public.{p}_handle_new_user();

-- Users that already exist in this project (e.g. the admin) get a profile now.
insert into public.{p}_profiles (id, email, role)
  select u.id, u.email, public.{p}_role_for(u.email) from auth.users u
  on conflict (id) do update set role = case when excluded.role = 'admin' then 'admin' else public.{p}_profiles.role end;

-- Nobody can make themselves admin; only an admin can change roles.
create or replace function public.{p}_protect_role() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.role is distinct from old.role and not public.{p}_is_admin() and auth.uid() is not null then
    raise exception 'only an admin can change roles';
  end if;
  return new;
end $$;
drop trigger if exists {p}_protect_role on public.{p}_profiles;
create trigger {p}_protect_role before update on public.{p}_profiles
  for each row execute function public.{p}_protect_role();

alter table public.{p}_profiles enable row level security;
alter table public.{p}_admins enable row level security;
drop policy if exists "{p} profiles read" on public.{p}_profiles;
create policy "{p} profiles read" on public.{p}_profiles for select to authenticated
  using (id = auth.uid() or public.{p}_is_admin());
drop policy if exists "{p} profiles update" on public.{p}_profiles;
create policy "{p} profiles update" on public.{p}_profiles for update to authenticated
  using (id = auth.uid() or public.{p}_is_admin());
drop policy if exists "{p} admins manage" on public.{p}_admins;
create policy "{p} admins manage" on public.{p}_admins for all to authenticated
  using (public.{p}_is_admin()) with check (public.{p}_is_admin());

create table if not exists public.{p}_device_tokens (
  token text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  app text not null check (app in ('customer', 'admin')),
  platform text not null default 'android',
  updated_at timestamptz not null default now()
);
alter table public.{p}_device_tokens enable row level security;
drop policy if exists "{p} own devices" on public.{p}_device_tokens;
create policy "{p} own devices" on public.{p}_device_tokens for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- A device can move between accounts, so registration goes through this function.
create or replace function public.{p}_register_device(device_token text, app_name text, device_platform text default 'android')
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'sign in first'; end if;
  insert into public.{p}_device_tokens (token, user_id, app, platform, updated_at)
  values (device_token, auth.uid(), app_name, device_platform, now())
  on conflict (token) do update set user_id = auth.uid(), app = excluded.app, platform = excluded.platform, updated_at = now();
end $$;

create table if not exists public.{p}_notifications (
  id bigint generated always as identity primary key,
  to_user uuid references auth.users(id) on delete cascade,
  to_role text check (to_role in ('customer', 'admin')),
  title text not null,
  body text not null default '',
  data jsonb not null default '{{}}',
  created_by uuid default auth.uid(),
  read_at timestamptz,
  created_at timestamptz not null default now(),
  check (to_user is not null or to_role is not null)
);
alter table public.{p}_notifications enable row level security;
drop policy if exists "{p} notifications read" on public.{p}_notifications;
create policy "{p} notifications read" on public.{p}_notifications for select to authenticated
  using (to_user = auth.uid() or created_by = auth.uid()
         or (to_role = 'admin' and public.{p}_is_admin()) or to_role = 'customer');
-- Customers can notify the admins (or themselves); admins can notify anyone.
drop policy if exists "{p} notifications send" on public.{p}_notifications;
create policy "{p} notifications send" on public.{p}_notifications for insert to authenticated
  with check (created_by = auth.uid() and (to_role = 'admin' or to_user = auth.uid() or public.{p}_is_admin()));
drop policy if exists "{p} notifications mark read" on public.{p}_notifications;
create policy "{p} notifications mark read" on public.{p}_notifications for update to authenticated
  using (to_user = auth.uid() or (to_role = 'admin' and public.{p}_is_admin()));

-- Files (product pictures, payment receipts, documents): Backend.uploadFile in the apps. Public read so an image URL
-- works in Image.network; signed-in users upload into their own folder (uploads/<uid>/...), admins anywhere.
insert into storage.buckets (id, name, public) values ('{p.replace('_', '-')}-files', '{p.replace('_', '-')}-files', true)
  on conflict (id) do update set public = true;
drop policy if exists "{p} files read" on storage.objects;
create policy "{p} files read" on storage.objects for select using (bucket_id = '{p.replace('_', '-')}-files');
drop policy if exists "{p} files upload" on storage.objects;
create policy "{p} files upload" on storage.objects for insert to authenticated
  with check (bucket_id = '{p.replace('_', '-')}-files'
              and ((storage.foldername(name))[2] = auth.uid()::text or public.{p}_is_admin()));
drop policy if exists "{p} files delete" on storage.objects;
create policy "{p} files delete" on storage.objects for delete to authenticated
  using (bucket_id = '{p.replace('_', '-')}-files' and (owner = auth.uid() or public.{p}_is_admin()));
"""


def push_sql(p, function_url, secret):
    """Calls the <p>-push Edge Function for every new notification (pg_net, asynchronous)."""
    url = function_url.replace("'", "''")
    sec = secret.replace("'", "''")
    return f"""
create table if not exists public.{p}_push_config (id int primary key default 1 check (id = 1), url text not null, secret text not null);
alter table public.{p}_push_config enable row level security;
revoke all on public.{p}_push_config from anon, authenticated;
insert into public.{p}_push_config (id, url, secret) values (1, '{url}', '{sec}')
  on conflict (id) do update set url = excluded.url, secret = excluded.secret;

create or replace function public.{p}_push_notify() returns trigger
language plpgsql security definer set search_path = public, extensions as $$
declare c record;
begin
  select url, secret into c from public.{p}_push_config where id = 1;
  if c.url is not null then
    perform net.http_post(
      url := c.url,
      body := jsonb_build_object('record', to_jsonb(new)),
      headers := jsonb_build_object('Content-Type', 'application/json', 'x-push-secret', c.secret)
    );
  end if;
  return new;
end $$;
drop trigger if exists {p}_push on public.{p}_notifications;
create trigger {p}_push after insert on public.{p}_notifications
  for each row execute function public.{p}_push_notify();
"""


def realtime_sql(tables):
    """Add tables to Supabase Realtime (live updates in the apps) when the publication exists."""
    stmts = "".join(
        f"  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = '{t}') "
        f"then execute 'alter publication supabase_realtime add table public.{t}'; end if;\n"
        for t in tables
    )
    return f"do $$ begin\n if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then\n{stmts} end if;\nend $$;"


# ---- Supabase Management API ----

def _request(method, path, token, body=None):
    req = urllib.request.Request(
        API + path,
        data=json.dumps(body).encode() if body is not None else None,
        method=method,
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json",
                 "User-Agent": "apk-fact"},
    )
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            raw = r.read().decode()
            return json.loads(raw) if raw.strip() else None
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"Supabase {method} {path} -> {e.code}: {e.read().decode()[:600]}")


def set_function_secrets(ref, token, values):
    """Edge Function secrets through the Management API (the CLI now asks for a confirmation it cannot get in CI)."""
    return _request("POST", f"/projects/{ref}/secrets", token, [{"name": k, "value": v} for k, v in values.items()])


# Right after a Supabase project is created (or resumed), its database is not ready for a moment and the
# Management API's SQL endpoint answers with one of these; Supabase itself says to wait and retry. The SQL we
# run is idempotent (create ... if not exists / or replace / drop ... if exists), so retrying is safe.
_SQL_NOT_READY = (
    "28p01",                        # password authentication failed for user "postgres"
    "password authentication failed",
    "wait a moment",
    "tenant or user not found",
    "502 bad gateway",
    "503",
    "upstream connect error",
    "max client connections",
    "the database is not",
    "database is starting",
)


# When a project is paused/inactive, the SQL endpoint keeps returning 28P01 forever (not a transient wait),
# so retrying is pointless; the owner must resume it. These are the Management API statuses that mean "not usable".
_PAUSED_STATES = ("INACTIVE", "PAUSING", "PAUSE_FAILED", "GOING_DOWN", "REMOVED", "RESTORING", "RESTORE_FAILED",
                  "INIT_FAILED", "UPGRADING", "RESTARTING")


def project_status(ref, token):
    """The Management API status of a project (ACTIVE_HEALTHY, INACTIVE/paused, COMING_UP, …); '' if unknown."""
    try:
        info = _request("GET", f"/projects/{ref}", token)
        return str((info or {}).get("status", "")).upper()
    except Exception:
        return ""


def _paused_error(ref, status):
    nice = status or "paused or unavailable"
    return RuntimeError(
        f"Supabase project {ref} is {nice}: its database refuses the connection (password authentication failed "
        "for user 'postgres'). Open the Supabase dashboard for this project and press Restore/Resume until its "
        "status is Active (ACTIVE_HEALTHY), then create the pair again. In APK Fact you can also pick a different, "
        "active Supabase project. This is a project-state issue on Supabase, not a problem with your app or data."
    )


def run_sql(ref, token, sql):
    last = None
    for attempt in range(7):  # ~ up to 3 minutes while a newly created project's database comes up
        try:
            return _request("POST", f"/projects/{ref}/database/query", token, {"query": sql})
        except RuntimeError as e:
            msg = str(e).lower()
            if not any(s in msg for s in _SQL_NOT_READY):
                raise  # a real SQL/API error: fail fast with the real message
            last = e
            # Tell a paused project apart from a just-provisioning one so we don't wait 3 minutes for nothing.
            if attempt == 0:
                status = project_status(ref, token)
                if status in _PAUSED_STATES:
                    raise _paused_error(ref, status)
            wait = min(5 * (2 ** attempt), 40)
            print(f"Supabase database not ready yet ({str(e)[:140]}); waiting {wait}s and retrying…", flush=True)
            time.sleep(wait)
    # Still failing after the retries: almost always a paused/inactive project the owner must resume.
    raise _paused_error(ref, project_status(ref, token))


def pick_client_key(keys):
    """The key the apps send as `apikey`: the legacy anon key, or a publishable key (sb_publishable_...)
    on projects that only have the new API keys. Never a secret / service_role key."""
    keys = [k for k in keys or [] if isinstance(k, dict) and k.get("api_key")]
    for test in (
        lambda k: k.get("name") == "anon" and k.get("type") in (None, "legacy"),
        lambda k: k.get("type") == "publishable",
        lambda k: str(k.get("api_key", "")).startswith("sb_publishable_"),
    ):
        found = next((k["api_key"] for k in keys if test(k)), None)
        if found:
            return found
    return None


def _key_list(resp):
    if isinstance(resp, dict):  # tolerate a wrapped list
        resp = resp.get("api_keys") or resp.get("keys") or resp.get("data") or []
    return resp if isinstance(resp, list) else []


def _describe(keys):
    return ", ".join(f"{k.get('name')}({k.get('type') or 'legacy'}{'' if k.get('api_key') else ', no value'})"
                     for k in keys if isinstance(k, dict)) or "none"


def api_keys(ref, token):
    url = f"https://{ref}.supabase.co"
    override = os.environ.get("SUPABASE_PUBLISHABLE_KEY", "").strip()
    if override and not override.startswith("sb_secret_"):
        return url, override
    seen = []
    for path in (f"/projects/{ref}/api-keys", f"/projects/{ref}/api-keys?reveal=true"):
        try:
            keys = _key_list(_request("GET", path, token))
        except RuntimeError as e:
            print(f"Reading API keys failed: {e}", flush=True)
            continue
        seen = seen or keys
        anon = pick_client_key(keys)
        if anon:
            return url, anon
    print(f"API keys of the project: {_describe(seen)}. Creating a publishable key for the apps.", flush=True)
    try:
        created = _request("POST", f"/projects/{ref}/api-keys", token,
                           {"type": "publishable", "name": "apk_fact", "description": "Used by APK Fact apps"})
        anon = pick_client_key(_key_list(created) or [created])
        if not anon:
            anon = pick_client_key(_key_list(_request("GET", f"/projects/{ref}/api-keys", token)))
        if anon:
            return url, anon
    except RuntimeError as e:
        print(f"Creating a publishable key failed: {e}", flush=True)
    raise RuntimeError(
        f"Could not get a publishable/anon key for project {ref} (keys seen: {_describe(seen)}). "
        "Check that the Supabase access token belongs to the account that owns this project and that the "
        "project ref is right, or open Supabase > Project Settings > API Keys and create a publishable key."
    )


def service_key(ref, token):
    """The project's server key (legacy service_role JWT, or a secret sb_secret_... key), for admin-only calls such
    as creating the temporary QA account. Never put it in an app. None when it cannot be read."""
    try:
        keys = _key_list(_request("GET", f"/projects/{ref}/api-keys?reveal=true", token))
    except RuntimeError:
        return None
    keys = [k for k in keys if isinstance(k, dict) and k.get("api_key")]
    for test in (lambda k: k.get("name") == "service_role",
                 lambda k: k.get("type") == "secret" or str(k.get("api_key", "")).startswith("sb_secret_")):
        found = next((k["api_key"] for k in keys if test(k)), None)
        if found:
            return found
    return None


def configure_email_otp(ref, token, smtp=None, autoconfirm=False):
    """Email sign-in: the 6-digit code is in both the sign-up and the sign-in email. autoconfirm: sign-ups with
    a password need no code (only when no app of the pair confirms emails with a code)."""
    code_mail = (
        '<div dir="rtl" style="font-family:Tahoma,Arial,sans-serif;text-align:center;padding:24px">'
        "<h2>رمز الدخول</h2><p>استخدم الرمز ده لتسجيل الدخول:</p>"
        '<p style="font-size:32px;letter-spacing:8px;font-weight:bold">{{ .Token }}</p>'
        "<p style=\"color:#888\">الرمز صالح لمدة 10 دقائق. لو ما طلبته، تجاهل الرسالة.</p></div>"
    )
    body = {
        "external_email_enabled": True,
        "mailer_autoconfirm": bool(autoconfirm),
        "mailer_otp_length": 6,
        "mailer_otp_exp": 600,
        "mailer_subjects_magic_link": "رمز الدخول",
        "mailer_templates_magic_link_content": code_mail,
        "mailer_subjects_confirmation": "رمز تأكيد حسابك",
        "mailer_templates_confirmation_content": code_mail,
    }
    if smtp and smtp.get("host"):
        body.update({
            "smtp_host": smtp["host"],
            "smtp_port": str(smtp.get("port", "587")),
            "smtp_user": smtp.get("user", ""),
            # Gmail shows app passwords in groups of 4 ("abcd efgh ..."); the spaces are not part of it.
            "smtp_pass": str(smtp.get("pass", "")).replace(" ", "") if "gmail" in smtp["host"] else smtp.get("pass", ""),
            "smtp_admin_email": smtp.get("from", smtp.get("user", "")),
            "smtp_sender_name": smtp.get("name", "APK Fact"),
            # Supabase allows only a couple of emails per hour by default; real customers need more.
            "rate_limit_email_sent": 100,
        })
    return _request("PATCH", f"/projects/{ref}/config/auth", token, body)


def configure_anonymous(ref, token):
    """Apps without a sign-in screen: each install gets an invisible (anonymous) account, so row level
    security still keeps every customer's data apart."""
    return _request("PATCH", f"/projects/{ref}/config/auth", token, {"external_anonymous_users_enabled": True})


def env_smtp():
    raw = os.environ.get("SUPABASE_SMTP", "").strip()
    return json.loads(raw) if raw else None
