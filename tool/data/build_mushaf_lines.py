#!/usr/bin/env python3
# Usage: python3 tool/data/build_mushaf_lines.py <holy-quran-word-by-word-full-data/package/data.json> assets/data/quran_uthmani.json.gz assets/data/mushaf_lines.json.gz
"""Builds assets/data/mushaf_lines.json.gz: the printed Madani page layout
(15 lines a page) mapped onto the words of the app's own Uthmani text."""
import collections, gzip, json, sys, unicodedata

wbw_path, text_path, out_path = sys.argv[1:4]
pages = json.load(open(wbw_path))
text = json.load(gzip.open(text_path))["ayahs"]

def toks(t):
    return [x for x in t.split(" ") if any(unicodedata.category(c).startswith("L") for c in x)]

# Word counts per ayah in the layout data.
wcount = collections.Counter()
for p in pages:
    for a in p["ayahs"]:
        for w in a["words"]:
            if w["char_type_name"] == "word":
                wcount[w["parentAyahVerseKey"]] += 1

def our_indices(key, pos):
    """Layout word position (1-based) -> indices into our tokens (0-based)."""
    s, a = map(int, key.split(":"))
    n_ours = len(toks(text[s - 1][a - 1]))
    n_them = wcount[key]
    if n_ours == n_them:
        return [pos - 1]
    # Different word split (9 verses): each layout word covers a share of
    # ours; together the shares cover every word once and in order.
    lo = (pos - 1) * n_ours // n_them
    hi = pos * n_ours // n_them
    return list(range(lo, hi))

out = []
mismatch = 0
for p in pages:
    lines = {}
    metas = []
    for a in p["ayahs"]:
        if a["metaData"]:
            metas.append(a["metaData"]["lineType"])
        for w in a["words"]:
            s, ay = map(int, w["parentAyahVerseKey"].split(":"))
            ln = w["line_number"]
            if w["char_type_name"] == "end":
                lines.setdefault(ln, []).append([s, ay, -1])
            else:
                cur = lines.setdefault(ln, [])
                for i in our_indices(w["parentAyahVerseKey"], w["position"]):
                    cur.append([s, ay, i])
    last = 8 if p["page"] <= 2 else 15
    rows = []
    mi = 0
    for ln in range(1, last + 1):
        if ln in lines:
            rows.append({"w": lines[ln]})
        else:
            kind = metas[mi] if mi < len(metas) else None
            mi += 1
            nxt = next((lines[k][0][0] for k in sorted(lines) if k > ln), None)
            if kind == "start_sura":
                rows.append({"h": nxt})
            elif kind == "besmellah":
                rows.append({"b": nxt})
            else:
                rows.append({})
    # Our words must all appear once, in order.
    out.append(rows)

# Check coverage: every word of every verse appears in order exactly once.
seen = collections.defaultdict(list)
for rows in out:
    for r in rows:
        for s, a, i in r.get("w", []):
            if i >= 0:
                seen[(s, a)].append(i)
bad = 0
for s, surah in enumerate(text, 1):
    for a, t in enumerate(surah, 1):
        if seen[(s, a)] != list(range(len(toks(t)))):
            bad += 1
            if bad < 5:
                print("coverage", s, a, seen[(s, a)][:20], len(toks(t)))
print("bad verses", bad)
with gzip.GzipFile(out_path, "wb", 9, mtime=0) as f:
    f.write(json.dumps({
        "source": "Madani mushaf line layout (page, line) from Quran.com data as packaged in @kmaslesa/holy-quran-word-by-word-full-data 1.0.6 (ISC), mapped onto the bundled Uthmani text.",
        "pages": out,
    }, separators=(",", ":")).encode())
