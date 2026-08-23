"""Stage 6 audit: check the shipped code against the brief's UX rules.

Reports rather than fixes. Kept in the repo docs so the next person can re-run
it after adding screens.

The checks are deliberately narrow. An audit that flags things which are fine
gets ignored, and then it flags nothing.
"""

import io
import os
import re

ROOTS = ('lib/features', 'lib/shared')
FRENCH_CHARS = 'àâäéèêëïîôöùûüçÀÂÄÉÈÊËÏÎÔÖÙÛÜÇ'


def dart_files(*roots):
    for root in roots:
        for dirpath, _, names in os.walk(root):
            for name in names:
                if name.endswith('.dart'):
                    yield os.path.join(dirpath, name).replace('\\', '/')


def read(path):
    return io.open(path, encoding='utf-8').read()


problems = []
stats = {}

# --- 1. No hardcoded user-facing French --------------------------------------
# Every display string goes through AppLocalizations so Dutch can be added
# without touching screens.
hardcoded = []
literal = re.compile(r"'([^'\\\n]{4,})'")
for path in dart_files(*ROOTS):
    for line_no, line in enumerate(read(path).splitlines(), 1):
        stripped = line.strip()
        if stripped.startswith('//'):
            continue
        for match in literal.finditer(line):
            text = match.group(1)
            if any(ch in text for ch in FRENCH_CHARS):
                hardcoded.append(f'{path}:{line_no}  {text}')
stats['hardcoded French strings'] = len(hardcoded)
if hardcoded:
    problems.append(('Hardcoded user-facing strings', hardcoded))

# --- 2. Destructive actions confirm ------------------------------------------
# Only counts a *destructive control*. trash2 is also the icon for the "Perte"
# stock-out reason and the waste tile, which are not destructive actions —
# matching on the icon alone made this check useless.
missing_confirm = []
for path in dart_files('lib/features'):
    src = read(path)
    # Presentational widgets take an onRemove/onDelete callback and let the
    # screen above them own the confirmation. Only flag the file that actually
    # decides to delete something.
    is_callback_only = re.search(
        r'final VoidCallback\?? (onRemove|onDelete);', src
    )
    if is_callback_only:
        continue
    if 'DestructiveButton(' in src and 'ConfirmDialog' not in src:
        missing_confirm.append(path)
stats['destructive actions without confirm'] = len(missing_confirm)
if missing_confirm:
    problems.append(('Destructive action with no ConfirmDialog', missing_confirm))

# --- 3. Mutating screens confirm back ----------------------------------------
# Only screens whose submit actually changes something. A submit that just
# navigates (login) or hands a value back to its caller (the create sheets)
# correctly shows nothing itself.
missing_snackbar = []
for path in dart_files('lib/features'):
    src = read(path)
    # An arrow-bodied submit only navigates (login), so it has nothing to
    # confirm. A block-bodied one records something and must say so.
    block_submit = re.search(r'_submit\(\)\s*(?:async\s*)?\{', src)
    # A sheet that pops a value hands the outcome back to its caller, which is
    # what shows the confirmation — the sheet is already gone by then.
    returns_to_caller = 'Navigator.of(context).pop(' in src
    if block_submit and not returns_to_caller and 'AppSnackBar' not in src:
        missing_snackbar.append(path)
stats['mutating forms without confirmation'] = len(missing_snackbar)
if missing_snackbar:
    problems.append(('Form submit with no feedback', missing_snackbar))

# --- 4. Nothing renders below the readable floor ------------------------------
small_text = []
for path in dart_files(*ROOTS):
    for line_no, line in enumerate(read(path).splitlines(), 1):
        for match in re.finditer(r'fontSize:\s*(\d+)', line):
            if int(match.group(1)) < 13:
                small_text.append(f'{path}:{line_no}  {match.group(0)}')
stats['text below the 13pt floor'] = len(small_text)
if small_text:
    problems.append(('Text below the 13pt readable floor', small_text))

# --- 5. Lists offer an empty state -------------------------------------------
missing_empty = []
for path in dart_files('lib/features'):
    src = read(path)
    if ('ListView.separated' in src or 'ListView.builder' in src) and (
        'EmptyState' not in src
    ):
        missing_empty.append(path)
stats['lists without an empty state'] = len(missing_empty)
if missing_empty:
    problems.append(('List with no empty state', missing_empty))

# --- 6. Product code never imports the dev gallery ----------------------------
dev_imports = [p for p in dart_files(*ROOTS) if re.search(r"import '.*/dev/", read(p))]
stats['product code importing lib/dev'] = len(dev_imports)
if dev_imports:
    problems.append(('Feature code importing lib/dev', dev_imports))

print('=== Stage 6 audit ===')
for label, count in stats.items():
    print(f'  {count:>3}  {label}')
print()

if not problems:
    print('Clean — no violations found.')
else:
    for title, entries in problems:
        print(f'--- {title} ({len(entries)}) ---')
        for entry in entries[:40]:
            print(f'  {entry}')
        print()
