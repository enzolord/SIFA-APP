-- Bucket public en lecture pour les modèles d'analyse SIFA.
-- Seul le propriétaire du projet peut y déposer des fichiers (via le tableau de bord).
insert into storage.buckets (id, name, public)
values ('modeles', 'modeles', true)
on conflict (id) do update set public = true;
