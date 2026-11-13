#!/usr/bin/env python3
"""Prépare un nouveau modèle SIFA à publier (sans réinstaller l'application).

Usage :
  python tools/publier_modele.py sifa_fp16.tflite labels.json 2

  - sifa_fp16.tflite : le modèle sorti de l'entraînement Colab
  - labels.json      : les étiquettes dans le même ordre que la sortie du modèle
  - 2                : numéro de version, toujours plus grand que le précédent
                       (le modèle livré dans l'app est la version 1)

Crée le dossier a_publier/ avec le modèle renommé (sifa_v2.tflite) et manifest.json.
Envoyez ces DEUX fichiers dans Supabase > Storage > bucket « modeles » (remplacez
manifest.json). Les téléphones récupèrent le modèle au prochain lancement avec Internet,
le vérifient (taille + empreinte SHA-256) et reviennent au modèle livré s'il est illisible.
"""
import hashlib
import json
import pathlib
import shutil
import sys

if len(sys.argv) != 4:
    sys.exit(__doc__)
model, labels_path, version = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]), int(sys.argv[3])
labels = json.loads(labels_path.read_text(encoding="utf-8"))
assert isinstance(labels, list) and all(isinstance(x, str) for x in labels), "labels.json invalide"
low = " ".join(labels).lower()
for need in ("cocci", "salmo", "castle", "health"):
    if need not in low:
        sys.exit(f"Il manque une étiquette « {need} » : le modèle doit connaître les 4 résultats.")
data = model.read_bytes()
if not 100_000 < len(data) < 60_000_000:
    sys.exit("Taille de modèle inattendue.")
out = pathlib.Path("a_publier")
out.mkdir(exist_ok=True)
name = f"sifa_v{version}.tflite"
shutil.copy(model, out / name)
manifest = {
    "version": version,
    "fichier": name,
    "labels": labels,
    "sha256": hashlib.sha256(data).hexdigest(),
    "taille": len(data),
}
(out / "manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False), encoding="utf-8")
print(f"Prêt dans a_publier/ : {name} ({len(data)/1e6:.1f} Mo) + manifest.json (version {version})")
