-- ============================================================
-- SIFA : administration en temps réel
-- À exécuter une fois dans Supabase > SQL Editor (peut être relancé sans danger).
-- Prérequis : le schéma principal (sifa_supabase.sql) déjà exécuté ; il définit is_admin()
-- (un administrateur est un profil dont role = 'admin').
-- ============================================================

-- 1. Profils : e-mail et nom récupérés du compte Google (pour le tableau de bord)
alter table public.profiles add column if not exists email text;

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, telephone, email, nom)
  values (new.id, new.phone, new.email,
          coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name', ''))
  on conflict (id) do nothing;
  return new;
end $$;

update public.profiles p
   set email = u.email,
       nom = coalesce(nullif(p.nom, ''), u.raw_user_meta_data->>'full_name', u.raw_user_meta_data->>'name', '')
  from auth.users u where u.id = p.id;

-- 2. Contenu modifiable à distance (annonce, maintenance, formules, fiches maladies...)
create table if not exists public.contenu (
  cle    text primary key,
  valeur jsonb not null default '{}'::jsonb,
  maj    timestamptz not null default now()
);
alter table public.contenu enable row level security;
drop policy if exists contenu_lecture on public.contenu;
create policy contenu_lecture on public.contenu for select using (true);
drop policy if exists contenu_admin on public.contenu;
create policy contenu_admin on public.contenu for all using (public.is_admin()) with check (public.is_admin());

create or replace function public.touch_contenu() returns trigger language plpgsql as
$$ begin new.maj = now(); return new; end $$;
drop trigger if exists contenu_maj on public.contenu;
create trigger contenu_maj before update on public.contenu for each row execute function public.touch_contenu();

-- 3. Temps réel : l'application est prévenue dès qu'une ligne change
do $$ begin
  begin alter publication supabase_realtime add table public.contenu;     exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.pharmacies;  exception when duplicate_object then null; end;
end $$;

-- 4. Statistiques du tableau de bord (réservées aux administrateurs)
create or replace function public.stats_admin() returns jsonb
language plpgsql security definer set search_path = public as $$
declare r jsonb;
begin
  if not public.is_admin() then raise exception 'Réservé aux administrateurs'; end if;
  select jsonb_build_object(
    'utilisateurs',       (select count(*) from profiles),
    'utilisateurs_7j',    (select count(*) from profiles where created_at > now() - interval '7 days'),
    'analyses',           (select count(*) from analyses),
    'analyses_7j',        (select count(*) from analyses where cree_le > now() - interval '7 days'),
    'par_maladie_30j',    coalesce((select jsonb_object_agg(maladie, n) from
                            (select maladie, count(*) n from analyses where cree_le > now() - interval '30 days' group by maladie) x), '{}'::jsonb),
    'publications',       (select count(*) from publications),
    'masquees',           (select count(*) from publications where masque) + (select count(*) from commentaires where masque),
    'signalements',       (select count(*) from signalements),
    'abonnements_actifs', (select count(*) from abonnements where statut = 'actif' and formule <> 'essai'),
    'pharmacies_actives', (select count(*) from pharmacies where actif)
  ) into r;
  return r;
end $$;
revoke all on function public.stats_admin() from public, anon;
grant execute on function public.stats_admin() to authenticated;

-- 5. Modèles d'analyse : lecture publique, écriture administrateurs
insert into storage.buckets (id, name, public) values ('modeles', 'modeles', true)
on conflict (id) do update set public = true;
drop policy if exists "modeles_admin_ecriture" on storage.objects;
create policy "modeles_admin_ecriture" on storage.objects for all to authenticated
  using (bucket_id = 'modeles' and public.is_admin())
  with check (bucket_id = 'modeles' and public.is_admin());

-- 6. Contenu de départ (ne remplace rien d'existant)
insert into public.contenu (cle, valeur) values
  ('annonce',     '{"actif": false, "niveau": "info", "titre": {"fr": "", "en": ""}, "texte": {"fr": "", "en": ""}}'),
  ('maintenance', '{"actif": false, "message": {"fr": "SIFA est en maintenance. Revenez dans quelques minutes.", "en": "SIFA is under maintenance. Please come back in a few minutes."}}'),
  ('formules',    '{"mensuelle": {"prix": "", "desc": {"fr": "Analyses illimitées pour une ferme", "en": "Unlimited analyses for one farm"}},
                    "annuelle":  {"prix": "", "desc": {"fr": "Même formule, moins chère par mois", "en": "Same plan, cheaper per month"}},
                    "paiement":  {"fr": "", "en": ""}}'),
  ('fiches',      '{}')
on conflict (cle) do nothing;

-- ============================================================
-- À FAIRE UNE FOIS : vous rendre administrateur
--   1. Authentication > Users > Add user (e-mail + mot de passe) pour l'outil web,
--      ou connectez-vous une fois à l'app avec Google.
--   2. Puis exécutez, avec votre e-mail :
--      update public.profiles set role = 'admin'
--       where id = (select id from auth.users where email = 'VOTRE_EMAIL');
-- ============================================================
