"""Entraîne le modèle SIFA v2 (EfficientNet-B0) et l'exporte en TFLite.

Nouveautés par rapport à la v1 :
  1. Une 5e classe « Autre » : tout ce qui n'est pas une fiente (objets, fleurs, sol, couleurs
     unies...). Sans elle, le modèle est obligé de répondre une maladie pour n'importe quelle image,
     par exemple « Newcastle » devant un objet vert.
  2. Des images « couleur seule » fabriquées à partir des fientes (très floues, aplats, dégradés) et
     rangées dans « Autre » : le modèle apprend qu'une couleur sans forme de fiente ne suffit pas.
  3. Une légère variation de teinte et de saturation, pour supporter les différences entre téléphones.
  4. Un contrôle du GPU au démarrage : sur processeur seul l'entraînement prend plusieurs heures.

À lancer sur Google Colab (Exécution > Modifier le type d'exécution > GPU T4) :

  !python entrainer_sifa_v2.py --donnees /content/sifa_pret/sifa_pret --sortie /content/drive/MyDrive/sifa_sortie_v2

Options utiles :
  --perso DOSSIER   vos propres photos « pas une fiente » (sol, litière, aliment, mains, objets) :
                    très recommandé, 100 à 300 photos prises dans vos poulaillers.
  --negatifs aucun  entraîne sans classe « Autre » (comme la v1).
  --cpu             autorise l'entraînement sans GPU (très lent).
"""
import argparse, glob, json, os, random, shutil, sys, tarfile, time
import numpy as np
import tensorflow as tf
from tensorflow import keras
from PIL import Image, ImageFilter
from sklearn.metrics import classification_report, confusion_matrix, f1_score

ap = argparse.ArgumentParser()
ap.add_argument('--donnees', required=True, help='dossier contenant train/ val/ test/')
ap.add_argument('--sortie', default='sortie')
ap.add_argument('--taille', type=int, default=224)
ap.add_argument('--lot', type=int, default=32)
ap.add_argument('--epoques1', type=int, default=8)
ap.add_argument('--epoques2', type=int, default=15)
ap.add_argument('--negatifs', default='auto', help="auto (téléchargement), aucun, ou un dossier d'images")
ap.add_argument('--perso', default='', help='dossier de vos photos « pas une fiente » (facultatif)')
ap.add_argument('--poids', default='imagenet', help='imagenet, ou aucun (tests seulement)')
ap.add_argument('--cpu', action='store_true', help="autoriser l'entraînement sans GPU")
a = ap.parse_args()

AUTRE = 'Autre'
EXT = ('.jpg', '.jpeg', '.png', '.webp', '.bmp')
os.makedirs(a.sortie, exist_ok=True)
keras.utils.set_random_seed(42)
rnd = random.Random(42)
S = (a.taille, a.taille)

for split in ('train', 'val', 'test'):
    if not os.path.isdir(os.path.join(a.donnees, split)):
        sys.exit(f"Dossier introuvable : {os.path.join(a.donnees, split)}\n"
                 "Vérifiez --donnees : il doit contenir train/, val/ et test/.")

# ───────────────────────── 1. GPU ─────────────────────────
gpus = tf.config.list_physical_devices('GPU')
if gpus:
    print('GPU détecté :', gpus[0].name)
elif a.cpu:
    print('ATTENTION : pas de GPU. Comptez plusieurs heures.')
else:
    sys.exit("\nAUCUN GPU DÉTECTÉ : l'entraînement prendrait plusieurs heures.\n"
             "Dans Colab : Exécution > Modifier le type d'exécution > Accélérateur matériel : GPU T4,\n"
             "puis relancez TOUTES les cellules (la session repart de zéro).\n"
             "Pour entraîner quand même sans GPU, ajoutez --cpu.\n")

# ───────────────────────── 2. Classe « Autre » ─────────────────────────
def images_de(dossier):
    return sorted(p for p in glob.glob(os.path.join(dossier, '**', '*'), recursive=True)
                  if p.lower().endswith(EXT))

def enregistrer(im, split, nom):
    d = os.path.join(a.donnees, split, AUTRE)
    os.makedirs(d, exist_ok=True)
    im.convert('RGB').resize((256, 256), Image.BILINEAR).save(os.path.join(d, nom + '.jpg'), 'JPEG', quality=90)

