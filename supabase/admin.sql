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

-- 4. Mesure d'usage anonyme (envoyée par l'application ; jamais de photo, jamais de nom)
create table if not exists public.evenements (
  id          bigint generated always as identity primary key,
  cree_le     timestamptz not null default now(),
  appareil    text not null check (char_length(appareil) between 8 and 64),  -- identifiant aléatoire du téléphone
  user_id     uuid,
  nom         text not null check (char_length(nom) between 1 and 40),
  props       jsonb not null default '{}'::jsonb check (pg_column_size(props) < 2000),
  langue      text check (langue in ('fr','en')),
  version_app text check (char_length(version_app) <= 20)
);
create index if not exists evenements_date_idx   on public.evenements (cree_le);
create index if not exists evenements_nom_idx    on public.evenements (nom, cree_le);
create index if not exists evenements_app_idx    on public.evenements (appareil, cree_le);
alter table public.evenements enable row level security;
drop policy if exists evt_insert on public.evenements;
create policy evt_insert on public.evenements for insert to anon, authenticated
  with check (user_id is null or user_id = auth.uid());
drop policy if exists evt_admin on public.evenements;
create policy evt_admin on public.evenements for select using (public.is_admin());
drop policy if exists evt_admin_del on public.evenements;
create policy evt_admin_del on public.evenements for delete using (public.is_admin());

-- Statistiques du tableau de bord (réservées aux administrateurs). p_jours = longueur de la période.
create or replace function public.stats_admin(p_jours int default 30) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  j   int := greatest(1, least(coalesce(p_jours, 30), 365));
  dep timestamptz := now() - make_interval(days => j);
  tz  constant text := 'Africa/Douala';
  r   jsonb;
