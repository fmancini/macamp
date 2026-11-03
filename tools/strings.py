#!/usr/bin/env python3
"""Lists the texts the app shows (SwiftUI literals and String(localized:)) and
checks that every one has a Spanish translation in Localization/es.lproj.

  tools/strings.py            list keys that have no Spanish translation (exit 1 if any)
  tools/strings.py --all      list every key
Interpolations \\(x) are shown as %@ and match %@, %lld, %d, %f and %+.1f in the strings file.
"""
import re, sys, glob, os

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
API = r'(?:Text|Button|Label|Toggle|Picker|Section|LabeledContent|ContentUnavailableView|TextField|ProgressView|Menu|CommandMenu|MenuBarExtra|Window|\.help|\.navigationTitle|\.accessibilityLabel|\.accessibilityValue|\.alert|\.confirmationDialog|\.searchable\(text: [^,]+, prompt:|prompt:|String\(localized:|LocalizedStringKey)\(?\s*'
LIT = r'"((?:[^"\\]|\\.)*)"'

def unescape(s):
    s = re.sub(r'\\u\{([0-9A-Fa-f]+)\}', lambda m: chr(int(m.group(1), 16)), s)
    return s.replace('\\"', '"').replace('\\\\', '\\')

def keys():
    found = {}
    for path in glob.glob(root + '/Sources/**/*.swift', recursive=True):
        if re.search(r'(SelfTest|Snapshot|SeedData)', path): continue
        text = open(path).read()
        for m in re.finditer(API + LIT, text):
            raw = m.group(1)
            if raw.startswith('systemName') : continue
            key = re.sub(r'\\\((?:[^()]|\((?:[^()]|\([^()]*\))*\))*\)', '%@', unescape(raw))
            found.setdefault(key, os.path.relpath(path, root))
    return found

def spanish():
    out = set()
    path = root + '/Localization/es.lproj/Localizable.strings'
    if not os.path.exists(path): return out
    for m in re.finditer(r'^"((?:[^"\\]|\\.)*)"\s*=', open(path).read(), re.M):
        out.add(unescape(m.group(1)))
    plural = root + '/Localization/es.lproj/Localizable.stringsdict'
    if os.path.exists(plural):
        for m in re.finditer(r'<key>([^<]+)</key>\s*<dict>\s*<key>NSStringLocalizedFormatKey', open(plural).read()):
            out.add(m.group(1).replace('&amp;', '&'))
    return out

def norm(k):  # compare with all format specifiers treated alike
    return re.sub(r'%(?:lld|ld|[+\-0-9.]*[a-zA-Z@])', '%@', k)

if __name__ == '__main__':
    have = {norm(k) for k in spanish()}
    ks = keys()
    missing = {k: f for k, f in ks.items() if norm(k) not in have and re.search(r'[A-Za-z]{2}', k) and k not in ('MacAmp', 'https://\u2026') and not k.endswith('.fill') and 'specifier' not in k and 'String(localized' not in k}
    if '--all' in sys.argv:
        for k, f in sorted(ks.items()): print(repr(k), '|', f)
    else:
        for k, f in sorted(missing.items()): print(repr(k), '|', f)
        print(f'{len(missing)} of {len(ks)} keys without a Spanish translation')
        sys.exit(1 if missing else 0)
