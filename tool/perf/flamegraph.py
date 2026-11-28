"""Turns a profile folder into one self-contained flame graph page.

    python tool/perf/flamegraph.py [build/perf_profile] [--jdk <JDK home>]

Reads every *.folded (written by test/profile) and, when --jdk is given,
every *.jfr (Java Flight Recorder, the extension server's side). Writes
report.html and top.txt, the functions with the most samples per scenario.
"""

import argparse
import collections
import json
import pathlib
import re
import subprocess

JAVA_EVENTS = "jdk.ExecutionSample,jdk.NativeMethodSample"
WAIT_EVENTS = "jdk.JavaMonitorEnter,jdk.SocketRead,jdk.ThreadPark"


def jfr_json(jfr, path, events):
    out = subprocess.run(
        [str(jfr), "print", "--json", "--events", events, str(path)],
        capture_output=True,
        check=True,
    ).stdout
    return json.loads(out.decode("utf-8", "replace"))["recording"]["events"]


def frame_name(frame):
    method = frame["method"]
    owner = method["type"]["name"].replace("/", ".")
    return f"{owner}.{method['name']}"


def stack_of(values):
    trace = values.get("stackTrace") or {}
    frames = trace.get("frames") or []
    return ";".join(frame_name(f) for f in reversed(frames))


def seconds(duration):
    """ISO-8601 durations as jfr prints them, e.g. PT0.0123S."""
    match = re.fullmatch(r"PT(?:(\d+)M)?([\d.]+)S", duration or "")
    return int(match[1] or 0) * 60 + float(match[2]) if match else 0.0


def read_jfr(jfr, path):
    cpu = collections.Counter()
    for event in jfr_json(jfr, path, JAVA_EVENTS):
        stack = stack_of(event["values"])
        if stack:
            cpu[stack] += 1
    # Time threads spent blocked on a monitor, weighted in milliseconds.
    blocked = collections.Counter()
    for event in jfr_json(jfr, path, "jdk.JavaMonitorEnter"):
        values = event["values"]
        stack = stack_of(values)
        if stack:
            blocked[stack] += round(seconds(values.get("duration")) * 1000)
    return cpu, blocked


def read_folded(path):
    stacks = collections.Counter()
    for line in path.read_text(encoding="utf-8").splitlines():
        stack, _, count = line.rpartition(" ")
        if stack:
            stacks[stack] += int(count)
    return stacks


def tree(stacks):
    root = {"n": "all", "v": 0, "c": {}}
    for stack, count in stacks.items():
        node = root
        node["v"] += count
        for name in stack.split(";"):
            node = node["c"].setdefault(name, {"n": name, "v": 0, "c": {}})
            node["v"] += count

    def pack(node):
        # Slivers under 0.1 % are invisible and only cost page size.
        floor = root["v"] / 1000
        return [
            node["n"],
            node["v"],
            [pack(c) for c in node["c"].values() if c["v"] >= floor],
        ]

    return pack(root)


def top(stacks, count=25):
    own = collections.Counter()
    inclusive = collections.Counter()
    for stack, value in stacks.items():
        frames = stack.split(";")
        own[frames[-1]] += value
        for name in set(frames):
            inclusive[name] += value
    total = sum(stacks.values()) or 1

    def table(counter):
        return "\n".join(
            f"  {100 * v / total:5.1f}%  {v:7d}  {n[:170]}"
            for n, v in counter.most_common(count)
        )

    app = collections.Counter(
        {n: v for n, v in inclusive.items() if "[app:" in n or "mextension" in n}
    )
    return (
        f"self:\n{table(own)}\ninclusive, this project's code:\n{table(app)}"
    )


