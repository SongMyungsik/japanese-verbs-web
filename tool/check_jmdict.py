"""verbs.json의 그룹·어미를 일본어 사전 JMdict의 품사(활용 종류)와 대조한다.

동사를 추가하거나 고친 뒤, 정답(expected_forms.json)을 갱신하기 전에 실행한다.

    # JMdict 받기 (약 10MB, 검사용으로만 쓰고 앱에는 넣지 않는다)
    curl -L -o JMdict_e.gz http://ftp.edrdg.org/pub/Nihongo/JMdict_e.gz
    python tool/check_jmdict.py JMdict_e.gz

결과
    OK        사전과 그룹·어미가 같다
    HANDLED   특수 활용이지만 엔진(conjugator.dart)이 이미 처리한다
    SPECIAL   특수 활용인데 엔진이 아직 처리하지 않는다 → 엔진에 규칙 추가 필요
    MISMATCH  그룹·어미가 사전과 다르다 → verbs.json 확인 필요
    NOT_FOUND 사전에서 찾지 못했다 → 직접 확인

SPECIAL·MISMATCH·NOT_FOUND가 없으면 다음으로 정답을 갱신한다.
    dart run tool/dump_forms.dart assets/data/expected_forms.json

JMdict: Electronic Dictionary Research and Development Group, CC BY-SA 4.0
"""
import gzip
import json
import pathlib
import re
import sys
import xml.etree.ElementTree as ET
from collections import Counter, defaultdict

ROOT = pathlib.Path(__file__).resolve().parent.parent
VERB_POS = re.compile(r'^(v1|v1-s|v5.*|vs|vs-i|vs-s|vs-c|vk|vz)$')

# 사전 품사 → 5단 어미
GODAN_END = {'v5u': 'う', 'v5k': 'く', 'v5g': 'ぐ', 'v5s': 'す', 'v5t': 'つ',
             'v5n': 'ぬ', 'v5b': 'ぶ', 'v5m': 'む', 'v5r': 'る',
             'v5k-s': 'く', 'v5u-s': 'う', 'v5r-i': 'る', 'v5aru': 'る'}

# 규칙에서 벗어나는 활용 종류
SPECIAL = {
    'v5k-s': '行く형: て형이 ~って',
    'v5r-i': 'ある: ない형이 ない',
    'v5aru': 'くださる형: ます형 ~います, 명령형 ~い',
    'v5u-s': '問う형: て형이 ~うて, た형이 ~うた',
    'v1-s': 'くれる형: 명령형이 くれ',
    'vz': 'ずる동사: ~じる와 비슷하게 활용',
    'vs-s': '한 글자 한자+する(愛する 등): 5단 ~す처럼 활용하는 형태가 있음',
    'vs-c': '옛 する동사',
}

# 엔진(lib/services/conjugator.dart)이 이미 처리하는 특수 동사 (표기 기준).
# 엔진에 예외 규칙을 추가하면 여기에도 적는다.
HANDLED = {
    '行く', 'ある',
    'くださる', 'なさる', 'おっしゃる', 'いらっしゃる',
    'くれる', '呉れる',
    '愛する',
}


def load_index(path):
    """표기(한자·가나 모두) → [(읽기 집합, 품사 집합)]"""
    raw = gzip.open(path, 'rb').read().decode('utf-8')
    # 품사는 &v5r; 같은 엔티티로 적혀 있다. 이름 그대로 남기려고 파싱 전에 바꾼다.
    raw = re.sub(r'<!DOCTYPE.*?\]>', '', raw, flags=re.S)
    raw = re.sub(r'&(?!amp;|lt;|gt;|quot;|apos;)([A-Za-z0-9\-]+);', r'\1', raw)
    index = defaultdict(list)
    for e in ET.fromstring(raw).iter('entry'):
        pos = {p.text for p in e.iter('pos') if VERB_POS.match(p.text or '')}
        if not pos:
            continue
        kebs = {k.text for k in e.iter('keb')}
        rebs = {r.text for r in e.iter('reb')}
        for w in kebs | rebs:  # できる처럼 가나로 적은 동사도 찾는다
            index[w].append((rebs, pos))
    return index


def lookup(index, text, reading):
    """표기·읽기가 맞는 모든 사전 항목의 품사를 모은다. → (품사 집합, 찾은 방법)"""
    pos = set()
    for rebs, p in index.get(text, []):
        if reading in rebs:
            pos |= p
    if pos:
        return pos, 'exact'
    # 勉強する: 사전에는 勉強(vs)로 실려 있다.
    if text.endswith('する') and reading.endswith('する'):
        for rebs, p in index.get(text[:-2], []):
            if reading[:-2] in rebs:
                pos |= p & {'vs', 'vs-i', 'vs-s'}
        if pos:
            return pos, 'suru-noun'
    # 道に迷う 같은 구: 뒤쪽의 가장 긴 동사로 판단한다.
    for i in range(1, len(text)):
        tail = text[i:]
        for rebs, p in index.get(tail, []):
            if any(reading.endswith(r) for r in rebs):
                pos |= p
        if pos:
            return pos, f'tail:{tail}'
    return set(), 'none'


def groups_of(pos):
    """사전 품사 → 가능한 (그룹, 어미) 집합"""
    out = set()
    for p in pos:
        if p in ('v1', 'v1-s'):
            out.add(('ichidan', 'る'))
        elif p in GODAN_END:
            out.add(('godan', GODAN_END[p]))
        elif p in ('vs', 'vs-i', 'vs-s', 'vs-c', 'vk', 'vz'):
            out.add(('irregular', 'る'))
    return out


def main():
    sys.stdout.reconfigure(encoding='utf-8')
    index = load_index(sys.argv[1])
    verbs = json.loads((ROOT / 'assets/data/verbs.json').read_text('utf-8'))
    results = Counter()
    for v in verbs:
        pos, how = lookup(index, v['text'], v['reading'])
        specials = sorted(p for p in pos if p in SPECIAL)
        if not pos:
            status = 'NOT_FOUND'
        elif (v['group'], v['ending']) not in groups_of(pos):
            status = 'MISMATCH'
        elif specials:
            status = 'HANDLED' if v['text'] in HANDLED else 'SPECIAL'
        else:
            status = 'OK'
        results[status] += 1
        if status != 'OK':
            note = '; '.join(SPECIAL[p] for p in specials)
            print(f"{status:9} {v['id']:>4} {v['text']}({v['reading']}) "
                  f"{v['group']}/{v['ending']}  사전: {','.join(sorted(pos))} "
                  f"[{how}] {note}")
    print(dict(results))


if __name__ == '__main__':
    main()
