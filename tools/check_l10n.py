#!/usr/bin/env python3
"""Liste les textes français de l'app qui n'ont pas de traduction anglaise.

  python3 tools/check_l10n.py          -> affiche les manquants (code de sortie 1 s'il y en a)

Repère : Tx('...'), tr('...'), trf('...'), et toutes les chaînes des fichiers de contenu
(lib/data/knowledge.dart, lib/services/triage.dart, lib/models/diagnosis.dart).
"""
import pathlib, re, sys
sys.path.insert(0, str(pathlib.Path(__file__).parent))
from translations_en import EN, TEMPLATES

ROOT = pathlib.Path(__file__).parent.parent / 'lib'
STR = r"""(?:'((?:[^'\\]|\\.)*)'|"((?:[^"\\]|\\.)*)")"""

def unescape(s):
    return s.replace("\\'", "'").replace('\\"', '"').replace('\\n', '\n').replace('\\$', '$')

def lit(m, i=1):
    return unescape(m.group(i) if m.group(i) is not None else m.group(i + 1))

# Fichiers dont TOUTES les chaînes sont du texte affiché (pas seulement Tx/tr).
CONTENT = {'data/knowledge.dart', 'services/triage.dart', 'models/diagnosis.dart',
           'screens/result_screen.dart', 'screens/remedes_screen.dart', 'screens/signs_screen.dart',
           'screens/scan_screen.dart', 'screens/tips_screen.dart'}
# Chaînes qui ne se traduisent pas (noms propres, clés techniques).
IGNORE = {'SIFA', 'Langue / Language', 'photoPath'}

def joined(src, m):
    """Chaîne complète quand plusieurs littéraux se suivent ('a' 'b')."""
    parts, end = [lit(m)], m.end()
    nxt = re.compile(r"\s*" + STR)
    while True:
        n = nxt.match(src, end)
        if not n:
            return ''.join(parts)
        parts.append(lit(n))
        end = n.end()

found = {}
for f in ROOT.rglob('*.dart'):
    if f.name == 'strings_en.dart':
        continue
    src = f.read_text(encoding='utf-8')
    rel = str(f.relative_to(ROOT))
    for m in re.finditer(r"\b(?:Tx|tr)\(\s*" + STR, src):
        found.setdefault(joined(src, m), rel)
    for m in re.finditer(r"\btrf\(\s*" + STR, src):
        found.setdefault('TPL:' + joined(src, m), rel)
    if rel in CONTENT:
        code = re.sub(r'(?m)^\s*(//|import ).*$', '', src)
        for m in re.finditer(STR, code):
            s = lit(m)
            if '$' in s or not re.search(r'[A-Za-zÀ-ÿ]{2}', s) or re.fullmatch(r'[a-z_0-9]+', s):
                continue
            found.setdefault(s, rel)

missing = []
for s, rel in found.items():
    if s.startswith('TPL:'):
        if s[4:] not in TEMPLATES:
            missing.append((rel, s))
    elif s not in EN and '$' not in s and s.strip() and s not in IGNORE:
        missing.append((rel, s))

for rel, s in sorted(missing):
    print(f'{rel}\t{s!r}')
print(f'{len(found)} textes repérés, {len(missing)} sans traduction', file=sys.stderr)
sys.exit(1 if missing else 0)
