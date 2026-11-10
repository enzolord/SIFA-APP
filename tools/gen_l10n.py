#!/usr/bin/env python3
"""Génère lib/l10n/strings_en.dart depuis tools/translations_en.py."""
import pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).parent))
from translations_en import EN, TEMPLATES

def q(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("$", "\\$").replace("\n", "\\n") + '"'

out = ["// GÉNÉRÉ par tools/gen_l10n.py : ne pas modifier à la main.", "",
       "const Map<String, String> enStrings = {"]
out += [f"  {q(k)}: {q(v)}," for k, v in EN.items()]
out += ["};", "", "const Map<String, String> enTemplates = {"]
out += [f"  {q(k)}: {q(v)}," for k, v in TEMPLATES.items()]
out += ["};", ""]
p = pathlib.Path(__file__).parent.parent / "lib/l10n/strings_en.dart"
p.write_text("\n".join(out), encoding="utf-8")
print("écrit", p, len(EN), "textes,", len(TEMPLATES), "gabarits")
