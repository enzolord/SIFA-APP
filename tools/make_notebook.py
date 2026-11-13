#!/usr/bin/env python3
"""Fabrique le carnet Colab tools/SIFA_entrainement_v2.ipynb (le script d'entraînement est dedans)."""
import json, pathlib

ici = pathlib.Path(__file__).parent
script = (ici / 'entrainer_sifa_v2.py').read_text(encoding='utf-8')

def md(t): return {"cell_type": "markdown", "metadata": {}, "source": t.strip('\n').splitlines(keepends=True)}
def code(t): return {"cell_type": "code", "metadata": {}, "execution_count": None, "outputs": [],
                     "source": t.strip('\n').splitlines(keepends=True)}

cells = [
md("""
# SIFA — entraînement du modèle v2

Ce carnet fait tout : il récupère les photos, entraîne le modèle et range le résultat dans votre Google Drive.

**Avant de commencer**
1. Menu **Exécution > Modifier le type d'exécution > GPU T4**, puis **Enregistrer**.
2. Mettez `sifa_pret.zip` dans votre Google Drive (n'importe quel dossier). Sinon le carnet vous demandera de le choisir sur votre ordinateur.
3. Facultatif mais très utile : créez dans Drive un dossier **`sifa_autres`** avec 100 à 300 photos prises dans vos poulaillers qui ne montrent **pas** de fiente (sol, litière propre, aliment, mangeoire, main, seau, feuilles, objets verts, rouges ou blancs).

Lancez ensuite les cellules **une par une, de haut en bas**. Avec le GPU, l'entraînement dure environ 15 à 30 minutes.
"""),
md("## 1. Vérifier le GPU"),
code("""
import tensorflow as tf
gpus = tf.config.list_physical_devices('GPU')
print('GPU :', gpus[0].name if gpus else 'AUCUN')
assert gpus, "Pas de GPU. Menu Exécution > Modifier le type d'exécution > GPU T4, puis relancez cette cellule."
"""),
md("## 2. Brancher Google Drive et récupérer les photos"),
code("""
from google.colab import drive, files
import glob, os, shutil, zipfile

drive.mount('/content/drive')
ZIP = '/content/sifa_pret.zip'

def complet(p):
    \"\"\"Vrai si le zip existe, n'est pas tronqué et contient bien les photos.\"\"\"
    try:
        with zipfile.ZipFile(p) as z:
            return sum(n.lower().endswith('.jpg') for n in z.namelist()) > 5000
    except Exception:
        return False

if not complet(ZIP):
    sur_drive = [p for p in glob.glob('/content/drive/MyDrive/**/sifa_pret*.zip', recursive=True) if complet(p)]
    if sur_drive:
        shutil.copy(sur_drive[0], ZIP)
        print('Copié depuis Drive :', sur_drive[0])
    else:
        print("sifa_pret.zip introuvable (ou incomplet) dans Drive.")
        print("Choisissez le fichier sur votre ordinateur et gardez cet onglet ouvert pendant l'envoi.")
        for nom in files.upload():
            shutil.move(nom, ZIP)

assert complet(ZIP), "Le fichier est incomplet (envoi coupé). Supprimez-le et recommencez cette cellule."
if not os.path.exists('/content/drive/MyDrive/sifa_pret.zip'):
    shutil.copy(ZIP, '/content/drive/MyDrive/sifa_pret.zip')   # pour ne plus avoir à le renvoyer
    print('Copie de sécurité rangée dans Drive.')

shutil.rmtree('/content/sifa_pret', ignore_errors=True)
zipfile.ZipFile(ZIP).extractall('/content/sifa_pret')
DONNEES = sorted(os.path.dirname(p) for p in glob.glob('/content/sifa_pret/**/train', recursive=True))[0]
print('Photos prêtes dans', DONNEES, '->', sorted(os.listdir(DONNEES)))
"""),
md("## 3. Écrire le script d'entraînement"),
code("%%writefile /content/entrainer_sifa_v2.py\n" + script),
md("## 4. Vos photos « pas une fiente » (facultatif)"),
code("""
PERSO = '/content/drive/MyDrive/sifa_autres'
os.makedirs(PERSO, exist_ok=True)
n = sum(f.lower().endswith(('.jpg', '.jpeg', '.png', '.webp')) for _, _, fs in os.walk(PERSO) for f in fs)
print(n, "photo(s) dans le dossier Drive « sifa_autres ».")
if n == 0:
    print("Vous pouvez continuer sans, mais le modèle refusera mieux les mauvaises photos si vous en ajoutez.")
"""),
md("## 4b. Photos terrain des éleveurs (facultatif)\n\nAprès avoir étiqueté des photos dans l'administration SIFA (onglet « Jeu de données »), téléchargez le ZIP, envoyez-le ici et décompressez-le."),
code("""
TERRAIN = ''
zips = sorted(glob.glob('/content/sifa_terrain_*.zip'))
if not zips:
    print("Pas de ZIP terrain : l'entraînement se fera sans. Pour en ajouter, envoyez le ZIP via le dossier à gauche (Fichiers).")
else:
    shutil.rmtree('/content/terrain', ignore_errors=True)
    zipfile.ZipFile(zips[-1]).extractall('/content/terrain')
    TERRAIN = sorted(os.path.dirname(p) for p in glob.glob('/content/terrain/**/train', recursive=True))[0]
    print('Photos terrain prêtes dans', TERRAIN)
"""),
md("## 5. Entraîner (15 à 30 minutes avec le GPU)\n\nLe résultat est écrit directement dans Drive, dossier `sifa_sortie_v2` : rien n'est perdu si la session se coupe à la fin."),
code("""
SORTIE = '/content/drive/MyDrive/sifa_sortie_v2'
!python /content/entrainer_sifa_v2.py --donnees "{DONNEES}" --sortie "{SORTIE}" --perso "{PERSO}" {("--terrain " + chr(34) + TERRAIN + chr(34)) if TERRAIN else ""}
"""),
md("## 6. Lire le rapport et télécharger les 3 fichiers à envoyer"),
code("""
print(open(f'{SORTIE}/rapport_test.txt', encoding='utf-8').read())
for f in ('sifa_fp16.tflite', 'labels.json', 'rapport_test.txt'):
    files.download(f'{SORTIE}/{f}')
"""),
]

nb = {"cells": cells, "nbformat": 4, "nbformat_minor": 5,
      "metadata": {"accelerator": "GPU", "colab": {"provenance": [], "gpuType": "T4"},
                   "kernelspec": {"name": "python3", "display_name": "Python 3"},
                   "language_info": {"name": "python"}}}
out = ici / 'SIFA_entrainement_v2.ipynb'
out.write_text(json.dumps(nb, ensure_ascii=False, indent=1), encoding='utf-8')
print('écrit', out, f'({out.stat().st_size // 1024} Ko, {len(cells)} cellules)')