def repartir(i, n):
    """70 % train, 15 % val, 15 % test."""
    r = i / max(n, 1)
    return 'train' if r < 0.70 else ('val' if r < 0.85 else 'test')

def ajouter(source, images, maxi):
    """images : liste de chemins ou d'images PIL. Renvoie le nombre d'images ajoutées."""
    images = list(images)
    rnd.shuffle(images)
    images = images[:maxi]
    n = 0
    for i, x in enumerate(images):
        try:
            im = Image.open(x) if isinstance(x, str) else x
            enregistrer(im, repartir(i, len(images)), f'{source}_{i:05d}')
            n += 1
        except Exception as e:  # image illisible : on passe
            if n == 0 and i > 20:
                print('  illisible :', e)
    return n

def fleurs():
    url = 'https://storage.googleapis.com/download.tensorflow.org/example_images/flower_photos.tgz'
    chemin = keras.utils.get_file('flower_photos.tgz', url)
    dest = os.path.join(os.path.dirname(chemin), 'flower_photos_sifa')
    if not os.path.isdir(dest):
        with tarfile.open(chemin) as t:
            t.extractall(dest)
    return images_de(dest)

def objets():
    (x, _), _ = keras.datasets.cifar100.load_data()
    idx = np.random.RandomState(42).permutation(len(x))[:800]
    return [Image.fromarray(x[i]).resize((256, 256), Image.BICUBIC) for i in idx]

def couleur_seule(chemins, n):
    """Images qui gardent les COULEURS d'une fiente mais plus sa forme."""
    out = []
    for i in range(n):
        im = Image.open(rnd.choice(chemins)).convert('RGB').resize((256, 256))
        mode = i % 3
        if mode == 0:      # très flou : taches de couleur
            petit = rnd.choice([4, 6, 8])
            out.append(im.resize((petit, petit), Image.BILINEAR).resize((256, 256), Image.BICUBIC)
                       .filter(ImageFilter.GaussianBlur(6)))
        elif mode == 1:    # aplat d'une couleur de l'image + grain léger
            px = np.asarray(im.resize((8, 8)), np.float32).reshape(-1, 3)
            c = px[rnd.randrange(len(px))]
            bruit = np.random.RandomState(i).normal(0, rnd.choice([2, 6, 12]), (256, 256, 3))
            out.append(Image.fromarray(np.clip(c + bruit, 0, 255).astype(np.uint8)))
        else:              # dégradé entre deux couleurs de l'image
            px = np.asarray(im.resize((8, 8)), np.float32).reshape(-1, 3)
            c1, c2 = px[rnd.randrange(len(px))], px[rnd.randrange(len(px))]
            t = np.linspace(0, 1, 256, dtype=np.float32)[None, :, None]
            g = np.repeat(c1 * (1 - t) + c2 * t, 256, axis=0)
            if rnd.random() < 0.5:
                g = g.transpose(1, 0, 2)
            out.append(Image.fromarray(np.clip(g, 0, 255).astype(np.uint8)))
    return out

marque = os.path.join(a.donnees, '.autre_v2')
if a.negatifs.lower() == 'aucun':
    print('Classe « Autre » désactivée (--negatifs aucun).')
elif os.path.exists(marque):
    print('Classe « Autre » déjà préparée.')
else:
    for split in ('train', 'val', 'test'):
        shutil.rmtree(os.path.join(a.donnees, split, AUTRE), ignore_errors=True)
    fientes = [p for p in images_de(os.path.join(a.donnees, 'train'))]
    bilan = {}
    if a.negatifs.lower() == 'auto':
        for nom, fonction, maxi in (('fleurs', fleurs, 700), ('objets', objets, 500)):
            try:
                bilan[nom] = ajouter(nom, fonction(), maxi)
            except Exception as e:
                print(f'  Téléchargement « {nom} » impossible ({type(e).__name__}) : on continue sans.')
    else:
        bilan['dossier'] = ajouter('dossier', images_de(a.negatifs), 2000)
    if a.perso:
        bilan['perso'] = ajouter('perso', images_de(a.perso), 5000)
        if bilan['perso'] == 0:
            print(f'  Aucune image trouvée dans --perso {a.perso}')
    bilan['couleur_seule'] = ajouter('couleur', couleur_seule(fientes, 600), 600)
    open(marque, 'w').write(json.dumps(bilan))
    print('Classe « Autre » créée :', bilan)
    if sum(v for k, v in bilan.items() if k != 'couleur_seule') == 0:
        print("ATTENTION : aucune vraie photo « pas une fiente » (ni téléchargement, ni --perso).\n"
              "Le modèle saura refuser les couleurs unies, mais mal les objets. Ajoutez --perso DOSSIER.")

