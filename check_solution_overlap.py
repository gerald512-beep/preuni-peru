import json, re, itertools, difflib, statistics, sys
sys.stdout.reconfigure(encoding='utf-8')

BATCH = 'bulk_data/sanmarcos_2026_2.json'
MD = r'C:\Users\smart\MinerU\SOLUCIONARIO SAN MARCOS 2026 II.pdf-200a03fa-3994-4a9a-a8af-e026cf82c8f3\full.md'

recs = {r['numero']: r for r in json.load(open(BATCH, encoding='utf-8'))}
pilot = json.load(open('bulk_data/independent_solutions_sanmarcos_2026_2.json', encoding='utf-8'))
md = open(MD, encoding='utf-8').read()
parts = re.split(r'^## Pregunta (\d+)\s*$', md, flags=re.M)
academy = {}
for i in range(1, len(parts), 2):
    n = int(parts[i])
    body = parts[i + 1]
    m = re.search(r'Resoluci[oó]n|Sustentaci[oó]n', body)
    academy[n] = body[m.start():] if m else ''


def toks(s):
    s = re.sub(r'<!--.*?-->', ' ', s, flags=re.S).lower()
    return re.findall(r'[0-9a-záéíóúüñ]+', s)


def grams(t, n=4):
    return {tuple(t[i:i + n]) for i in range(len(t) - n + 1)}


def overlap(mine, theirs):
    a, b = toks(mine), toks(theirs)
    ga, gb = grams(a), grams(b)
    frac = len(ga & gb) / len(ga) if ga else 0.0
    sm = difflib.SequenceMatcher(None, a, b, autojunk=False)
    run = sm.find_longest_match(0, len(a), 0, len(b)).size
    return frac, run


print('== Pilot: independent solution vs academy original / vs currently published text')
print('num | key | mine | ov(academy) run | ov(published) run')
for n_str, p in pilot.items():
    n = int(n_str)
    r = recs[n]
    fa, ra = overlap(p['text'], academy.get(n, ''))
    fp, rp = overlap(p['text'], r['solutionBody'])
    print(f"{n:>3} | {r['clave']} | {p['answer'][:22]:<22} | {fa:5.0%} {ra:>3} | {fp:5.0%} {rp:>3}")

print()
print('== All 90: currently published solutionBody vs academy original (share of 4-grams copied)')
fr, runs = [], []
for n, r in recs.items():
    sb = r['solutionBody']
    if not sb or not academy.get(n):
        continue
    f, run = overlap(sb, academy[n])
    fr.append(f)
    runs.append(run)
print('records compared:', len(fr))
print('mean 4-gram overlap: %.0f%%   median: %.0f%%' % (statistics.mean(fr) * 100, statistics.median(fr) * 100))
print('>=50%% overlap: %d   >=25%%: %d   <10%%: %d' % (sum(f >= .5 for f in fr), sum(f >= .25 for f in fr), sum(f < .10 for f in fr)))
print('longest verbatim run (words): mean %.1f  max %d' % (statistics.mean(runs), max(runs)))

# brute-force check of N28
W = [('S', 'W')] * 6 + [('S', 'B')] * 5 + [('C', 'W')] * 3 + [('C', 'B')] * 4
def has_pair(cnt):
    return any(cnt.get(('S', c), 0) > 0 and cnt.get(('C', c), 0) > 0 for c in 'WB')
avail = {('S', 'W'): 6, ('S', 'B'): 5, ('C', 'W'): 3, ('C', 'B'): 4}
worst = 0
for a, b, c, d in itertools.product(range(7), range(6), range(4), range(5)):
    cnt = {('S', 'W'): a, ('S', 'B'): b, ('C', 'W'): c, ('C', 'B'): d}
    if not has_pair(cnt):
        worst = max(worst, a + b + c + d)
print()
print('N28 brute force: largest draw without a same-colour sphere+cube pair =', worst, '-> minimum to guarantee =', worst + 1)