begin
  if not public.is_admin() then raise exception 'Réservé aux administrateurs'; end if;

  with
  ev as (select * from evenements where cree_le >= dep),
  premiere as (select appareil, min(cree_le) as vu from evenements group by appareil),
  jours as (select d::date as jour from generate_series((now() at time zone tz)::date - (j - 1), (now() at time zone tz)::date, interval '1 day') d),
  ev_jour as (select (cree_le at time zone tz)::date as jour, * from ev),
  serie as (
    select jo.jour,
      (select count(distinct appareil) from ev_jour e where e.jour = jo.jour) as actifs,
      (select count(*) from premiere pr where (pr.vu at time zone tz)::date = jo.jour) as nouveaux,
      (select count(*) from ev_jour e where e.jour = jo.jour and e.nom = 'analyse') as analyses,
      (select count(*) from ev_jour e where e.jour = jo.jour and e.nom = 'scan') as scans,
      (select count(*) from ev_jour e where e.jour = jo.jour and e.nom = 'retour') as retours,
      (select count(*) from ev_jour e where e.jour = jo.jour and e.nom = 'retour' and e.props->>'juste' = 'true') as justes
    from jours jo order by jo.jour
  ),
  an as (select * from ev where nom = 'analyse'),
  rt as (select * from ev where nom = 'retour'),
  -- retour joint à son analyse (même appareil, même référence)
  rt_an as (
    select r.props->>'juste' as juste, r.props->>'reelle' as reelle,
           a.props->>'maladie' as predit, a.props->>'fiabilite' as fiabilite,
           coalesce((a.props->>'questions')::int, 0) as questions
      from rt r left join an a on a.appareil = r.appareil and a.props->>'ref' = r.props->>'ref'
  )
  select jsonb_build_object(
    'periode_jours', j,
    'genere_le', now(),
    'utilisateurs', jsonb_build_object(
      'appareils_total',   (select count(*) from premiere),
      'actifs_periode',    (select count(distinct appareil) from ev),
      'actifs_24h',        (select count(distinct appareil) from evenements where cree_le >= now() - interval '1 day'),
      'actifs_7j',         (select count(distinct appareil) from evenements where cree_le >= now() - interval '7 days'),
      'actifs_30j',        (select count(distinct appareil) from evenements where cree_le >= now() - interval '30 days'),
      'nouveaux_periode',  (select count(*) from premiere where vu >= dep),
      'comptes',           (select count(*) from profiles),
      'comptes_periode',   (select count(*) from profiles where created_at >= dep),
      'par_role',          coalesce((select jsonb_object_agg(coalesce(role, 'inconnu'), n) from (select role, count(*) n from profiles group by role) x), '{}'::jsonb),
      'par_langue',        coalesce((select jsonb_object_agg(coalesce(langue, 'inconnu'), n) from (select langue, count(distinct appareil) n from ev where langue is not null group by langue) x), '{}'::jsonb),
      'par_version',       coalesce((select jsonb_object_agg(coalesce(version_app, 'inconnu'), n) from (select version_app, count(distinct appareil) n from ev where version_app is not null group by version_app) x), '{}'::jsonb),
      'par_type_elevage',  coalesce((select jsonb_object_agg(coalesce(type_elevage, 'inconnu'), n) from (select type_elevage, count(*) n from profiles group by type_elevage) x), '{}'::jsonb),
      'par_ville',         coalesce((select jsonb_agg(jsonb_build_object('ville', ville, 'n', n) order by n desc) from (select ville, count(*) n from profiles where ville <> '' group by ville order by n desc limit 10) x), '[]'::jsonb),
      'moyenne_ouvertures_par_actif', coalesce((select round(count(*)::numeric / nullif(count(distinct appareil), 0), 1) from ev where nom = 'ouverture'), 0)
    ),
    'serie', coalesce((select jsonb_agg(jsonb_build_object('jour', jour, 'actifs', actifs, 'nouveaux', nouveaux, 'analyses', analyses, 'scans', scans, 'retours', retours, 'justes', justes) order by jour) from serie), '[]'::jsonb),
    'retention', jsonb_build_object(
      'cohorte_1j', (select count(*) from premiere where vu < now() - interval '1 day' and vu >= now() - interval '60 days'),
      'revenus_1j', (select count(*) from premiere p where p.vu < now() - interval '1 day' and p.vu >= now() - interval '60 days'
                       and exists (select 1 from evenements e where e.appareil = p.appareil and e.cree_le >= p.vu + interval '1 day')),
      'cohorte_7j', (select count(*) from premiere where vu < now() - interval '7 days' and vu >= now() - interval '60 days'),
      'revenus_7j', (select count(*) from premiere p where p.vu < now() - interval '7 days' and p.vu >= now() - interval '60 days'
                       and exists (select 1 from evenements e where e.appareil = p.appareil and e.cree_le >= p.vu + interval '7 days'))
    ),
    'analyses', jsonb_build_object(
      'total',            (select count(*) from an),
      'appareils',        (select count(distinct appareil) from an),
      'par_maladie',      coalesce((select jsonb_object_agg(coalesce(m, 'inconnu'), n) from (select props->>'maladie' m, count(*) n from an group by 1) x), '{}'::jsonb),
      'par_fiabilite',    coalesce((select jsonb_object_agg(coalesce(m, 'inconnu'), n) from (select props->>'fiabilite' m, count(*) n from an group by 1) x), '{}'::jsonb),
      'alertes',          (select count(*) from an where props->>'alerte' = 'true'),
      'photo_seule',      (select count(*) from an where coalesce((props->>'questions')::int, 0) = 0),
      'confiance_moyenne',coalesce((select round(avg((props->>'confiance')::numeric), 3) from an), 0),
      'par_heure',        coalesce((select jsonb_agg(coalesce(n, 0) order by h) from (select h, (select count(*) from an where extract(hour from cree_le at time zone tz) = h) n from generate_series(0, 23) h) x), '[]'::jsonb)
    ),
    'qualite', jsonb_build_object(
      'retours',          (select count(*) from rt),
      'justes',           (select count(*) from rt where props->>'juste' = 'true'),
      'faux',             (select count(*) from rt where props->>'juste' = 'false'),
      'par_maladie',      coalesce((select jsonb_object_agg(coalesce(predit, 'inconnu'), jsonb_build_object('retours', n, 'justes', ok)) from
                            (select predit, count(*) n, count(*) filter (where juste = 'true') ok from rt_an where predit is not null group by predit) x), '{}'::jsonb),
      'par_fiabilite',    coalesce((select jsonb_object_agg(coalesce(fiabilite, 'inconnu'), jsonb_build_object('retours', n, 'justes', ok)) from
                            (select fiabilite, count(*) n, count(*) filter (where juste = 'true') ok from rt_an where fiabilite is not null group by fiabilite) x), '{}'::jsonb),
      'avec_questions',   (select jsonb_build_object('retours', count(*), 'justes', count(*) filter (where juste = 'true')) from rt_an where questions > 0),
      'photo_seule',      (select jsonb_build_object('retours', count(*), 'justes', count(*) filter (where juste = 'true')) from rt_an where questions = 0),
      'confusions',       coalesce((select jsonb_agg(jsonb_build_object('predit', predit, 'reel', reelle, 'n', n) order by n desc) from
                            (select predit, reelle, count(*) n from rt_an where juste = 'false' and predit is not null and reelle is not null group by 1, 2 order by n desc limit 12) x), '[]'::jsonb)
    ),
    'scans', jsonb_build_object(
      'total',      (select count(*) from ev where nom = 'scan'),
      'par_issue',  coalesce((select jsonb_object_agg(coalesce(m, 'inconnu'), n) from (select props->>'issue' m, count(*) n from ev where nom = 'scan' group by 1) x), '{}'::jsonb),
      'gemini',     coalesce((select jsonb_object_agg(coalesce(m, 'inconnu'), n) from (select coalesce(props->>'gemini', 'absent') m, count(*) n from ev where nom = 'scan' group by 1) x), '{}'::jsonb)
    ),
    'fonctionnalites', jsonb_build_object(
      'ecrans',   coalesce((select jsonb_agg(jsonb_build_object('nom', nom, 'vues', vues, 'appareils', appareils) order by vues desc) from
                    (select props->>'nom' as nom, count(*) vues, count(distinct appareil) appareils from ev where nom = 'ecran' group by 1 order by vues desc limit 40) x), '[]'::jsonb),
      'actions',  coalesce((select jsonb_agg(jsonb_build_object('nom', nom, 'n', n, 'appareils', appareils) order by n desc) from
                    (select props->>'nom' as nom, count(*) n, count(distinct appareil) appareils from ev where nom = 'action' group by 1 order by n desc limit 30) x), '[]'::jsonb)
    ),
    'entonnoir', jsonb_build_object(
      'ouverture', (select count(distinct appareil) from ev where nom = 'ouverture'),
      'scan',      (select count(distinct appareil) from ev where nom = 'scan'),
      'analyse',   (select count(distinct appareil) from ev where nom = 'analyse'),
      'retour',    (select count(distinct appareil) from ev where nom = 'retour')
    ),
    'communaute', jsonb_build_object(
      'publications',        (select count(*) from publications where cree_le >= dep),
      'publications_total',  (select count(*) from publications),
      'commentaires',        (select count(*) from commentaires where cree_le >= dep),
      'masques',             (select count(*) from publications where masque) + (select count(*) from commentaires where masque),
      'signalements',        (select count(*) from signalements),
      'signalements_periode',(select count(*) from signalements where cree_le >= dep),
      'auteurs_periode',     (select count(distinct auteur_id) from publications where cree_le >= dep)
    ),
    'abonnements', jsonb_build_object(
      'actifs',       coalesce((select jsonb_object_agg(coalesce(formule, 'inconnu'), n) from (select formule, count(*) n from abonnements where statut = 'actif' group by 1) x), '{}'::jsonb),
      'codes_crees',  (select count(*) from codes_activation),
      'codes_utilises',(select count(*) from codes_activation where utilise_par is not null),
      'codes_periode',(select count(*) from codes_activation where utilise_le >= dep)
    ),
    'pharmacies', jsonb_build_object(
      'actives',   (select count(*) from pharmacies where actif),
      'par_stock', coalesce((select jsonb_object_agg(coalesce(stock, 'inconnu'), n) from (select stock, count(*) n from pharmacies where actif group by 1) x), '{}'::jsonb),
      'perimees',  (select count(*) from pharmacies where actif and stock_maj < now() - interval '30 days')
    )
  ) into r
  from (select 1) _;
  return r;
end $$;
revoke all on function public.stats_admin(int) from public, anon;
grant execute on function public.stats_admin(int) to authenticated;
drop function if exists public.stats_admin();

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
