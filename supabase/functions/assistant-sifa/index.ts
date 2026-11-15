// Fonction Supabase « assistant-sifa »
// Assistant vocal de SIFA : répond, en français ou en anglais, aux questions d'un éleveur
// de poulets (santé, élevage, prévention). L'application lit la réponse à voix haute.
//
// Secrets (les mêmes que verifier-fiente) : GEMINI_API_KEY, GEMINI_MODEL (facultatif),
// SIFA_APP_KEY (facultatif : si défini, les appels sans cette clé sont refusés).
// Déploiement : supabase functions deploy assistant-sifa --no-verify-jwt
//
// Quota : compté ICI, dans la base (table assistant_questions), jamais sur le téléphone, donc il
// résiste à la réinstallation. Compte Google si l'éleveur est connecté, sinon identifiant d'appareil.
//   { "action": "statut", "appareil": "<id>" }
//        -> { "limite": 10|null, "utilise": 3, "restant": 7|null, "gratuit": true, "offre": null }
//   { "lang": "fr"|"en", "appareil": "<id>", "messages": [{ "role": "user"|"model", "text": "..." }] }
//        -> { "reponse": "...", "limite": ..., "restant": ... }   ou 402 { "erreur": "quota", ... }

import { createClient } from "npm:@supabase/supabase-js@2";
import { assistantLimit, windowStart, type AssistantCfg } from "../_shared/quotas.ts";

const admin = () => createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });

const MODEL = Deno.env.get("GEMINI_MODEL") ?? "gemini-flash-lite-latest";
const MAX_TURNS = 10;
const MAX_CHARS = 600;

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const RULES = [
  "Tu es l'assistant vocal de SIFA, une application qui aide les éleveurs de poulets de chair et de poules pondeuses au Cameroun.",
  "Tu réponds uniquement aux questions sur les poulets et poules : santé, maladies (coccidiose, salmonellose, Newcastle), alimentation, eau, bâtiment, hygiène, vaccination, ponte, gestion de l'élevage. Pour tout autre sujet, dis poliment que tu ne peux aider que pour l'élevage de poulets.",
  "Ta réponse est lue à voix haute : phrases courtes et simples, 3 à 5 phrases au maximum, sans liste, sans tableau, sans symbole, sans emoji, sans markdown.",
  "Dis « poulets », jamais « oiseaux ». Utilise des conseils pratiques adaptés à un petit élevage africain.",
  "Tu ne remplaces pas un vétérinaire. Ne donne jamais de dose de médicament ni d'antibiotique à utiliser. En cas de signes graves (mortalité soudaine, troubles nerveux, cou tordu, diarrhée sanglante, plusieurs poulets malades), de suspicion de maladie de Newcastle ou de doute, dis d'isoler les sujets malades et d'appeler un vétérinaire sans attendre.",
  "Ne pose pas de diagnostic ferme à partir d'une description : dis ce qui est possible et ce qu'il faut vérifier. Si tu ne sais pas, dis-le.",
  "Si la personne demande un conseil sur une photo de fiente, invite-la à utiliser le bouton Scanner de SIFA.",
].join(" ");

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json; charset=utf-8" },
  });
}

