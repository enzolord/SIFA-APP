#!/usr/bin/env python3
"""Ajoute au AndroidManifest les permissions dont SIFA a besoin (idempotent).

Le dossier android/ est généré par `flutter create` ; ce script y ajoute :
INTERNET (tuiles de carte, itinéraire), localisation (distance et itinéraire),
et les « queries » pour ouvrir Maps / le téléphone.
Usage : python tools/patch_manifest.py
"""
import pathlib
import sys

p = pathlib.Path("android/app/src/main/AndroidManifest.xml")
if not p.exists():
    sys.exit("android/ introuvable : lancez d'abord `flutter create --platforms android .`")
s = p.read_text(encoding="utf-8")
perms = [
    "android.permission.INTERNET",
    "android.permission.ACCESS_FINE_LOCATION",
    "android.permission.ACCESS_COARSE_LOCATION",
]
add = "".join(f'    <uses-permission android:name="{x}"/>\n' for x in perms if x not in s)
if add:
    s = s.replace("<application", add + "    <application", 1)
if "android.intent.action.DIAL" not in s:
    q = """    <queries>
        <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent>
        <intent><action android:name="android.intent.action.DIAL"/><data android:scheme="tel"/></intent>
    </queries>
"""
    s = s.replace("<application", q + "    <application", 1)
p.write_text(s, encoding="utf-8")
print("AndroidManifest.xml à jour.")
