#!/usr/bin/env python3
"""Builds the offline data bundle shipped in assets/data/.

Every religious text in Mishkah comes from a published, licensed source.
Nothing here is written by hand except the prophets index, which only
stores *verse references* (surah:ayah ranges); the verses themselves are
read from the Quran text at runtime.

Sources (fetch them first, see docs/DATA_SOURCES.md):
  npm  quran-json@3.1.2        Uthmani text (QuranEnc) + Saheeh Intl (en),
                               Hamidullah (fr)          CC-BY-SA-4.0
  npm  islam.js@1.3.0          Italian (Piccardo) translation, Hisn al-Muslim
                               azkar collection         MIT
  npm  quran-meta@7.0.0        Hafs page / juz / hizb / sajda lists  MIT
  git  spa5k/tafsir_api        Tafsir al-Muyassar (King Fahd Complex)  MIT
  git  fawazahmed0/hadith-api  Forty Nawawi + Forty Qudsi (ar/en)      Unlicense
  npm  @kmaslesa/holy-quran-word-by-word-full-data@1.0.6
                               English word meanings + transliteration
                               (Quran.com data)          ISC
  (tajweed.json.gz is built separately: see tool/data/tajweed/README.md)

Usage:
  python3 tool/data/build_data.py --src /path/to/downloads --out assets/data
"""
import argparse
import gzip
import json
import os
import re
import subprocess
import sys


def write_gz(path, obj):
    raw = json.dumps(obj, ensure_ascii=False, separators=(",", ":")).encode()
    # mtime=0 keeps the output byte-identical between builds.
    with open(path, "wb") as fh, gzip.GzipFile(fileobj=fh, mode="wb", compresslevel=9, mtime=0) as f:
        f.write(raw)
    print(f"  {os.path.basename(path)}: {len(raw)//1024} KB raw")


def load_js_export(path):
    """islam.js ships CommonJS modules of the form `exports.X = <json-ish>;`."""
    node = os.environ.get("NODE", "node")
    code = (
        "const m=require(process.argv[1]);"
        "process.stdout.write(JSON.stringify(Object.values(m)[0]));"
    )
    out = subprocess.check_output([node, "-e", code, path])
    return json.loads(out)