# ───────────────────────── 3. Données ─────────────────────────
def charger(split):
    return keras.utils.image_dataset_from_directory(
        os.path.join(a.donnees, split), image_size=S, batch_size=None,
        label_mode='int', shuffle=False)

brut = {s: charger(s) for s in ('train', 'val', 'test')}
classes = brut['train'].class_names
assert brut['val'].class_names == classes and brut['test'].class_names == classes, \
    'Les dossiers train/val/test ne contiennent pas les mêmes classes.'
print('Classes :', classes)

comptes = np.array([len(images_de(os.path.join(a.donnees, 'train', c))) for c in classes], float)
poids = {i: float(comptes.sum() / (len(classes) * n)) for i, n in enumerate(comptes)}
print('Images train par classe :', dict(zip(classes, comptes.astype(int))))

AUTO = tf.data.AUTOTUNE
def en_cache(ds):   # décodage une seule fois, gardé en mémoire en 8 bits
    return ds.map(lambda x, y: (tf.cast(x, tf.uint8), y), num_parallel_calls=AUTO).cache()

geometrie = keras.Sequential([
    keras.layers.RandomFlip('horizontal_and_vertical'),
    keras.layers.RandomRotation(0.25),
    keras.layers.RandomZoom(0.15),
    keras.layers.RandomBrightness(0.25, value_range=(0, 255)),
    keras.layers.RandomContrast(0.25),
])

def teinte(x, y):
    # Petite variation : la couleur reste un indice de maladie, mais chaque téléphone la rend autrement.
    x = tf.cast(x, tf.float32) / 255.0
    x = tf.image.random_hue(x, 0.02)
    x = tf.image.random_saturation(x, 0.8, 1.25)
    return tf.clip_by_value(x, 0.0, 1.0) * 255.0, y

n_train = int(comptes.sum())
train = (en_cache(brut['train']).shuffle(n_train, seed=42, reshuffle_each_iteration=True)
         .map(teinte, num_parallel_calls=AUTO).batch(a.lot)
         .map(lambda x, y: (geometrie(x, training=True), y), num_parallel_calls=AUTO).prefetch(AUTO))
val = en_cache(brut['val']).map(lambda x, y: (tf.cast(x, tf.float32), y)).batch(a.lot).prefetch(AUTO)
test = en_cache(brut['test']).map(lambda x, y: (tf.cast(x, tf.float32), y)).batch(a.lot).prefetch(AUTO)

# ───────────────────────── 4. Modèle ─────────────────────────
base = keras.applications.EfficientNetB0(
    include_top=False, weights=None if a.poids == 'aucun' else 'imagenet', input_shape=S + (3,))
base.trainable = False
entree = keras.Input(S + (3,))
x = base(entree, training=False)          # EfficientNet normalise ses entrées en interne (0-255)
x = keras.layers.GlobalAveragePooling2D()(x)
x = keras.layers.Dropout(0.3)(x)
sortie = keras.layers.Dense(len(classes), activation='softmax')(x)
modele = keras.Model(entree, sortie)

def compiler(lr):
    modele.compile(optimizer=keras.optimizers.Adam(lr),
                   loss='sparse_categorical_crossentropy', metrics=['accuracy'])

def arret():
    return keras.callbacks.EarlyStopping(monitor='val_loss', patience=4, restore_best_weights=True)

t0 = time.time()
print('\n--- Phase 1 : entraînement de la tête ---')
compiler(1e-3)
modele.fit(train, validation_data=val, epochs=a.epoques1, class_weight=poids, callbacks=[arret()])

print('\n--- Phase 2 : affinage des dernières couches ---')
base.trainable = True
for couche in base.layers[:-40]:
    couche.trainable = False
