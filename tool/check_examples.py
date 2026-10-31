"""예문(assets/data/examples.json)을 검사한다.

    python tool/check_examples.py

확인하는 것
  - 모든 동사에 예문이 있는지
  - 예문에 그 동사가 들어 있는지 (사전형에서 마지막 글자(する동사는 する)를 뺀 부분이 있는지)
  - 읽기가 표기와 맞물리는지: 한자가 아닌 글자(가나·문장부호·영숫자)는 읽기에 그대로 있고,
    한자 부분마다 히라가나 읽기가 붙는지 (앱의 후리가나와 같은 방식)
  - 같은 예문이 두 번 나오지 않는지
"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent


def is_kanji(c):
    o = ord(c)
    return 0x4E00 <= o <= 0x9FFF or 0x3400 <= o <= 0x4DBF or c in '々ヶ'


def split_ruby(text, reading):
    """lib/widgets/furigana.dart의 splitRuby와 같은 방식. 실패하면 None."""
    chunks = []
    for c in text:
        k = is_kanji(c)
        if chunks and chunks[-1][1] == k:
            chunks[-1][0] += c
        else:
            chunks.append([c, k])
    # 나누는 방법이 여러 가지면 한자 한 글자에 읽기 두 글자 정도 붙는 쪽을 고른다.
    from functools import lru_cache

    @lru_cache(maxsize=None)
    def best(i, pos):
        if i == len(chunks):
            return (0, ()) if pos == len(reading) else None
        t, k = chunks[i]
        if not k:
            return best(i + 1, pos + len(t)) if reading.startswith(t, pos) else None
        result = None
        for end in range(pos + 1, len(reading) + 1):
            rest = best(i + 1, end)
            if rest is None:
                continue
            cost = rest[0] + abs((end - pos) - 2 * len(t))
            if result is None or cost < result[0]:
                result = (cost, (end,) + rest[1])
        return result

    found = best(0, 0)
    if found is None:
        return None
    ends = iter(found[1])
    out, pos = [], 0
    for t, k in chunks:
        if k:
            end = next(ends)
            out.append((t, reading[pos:end]))
            pos = end
        else:
            out.append((t, None))
            pos += len(t)
    return out


def main():
    sys.stdout.reconfigure(encoding='utf-8')
    verbs = json.loads((ROOT / 'assets/data/verbs.json').read_text('utf-8'))
    examples = json.loads((ROOT / 'assets/data/examples.json').read_text('utf-8'))
    problems = 0
    seen = {}
    for v in verbs:
        e = examples.get(str(v['id']))
        if e is None:
            print(f"예문 없음  {v['id']} {v['text']}")
            problems += 1
            continue
        ja, rd = e['ja'], e['reading']
        # 書く→書, する동사는 する를 뺀 부분 (勉強する→勉強: 勉強し·勉強を…)
        text = v['text']
        stem = text[:-2] if text.endswith('する') else text[:-1]
        if stem not in ja:
            print(f"동사 없음  {v['id']} {v['text']}: {ja}")
            problems += 1
        segs = split_ruby(ja, rd)
        if segs is None:
            print(f"읽기 불일치 {v['id']}: {ja} / {rd}")
            problems += 1
        else:
            for base, ruby in segs:
                if ruby is not None and not re.fullmatch('[ぁ-ゖー]+', ruby):
                    print(f"읽기 이상  {v['id']}: {base} → {ruby}")
                    problems += 1
        if ja in seen:
            print(f"중복 예문  {v['id']} = {seen[ja]}: {ja}")
            problems += 1
        seen[ja] = v['id']
    print(f'예문 {len(examples)}개, 문제 {problems}건')
    sys.exit(1 if problems else 0)


if __name__ == '__main__':
    main()
