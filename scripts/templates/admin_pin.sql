-- APK Fact pair "{p}": admin PIN. Anyone signed in can become an admin with the secret PIN
-- (set from APK Fact > the app page > حسابات الإدارة). The PIN is stored hashed (bcrypt) in a
-- table that the apps cannot read; 5 wrong tries lock that account out for an hour.
create extension if not exists pgcrypto with schema extensions;

create table if not exists public.{p}_admin_secret (
  id int primary key default 1 check (id = 1),
  pin_hash text not null,
  updated_at timestamptz not null default now()
);
alter table public.{p}_admin_secret enable row level security;

create table if not exists public.{p}_admin_attempts (
  uid uuid primary key,
  fails int not null default 0,
  last_at timestamptz not null default now()
);
alter table public.{p}_admin_attempts enable row level security;

-- Roles can change only by an admin, by the server, or through {p}_claim_admin.
create or replace function public.{p}_protect_role() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.role is distinct from old.role and not public.{p}_is_admin() and auth.uid() is not null
     and coalesce(current_setting('apkfact.claim_admin', true), '') <> 'on' then
    raise exception 'only an admin can change roles';
  end if;
  return new;
end $$;

create or replace function public.{p}_claim_admin(pin text) returns boolean
language plpgsql security definer set search_path = public, extensions as $$
declare
  me uuid := auth.uid();
  h text;
  mail text;
  a public.{p}_admin_attempts;
begin
  if me is null or pin is null then return false; end if;
  select * into a from public.{p}_admin_attempts where uid = me;
  if found and a.fails >= 5 and a.last_at > now() - interval '1 hour' then return false; end if;
  select pin_hash into h from public.{p}_admin_secret where id = 1;
  if h is null or extensions.crypt(pin, h) <> h then
    insert into public.{p}_admin_attempts as t (uid, fails, last_at) values (me, 1, now())
      on conflict (uid) do update
      set fails = case when t.last_at < now() - interval '1 hour' then 1 else t.fails + 1 end, last_at = now();
    return false;
  end if;
  delete from public.{p}_admin_attempts where uid = me;
  select email into mail from auth.users where id = me;
  if mail is not null then
    insert into public.{p}_admins(email) values (lower(mail)) on conflict do nothing;
  end if;
  perform set_config('apkfact.claim_admin', 'on', true);
  insert into public.{p}_profiles (id, email, role) values (me, mail, 'admin')
    on conflict (id) do update set role = 'admin';
  perform set_config('apkfact.claim_admin', 'off', true);
  return true;
end $$;

revoke all on function public.{p}_claim_admin(text) from public, anon;
grant execute on function public.{p}_claim_admin(text) to authenticated;
