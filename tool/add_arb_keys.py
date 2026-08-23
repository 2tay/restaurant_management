"""Append a block of ARB keys, validating the JSON before writing."""

import io
import json
import sys

arb_path = 'lib/l10n/app_fr.arb'
block_path = sys.argv[1]

existing = io.open(arb_path, encoding='utf-8').read().rstrip()
block = io.open(block_path, encoding='utf-8').read().strip()

assert existing.endswith('}'), 'ARB does not end with a closing brace'
merged = existing[:-1].rstrip().rstrip(',') + ',\n' + block.rstrip(',') + '\n}\n'

parsed = json.loads(merged)  # fails loudly rather than generating a broken class

keys = [k for k in parsed if not k.startswith('@')]
undocumented = [k for k in keys if k != '@@locale' and f'@{k}' not in parsed]
assert not undocumented, f'keys missing a description: {undocumented}'

io.open(arb_path, 'w', encoding='utf-8').write(merged)
print(f'ARB valid — {len(keys)} keys, all documented')
