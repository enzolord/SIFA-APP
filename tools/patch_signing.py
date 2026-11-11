"""Signe l'APK de release avec la clé fixe tools/sifa-test.jks (clé de TEST).

Sans cela, Flutter signe avec une clé de debug régénérée à chaque compilation CI,
et l'empreinte SHA-1 (nécessaire à la connexion Google) change à chaque fois.
Pour Google Play : remplacer par une vraie clé de publication stockée en secret GitHub.
"""
import os, re, sys

kts = 'android/app/build.gradle.kts'
groovy = 'android/app/build.gradle'
path = kts if os.path.exists(kts) else groovy
src = open(path, encoding='utf-8').read()
if 'sifaTest' in src:
    print('déjà patché'); sys.exit(0)

if path.endswith('.kts'):
    block = '''    signingConfigs {
        create("sifaTest") {
            storeFile = file(System.getenv("SIFA_KS") ?: "../../tools/sifa-test.jks")
            storePassword = "sifa-test-2026"
            keyAlias = "sifa"
            keyPassword = "sifa-test-2026"
        }
    }
'''
    src = re.sub(r'signingConfig\s*=\s*signingConfigs\.getByName\("debug"\)',
                 'signingConfig = signingConfigs.getByName("sifaTest")', src)
else:
    block = '''    signingConfigs {
        sifaTest {
            storeFile file(System.getenv("SIFA_KS") ?: "../../tools/sifa-test.jks")
            storePassword "sifa-test-2026"
            keyAlias "sifa"
            keyPassword "sifa-test-2026"
        }
    }
'''
    src = re.sub(r'signingConfig\s+signingConfigs\.debug', 'signingConfig signingConfigs.sifaTest', src)

m = re.search(r'^\s*buildTypes\s*\{', src, re.M)
if not m or 'sifaTest' not in src:
    print('ERREUR: structure gradle inattendue', file=sys.stderr); sys.exit(1)
src = src[:m.start()] + block + src[m.start():]
open(path, 'w', encoding='utf-8').write(src)
print('signature fixe appliquée à', path)
