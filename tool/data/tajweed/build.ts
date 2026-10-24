import { readFileSync, writeFileSync } from 'node:fs'
import { gunzipSync } from 'node:zlib'
import { Tajweed } from './src/index.ts'

const corpus = JSON.parse(readFileSync('process.env.TAJWEED_RULES ?? '/tmp/qws/packages/rules/rules.json'', 'utf8'))
const t = new Tajweed(corpus)
const quran = JSON.parse(gunzipSync(readFileSync(process.argv[2])).toString('utf8'))

// Display classes, highest priority first.
const classes: [string, (h: string) => boolean][] = [
  ['madd_lazim', (h) => h.startsWith('madd-lazim')],
  ['madd_wajib', (h) => h === 'madd-muttasil'],
  ['madd_jaiz', (h) => h === 'madd-munfasil'],
  ['ghunnah', (h) => /^(noon|meem)-mushaddadah$|^idgham-bi-ghunnah|^ikhfa-haqiqi|^iqlab|^ikhfa-shafawi|^idgham-shafawi|^idgham-naqis|^mutajanisain-ikhfa-shafawi/.test(h)],
  ['silent', (h) => /^idgham-bila-ghunnah|^idgham-kamil|^mutamathilain-idgham-kamil|^mutajanisain-idgham-naqis/.test(h)],
  ['qalqalah', (h) => h.startsWith('qalqalah')],
  ['tafkheem', (h) => h === 'raa-tafkheem' || h === 'lam-jalalah-tafkheem'],
]
const isMark = (c: string) => /\p{M}/u.test(c)
const counts: Record<string, number> = {}
const out: number[][][] = []
for (const surah of quran.ayahs as string[][]) {
  const s: number[][] = []
  for (const text of surah) {
    const cps = [...text]
    const cls = new Array<number>(cps.length).fill(-1)
    for (const span of t.analyze(text)) {
      const k = classes.findIndex(([, f]) => f(span.hukumId))
      if (k < 0) continue
      let end = span.end
      while (end < cps.length && isMark(cps[end])) end++
      for (let i = span.start; i < end; i++) if (cls[i] < 0 || k < cls[i]) cls[i] = k
    }
    const flat: number[] = []
    for (let i = 0; i < cps.length; ) {
      if (cls[i] < 0) { i++; continue }
      let j = i
      while (j < cps.length && cls[j] === cls[i]) j++
      flat.push(i, j, cls[i]); counts[classes[cls[i]][0]] = (counts[classes[cls[i]][0]] ?? 0) + 1
      i = j
    }
    s.push(flat)
  }
  out.push(s)
}
writeFileSync(process.argv[3], JSON.stringify({
  source: 'quran.ws tajwid engine 0.1.0 (MIT) + rule corpus @quran.ws/tajwid-rules 0.1.0 (CC BY 4.0), computed on this app\'s Uthmani text; offsets are code points',
  classes: classes.map(([n]) => n),
  ayahs: out,
}))
console.log(counts)
