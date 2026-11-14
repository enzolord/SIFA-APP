# Paiement par Campay : mise en route

1. **Compte Campay** : créez une application sur campay.net (mode démo pour tester, puis production).
   Dans l'application Campay, notez le *username* et le *password* (API Credentials).
2. **Secrets Supabase** (Edge Functions > Secrets) :
   - `CAMPAY_USERNAME`, `CAMPAY_PASSWORD`
   - `CAMPAY_BASE_URL` : `https://demo.campay.net/api` (test) ou `https://www.campay.net/api` (production)
3. **Base de données** : relancez `supabase/admin.sql` (section 6d : table `paiements`).
4. **Déployer les deux fonctions** (sans « Verify JWT » : le jeton de l'éleveur est vérifié dans le code) :
   ```
   supabase functions deploy campay-paiement --no-verify-jwt --project-ref VOTRE_REF
   supabase functions deploy campay-webhook  --no-verify-jwt --project-ref VOTRE_REF
   ```
   Ou depuis le tableau de bord : Edge Functions > Deploy a new function, en collant `index.ts` de chaque dossier
   (les dossiers `_shared` doivent aussi être présents : préférez la ligne de commande).
5. **Webhook** : dans l'application Campay, adresse de rappel (GET ou POST) :
   `https://VOTRE_REF.supabase.co/functions/v1/campay-webhook`
6. **Test en démo** : numéros fournis par Campay, `237677777777` (MTN, réussi), `237677777770` (MTN, échec),
   `237699999999` (Orange, réussi), `237699999990` (Orange, échec).
7. **Passage en production** : changez `CAMPAY_BASE_URL` et les identifiants, rien à modifier dans l'application.

Sécurité : le prix est toujours recalculé sur le serveur (l'application n'envoie jamais de montant) ; l'appel du webhook
n'est jamais cru, on redemande l'état du paiement à Campay avant d'activer la formule.
