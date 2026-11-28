"""Top functions of a real-app driver run within a time window.

    python tool/perf/window_top.py <out folder> <run> <from ms> <to ms>

Times are the driver's (as in <run>.json); CPU sample timestamps are mapped
onto them through the frame events, which carry both clocks.
"""
import collections
import json
import sys

folder, run, lo, hi = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
frames = json.load(open(f"{folder}/{run}.frames.json"))
# startTime is the VM timeline clock (us); 'at' is when the driver got it.
offset = min(f["at"] * 1000 - f["startTime"] for f in frames)
own = collections.Counter()
inclusive = collections.Counter()
total = 0
for line in open(f"{folder}/{run}.samples.txt", encoding="utf-8"):
    ts, _, stack = line.rstrip("\n").partition("\t")
    at = (int(ts) + offset) / 1000
    if not lo <= at < hi:
        continue
    total += 1
    names = stack.split(";")
    own[names[-1]] += 1
    for name in set(names):
        inclusive[name] += 1
print(f"{total} samples between {lo} and {hi} ms")
print("self:")
for name, n in own.most_common(18):
    print(f"  {n:5d} {name[:150]}")
print("inclusive, this project's code:")
for name, n in [(k, v) for k, v in inclusive.most_common() if "[app:" in k][:25]:
    print(f"  {n:5d} {name[:150]}")
