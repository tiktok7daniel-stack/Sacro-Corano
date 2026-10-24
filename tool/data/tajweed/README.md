# Tajweed annotations

`assets/data/tajweed.json.gz` holds, for every verse of the bundled Uthmani
text, colour runs `[start, end, class]` in **code points**. It is produced by
running the open tajweed engine of [quran-ws/quran-tajweed](https://github.com/quran-ws/quran-tajweed)
(code MIT; rule corpus CC BY 4.0, a scholar-authored corpus for Hafs ʿan ʿĀsim)
over the app's own text, so the offsets always match it.

```sh
git clone --depth 1 https://github.com/quran-ws/quran-tajweed /tmp/qws
mkdir -p /tmp/tj && cp -r /tmp/qws/packages/core/src /tmp/tj/src
sed -i "s#from '\./\([a-z]*\)\.js'#from './\1.ts'#g" /tmp/tj/src/*.ts
cp tool/data/tajweed/build.ts /tmp/tj/
# build.ts reads the rules from /tmp/claude-0/dl/qws/...; or set TAJWEED_RULES
node --experimental-transform-types /tmp/tj/build.ts assets/data/quran_uthmani.json.gz /tmp/tajweed.json
gzip -9 -n -c /tmp/tajweed.json > assets/data/tajweed.json.gz
```

Classes, by priority when rules overlap: `madd_lazim`, `madd_wajib`
(muttasil), `madd_jaiz` (munfasil), `ghunnah` (noon/meem mushaddadah, ikhfa,
iqlab, idgham with ghunnah, shafawi), `silent` (idgham without ghunnah /
complete), `qalqalah`, `tafkheem` (heavy raa and the heavy lam of the Name).
The run counts match the project's published annotations for the same rules.
