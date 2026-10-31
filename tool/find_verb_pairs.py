"""자동사·타동사 짝 후보를 뽑는다. (開く/開ける, 起きる/起こす 등)

    python tool/find_verb_pairs.py JMdict_e.gz candidates.csv

기준: verbs.json 안에서 한자 부분(앞쪽의 가나가 아닌 글자)이 같고,
JMdict에서 한쪽은 자동사(vi), 다른 쪽은 타동사(vt)로만 표시된 동사.
결과 CSV를 검토한 뒤 확정한 짝을 assets/data/verb_pairs.json에 적는다.
JMdict는 tool/check_jmdict.py의 설명을 참고.
"""
import csv
import gzip
import json
import pathlib
import re
import sys
import xml.etree.ElementTree as ET
from collections import defaultdict

ROOT = pathlib.Path(__file__).resolve().parent.parent


def is_kana(c):
    return 'ぁ' <= c <= 'ヿ'


def kanji_stem(text):
    """앞쪽의 한자 부분. 開く → 開, 片付ける → 片付 (가나가 나오기 전까지)"""
    out = ''
    for c in text:
        if is_kana(c):
            break
        out += c
    return out


def load_transitivity(path):
    """(표기, 읽기) → {'vi', 'vt'} 중 사전에 적힌 것"""
    raw = gzip.open(path, 'rb').read().decode('utf-8')
    raw = re.sub(r'<!DOCTYPE.*?\]>', '', raw, flags=re.S)
    raw = re.sub(r'&(?!amp;|lt;|gt;|quot;|apos;)([A-Za-z0-9\-]+);', r'\1', raw)
    out = defaultdict(set)
    for e in ET.fromstring(raw).iter('entry'):
        pos = {p.text for p in e.iter('pos')} & {'vi', 'vt'}
        if not pos:
            continue
        kebs = {k.text for k in e.iter('keb')}
        rebs = {r.text for r in e.iter('reb')}
        for k in kebs | rebs:
            for r in rebs:
                out[(k, r)] |= pos
    return out


def main():
    sys.stdout.reconfigure(encoding='utf-8')
    trans = load_transitivity(sys.argv[1])
    verbs = json.loads((ROOT / 'assets/data/verbs.json').read_text('utf-8'))
    by_stem = defaultdict(list)
    for v in verbs:
        if v['text'].endswith('する'):
            continue
        stem = kanji_stem(v['text'])
        if stem:
            v['tr'] = trans.get((v['text'], v['reading']), set())
            by_stem[stem].append(v)

    rows = []
    for stem, group in by_stem.items():
        vis = [v for v in group if v['tr'] == {'vi'}]
        vts = [v for v in group if v['tr'] == {'vt'}]
        for a in vis:
            for b in vts:
                rows.append([a['id'], a['text'], a['reading'], a['meaning'],
                             b['id'], b['text'], b['reading'], b['meaning']])
    rows.sort()
    with open(sys.argv[2], 'w', encoding='utf-8-sig', newline='') as f:
        w = csv.writer(f)
        w.writerow(['자동사 id', '자동사', '읽기', '뜻',
                    '타동사 id', '타동사', '읽기', '뜻'])
        w.writerows(rows)
    for r in rows:
        print(*r, sep=' | ')
    print(len(rows), '쌍')


if __name__ == '__main__':
    main()
