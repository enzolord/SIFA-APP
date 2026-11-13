// Fonction Supabase « verifier-fiente »
// Demande à Gemini si une photo montre bien une fiente de poulet, pour écarter les images
// sans rapport (stylo, ordinateur, route...) avant l'analyse.
//
// La clé Gemini reste ici, côté serveur : elle n'est jamais dans l'application.
// Secrets à définir dans Supabase (Edge Functions > Secrets) :
//   GEMINI_API_KEY   (obligatoire)  clé créée sur aistudio.google.com
//   GEMINI_MODEL     (facultatif)   modèle à utiliser, par défaut gemini-flash-lite-latest
//   SIFA_APP_KEY     (facultatif)   clé « publishable » du projet : si elle est définie,
//                                   les appels sans cette clé sont refusés
//
// Déploiement : désactiver « Verify JWT » pour cette fonction (l'app n'a pas toujours de session).
// Entrée  : POST { "image": "<JPEG en base64>" }
// Sortie  : { "fiente": true|false, "confiance": 0..1, "objet_fr": "...", "objet_en": "..." }

const MODEL = Deno.env.get("GEMINI_MODEL") ?? "gemini-flash-lite-latest";
const MAX_BASE64 = 2_000_000; // environ 1,5 Mo d'image

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const PROMPT =
  "Tu es le contrôle d'entrée d'une application vétérinaire pour éleveurs de poulets. " +
  "Regarde l'image et dis si son sujet principal est une fiente (excrément) de poulet ou de poule, " +
  "fraîche ou sèche, posée sur un sol, une litière, une planche, un papier ou une main. " +
  "Réponds fiente=true seulement si une fiente d'oiseau est clairement visible. " +
  "Pour tout le reste (objet, personne, animal entier, aliment, écran, route, mur, plante, image floue ou vide), " +
  "réponds fiente=false. " +
  "confiance : ta certitude entre 0 et 1. " +
  "objet_fr et objet_en : ce que montre l'image, en 2 à 4 mots, en français puis en anglais.";

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

  let image: unknown;
  try {
    image = (await req.json()).image;
  } catch (_) {
    return json({ erreur: "JSON invalide" }, 400);
  }
  if (typeof image !== "string" || image.length < 100) return json({ erreur: "image manquante" }, 400);
  if (image.length > MAX_BASE64) return json({ erreur: "image trop lourde" }, 413);

  const body = {
    contents: [{ parts: [{ text: PROMPT }, { inline_data: { mime_type: "image/jpeg", data: image } }] }],
    generationConfig: {
      temperature: 0,
      maxOutputTokens: 512,
      thinkingConfig: { thinkingBudget: 0 }, // pas de « réflexion » : réponse bien plus rapide
      responseMimeType: "application/json",
      responseSchema: {
        type: "OBJECT",
        properties: {
          fiente: { type: "BOOLEAN" },
          confiance: { type: "NUMBER" },
          objet_fr: { type: "STRING" },
          objet_en: { type: "STRING" },
        },
        required: ["fiente", "confiance", "objet_fr", "objet_en"],
      },
    },
  };

  try {
    const call = (b: unknown) => fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json", "x-goog-api-key": geminiKey },
        body: JSON.stringify(b),
        signal: AbortSignal.timeout(12_000),
      },
    );
    let r = await call(body);
    if (r.status === 400) { // modèle sans option de réflexion : on réessaie sans
      delete (body.generationConfig as Record<string, unknown>).thinkingConfig;
      r = await call(body);
    }
    if (!r.ok) {
      // 429 = quota gratuit dépassé : l'application se rabat sur le modèle embarqué.
      const detail = (await r.text()).slice(0, 300);
      console.error("Gemini", r.status, detail);
      return json({ erreur: "gemini", statut: r.status }, r.status === 429 ? 429 : 502);
    }
    const data = await r.json();
    const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;
    const out = JSON.parse(text);
    return json({
      fiente: out.fiente === true,
      confiance: Math.max(0, Math.min(1, Number(out.confiance) || 0)),
      objet_fr: String(out.objet_fr ?? "").slice(0, 60),
      objet_en: String(out.objet_en ?? "").slice(0, 60),
    });
  } catch (e) {
    console.error("verifier-fiente", e);
    return json({ erreur: "indisponible" }, 502);
  }
});