for couche in base.layers:
    if isinstance(couche, keras.layers.BatchNormalization):
        couche.trainable = False
compiler(1e-5)
modele.fit(train, validation_data=val, epochs=a.epoques2, class_weight=poids, callbacks=[arret()])
modele.save(os.path.join(a.sortie, 'sifa.keras'))
print(f'Entraînement : {(time.time() - t0) / 60:.0f} min')

# ───────────────────────── 5. Évaluation sur le TEST (jamais vu) ─────────────────────────
y = np.concatenate([lab.numpy() for _, lab in test])
proba = modele.predict(test, verbose=0)
p_keras = np.argmax(proba, axis=1)
acc_keras = float((p_keras == y).mean())
f1 = f1_score(y, p_keras, average='macro')
etiquettes = list(range(len(classes)))
texte = (f"MODÈLE SIFA v2 — classes : {classes}\n"
         f"EXACTITUDE TEST (Keras) : {acc_keras:.4f} | F1 macro : {f1:.4f}\n\n"
         f"{classification_report(y, p_keras, labels=etiquettes, target_names=classes, digits=3, zero_division=0)}\n"
         f"Matrice de confusion (lignes = vrai, colonnes = prédit) :\n{classes}\n"
         f"{confusion_matrix(y, p_keras, labels=etiquettes)}\n")

if AUTRE in classes:
    k = classes.index(AUTRE)
    autres, fientes_t = y == k, y != k
    texte += (f"\nREFUS DES PHOTOS QUI NE SONT PAS DES FIENTES\n"
              f"  non-fientes correctement refusées : {100 * (p_keras[autres] == k).mean():.1f} % "
              f"({int(autres.sum())} images)\n"
              f"  vraies fientes refusées à tort    : {100 * (p_keras[fientes_t] == k).mean():.1f} % "
              f"({int(fientes_t.sum())} images)\n"
              f"  exactitude entre maladies (fientes seules) : "
              f"{100 * (p_keras[fientes_t] == y[fientes_t]).mean():.1f} %\n")
print(texte)

# ───────────────────────── 6. Export TFLite ─────────────────────────
try:
    from ai_edge_litert.interpreter import Interpreter
except ImportError:
    Interpreter = tf.lite.Interpreter

def exporter(nom, float16):
    conv = tf.lite.TFLiteConverter.from_keras_model(modele)
    conv.optimizations = [tf.lite.Optimize.DEFAULT]
    if float16:
        conv.target_spec.supported_types = [tf.float16]
    chemin = os.path.join(a.sortie, nom)
    with open(chemin, 'wb') as f:
        f.write(conv.convert())
    return chemin

def evaluer_tflite(chemin):
    it = Interpreter(model_path=chemin)
    it.allocate_tensors()
    ent, sor = it.get_input_details()[0], it.get_output_details()[0]
    preds, t1 = [], time.time()
    for lot, _ in test:
        for img in lot.numpy():
            it.set_tensor(ent['index'], img[None].astype(np.float32))
            it.invoke()
            preds.append(int(np.argmax(it.get_tensor(sor['index']))))
    return float((np.array(preds) == y).mean()), (time.time() - t1) * 1000 / len(preds)

texte += '\nEXPORT TFLITE\n'
for nom, f16 in [('sifa_fp16.tflite', True), ('sifa_dyn.tflite', False)]:
    chemin = exporter(nom, f16)
    acc, ms = evaluer_tflite(chemin)
    texte += (f"{nom}: {os.path.getsize(chemin) / 1e6:.1f} Mo | exactitude test {acc:.4f} "
              f"(écart {100 * (acc - acc_keras):+.2f} pt) | {ms:.0f} ms/image (Colab, pas téléphone)\n")
print(texte)

with open(os.path.join(a.sortie, 'rapport_test.txt'), 'w', encoding='utf-8') as f:
    f.write(texte)
with open(os.path.join(a.sortie, 'labels.json'), 'w', encoding='utf-8') as f:
    json.dump(classes, f, ensure_ascii=False)
print('Fichiers dans', a.sortie, ': sifa_fp16.tflite, labels.json, rapport_test.txt (+ sifa_dyn.tflite, sifa.keras)')
print('À envoyer pour mettre à jour l\'application : sifa_fp16.tflite, labels.json, rapport_test.txt')
