import re
import collections
from pathlib import Path

ranks = collections.Counter()
total = ph = with_drop = 0
for p in Path("Data").glob("*.lua"):
    if p.name == "Registry.lua":
        continue
    t = p.read_text(encoding="utf-8")
    for m in re.finditer(r"rank = RANK\.(\w+)", t):
        ranks[m.group(1)] += 1
    n = len(re.findall(r"\[\d+\] = entry", t))
    total += n
    with_drop += len(re.findall(r'drop = "[^"]+"', t))
    ph += len(re.findall(r'name = "Item \d+"', t))

print("ranks", dict(ranks))
print(
    f"total={total} with_drop={with_drop} empty_drop~={total - with_drop} ph={ph}"
)
