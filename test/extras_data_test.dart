import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_verbs_app/widgets/furigana.dart';

/// 예문(examples.json)과 자동사·타동사 짝(verb_pairs.json)이 앱에서 쓸 수 있는 상태인지 확인한다.
/// 내용(문장이 자연스러운지 등)은 tool/check_examples.py와 사람의 검토로 확인한다.
void main() {
  final verbs =
      (jsonDecode(File('assets/data/verbs.json').readAsStringSync()) as List)
          .cast<Map<String, dynamic>>();
  final ids = {for (final v in verbs) v['id'] as int};
  final examples =
      jsonDecode(File('assets/data/examples.json').readAsStringSync())
          as Map<String, dynamic>;
  final pairs =
      (jsonDecode(File('assets/data/verb_pairs.json').readAsStringSync())
              as List)
          .cast<Map<String, dynamic>>();

  test('모든 동사에 예문이 있다', () {
    expect(examples.keys.map(int.parse).toSet(), ids);
  });

  test('예문의 읽기가 한자 위치에 맞게 나뉜다', () {
    final kanji = RegExp(r'[一-鿿々]');
    for (final e in examples.entries) {
      final ja = e.value['ja'] as String;
      final reading = e.value['reading'] as String;
      final s = splitRuby(ja, reading);
      // 통째로 읽기를 올렸다면 맞추기에 실패한 것
      final failed =
          kanji.hasMatch(ja) && s.length == 1 && s.single.ruby != null;
      expect(failed, isFalse, reason: '${e.key}: $ja');
      expect(s.map((x) => x.ruby ?? x.base).join(), reading, reason: e.key);
    }
  });

  test('짝은 서로 다른 두 동사를 가리킨다', () {
    for (final p in pairs) {
      final a = p['intransitive'] as int, b = p['transitive'] as int;
      expect(ids, contains(a));
      expect(ids, contains(b));
      expect(a, isNot(b));
    }
    final keys = pairs.map((p) => '${p['intransitive']}-${p['transitive']}');
    expect(keys.toSet().length, pairs.length, reason: '같은 짝이 두 번 있음');
  });

  test('昨日の처럼 뒤의 가나가 읽기 안에도 있는 경우를 바르게 나눈다', () {
    final s = splitRuby('昨日の試合', 'きのうのしあい');
    expect(s.map((e) => '${e.base}/${e.ruby}').toList(), [
      '昨日/きのう',
      'の/null',
      '試合/しあい',
    ]);
  });
}
