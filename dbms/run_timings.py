#!/usr/bin/env python3
"""Run every query in 04_queries.sql under EXPLAIN (ANALYZE, BUFFERS).

Usage:  python3 run_timings.py <mode> [dbname]
        mode = baseline | indexed   (plans saved to plans/<mode>/)
Writes (W*) run inside BEGIN ... ROLLBACK so the data is never changed.
Each query: 1 warm-up run, then 5 timed runs; the median is reported.
Outputs plans/<mode>/<ID>.txt and plans/<mode>/summary.csv
"""
import re, subprocess, statistics, sys, os, csv, tempfile

mode = sys.argv[1]
db = sys.argv[2] if len(sys.argv) > 2 else "olx"
here = os.path.dirname(os.path.abspath(__file__))
out = os.path.join(here, "plans", mode)
os.makedirs(out, exist_ok=True)

text = open(os.path.join(here, "04_queries.sql")).read()
blocks = re.split(r"^-- \[(\w+)\] (.*)$", text, flags=re.M)
queries = [(blocks[i], blocks[i+1], blocks[i+2].strip()) for i in range(1, len(blocks), 3)]

def explain(sql, write):
    body = f"EXPLAIN (ANALYZE, BUFFERS) {sql}"
    script = f"BEGIN;\n{body}\nROLLBACK;\n" if write else body + "\n"
    with tempfile.NamedTemporaryFile("w", suffix=".sql", delete=False) as f:
        f.write(script); path = f.name
    r = subprocess.run(["psql", "-q", "-At", "-d", db, "-f", path],
                       capture_output=True, text=True)
    os.unlink(path)
    if r.returncode or "ERROR" in r.stderr:
        raise SystemExit(f"query failed:\n{sql}\n{r.stderr}")
    lines = [l for l in r.stdout.splitlines() if l not in ("BEGIN", "ROLLBACK")]
    return "\n".join(lines)

def ms(plan, label):
    m = re.search(rf"{label} Time: ([\d.]+) ms", plan)
    return float(m.group(1))

rows = []
for qid, title, sql in queries:
    write = qid.startswith("W")
    explain(sql, write)                       # warm-up
    runs, plan = [], ""
    for _ in range(5):
        plan = explain(sql, write)
        runs.append(ms(plan, "Execution"))
    plan_ms = ms(plan, "Planning")
    med = statistics.median(runs)
    open(os.path.join(out, f"{qid}.txt"), "w").write(f"-- [{qid}] {title}\n-- median execution: {med:.3f} ms\n\n{plan}\n")
    rows.append((qid, title, f"{plan_ms:.3f}", f"{med:.3f}", f"{min(runs):.3f}", f"{max(runs):.3f}"))
    print(f"{qid:4} {med:10.3f} ms  {title}")

with open(os.path.join(out, "summary.csv"), "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["id", "title", "planning_ms", "median_exec_ms", "min_ms", "max_ms"])
    w.writerows(rows)
