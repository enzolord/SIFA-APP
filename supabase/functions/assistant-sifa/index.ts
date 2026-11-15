// Fonction Supabase « assistant-sifa »
// Assistant vocal de SIFA : répond, en français ou en anglais, aux questions d'un éleveur
// de poulets (santé, élevage, prévention). L'application lit la réponse à voix haute.
//
// Secrets (les mêmes que verifier-fiente) : GEMINI_API_KEY, GEMINI_MODEL (facultatif),
// SIFA_APP_KEY (facultatif : si défini, les appels sans cette clé sont refusés).
// Déploiement : supabase functions deploy assistant-sifa --no-verify-jwt
// Entrée : POST { "lang": "fr"|"en", "messages": [{ "role": "user"|"model", "text": "..." }] }
// Sortie : { "reponse": "..." }

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

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ erreur: "POST attendu" }, 405);

  const appKey = Deno.env.get("SIFA_APP_KEY");
  if (appKey && req.headers.get("apikey") !== appKey) return json({ erreur: "clé d'application invalide" }, 401);
  const geminiKey = Deno.env.get("GEMINI_API_KEY");
  if (!geminiKey) return json({ erreur: "GEMINI_API_KEY manquante" }, 503);

  let lang = "fr";
  let turns: { role: string; text: string }[] = [];
  try {
    const b = await req.json();
    lang = b.lang === "en" ? "en" : "fr";
    if (Array.isArray(b.messages)) {
      turns = b.messages
        .filter((m: { role?: unknown; text?: unknown }) =>
          (m?.role === "user" || m?.role === "model") && typeof m?.text === "string" && m.text.trim() !== ""
        )
        .slice(-MAX_TURNS)
        .map((m: { role: string; text: string }) => ({ role: m.role, text: m.text.slice(0, MAX_CHARS) }));
    }
  } catch (_) {
    return json({ erreur: "JSON invalide" }, 400);
  }
  // Gemini veut une conversation qui commence et finit par un message de l'éleveur.
  while (turns.length && turns[0].role !== "user") turns.shift();
  if (!turns.length || turns[turns.length - 1].role !== "user") return json({ erreur: "message manquant" }, 400);

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
    const call = (b: unknown) => fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json", "x-goog-api-key": geminiKey },
        body: JSON.stringify(b),
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
      return json({ erreur: "gemini", statut: r.status }, r.status === 429 ? 429 : 502);
    }
    const data = await r.json();
    const text = String(data?.candidates?.[0]?.content?.parts?.[0]?.text ?? "").trim();
    if (!text) return json({ erreur: "réponse vide" }, 502);
    return json({ reponse: text.slice(0, 1500) });
  } catch (e) {
    console.error("assistant-sifa", e);
    return json({ erreur: "indisponible" }, 502);
  }
});
