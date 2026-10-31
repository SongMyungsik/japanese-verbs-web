import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/quiz_question.dart';
import '../models/verb.dart';
import '../providers/quiz_controller.dart';
import '../providers/quiz_settings.dart';
import '../providers/verb_provider.dart';
import '../services/verb_repository.dart';
import '../widgets/common.dart';
import '../widgets/furigana.dart';
import 'review_screen.dart';

/// 퀴즈 풀이 화면 (4지선다 또는 글자 맞추기). 문제를 다 풀면 같은 화면에서 결과를 보여 준다.
class QuizScreen extends StatelessWidget {
  const QuizScreen({super.key});

  static Route<void> route(
    List<QuizQuestion> questions,
    VerbRepository repo, {
    QuizMode mode = QuizMode.choice,
  }) {
    return MaterialPageRoute<void>(
      builder: (_) => ChangeNotifierProvider(
        create: (_) =>
            QuizController(questions: questions, repo: repo, mode: mode),
        child: const QuizScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<QuizController>();
    return Scaffold(
      appBar: AppBar(
        title: Text(c.finished ? '결과' : '${c.index + 1} / ${c.total}'),
        // 한자 위 읽기를 끄고 풀 수도 있다.
        actions: const [ReadingToggleButton()],
      ),
      body: c.finished
          ? _ResultView(controller: c)
          : _QuestionView(controller: c),
    );
  }
}

class _QuestionView extends StatelessWidget {
  const _QuestionView({required this.controller});
  final QuizController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final q = c.current;
    final theme = Theme.of(context);
    final ruby = context.watch<VerbProvider>().showReading;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        LinearProgressIndicator(value: c.index / c.total),
        const SizedBox(height: 24),
        // 문제 동사와 읽어 주기 버튼
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Furigana(
                text: q.verb.text,
                reading: q.verb.reading,
                showRuby: ruby,
                style: theme.textTheme.headlineLarge,
              ),
            ),
            SpeakButton(reading: q.verb.reading),
          ],
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            '${q.verb.meaning}  ·  ${groupLabel(q.verb.group)}',
            style: theme.textTheme.bodyMedium,
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text('${q.form.label}은?', style: theme.textTheme.titleLarge),
        ),
        const SizedBox(height: 16),
        if (c.mode == QuizMode.tiles)
          // 문제마다 입력 칸을 새로 만든다.
          _TileAnswer(key: ValueKey(c.index), controller: c)
        else
          // 보기 4개를 2×2로 놓아 스크롤 없이 한 화면에 보이게 한다.
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              mainAxisExtent: 76,
            ),
            itemCount: q.choices.length,
            itemBuilder: (context, i) => _ChoiceCard(
              choice: q.choices[i],
              showRuby: ruby,
              state: _stateOf(c, i),
              // 답을 고른 뒤에는 보기를 누르면 그 활용형을 읽어 준다. (고르기 전에는 힌트가 되므로 읽지 않음)
              onTap: c.answered
                  ? () => speakJapanese(context, q.choices[i].reading)
                  : () {
                      c.select(i);
                      _speakAnswer(context, q);
                    },
            ),
          ),
        const SizedBox(height: 8),
        if (c.answered) ...[
          Text.rich(
            TextSpan(
              children: [
                if (c.currentCorrect)
                  const TextSpan(text: '정답입니다!')
                else ...[
                  const TextSpan(text: '오답입니다. 정답: '),
                  _span(context, q.answer, theme.textTheme.titleMedium, ruby),
                ],
              ],
            ),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: c.next,
            child: Text(c.isLast ? '결과 보기' : '다음'),
          ),
        ],
      ],
    );
  }

  _ChoiceState _stateOf(QuizController c, int i) {
    if (!c.answered) return _ChoiceState.idle;
    if (i == c.current.answerIndex) return _ChoiceState.correct;
    if (i == c.selected) return _ChoiceState.wrong;
    return _ChoiceState.idle;
  }
}

/// 글자 맞추기 방식의 답 칸. 정답 읽기를 한 글자씩 조각으로 나누고 헷갈리는 조각을 섞어 보여 준다.
/// 조각을 차례로 눌러 답을 만들고 '확인'을 누른다. 일본어 자판이 없어도 풀 수 있다.
class _TileAnswer extends StatefulWidget {
  const _TileAnswer({super.key, required this.controller});
  final QuizController controller;

  @override
  State<_TileAnswer> createState() => _TileAnswerState();
}

class _TileAnswerState extends State<_TileAnswer> {
  static const int _extraTiles = 3;

  late final List<String> _answer; // 정답 읽기의 글자들
  late final List<String> _tiles; // 섞어 놓은 조각 (정답 글자 + 헷갈리는 글자)
  final List<int> _picked = []; // 누른 조각의 번호 (차례대로)

  @override
  void initState() {
    super.initState();
    final q = widget.controller.current;
    _answer = q.answer.reading.split('');
    _tiles = [..._answer, ..._distractors(q)]..shuffle();
  }

  /// 헷갈리는 조각: 오답 보기(読って 등)에서 정답에 없는 글자를 먼저 쓰고, 모자라면 비슷한 가나로 채운다.
  List<String> _distractors(QuizQuestion q) {
    final random = Random();
    final have = _answer.toSet();
    final fromChoices = {
      for (final c in q.choices)
        if (c != q.answer) ...c.reading.split(''),
    }.difference(have).toList()..shuffle(random);
    final fallback =
        'かきくけこさしすせそたちつてとなにぬねのまみむめもらりるれろ'
            .split('')
            .where((k) => !have.contains(k) && !fromChoices.contains(k))
            .toList()
          ..shuffle(random);
    return [...fromChoices, ...fallback].take(_extraTiles).toList();
  }

