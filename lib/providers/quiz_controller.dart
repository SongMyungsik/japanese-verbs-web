import 'package:flutter/foundation.dart';

import '../models/quiz_question.dart';
import '../services/verb_repository.dart';

/// 문제 방식
enum QuizMode {
  choice, // 4지선다
  tiles, // 글자 맞추기: 히라가나 조각을 눌러 답을 만든다 (일본어 자판 없이)
}

extension QuizModeLabel on QuizMode {
  String get label => switch (this) {
    QuizMode.choice => '4지선다',
    QuizMode.tiles => '글자 맞추기',
  };
}

/// 퀴즈 한 판의 진행 상태. 풀이 화면이 열릴 때마다 새로 만든다.
class QuizController extends ChangeNotifier {
  QuizController({
    required this.questions,
    required this.repo,
    this.mode = QuizMode.choice,
  });

  final List<QuizQuestion> questions;
  final VerbRepository repo;
  final QuizMode mode;

  int _index = 0;
  int? _selected; // 4지선다: 지금 문제에서 고른 보기 번호
  String? _typed; // 글자 맞추기: 지금 문제에 만든 답
  final List<bool> _results = []; // 문제별 정답 여부
  final List<String> _myAnswers = []; // 문제별 내 답 (결과 화면에 보여 줌)

  int get index => _index;
  int get total => questions.length;
  int? get selected => _selected;
  String? get typed => _typed;
  bool get answered => _results.length > _index;
  bool get finished => _index >= questions.length;
  bool get isLast => _index == questions.length - 1;
  QuizQuestion get current => questions[_index];

  /// 지금 문제를 맞혔는지 (답하기 전에는 false)
  bool get currentCorrect => answered && _results[_index];

  bool isCorrectAt(int i) => _results[i];
  int get correctCount => _results.where((ok) => ok).length;

  /// 틀린 문제의 번호들
  List<int> get wrongIndexes => [
    for (var i = 0; i < _results.length; i++)
      if (!_results[i]) i,
  ];

  /// i번 문제에 적은(고른) 답
  String myAnswerAt(int i) => _myAnswers[i];

  /// 4지선다: 보기를 고른다.
  Future<void> select(int choiceIndex) async {
    if (answered || finished) return;
    _selected = choiceIndex;
    await _record(
      choiceIndex == current.answerIndex,
      current.choices[choiceIndex].text,
    );
  }

  /// 글자 맞추기: 만든 답을 채점한다. 히라가나 읽기나 한자 표기 중 하나와 같으면 정답.
  Future<void> submit(String input) async {
    if (answered || finished) return;
    final typed = normalizeAnswer(input);
    if (typed.isEmpty) return;
    _typed = typed;
    final a = current.answer;
    await _record(
      typed == normalizeAnswer(a.reading) || typed == normalizeAnswer(a.text),
      typed,
    );
  }

  Future<void> _record(bool ok, String myAnswer) async {
    _results.add(ok);
    _myAnswers.add(myAnswer);
    notifyListeners();
    await repo.recordReview(
      verbId: current.verb.id,
      form: current.form,
      correct: ok,
    );
  }

  void next() {
    if (!answered) return;
    _selected = null;
    _typed = null;
    _index++;
    notifyListeners();
  }
}

/// 입력한 답을 비교하기 좋게 다듬는다: 앞뒤·중간 공백을 없애고 가타카나는 히라가나로.
String normalizeAnswer(String s) {
  final out = StringBuffer();
  for (final r in s.runes) {
    if (r == 0x20 || r == 0x3000) continue; // 반각·전각 공백
    // 가타카나(ァ~ヶ) → 히라가나
    out.writeCharCode(r >= 0x30A1 && r <= 0x30F6 ? r - 0x60 : r);
  }
  return out.toString();
}
