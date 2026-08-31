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
    """Every hand-written Dart file under the given roots.

    Generated code is skipped, the same set the analyzer excludes. It follows
    none of the conventions checked here and nobody edits it, so a hit in it is
    always noise — `app_database.g.dart` alone builds every companion the schema
    can express, including the two this file forbids by hand.
    """
    for root in roots:
        for dirpath, _, names in os.walk(root):
            for name in names:
                if name.endswith('.g.dart') or name.endswith('.drift.dart'):
                    continue
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
    for p in dart_files(*ROOTS, 'lib/data')
    for n, line in enumerate(read(p).splitlines(), 1)
    if re.search(r'(firstWhere|singleWhere)\([^)]*barcode', line)
]
record(
    'single-object barcode lookups',
    single_barcode_lookup,
    'Barcode lookup that is not collection-shaped',
)

# --- Writes go through a repository -------------------------------------------
# The rule the mutation layer used to enforce, for the layer that replaced it.
# A screen that reaches past a repository into drift bypasses every guard those
# repositories exist to hold: the movement behind a quantity change, the price
# history behind a price, the transaction around a delivery.
#
# Matched by shape rather than by name: `into(`, `update(`, `delete(` and
# `customStatement(` are how anything is written through drift, and none of them
# belong outside `lib/data/repositories/`.
REPOSITORY_LAYER = 'lib/data/repositories/'

# `_db.into(_db.items)`, `_db.update(_db.stores)`, `_db.delete(_db.units)` and
# the two escape hatches. Matched with the receiver included, because that is
# how every one of them is actually written.
drift_write = re.compile(
    r'\.\s*(?:into|update|delete)\s*\(\s*[\w.]+\s*\)'
    r'|customStatement\s*\(|\.\s*batch\s*\('
)
writes_outside_repositories = [
    f'{p}:{n}  {line.strip()}'
    # Only the data layer. A screen calling `repository.delete(id)` has the same
    # shape and is exactly what is supposed to happen; check 15 is what stops a
    # screen reaching a table at all.
    for p in dart_files('lib/data')
    if not p.startswith(REPOSITORY_LAYER)
    and not p.startswith('lib/data/seed/')
    and not p.startswith('lib/data/database/')
    for n, line in enumerate(read(p).splitlines(), 1)
    if drift_write.search(line) and not line.strip().startswith('//')
]
record(
    'database writes outside the repository layer',
    writes_outside_repositories,
    'A table written without going through a repository',
)

# --- Cost is written in one place, and read for the right job -----------------
# `Item.averageCost` is a running total, and a running total is only safe while
# exactly one thing advances it. The movement repository advances it; the
# arithmetic lives in stock_cost.dart. Dataset literals are the starting
# balance, not a write, so this looks for the two shapes that actually move it:
# an assignment, and a `copyWith` carrying it.
COST_WRITERS = (REPOSITORY_LAYER, 'lib/core/utils/stock_cost.dart')

cost_writes = [
    f'{p}:{n}  {line.strip()}'
    for p in dart_files(*ROOTS, 'lib/data')
    if not p.startswith(COST_WRITERS)
    for n, line in enumerate(read(p).splitlines(), 1)
    # `=>` is a declaration, not a write: the schema names the column that way.
    if re.search(r'averageCost\s*=(?![=>])', line)
    or ('copyWith(' in line and 'averageCost' in line)
]
record(
    'average cost written outside the movement repository',
    cost_writes,
    'Stock cost changed without a movement',
)

# The bug this whole change exists to stop coming back.
#
# A supplier price is what the *next* unit will cost. Multiplying it by the
# quantity on hand revalues stock bought weeks ago at this morning's price —
# 100 kg at 8 € plus 50 kg at 10 € reported as 1 500 € rather than the 1 300 €
# actually spent. Valuation multiplies by `averageCost` instead.
#
# Matches the shape rather than the intent, because the shape is the bug: a
# quantity and a purchase price meeting in one expression.
quantity_times_price = [
    f'{p}:{n}  {line.strip()}'
    for p in dart_files(*ROOTS, 'lib/data')
    for n, line in enumerate(read(p).splitlines(), 1)
    if 'pricePerUnit' in line
    and re.search(r'\bquantity\b', line)
    and '*' in line
]
record(
    'stock quantity multiplied by a supplier price',
    quantity_times_price,
    'Stock valued at a purchase price rather than at what it cost',
)

# --- Quantity and cost are written in one place, in the data layer ------------
# The same rule as the two checks above, for the layer that is replacing the
# mock lists. `items.quantity` and `items.averageCost` may only be written by
# `movement_repository.dart`, so that every change to either is explained by a
# movement filed in the same transaction.
#
# `item_mapper.dart` is allowed because it is how a whole item becomes a row —
# the seed and the movement repository both go through it, and neither decides
# anything there.
#
# Matched by finding each `ItemsCompanion` and reading the call that follows it,
# rather than line by line: a companion spans several lines, and `quantity:` on
# its own also appears in perfectly legitimate calls to the movement repository.
QUANTITY_WRITERS = (
    'lib/data/repositories/movement_repository.dart',
    'lib/data/mappers/item_mapper.dart',
)

def companion_writes(path, text):
    for match in re.finditer(r'ItemsCompanion(?:\.insert)?\(', text):
        depth = 0
        start = match.end() - 1
        for index in range(start, len(text)):
            if text[index] == '(':
                depth += 1
            elif text[index] == ')':
                depth -= 1
                if depth == 0:
                    body = text[match.end():index]
                    field = re.search(r'\b(quantity|averageCost)\s*:', body)
                    if field:
                        line = text.count('\n', 0, match.start()) + 1
                        yield f'{path}:{line}  ItemsCompanion sets {field.group(1)}'
                    break
        else:
            continue


data_stock_writes = [
    entry
    for p in dart_files(*ROOTS, 'lib/data')
    if p not in QUANTITY_WRITERS
    for entry in companion_writes(p, read(p))
]
record(
    'stock quantity or cost written outside movement_repository',
    data_stock_writes,
    'items.quantity or items.averageCost changed without a movement',
)

# --- Screens talk to repositories, never to drift -----------------------------
# The provider layer exists so a widget names what it needs rather than holding
# a database. A feature importing `data/database/` has reached past that — and
# would be able to write a table from inside a `build`, which is the shape every
# check above exists to prevent.
#
# `data/repositories/` is fine: a form reads `ItemFilter` and `ReceiptDraftLine`
# from there, and both are argument types rather than access to anything.
feature_database_imports = [
    f'{p}:{n}  {line.strip()}'
    for p in dart_files('lib/features', 'lib/shared')
    for n, line in enumerate(read(p).splitlines(), 1)
    if re.search(r"import '[^']*data/database/", line)
    or re.search(r"import 'package:drift/", line)
]
record(
    'feature code importing the database directly',
    feature_database_imports,
    'A screen reaching past its repository into drift',
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