def load_quran_meta(path):
    node = os.environ.get("NODE", "node")
    code = (
        "import(process.argv[1]).then(m=>process.stdout.write("
        "JSON.stringify(Object.values(m)[0])))"
    )
    return json.loads(subprocess.check_output([node, "-e", code, path]))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True)
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    src, out = a.src, a.out
    os.makedirs(out, exist_ok=True)

    qj = os.path.join(src, "quran-json/package/dist")
    en = json.load(open(os.path.join(qj, "quran_en.json")))
    fr = json.load(open(os.path.join(qj, "quran_fr.json")))

    # ---- meta (pages, juz, hizb, sajda) ----
    hl = [f for f in os.listdir(os.path.join(src, "quran-meta/package/dist"))
          if f.startswith("HafsLists-")][0]
    tmp = os.path.join(src, "hafs_lists.mjs")
    with open(os.path.join(src, "quran-meta/package/dist", hl)) as f:
        open(tmp, "w").write(f.read())
    L = load_quran_meta(tmp)
    surahs = []
    for i, s in enumerate(en):
        start, count, order, rukus, _, meccan = L["SurahList"][i + 1]
        assert count == len(s["verses"]) == s["total_verses"], s["id"]
        surahs.append({
            "n": s["id"], "ar": s["name"], "tr": s["transliteration"],
            "en": s["translation"], "c": count, "s": start,
            "o": order, "m": 1 if s["type"] == "meccan" else 0,
        })
    meta = {
        "surahs": surahs,
        # Absolute (1-based) ayah index where each page / juz / rub' starts.
        "pages": L["PageList"][1:605],
        "juz": L["JuzList"][1:31],
        "rub": L["HizbQuarterList"][1:241],
        "sajda": L["SajdaList"],
        "source": "quran-meta 7.0.0 (MIT) Hafs lists",
    }
    json.dump(meta, open(os.path.join(out, "meta.json"), "w"),
              ensure_ascii=False, separators=(",", ":"))
    print("  meta.json")

    # ---- Quran text ----
    total = sum(len(s["verses"]) for s in en)
    assert total == 6236, total
    write_gz(os.path.join(out, "quran_uthmani.json.gz"), {
        "source": "QuranEnc Uthmani text via quran-json 3.1.2 (CC-BY-SA-4.0)",
        "ayahs": [[v["text"] for v in s["verses"]] for s in en],
    })

    # ---- Translations ----
    write_gz(os.path.join(out, "tr_en_sahih.json.gz"), {
        "name": "Saheeh International", "lang": "en",
        "source": "tanzil.net/trans/en.sahih via quran-json (CC-BY-SA-4.0)",
        "ayahs": [[v["translation"] for v in s["verses"]] for s in en],
    })
    write_gz(os.path.join(out, "tr_fr_hamidullah.json.gz"), {
        "name": "Muhammad Hamidullah", "lang": "fr",
        "source": "tanzil.net/trans/fr.hamidullah via quran-json (CC-BY-SA-4.0)",
        "ayahs": [[v["translation"] for v in s["verses"]] for s in fr],
    })
    ij = os.path.join(src, "islam.js/package/assets")
    it = load_js_export(os.path.join(ij, "translations/QuranItalian.js"))
    assert [len(x) for x in it] == [s["c"] for s in surahs]
    write_gz(os.path.join(out, "tr_it_piccardo.json.gz"), {
        "name": "Hamza Roberto Piccardo", "lang": "it",
        "source": "islam.js 1.3.0 (MIT) translations/QuranItalian",
        "ayahs": it,
    })

    # ---- Tafsir al-Muyassar ----
    tdir = os.path.join(src, "tafsir/tafsir/ar-tafsir-muyassar")
    # The dataset prefixes some verses with a surah introduction ("تسمية
    # السورة / من مقاصد السورة") followed by "[التفسير]". Keep the commentary
    # in the verse and move the introduction to its own per-surah field.
    muy, intros = [], []
    for s in surahs:
        rows = json.load(open(os.path.join(tdir, f"{s['n']}.json")))
        intro = ""
        by = {}
        for r in rows:
            text = r["text"].strip()
            if "[التفسير]" in text:
                head, text = text.split("[التفسير]", 1)
                intro = intro or head.strip()
                text = text.strip()
            by[r["ayah"]] = text
        muy.append([by.get(i, "") for i in range(1, s["c"] + 1)])
        intros.append(intro)
    write_gz(os.path.join(out, "tafsir_muyassar.json.gz"), {
        "name": "التفسير الميسر", "lang": "ar",
        "source": "King Fahd Complex, via github.com/spa5k/tafsir_api (MIT)",
        "ayahs": muy,
        "intros": intros,
    })

    # ---- Azkar (Hisn al-Muslim) ----
    az = load_js_export(os.path.join(ij, "azkar-collection.js"))
    cats = []
    for name, items in az.items():
        rows = []
        for it_ in items:
            text = re.sub(r"\s+", " ", it_["zikr"]).strip()
            try:
                count = int(str(it_.get("count") or "1").strip() or 1)
            except ValueError:
                count = 1
            rows.append({"t": text, "c": max(count, 1),
                         "r": (it_.get("reference") or "").strip()})
        cats.append({"name": name.strip(), "items": rows})
    write_gz(os.path.join(out, "azkar.json.gz"), {
        "source": "حصن المسلم - islam.js 1.3.0 azkar-collection (MIT)",
        "categories": cats,
    })
    # ---- Hadith: An-Nawawi's Forty and Forty Hadith Qudsi ----
    hd = os.path.join(src, "hadith/editions")
    if os.path.isdir(hd):
        cols = []
        for key, ar_name, en_name in [("nawawi", "الأربعون النووية", "An-Nawawi's Forty"),
                                      ("qudsi", "الأحاديث القدسية الأربعون", "Forty Hadith Qudsi")]:
            ar = json.load(open(os.path.join(hd, f"ara-{key}.min.json")))["hadiths"]
            en = {h["hadithnumber"]: h["text"].strip() for h in json.load(open(os.path.join(hd, f"eng-{key}.min.json")))["hadiths"]}
            rows = [{"n": h["hadithnumber"], "ar": h["text"].strip(), "en": en.get(h["hadithnumber"], "")}
                    for h in ar if h["text"].strip()]
            cols.append({"id": key, "ar": ar_name, "en": en_name, "items": rows})
        write_gz(os.path.join(out, "hadith.json.gz"), {
            "source": "github.com/fawazahmed0/hadith-api (Unlicense / public domain)",
            "collections": cols,
        })

    # Word by word (English meaning + transliteration), aligned to our words.
    wp = os.path.join(src, "npm2/holy-quran-word-by-word-full-data-1.0.6/package/data.json")
    if os.path.exists(wp):
        import collections
        import unicodedata
        words = collections.defaultdict(list)
        for page in json.load(open(wp)):
            for ay in page["ayahs"]:
                for w in ay["words"]:
                    if w["char_type_name"] == "word":
                        words[w["parentAyahVerseKey"]].append(
                            (w["position"], w["translation"]["text"] or "", w["transliteration"]["text"] or ""))
        text = json.load(gzip.open(os.path.join(out, "quran_uthmani.json.gz")))["ayahs"]

        def toks(t):
            return [x for x in t.split(" ") if any(unicodedata.category(c).startswith("L") for c in x)]

        rows = []
        for si, surah in enumerate(text, 1):
            rows.append([])
            for ai, t in enumerate(surah, 1):
                ws = sorted(words[f"{si}:{ai}"])
                rows[-1].append([[m, tr] for _, m, tr in ws] if len(ws) == len(toks(t)) else [])
        write_gz(os.path.join(out, "wbw_en.json.gz"), {
            "source": "Word-by-word English meanings and transliteration from Quran.com, as packaged in "
                      "@kmaslesa/holy-quran-word-by-word-full-data 1.0.6 (ISC). Verses whose word split "
                      "differs from the bundled text are left empty.",
            "ayahs": rows,
        })
    print("done")


if __name__ == "__main__":
    sys.exit(main())
