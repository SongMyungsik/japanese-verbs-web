"""앱에 넣는 Noto Sans JP 글꼴을 앱에서 쓰는 글자만 남겨 작게 만든다.

verbs.json이나 examples.json에 새 한자가 들어오면 다시 실행한다. (없는 글자는 기기 글꼴로 대신 그려진다.)

    pip install fonttools
    python tool/subset_font.py <원본 NotoSansJP[wght].ttf 경로>

원본: https://github.com/google/fonts/tree/main/ofl/notosansjp (SIL Open Font License 1.1)
결과: assets/fonts/NotoSansJP-subset.ttf
한글은 넣지 않는다. 한글은 기기의 기본 한글 고딕 글꼴로 그려진다.
"""

import pathlib
import sys

from fontTools import subset

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / 'assets' / 'fonts' / 'NotoSansJP-subset.ttf'

# 항상 넣는 범위: 영문·숫자, 일본어 문장부호, 히라가나, 가타카나, 전각 문자
RANGES = [
    (0x0020, 0x007E),
    (0x00B7, 0x00B7),  # ·
    (0x2010, 0x2027),  # ‐ ― … 등
    (0x3000, 0x303F),
    (0x3040, 0x309F),
    (0x30A0, 0x30FF),
    (0xFF01, 0xFF5E),
]


def is_hangul(c: str) -> bool:
    o = ord(c)
    return 0xAC00 <= o <= 0xD7A3 or 0x1100 <= o <= 0x11FF or 0x3130 <= o <= 0x318F


def main() -> None:
    src = sys.argv[1]
    chars = {chr(c) for a, b in RANGES for c in range(a, b + 1)}
    # 동사·예문 등 데이터 폴더의 JSON 전부와 코드
    files = [*(ROOT / 'assets' / 'data').glob('*.json'),
             *(ROOT / 'lib').rglob('*.dart')]
    for f in files:
        if f.exists():
            chars |= {c for c in f.read_text(encoding='utf-8')
                      if ord(c) > 0x7E and not is_hangul(c)}

    OUT.parent.mkdir(parents=True, exist_ok=True)
    options = subset.Options()
    options.layout_features = ['*']  # 세로쓰기·합자 등 기능은 그대로 둔다
    options.name_IDs = ['*']
    options.notdef_outline = True
    font = subset.load_font(src, options)
    subsetter = subset.Subsetter(options)
    subsetter.populate(text=''.join(sorted(chars)))
    subsetter.subset(font)
    subset.save_font(font, str(OUT), options)
    print(f'{len(chars)}자 → {OUT} ({OUT.stat().st_size // 1024} KB)')


if __name__ == '__main__':
    main()