PAGE = """<!doctype html><meta charset="utf-8"><title>Mangatan performance profile</title>
<style>
 body{font:13px system-ui;margin:16px;background:#fff;color:#111}
 select,input,button{font:inherit;padding:4px 8px;margin-right:8px}
 #g{position:relative;width:100%;margin-top:12px}
 .f{position:absolute;height:17px;line-height:17px;overflow:hidden;white-space:nowrap;
    font-size:11px;padding-left:3px;box-sizing:border-box;border:1px solid #fff;cursor:pointer}
 .hit{outline:2px solid #6a00ff;outline-offset:-2px}
 #facts,#info{font-family:ui-monospace,monospace;white-space:pre-wrap;margin-top:8px}
 #info{min-height:36px}
</style>
<select id="s"></select><input id="q" placeholder="search a function"><button id="r">reset zoom</button>
<div id="facts"></div><div id="info"></div><div id="g"></div>
<script>
const DATA = __DATA__;
const s = document.getElementById('s'), g = document.getElementById('g'),
  q = document.getElementById('q'), info = document.getElementById('info');
let zoom = null;
for (const [i, d] of DATA.entries()) s.add(new Option(d.title, i));
function colour(n) {
  let h = 0; for (const c of n) h = (h * 31 + c.charCodeAt(0)) >>> 0;
  const base = n.includes('[app:') || n.startsWith('mextension') ? 205
    : n.includes('[flutter]') ? 100 : n.includes('isar') ? 280 : 20;
  return `hsl(${base + h % 30} 75% ${70 + h % 12}%)`;
}
function draw() {
  const d = DATA[+s.value], root = zoom || d.tree, total = root[1] || 1;
  document.getElementById('facts').textContent = d.facts + '\\nwidth = ' + d.unit +
    '; click a box to zoom. Blue: this project, green: Flutter, purple: database.';
  g.textContent = ''; let depth = 0;
  const needle = q.value.toLowerCase(); let hits = 0;
  (function place(node, x, level) {
    const [name, value, children] = node, w = value / total;
    if (w * g.clientWidth < 1.5) return;
    depth = Math.max(depth, level);
    const e = document.createElement('div'); e.className = 'f';
    e.style.cssText = `left:${100 * x}%;width:${100 * w}%;top:${level * 17}px;background:${colour(name)}`;
    e.textContent = name;
    const text = `${name}\\n${value} (${(100 * value / d.tree[1]).toFixed(1)}% of the scenario)`;
    e.onmouseenter = () => info.textContent = text;
    e.onclick = () => { zoom = node; draw(); };
    if (needle && name.toLowerCase().includes(needle)) { e.classList.add('hit'); hits++; }
    g.appendChild(e);
    let at = x;
    for (const c of [...children].sort((a, b) => a[0] < b[0] ? -1 : 1)) {
      place(c, at, level + 1); at += c[1] / total;
    }
  })(root, 0, 0);
  g.style.height = (depth + 2) * 17 + 'px';
  if (needle) info.textContent = hits + ' boxes match';
}
s.onchange = () => { zoom = null; draw(); };
q.oninput = draw; document.getElementById('r').onclick = () => { zoom = null; draw(); };
onresize = draw; draw();
</script>
"""


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("folder", nargs="?", default="build/perf_profile")
    parser.add_argument("--jdk")
    args = parser.parse_args()
    folder = pathlib.Path(args.folder)

    facts = {}
    metrics = folder / "metrics.jsonl"
    if metrics.exists():
        for line in metrics.read_text(encoding="utf-8").splitlines():
            row = json.loads(line)
            row.pop("latenciesMs", None)
            facts[row.pop("scenario")] = json.dumps(row)

    graphs = []
    for path in sorted(folder.glob("*.folded")):
        graphs.append(
            (f"app: {path.stem}", read_folded(path), "Dart CPU samples (1 ms)",
             facts.get(path.stem, ""))
        )
    if args.jdk:
        jfr = pathlib.Path(args.jdk) / "bin" / "jfr"
        for path in sorted(folder.glob("*.jfr")):
            cpu, blocked = read_jfr(jfr, path)
            graphs.append((f"server CPU: {path.stem}", cpu, "Java CPU samples", ""))
            if blocked:
                graphs.append(
                    (f"server blocked on locks: {path.stem}", blocked,
                     "milliseconds threads waited for a monitor", "")
                )

    data = [
        {"title": title, "tree": tree(stacks), "unit": unit, "facts": fact}
        for title, stacks, unit, fact in graphs
        if stacks
    ]
    payload = json.dumps(data).replace("</", "<\\/")
    (folder / "report.html").write_text(
        PAGE.replace("__DATA__", payload), encoding="utf-8"
    )
    (folder / "top.txt").write_text(
        "\n\n".join(
            f"=== {title} ({sum(s.values())} total; {unit}) ===\n{fact}\n{top(s)}"
            for title, s, unit, fact in graphs
            if s
        ),
        encoding="utf-8",
    )
    print(f"{len(data)} graphs in {folder / 'report.html'}")


if __name__ == "__main__":
    main()