async function sha256(text: string): Promise<string> {
  const d = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return Array.from(new Uint8Array(d)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ erreur: "POST attendu" }, 405);

  const appKey = Deno.env.get("SIFA_APP_KEY");
  if (appKey && req.headers.get("apikey") !== appKey) return json({ erreur: "clé d'application invalide" }, 401);
  const geminiKey = Deno.env.get("GEMINI_API_KEY");
  if (!geminiKey) return json({ erreur: "GEMINI_API_KEY manquante" }, 503);

  let b: Record<string, unknown>;
  try {
    b = await req.json();
  } catch (_) {
    return json({ erreur: "JSON invalide" }, 400);
  }

  // Qui pose la question : le compte Google (jeton de l'éleveur) et/ou l'appareil (identifiant haché).
  const jwt = (req.headers.get("authorization") ?? "").replace(/^Bearer\s+/i, "");
  const anon = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, { auth: { persistSession: false } });
  const { data: u } = jwt ? await anon.auth.getUser(jwt) : { data: null };
  const userId: string | null = u?.user?.id ?? null;
  const rawDev = typeof b.appareil === "string" ? b.appareil.trim() : "";
  const appareil = rawDev.length >= 8 && rawDev.length <= 200 ? "d:" + (await sha256("sifa:" + rawDev)).slice(0, 40) : null;
  if (!userId && !appareil) return json({ erreur: "appareil inconnu" }, 400);

  // Formule en cours et quota qui en découle.
  const db = admin();
  let offre: string | null = null;
  let depuis: string | null = null;
  if (userId) {
    const { data: ab } = await db.from("abonnements").select("formule,debut,fin").eq("user_id", userId).eq("statut", "actif")
      .order("debut", { ascending: false }).limit(1);
    const a = ab?.[0];
    if (a && (!a.fin || new Date(a.fin) > new Date())) {
      offre = a.formule;
      depuis = windowStart(new Date(a.debut), new Date()).toISOString();
    }
  }
  const { data: tc } = await db.from("contenu").select("valeur").eq("cle", "tarifs").maybeSingle();
  const cfg = ((tc?.valeur ?? {}) as { assistant?: AssistantCfg }).assistant ?? {};
  const { limite, gratuit } = assistantLimit(offre, cfg);
  const compte = { p_user: userId, p_appareil: appareil, p_gratuit: gratuit, p_depuis: gratuit ? null : depuis };

  if (b.action === "statut") {
    const { data: n, error } = await db.rpc("assistant_utilise", compte);
    if (error) { console.error("assistant_utilise", error.message); return json({ erreur: "indisponible" }, 502); }
    const utilise = Number(n) || 0;
    return json({ limite, utilise, restant: limite === null ? null : Math.max(0, limite - utilise), gratuit, offre });
  }

  const lang = b.lang === "en" ? "en" : "fr";
  let turns: { role: string; text: string }[] = [];
  if (Array.isArray(b.messages)) {
    turns = b.messages
      .filter((m: { role?: unknown; text?: unknown }) =>
        (m?.role === "user" || m?.role === "model") && typeof m?.text === "string" && m.text.trim() !== ""
      )
      .slice(-MAX_TURNS)
      .map((m: { role: string; text: string }) => ({ role: m.role, text: m.text.slice(0, MAX_CHARS) }));
  }
  // Gemini veut une conversation qui commence et finit par un message de l'éleveur.
  while (turns.length && turns[0].role !== "user") turns.shift();
  if (!turns.length || turns[turns.length - 1].role !== "user") return json({ erreur: "message manquant" }, 400);

  // On réserve la question AVANT d'appeler Gemini (verrou en base), et on la rend si Gemini échoue.
  const { data: r0, error: e0 } = await db.rpc("assistant_reserver", { ...compte, p_limite: limite ?? 2147483647 });
  const res = Array.isArray(r0) ? r0[0] : r0;
  if (e0 || !res) { console.error("assistant_reserver", e0?.message); return json({ erreur: "indisponible" }, 502); }
  if (res.question_id === null) {
    return json({ erreur: "quota", limite, utilise: Number(res.utilise) || 0, restant: 0, gratuit, offre }, 402);
  }
  const qid = res.question_id as number;
  const utilise = Number(res.utilise) || 0;
  const rendre = () => db.rpc("assistant_rendre", { p_id: qid }).then(() => {}, () => {});

  const langRule = lang === "en"
    ? "Answer in English, whatever language the question is in."
    : "Réponds en français, quelle que soit la langue de la question.";

  const body = {
    systemInstruction: { parts: [{ text: `${RULES} ${langRule}` }] },
    contents: turns.map((m) => ({ role: m.role, parts: [{ text: m.text }] })),
    generationConfig: {
      temperature: 0.4,
      maxOutputTokens: 400,
      thinkingConfig: { thinkingBudget: 0 },
    },
  };

  try {
    const call = (g: unknown) => fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json", "x-goog-api-key": geminiKey },
        body: JSON.stringify(g),
        signal: AbortSignal.timeout(15_000),
      },
    );
    let r = await call(body);
    if (r.status === 400) { // modèle sans option de réflexion : on réessaie sans
      delete (body.generationConfig as Record<string, unknown>).thinkingConfig;
      r = await call(body);
    }
    if (!r.ok) {
      console.error("Gemini", r.status, (await r.text()).slice(0, 300));
      await rendre();
      return json({ erreur: "gemini", statut: r.status }, r.status === 429 ? 429 : 502);
    }
    const data = await r.json();
    const text = String(data?.candidates?.[0]?.content?.parts?.[0]?.text ?? "").trim();
    if (!text) { await rendre(); return json({ erreur: "réponse vide" }, 502); }
    return json({
      reponse: text.slice(0, 1500),
      limite,
      utilise,
      restant: limite === null ? null : Math.max(0, limite - utilise),
      gratuit,
      offre,
    });
  } catch (e) {
    console.error("assistant-sifa", e);
    await rendre();
    return json({ erreur: "indisponible" }, 502);
  }
});
