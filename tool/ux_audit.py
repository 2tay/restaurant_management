"""Audit the shipped code against the UX and design-system rules.

Reports rather than fixes. Re-run it after adding screens:

    python tool/ux_audit.py

The checks are deliberately narrow. An audit that flags things which are fine
gets ignored, and then it flags nothing.
"""

import io
import os
import re

ROOTS = ('lib/features', 'lib/shared')
FRENCH_CHARS = 'àâäéèêëïîôöùûüçÀÂÄÉÈÊËÏÎÔÖÙÛÜÇ'

# The spacing scale. Any padding, gap or radius literal outside this set is a
# one-off that should become a constant.
ALLOWED_SPACING = {0, 1, 2, 4, 8, 12, 16, 24, 32, 48}


def dart_files(*roots):
    for root in roots:
        for dirpath, _, names in os.walk(root):
            for name in names:
                if name.endswith('.dart'):
                    yield os.path.join(dirpath, name).replace(os.sep, '/')


def read(path):
    return io.open(path, encoding='utf-8').read()


problems = []
stats = {}


def record(label, entries, title):
    stats[label] = len(entries)
    if entries:
        problems.append((title, entries))


# --- Hardcoded user-facing French --------------------------------------------
hardcoded = []
literal = re.compile(r"'([^'\\\n]{4,})'")
for path in dart_files(*ROOTS):
    for number, line in enumerate(read(path).splitlines(), 1):
        if line.strip().startswith('//'):
            continue
        for match in literal.finditer(line):
            if any(ch in match.group(1) for ch in FRENCH_CHARS):
                hardcoded.append(f'{path}:{number}  {match.group(1)}')
record('hardcoded French strings', hardcoded, 'Hardcoded user-facing strings')

# --- Colours must come from the palette --------------------------------------
colors = [
    f'{p}:{n}  {line.strip()}'
    for p in dart_files(*ROOTS)
    for n, line in enumerate(read(p).splitlines(), 1)
    if 'Color(0x' in line
]
record('hardcoded colours', colors, 'Colour literal outside app_colors.dart')

# --- Text styles must come from the type scale -------------------------------
sizes = [
    f'{p}:{n}  {line.strip()}'
    for p in dart_files(*ROOTS)
    for n, line in enumerate(read(p).splitlines(), 1)
    if 'fontSize:' in line
]
record('inline fontSize', sizes, 'Inline fontSize outside app_typography.dart')

# --- Spacing must come from the scale ----------------------------------------
# Only checks the properties that set rhythm. Widths, heights and flex values
# are legitimately arbitrary — a chart is 280 tall because that is how tall it
# looks right, and turning that into a constant helps nobody.
spacing_literal = re.compile(
    r'(?:padding|margin):\s*(?:const\s+)?EdgeInsets\.[a-zA-Z]+\(([^)]*)\)'
)
number = re.compile(r'(?<![\w.])(\d+(?:\.\d+)?)(?![\w.])')
magic = []
for path in dart_files(*ROOTS):
    for line_no, line in enumerate(read(path).splitlines(), 1):
        for match in spacing_literal.finditer(line):
            for raw in number.findall(match.group(1)):
                value = float(raw)
                if value not in ALLOWED_SPACING:
                    magic.append(f'{path}:{line_no}  {match.group(0)}')
record('magic spacing values', magic, 'Padding outside the spacing scale')

# --- Destructive actions confirm ---------------------------------------------
missing_confirm = []
for path in dart_files('lib/features'):
    src = read(path)
    # Presentational widgets take a callback and let the screen above them own
    # the confirmation.
    if re.search(r'final VoidCallback\?? (onRemove|onDelete);', src):
        continue
    if 'DestructiveButton(' in src and 'ConfirmDialog' not in src:
        missing_confirm.append(path)
record(
    'destructive actions without confirm',
    missing_confirm,
    'Destructive action with no ConfirmDialog',
)

# --- Mutating forms confirm back ---------------------------------------------
missing_feedback = []
for path in dart_files('lib/features'):
    src = read(path)
    block_submit = re.search(r'_submit\(\)\s*(?:async\s*)?\{', src)
    returns_to_caller = 'Navigator.of(context).pop(' in src
    if block_submit and not returns_to_caller and 'AppSnackBar' not in src:
        missing_feedback.append(path)
record(
    'mutating forms without confirmation',
    missing_feedback,
    'Form submit with no feedback',
)

# --- Lists offer an empty state ----------------------------------------------
missing_empty = [
    p
    for p in dart_files('lib/features')
    if ('ListView.separated' in read(p) or 'ListView.builder' in read(p))
    and 'EmptyState' not in read(p)
]
record('lists without an empty state', missing_empty, 'List with no empty state')

# --- Navigation ---------------------------------------------------------------
# Phase 1 used context.go() everywhere, which replaces rather than stacks and
# left detail screens with nothing to go back to.
raw_go = [
    f'{p}:{n}'
    for p in dart_files(*ROOTS)
    for n, line in enumerate(read(p).splitlines(), 1)
    if 'context.go(' in line
]
record(
    'raw context.go() calls',
    raw_go,
    'Navigation bypassing goSection/pushScreen',
)

# --- Barcode lookups stay collection-shaped -----------------------------------
# Multiple barcodes per item is the likeliest next requirement here. A lookup
# already shaped as "give me the matches" absorbs that as a model change; a
# single-object lookup makes it a rewrite of every call site.
single_barcode_lookup = [
    f'{p}:{n}  {line.strip()}'
    for p in dart_files(*ROOTS, 'lib/mock_data')
    for n, line in enumerate(read(p).splitlines(), 1)
    if re.search(r'(firstWhere|singleWhere)\([^)]*barcode', line)
]
record(
    'single-object barcode lookups',
    single_barcode_lookup,
    'Barcode lookup that is not collection-shaped',
)

# --- Only a receipt moves stock -----------------------------------------------
# The rule the whole orders feature rests on: an order never changes stock, and
# every quantity change goes through a stock movement. Writing straight into
# mockItems from a screen would bypass the movement log, which is the single
# source of truth for stock levels.
STOCK_WRITER = 'lib/mock_data/mock_mutations.dart'
stock_writes = [
    f'{p}:{n}  {line.strip()}'
    for p in dart_files(*ROOTS, 'lib/mock_data')
    if p != STOCK_WRITER
    for n, line in enumerate(read(p).splitlines(), 1)
    if re.search(r'mockItems\[[^\]]+\]\s*=', line)
]
record(
    'stock writes outside the mutation layer',
    stock_writes,
    'Stock quantity changed without a movement',
)

# --- Product code never imports the dev gallery -------------------------------
dev_imports = [
    p for p in dart_files(*ROOTS) if re.search(r"import '.*/dev/", read(p))
]
record('product code importing lib/dev', dev_imports, 'Feature code importing lib/dev')

print('=== UX and design-system audit ===')
for label, count in stats.items():
    print(f'  {count:>3}  {label}')
print()

if not problems:
    print('Clean - no violations found.')
else:
    for title, entries in problems:
        print(f'--- {title} ({len(entries)}) ---')
        for entry in entries[:30]:
            print(f'  {entry}')
        if len(entries) > 30:
            print(f'  ... and {len(entries) - 30} more')
        print()
