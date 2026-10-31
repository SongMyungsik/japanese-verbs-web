import 'package:flutter/material.dart';

/// 후리가나 한 조각: [base]는 본문 글자, [ruby]는 그 위에 작게 올릴 읽기 (없으면 null)
class RubySegment {
  final String base;
  final String? ruby;
  const RubySegment(this.base, [this.ruby]);
}

/// 한자인지 (々 같은 반복 기호와 一ヶ月의 ヶ 포함). 한자에만 읽기를 붙인다.
bool _isKanji(int c) =>
    (c >= 0x4E00 && c <= 0x9FFF) || // 한자
    (c >= 0x3400 && c <= 0x4DBF) || // 한자 확장 A
    c == 0x3005 || // 々
    c == 0x30F6; // ヶ

/// 표기와 읽기를 맞춰서 한자 부분에만 읽기를 붙인다.
/// 예: 書かせられる / かかせられる → [書(か)] [かせられる]
///
/// 표기를 한자 덩어리와 나머지(가나·문장부호·영숫자) 덩어리로 나누고, 나머지 덩어리를
/// 읽기에서 그대로 찾아 그 사이에 남는 읽기를 한자 덩어리에 준다.
/// 그래서 예문처럼 。、가 섞인 문장도 다룰 수 있다. 맞출 수 없으면 표기 전체 위에 읽기를 올린다.
///
/// 나누는 방법이 여러 가지일 때가 있다. 昨日の(きのうの)는 昨日=き로도 맞아 버린다.
/// 그래서 가능한 나누기 중 한자 한 글자에 읽기가 두 글자 정도 붙는 쪽을 고른다.
/// (tool/check_examples.py의 split_ruby와 같은 방식)
List<RubySegment> splitRuby(String text, String reading) {
  if (text == reading || reading.isEmpty) return [RubySegment(text)];

  final chunks = <String>[];
  final kana = <bool>[]; // true = 한자가 아닌 덩어리 (읽기에 그대로 나온다)
  for (final r in text.runes) {
    final ch = String.fromCharCode(r);
    final k = !_isKanji(r);
    if (chunks.isNotEmpty && kana.last == k) {
      chunks.last += ch;
    } else {
      chunks.add(ch);
      kana.add(k);
    }
  }

  // best(i, pos): chunks[i..]를 reading[pos..]에 맞추는 가장 좋은 방법
  //   (비용, 한자 덩어리마다 읽기가 끝나는 위치). 맞출 수 없으면 null.
  final memo = <int, (int, List<int>)?>{};
  (int, List<int>)? best(int i, int pos) {
    if (i == chunks.length) return pos == reading.length ? (0, const []) : null;
    final key = i * (reading.length + 1) + pos;
    if (memo.containsKey(key)) return memo[key];
    (int, List<int>)? result;
    if (kana[i]) {
      if (reading.startsWith(chunks[i], pos)) {
        result = best(i + 1, pos + chunks[i].length);
      }
    } else {
      for (var end = pos + 1; end <= reading.length; end++) {
        final rest = best(i + 1, end);
        if (rest == null) continue;
        final cost = rest.$1 + ((end - pos) - 2 * chunks[i].length).abs();
        if (result == null || cost < result.$1) {
          result = (cost, [end, ...rest.$2]);
        }
      }
    }
    return memo[key] = result;
  }

  final found = best(0, 0);
  if (found == null) return [RubySegment(text, reading)];

  final ends = found.$2.iterator;
  var pos = 0;
  final out = <RubySegment>[];
  for (var i = 0; i < chunks.length; i++) {
    if (kana[i]) {
      out.add(RubySegment(chunks[i]));
      pos += chunks[i].length;
    } else {
      ends.moveNext();
      out.add(RubySegment(chunks[i], reading.substring(pos, ends.current)));
      pos = ends.current;
    }
  }
  return out;
}

/// 문장 안에 끼워 넣는 후리가나. `Text.rich(TextSpan(children: [furiganaSpan(...), ...]))`처럼 쓴다.
/// 한자 덩어리는 위에 읽기를 얹은 작은 위젯으로, 나머지는 보통 글자로 넣는다.
/// [style]은 크기·색을 정하는 데 쓰며, 비워 두면 주변 글자 모양을 따른다.
InlineSpan furiganaSpan(
  BuildContext context,
  String text,
  String reading, {
  TextStyle? style,
  bool showRuby = true,
}) {
  if (!showRuby) return TextSpan(text: text, style: style);

  final base = DefaultTextStyle.of(context).style.merge(style);
  final rubyStyle = base.copyWith(
    fontSize: (base.fontSize ?? 14) * 0.5,
    height: 1.1,
    fontWeight: FontWeight.normal,
  );
  final segments = splitRuby(text, reading);
  Widget ruby(String top, String bottom) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(top, style: rubyStyle, maxLines: 1),
      Text(bottom, style: base, maxLines: 1),
    ],
  );
  return TextSpan(
    style: style,
    children: [
      // 가나만 있는 말(ほどく 등)도 읽기가 있는 말과 같은 높이를 차지하게 폭 0의 자리를 둔다.
      if (segments.every((s) => s.ruby == null))
        WidgetSpan(
          alignment: PlaceholderAlignment.bottom,
          child: ruby(_zeroWidth, _zeroWidth),
        ),
      for (final s in segments)
        if (s.ruby == null)
          TextSpan(text: s.base)
        else
          // 아래쪽을 줄 아래쪽에 맞추면 한자가 옆 글자와 같은 높이에 놓인다.
          WidgetSpan(
            alignment: PlaceholderAlignment.bottom,
            child: ruby(s.ruby!, s.base),
          ),
    ],
  );
}

/// 한자 위에 작은 히라가나를 올려 보여 주는 글자 (한 줄).
/// [showRuby]가 false면 표기만 보여 준다.
class Furigana extends StatelessWidget {
  const Furigana({
    super.key,
    required this.text,
    required this.reading,
    this.style,
    this.showRuby = true,
    this.textAlign,
  });

  final String text;
  final String reading;
  final TextStyle? style;
  final bool showRuby;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      furiganaSpan(context, text, reading, style: style, showRuby: showRuby),
      style: style,
      textAlign: textAlign,
    );
  }
}

/// 폭이 0인 공백 (자리만 차지하고 보이지 않는다)
final String _zeroWidth = String.fromCharCode(0x200B);
