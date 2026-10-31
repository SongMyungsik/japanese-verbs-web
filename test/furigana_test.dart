import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_verbs_app/models/verb.dart';
import 'package:japanese_verbs_app/services/conjugator.dart';
import 'package:japanese_verbs_app/widgets/furigana.dart';

/// 후리가나 나누기: 한자 부분에만 읽기가 붙고, 이어 붙이면 원래 표기·읽기가 된다.
void main() {
  String joined(List<RubySegment> s) => s.map((e) => e.base).join();
  String joinedReading(List<RubySegment> s) =>
      s.map((e) => e.ruby ?? e.base).join();

  test('書かせられる', () {
    final s = splitRuby('書かせられる', 'かかせられる');
    expect(s.map((e) => '${e.base}/${e.ruby}').toList(), ['書/か', 'かせられる/null']);
  });

  test('道に迷う: 한자 덩어리가 둘', () {
    final s = splitRuby('道に迷う', 'みちにまよう');
    expect(s.map((e) => '${e.base}/${e.ruby}').toList(), [
      '道/みち',
      'に/null',
      '迷/まよ',
      'う/null',
    ]);
  });

  test('가나만 있는 동사는 읽기를 붙이지 않는다', () {
    expect(splitRuby('ほどく', 'ほどく').single.ruby, isNull);
  });

  test('모든 동사·활용형에서 나눈 결과가 표기·읽기와 맞는다', () {
    final verbs =
        (jsonDecode(File('assets/data/verbs.json').readAsStringSync()) as List)
            .map((e) => Verb.fromJson(e as Map<String, dynamic>));
    const conjugator = Conjugator();
    final fallback = <String>[];
    for (final v in verbs) {
      final items = [
        Conjugation(v.text, v.reading),
        ...conjugator.conjugateAll(v).values.whereType<Conjugation>(),
      ];
      for (final c in items) {
        final s = splitRuby(c.text, c.reading);
        expect(joined(s), c.text);
        expect(joinedReading(s), c.reading, reason: c.display);
        // 가나가 섞인 표기인데 통째로 읽기를 올렸다면 맞추기에 실패한 것
        final mixed = RegExp(r'[ぁ-ヿ]').hasMatch(c.text);
        if (mixed && s.length == 1 && s.single.ruby != null) {
          fallback.add(c.display);
        }
      }
    }
    expect(fallback, isEmpty);
  });
}
