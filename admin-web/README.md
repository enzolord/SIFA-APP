# SIFA Admin (React, PWA, Vercel)

Outil d'administration de l'application SIFA : statistiques, qualité des réponses, photos des éleveurs
(étiquetage, ZIP pour ré-entraîner), contenu en direct, publication du modèle.

## Mise en ligne sur Vercel (5 minutes)

1. Dans Supabase (SQL Editor), exécutez `supabase/admin.sql` (une fois, ou à chaque mise à jour du fichier).
2. Supabase › Authentication › Users › *Add user* : créez votre compte (e-mail + mot de passe), puis dans le SQL Editor :
   `update public.profiles set role = 'admin' where id = (select id from auth.users where email = 'VOTRE_EMAIL');`
3. Sur vercel.com : **Add New › Project**, importez le dépôt `SIFA-APP`, puis réglez **Root Directory = `admin-web`**.
   Vercel détecte Vite tout seul (commande `npm run build`, dossier `dist`). Cliquez **Deploy**.
   Le dépôt peut rester privé.
4. Ouvrez l'adresse fournie (`https://votre-projet.vercel.app`) et connectez-vous.

Aucune variable n'est obligatoire : le projet Supabase de SIFA est déjà configuré. Pour en changer, ajoutez dans
Vercel › Settings › Environment Variables : `VITE_SUPABASE_URL` et `VITE_SUPABASE_KEY` (clé *publishable* uniquement,
jamais la clé secrète ni la clé Gemini).

## Installer comme une application (PWA)

- Ordinateur / Android (Chrome, Edge) : bouton **Installer l'application** dans la barre latérale, ou l'icône d'installation de la barre d'adresse.
- iPhone (Safari) : **Partager › Sur l'écran d'accueil**.

## En local

```
cd admin-web
npm install
npm run dev        # http://localhost:5173
npm run build      # produit dist/
```

`npm run fiches` régénère les fiches maladies intégrées (src/data/fichesBase.json) depuis `lib/data/knowledge.dart`.

## Sécurité

La clé publishable est publique par conception. Les droits viennent des règles RLS de Supabase : seuls les comptes dont
`profiles.role = 'admin'` peuvent lire les photos, les statistiques détaillées et modifier le contenu.
