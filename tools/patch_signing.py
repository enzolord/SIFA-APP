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
                 'signingConfig = signingConfigs.getByName("sifaTest")\n            isMinifyEnabled = false\n            isShrinkResources = false', src)
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
    src = re.sub(r'signingConfig\s+signingConfigs\.debug',
                 'signingConfig signingConfigs.sifaTest\n            minifyEnabled false\n            shrinkResources false', src)

m = re.search(r'^\s*buildTypes\s*\{', src, re.M)
if not m or 'sifaTest' not in src:
    print('ERREUR: structure gradle inattendue', file=sys.stderr); sys.exit(1)
src = src[:m.start()] + block + src[m.start():]
open(path, 'w', encoding='utf-8').write(src)
print('signature fixe appliquée à', path)

# --- tflite_flutter 0.11 : tensorflow-lite / -api / -gpu partagent le même namespace Android,
# ce qui fait échouer la fusion des manifestes. L'appli n'utilise que l'API native (FFI) :
# on n'a besoin ni de l'API Java ni du delegate GPU.
src = open(path, encoding='utf-8').read()
if 'tensorflow-lite-gpu' not in src:
    if path.endswith('.kts'):
        src += '''

configurations.all {
    exclude(group = "org.tensorflow", module = "tensorflow-lite-gpu")
    exclude(group = "org.tensorflow", module = "tensorflow-lite-api")
}
'''
    else:
        src += '''

configurations.all {
    exclude group: "org.tensorflow", module: "tensorflow-lite-gpu"
    exclude group: "org.tensorflow", module: "tensorflow-lite-api"
}
'''
    open(path, 'w', encoding='utf-8').write(src)
    print('exclusions tensorflow ajoutées')


# --- tflite_flutter est compilé contre android-31 alors que ses dépendances androidx exigent >= 34.
# On force compileSdk 36 sur tous les sous-projets (avant evaluationDependsOn du gabarit Flutter).
root_kts, root_groovy = 'android/build.gradle.kts', 'android/build.gradle'
rpath = root_kts if os.path.exists(root_kts) else root_groovy
rsrc = open(rpath, encoding='utf-8').read()
if 'compileSdkVersion' not in rsrc:
    if rpath.endswith('.kts'):
        block = '''subprojects {
    afterEvaluate {
        extensions.findByName("android")?.let { ext ->
            ext.javaClass.methods
                .firstOrNull { it.name == "compileSdkVersion" && it.parameterTypes.size == 1 && it.parameterTypes[0] == Int::class.javaPrimitiveType }
                ?.invoke(ext, 36)
        }
    }
}

'''
    else:
        block = '''subprojects {
    afterEvaluate { p ->
        if (p.hasProperty("android")) { p.android.compileSdkVersion 36 }
    }
}

'''
    m = re.search(r'^subprojects\s*\{', rsrc, re.M)
    rsrc = (rsrc[:m.start()] + block + rsrc[m.start():]) if m else (rsrc + '\n' + block)
    open(rpath, 'w', encoding='utf-8').write(rsrc)
    print('compileSdk 36 forcé via', rpath)
