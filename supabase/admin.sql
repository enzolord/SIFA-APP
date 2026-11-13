-- Administration SIFA : seuls les comptes listés dans « admins » peuvent publier un modèle.
create table if not exists public.admins (user_id uuid primary key references auth.users(id) on delete cascade);
alter table public.admins enable row level security;

create or replace function public.is_admin() returns boolean
language sql security definer set search_path = public as
$$ select exists (select 1 from public.admins where user_id = auth.uid()) $$;
revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to authenticated;

-- Écriture dans le bucket « modeles » réservée aux admins (la lecture reste publique).
drop policy if exists "modeles_admin_ecriture" on storage.objects;
create policy "modeles_admin_ecriture" on storage.objects for all to authenticated
  using (bucket_id = 'modeles' and public.is_admin())
  with check (bucket_id = 'modeles' and public.is_admin());

-- À FAIRE UNE FOIS, après avoir créé votre compte (Authentication > Users > Add user) :
--   insert into public.admins select id from auth.users where email = 'VOTRE_EMAIL';
