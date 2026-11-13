#!/usr/bin/env python3
"""Extrait les fiches maladies intégrées (lib/data/knowledge.dart) + traductions EN en JSON,
pour pré-remplir l'éditeur de l'outil d'administration."""
import json, pathlib, re, sys
sys.path.insert(0, str(pathlib.Path(__file__).parent))
from translations_en import EN  # FR -> EN

SRC = pathlib.Path(__file__).parent.parent / "lib/data/knowledge.dart"
txt = SRC.read_text(encoding="utf-8")

STR = r"""(?:'(?:\\.|[^'\\])*'|"(?:\\.|[^"\\])*")"""
def unq(lit):
    body = lit[1:-1]
    return re.sub(r"\\(.)", lambda m: {"n": "\n"}.get(m.group(1), m.group(1)), body)
def strings(chunk):
    # chaînes adjacentes = une seule chaîne
    out, cur = [], []
    pos = 0
    for m in re.finditer(STR + r"|,", chunk):
        if m.group(0) == ",":
            if cur: out.append("".join(cur)); cur = []
        else:
            cur.append(unq(m.group(0)))
    if cur: out.append("".join(cur))
    return out
def both(fr): return {"fr": fr, "en": EN.get(fr, "")}

def field(block, name):
    m = re.search(r"\b%s:\s*\[" % name, block)
    if not m: return None
    i, depth = m.end(), 1
    j = i
    instr = None
    while depth:
        c = block[j]
        if instr:
            if c == "\\": j += 1
            elif c == instr: instr = None
        elif c in "'\"": instr = c
        elif c == "[": depth += 1
        elif c == "]": depth -= 1
        j += 1
    return block[i:j-1]

names = {"healthy": "healthy", "coccidiosis": "coccidiosis", "salmonella": "salmonella", "newcastle": "newcastle"}
out = {}
for key in names:
    m = re.search(r"Disease\.%s:\s*DiseaseSheet\(" % key, txt)
    start = m.end()
    nxt = re.search(r"\n  Disease\.\w+:\s*DiseaseSheet\(|\n\};", txt[start:])
    block = txt[start:start + nxt.start()]
    sheet = {}
    for f, k in (("recognize", "reconnaitre"), ("scientific", "scientifique"), ("artisanal", "artisanal")):
        chunk = field(block, f) or ""
        items = []
        for it in re.finditer(r"KbItem\(\s*(%s(?:\s*%s)*)\s*,\s*(%s(?:\s*%s)*)\s*(?:,\s*Evidence\.(\w+))?\s*\)" % (STR, STR, STR, STR), chunk):
            t = "".join(unq(x) for x in re.findall(STR, it.group(1)))
            b = "".join(unq(x) for x in re.findall(STR, it.group(2)))
            e = {"titre": both(t), "texte": both(b)}
            if it.group(3): e["preuve"] = it.group(3)
            items.append(e)
        sheet[k] = items
    for f, k in (("now", "maintenant"), ("prevention", "prevention"), ("confusions", "confusions")):
        sheet[k] = [both(s) for s in strings(field(block, f) or "")]
    hr = re.search(r"humanRisk:\s*((?:%s\s*)+)" % STR, block)
    sheet["risque_humain"] = both("".join(unq(x) for x in re.findall(STR, hr.group(1)))) if hr else {"fr": "", "en": ""}
    out[key] = sheet

if __name__ == "__main__":
    json.dump(out, sys.stdout, ensure_ascii=False)
