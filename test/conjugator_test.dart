import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_verbs_app/models/verb.dart';
import 'package:japanese_verbs_app/services/conjugator.dart';

/// 정답(expected_forms.json)과 규칙 엔진의 출력이 모든 동사·모든 활용형에서
/// 일치하는지 확인한다.
///
/// 정답의 출처: 1~377번은 엑셀 표, 378번부터는 사전(JMdict) 대조로 그룹·특수 활용을
/// 확인한 뒤 엔진 결과로 만든 것이다. (tool/check_jmdict.py, tool/dump_forms.dart)
void main() {
  const conjugator = Conjugator();

  final verbs =
      (jsonDecode(File('assets/data/verbs.json').readAsStringSync()) as List)
          .map((e) => Verb.fromJson(e as Map<String, dynamic>))
          .toList();
  final expected =
      jsonDecode(File('assets/data/expected_forms.json').readAsStringSync())
          as Map<String, dynamic>;

  // expected_forms.json의 키는 FormType의 이름(form.name)과 같다.

  test('동사 수가 엑셀과 같다', () {
    expect(verbs.length, expected.length);
  });

  for (final verb in verbs) {
    test('${verb.display} (${verb.group.name})', () {
      final row = expected['${verb.id}'] as Map<String, dynamic>;
      for (final form in FormType.values) {
        final want = row[form.name] as List?;
        final got = conjugator.conjugate(verb, form);
        if (want == null) {
          expect(got, isNull, reason: '${verb.text} ${form.label}');
        } else {
          expect(got, isNotNull, reason: '${verb.text} ${form.label}');
          expect(got!.text, want[0], reason: '${verb.text} ${form.label} 표기');
          expect(got.reading, want[1], reason: '${verb.text} ${form.label} 읽기');
        }
      }
    });
  }

  test('行く는 て형이 行って', () {
    final iku = verbs.firstWhere((v) => v.text == '行く');
    expect(conjugator.conjugate(iku, FormType.te)!.text, '行って');
    expect(conjugator.conjugate(iku, FormType.ta)!.text, '行った');
  });

  // 아래는 사전(JMdict)과 대조해서 찾은 특수 동사. expected_forms.json에도 들어 있지만,
  // 규칙을 고칠 때 무엇이 깨졌는지 바로 보이도록 따로 확인한다.
  String? form(String text, FormType f) =>
      conjugator.conjugate(verbs.firstWhere((v) => v.text == text), f)?.text;

  test('くださる형 존경어: ます형 ~います, 명령형 ~い', () {
    for (final (verb, masu, imperative) in [
      ('くださる', 'くださいます', 'ください'),
      ('なさる', 'なさいます', 'なさい'),
      ('おっしゃる', 'おっしゃいます', 'おっしゃい'),
      ('いらっしゃる', 'いらっしゃいます', 'いらっしゃい'),
    ]) {
      expect(form(verb, FormType.masu), masu);
      expect(form(verb, FormType.imperative), imperative);
      expect(form(verb, FormType.te), isNotNull);
      // 실제로 쓰지 않는 활용형은 비워 둔다.
      expect(form(verb, FormType.potential), isNull, reason: verb);
      expect(form(verb, FormType.passive), isNull, reason: verb);
    }
  });

  test('くれる는 명령형이 くれ, 暮れる는 보통 1단', () {
    expect(form('くれる', FormType.imperative), 'くれ');
    expect(form('くれる', FormType.potential), isNull);
    expect(form('暮れる', FormType.imperative), '暮れろ');
    expect(form('暮れる', FormType.potential), isNotNull);
  });

  test('愛する는 愛す처럼 활용', () {
    expect(form('愛する', FormType.nai), '愛さない');
    expect(form('愛する', FormType.potential), '愛せる');
    expect(form('愛する', FormType.volitional), '愛そう');
    expect(form('愛する', FormType.imperative), '愛せ');
    expect(form('愛する', FormType.conditional), '愛すれば');
  });
}
