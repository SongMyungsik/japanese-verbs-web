import 'verb.dart';

/// 4지선다 문제 하나: "{동사}의 {활용형}은?"
class QuizQuestion {
  final Verb verb;
  final FormType form;
  final Conjugation answer;
  final List<Conjugation> choices; // answer를 포함한 4개 (섞인 순서)

  const QuizQuestion({
    required this.verb,
    required this.form,
    required this.answer,
    required this.choices,
  });

  int get answerIndex => choices.indexOf(answer);
}
