# -*- coding: utf-8 -*-
"""Report localization keys that no Dart code uses.

**Why a tool rather than a test.** The `arb_parity_test.dart` guard lives in
`mt_ui`, which deliberately knows nothing about the two apps, so it cannot
decide that a key is dead when it cannot see who uses it. This script stands
above the whole repository instead.

**When to run it:** before translating into a new language, and before any
release. One dead key is a sentence translated into **every** language that
nobody ever sees.

    python tool/dead-l10n.py

Always exits 0 — a report, not a gate: deleting is a human decision, and a key
may have been added ahead of a screen still being built.
"""

import io
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EN_ARB = os.path.join(ROOT, 'packages', 'mt_ui', 'lib', 'src', 'l10n',
                      'app_en.arb')
SKIP_DIRS = {'.git', '.dart_tool', 'build', '.design', 'node_modules'}


def dart_sources():
    """Every Dart source except the l10n folder itself, which holds the
    generated code and the key definitions."""
    for base, dirs, files in os.walk(ROOT):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for name in files:
            if not name.endswith('.dart') or name.endswith('.g.dart'):
                continue
            path = os.path.join(base, name)
            if '/l10n/' in path.replace(os.sep, '/'):
                continue
            try:
                yield io.open(path, encoding='utf-8').read()
            except (IOError, UnicodeDecodeError):
                continue


def main():
    doc = json.loads(io.open(EN_ARB, encoding='utf-8').read())
    keys = [k for k in doc if not k.startswith('@')]
    text = '\n'.join(dart_sources())
    dead = [k for k in keys if not re.search(r'\b' + re.escape(k) + r'\b', text)]

    out = sys.stdout
    out.write('keys: %d - unused: %d\n' % (len(keys), len(dead)))
    for key in dead:
        out.write('  %s = %s\n' % (key, str(doc[key])[:70]))
    if not dead:
        out.write('clean: every key has a user.\n')
    return 0


if __name__ == '__main__':
    sys.exit(main())
