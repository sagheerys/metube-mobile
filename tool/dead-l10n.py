# -*- coding: utf-8 -*-
"""يبلّغ عن مفاتيح الترجمة التي لا يستعملها أي كود Dart.

**لماذا أداة لا اختبار**: حارس `arb_parity_test.dart` يعيش في `mt_ui`،
وهي حزمة لا تعرف التطبيقين بقصد (القاعدة 6) — فلا تستطيع أن تقرر أن
مفتاحاً ميت وهي لا ترى من يستعمله. هذا السكربت يقف فوق المستودع كله.

**متى يُشغَّل**: قبل أي دفعة ترجمة لغة جديدة (م-50) وقبل فتح المصدر.
مفتاح ميت واحد يعني جملة تُترجَم في **كل** لغة بلا أن يراها أحد.

    python tool/dead-l10n.py

يخرج بـ 0 دائماً — تقرير لا بوابة: الحذف قرار بشري، ومفتاح قد يكون
مضافاً استباقاً لشاشة قيد البناء.
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
    """كل مصادر Dart عدا مجلد l10n نفسه (فيه المولَّد وتعريف المفاتيح)."""
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
    out.write('مفاتيح: %d — غير مستعملة: %d\n' % (len(keys), len(dead)))
    for key in dead:
        out.write('  %s = %s\n' % (key, str(doc[key])[:70]))
    if not dead:
        out.write('نظيف: كل مفتاح له مستعمل.\n')
    return 0


if __name__ == '__main__':
    sys.exit(main())
