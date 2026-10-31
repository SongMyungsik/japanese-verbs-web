import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_verbs_app/models/verb.dart';
import 'package:japanese_verbs_app/services/quiz_generator.dart';

/// 모든 동사 × 활용형에서 보기 4개가 서로 다르고 정답을 포함하는지 확인한다.
void main() {
  final verbs =
      (jsonDecode(File('assets/data/verbs.json').readAsStringSync()) as List)
          .map((e) => Verb.fromJson(e as Map<String, dynamic>))
          .toList();

  test('모든 조합에서 중복 없는 4지선다가 만들어진다', () {
    final gen = QuizGenerator(random: Random(1));
    final questions = gen.generate(
      verbs: verbs,
      forms: FormType.values,
      count: 100000, // 전부 출제
    );
    expect(questions, isNotEmpty);
    for (final q in questions) {
      final label = '${q.verb.text} ${q.form.label}';
      expect(q.choices.length, 4, reason: label);
      expect(q.choices.toSet().length, 4, reason: '$label 보기 중복');
      expect(q.choices.contains(q.answer), isTrue, reason: label);
    }
  });

  test('できる의 가능형·명령형은 출제되지 않는다', () {
    final dekiru = verbs.where((v) => v.text == 'できる').toList();
    final gen = QuizGenerator(random: Random(1));
    final questions = gen.generate(
      verbs: dekiru,
      forms: [FormType.potential, FormType.imperative],
      count: 10,
    );
    expect(questions, isEmpty);
  });
}
