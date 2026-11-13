#!/usr/bin/env python3
"""Assemble admin/index.html : le gabarit + les fiches maladies intégrées (pré-remplissage de l'éditeur).
Usage : python3 tools/build_admin.py"""
import json, pathlib, subprocess, sys
root = pathlib.Path(__file__).parent.parent
fiches = subprocess.run([sys.executable, str(root / "tools/extract_fiches.py")], capture_output=True, text=True, check=True).stdout
json.loads(fiches)
safe = fiches.replace("</", "<\\/")  # jamais de </script> dans le JSON
tpl = (root / "admin/index.template.html").read_text(encoding="utf-8")
(root / "admin/index.html").write_text(tpl.replace("__FICHES_BASE__", safe), encoding="utf-8")
print("admin/index.html écrit,", len(tpl) + len(safe), "octets")