  String get _built => _picked.map((i) => _tiles[i]).join();

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final answered = c.answered;
    final full = _picked.length == _answer.length;
    final slotColor = answered
        ? (c.currentCorrect ? Colors.green.shade100 : Colors.red.shade100)
        : scheme.surfaceContainerHighest;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 내 답: 정답 글자 수만큼 칸을 놓고, 누른 조각을 차례로 채운다.
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 4,
          runSpacing: 4,
          children: [
            for (var i = 0; i < _answer.length; i++)
              Container(
                width: 36,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: slotColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  i < _picked.length ? _tiles[_picked[i]] : '',
                  style: theme.textTheme.titleLarge,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        // 조각: 누르면 위 칸에 들어가고, 쓴 조각은 흐리게 바뀐다.
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < _tiles.length; i++)
              SizedBox(
                width: 48,
                height: 48,
                child: FilledButton.tonal(
                  style: FilledButton.styleFrom(padding: EdgeInsets.zero),
                  onPressed: answered || full || _picked.contains(i)
                      ? null
                      : () => setState(() => _picked.add(i)),
                  child: Text(_tiles[i], style: theme.textTheme.titleLarge),
                ),
              ),
          ],
        ),
        if (!answered) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.backspace_outlined),
                  label: const Text('지우기'),
                  onPressed: _picked.isEmpty
                      ? null
                      : () => setState(_picked.removeLast),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: full
                      ? () {
                          c.submit(_built);
                          _speakAnswer(context, c.current);
                        }
                      : null,
                  child: const Text('확인'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

enum _ChoiceState { idle, correct, wrong }

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.choice,
    required this.showRuby,
    required this.state,
    required this.onTap,
  });

  final Conjugation choice;
  final bool showRuby;
  final _ChoiceState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      _ChoiceState.correct => Colors.green.shade100,
      _ChoiceState.wrong => Colors.red.shade100,
      _ChoiceState.idle => null,
    };
    final icon = switch (state) {
      _ChoiceState.correct => const Icon(
        Icons.check_circle,
        color: Colors.green,
        size: 20,
      ),
      _ChoiceState.wrong => const Icon(
        Icons.cancel,
        color: Colors.red,
        size: 20,
      ),
      _ChoiceState.idle => null,
    };
    return Card(
      color: color,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            // 반 폭 카드라 긴 활용형은 줄바꿈 대신 글자를 줄여 한 줄에 맞춘다.
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Furigana(
                    text: choice.text,
                    reading: choice.reading,
                    showRuby: showRuby,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
            ),
            if (icon != null) Positioned(top: 4, right: 4, child: icon),
          ],
        ),
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({required this.controller});
  final QuizController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final theme = Theme.of(context);
    final wrong = c.wrongIndexes;
    final percent = (c.correctCount * 100 / c.total).round();
    final ruby = context.watch<VerbProvider>().showReading;
    final titleStyle = theme.textTheme.bodyLarge;
    final subStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 16),
        Center(
          child: Text(
            '${c.correctCount} / ${c.total}',
            style: theme.textTheme.displayMedium,
          ),
        ),
        Center(
          child: Text('정답률 $percent%', style: theme.textTheme.titleMedium),
        ),
        const SizedBox(height: 24),
        if (wrong.isEmpty)
          const Center(child: Text('모두 맞혔습니다!'))
        else ...[
          Text('틀린 문제', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final i in wrong)
            Card(
              child: ListTile(
                title: Text.rich(
                  TextSpan(
                    children: [
                      furiganaSpan(
                        context,
                        c.questions[i].verb.text,
                        c.questions[i].verb.reading,
                        style: titleStyle,
                        showRuby: ruby,
                      ),
                      TextSpan(text: ' — ${c.questions[i].form.label}'),
                    ],
                  ),
                  style: titleStyle,
                ),
                subtitle: Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: '정답: '),
                      _span(context, c.questions[i].answer, subStyle, ruby),
                      const TextSpan(text: '\n내 답: '),
                      _myAnswerSpan(context, c, i, subStyle, ruby),
                    ],
                  ),
                  style: subStyle,
                ),
                isThreeLine: true,
              ),
            ),
        ],
        const SizedBox(height: 16),
        if (wrong.isNotEmpty)
          FilledButton(
            onPressed: () => Navigator.of(context).pushReplacement(
              QuizScreen.route(
                [for (final i in wrong) c.questions[i]],
                c.repo,
                mode: c.mode,
              ),
            ),
            child: const Text('틀린 문제 다시 풀기'),
          ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const ReviewScreen())),
          child: const Text('복습 · 오답 노트 보기'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('돌아가기'),
        ),
      ],
    );
  }
}

/// 활용 결과를 문장 안에 후리가나로 넣는다.
InlineSpan _span(
  BuildContext context,
  Conjugation c,
  TextStyle? style,
  bool ruby,
) => furiganaSpan(context, c.text, c.reading, style: style, showRuby: ruby);

/// 결과 화면의 '내 답'. 고른 보기는 후리가나로, 글자 맞추기로 만든 답은 그대로 보여 준다.
InlineSpan _myAnswerSpan(
  BuildContext context,
  QuizController c,
  int i,
  TextStyle? style,
  bool ruby,
) {
  final mine = c.myAnswerAt(i);
  for (final choice in c.questions[i].choices) {
    if (c.mode == QuizMode.choice && choice.text == mine) {
      return _span(context, choice, style, ruby);
    }
  }
  return TextSpan(text: mine);
}

/// 퀴즈 설정에서 켜 두었으면 답한 뒤 정답을 읽어 준다.
void _speakAnswer(BuildContext context, QuizQuestion q) {
  if (context.read<QuizSettings>().autoSpeak) {
    speakJapanese(context, q.answer.reading);
  }
}
