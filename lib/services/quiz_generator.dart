import 'dart:math';

import '../models/quiz_question.dart';
import '../models/verb.dart';
import 'conjugator.dart';

class _Pair {
  final Verb verb;
  final FormType form;
  const _Pair(this.verb, this.form);
}

/// 동사 × 활용형 조합에서 4지선다 문제를 만든다.
///
/// 오답 보기는 두 가지에서 뽑는다.
///  1. 흔한 실수: 다른 활용 규칙을 잘못 적용한 형태 (예: 読んで → 読って)
///  2. 같은 동사의 다른 활용형 (예: て형 문제에 ます형을 보기로)
class QuizGenerator {
  QuizGenerator({Random? random, Conjugator conjugator = const Conjugator()})
    : _random = random ?? Random(),
      _conj = conjugator;

  final Random _random;
  final Conjugator _conj;

  static const List<String> _godanEndings = [
    'う',
    'く',
    'ぐ',
    'す',
    'つ',
    'ぬ',
    'ぶ',
    'む',
    'る',
  ];

  List<QuizQuestion> generate({
    required List<Verb> verbs,
    required List<FormType> forms,
    int count = 10,
  }) {
    final pairs = <_Pair>[];
    for (final v in verbs) {
      for (final f in forms) {
        // 활용이 성립하지 않는 조합(できる의 가능형 등)은 출제하지 않는다.
        if (_conj.conjugate(v, f) != null) pairs.add(_Pair(v, f));
      }
    }
    pairs.shuffle(_random);
    return [for (final p in pairs.take(count)) _build(p.verb, p.form)];
  }

  /// 지정한 (동사, 활용형)으로 문제 하나를 만든다. 활용이 성립하지 않으면 null.
  /// 복습 화면에서 기록된 항목을 다시 출제할 때 쓴다.
  QuizQuestion? questionFor(Verb verb, FormType form) =>
      _conj.conjugate(verb, form) == null ? null : _build(verb, form);

  QuizQuestion _build(Verb verb, FormType form) {
    final answer = _conj.conjugate(verb, form)!;

    final mistakes = <Conjugation>[];
    for (final wrong in _mistakeVerbs(verb)) {
      final c = _conj.conjugate(wrong, form);
      if (c != null) mistakes.add(c);
    }
    final others = <Conjugation>[];
    for (final f in FormType.values) {
      if (f == form) continue;
      final c = _conj.conjugate(verb, f);
      if (c != null) others.add(c);
    }
    mistakes.shuffle(_random);
    others.shuffle(_random);

    // 흔한 실수 2개를 우선하고, 모자라면 다른 활용형, 그래도 모자라면 남은 실수로 채운다.
    final ordered = [...mistakes.take(2), ...others, ...mistakes.skip(2)];
    final distractors = <Conjugation>[];
    for (final c in ordered) {
      if (c == answer || distractors.contains(c)) continue;
      distractors.add(c);
      if (distractors.length == 3) break;
    }

    final choices = [answer, ...distractors]..shuffle(_random);
    return QuizQuestion(
      verb: verb,
      form: form,
      answer: answer,
      choices: choices,
    );
  }

  /// 같은 동사를 다른 규칙으로 활용한 것처럼 만든 복제본 (오답 생성용)
  List<Verb> _mistakeVerbs(Verb v) {
    final result = <Verb>[];
    if (v.group != VerbGroup.ichidan) {
      result.add(_copy(v, VerbGroup.ichidan, v.ending));
    }
    for (final e in _godanEndings) {
      if (v.group == VerbGroup.godan && e == v.ending) continue;
      result.add(_copy(v, VerbGroup.godan, e));
    }
    return result;
  }

  Verb _copy(Verb v, VerbGroup group, String ending) => Verb(
    id: v.id,
    text: v.text,
    reading: v.reading,
    meaning: v.meaning,
    group: group,
    ending: ending,
  );
}
