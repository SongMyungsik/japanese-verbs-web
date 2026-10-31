import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/quiz_question.dart';
import '../models/verb.dart';
import '../services/conjugator.dart';
import '../services/quiz_generator.dart';
import '../services/verb_repository.dart';
import '../providers/quiz_settings.dart';
import '../providers/verb_provider.dart';
import '../widgets/common.dart';
import '../widgets/furigana.dart';
import 'conjugation_screen.dart';
import 'quiz_screen.dart';

/// 퀴즈 기록을 바탕으로 '오늘 복습'과 '오답 노트'를 보여 주는 화면
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  static const int _maxQuestions = 20;

  late final VerbRepository _repo;
  Map<int, Verb> _verbs = {};
  List<ReviewItem> _due = [];
  List<ReviewItem> _weak = [];
  ReviewStats _stats = const ReviewStats(total: 0, due: 0, mastered: 0);
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _repo = context.read<VerbRepository>();
    // 퀴즈에서 답을 기록할 때마다 목록을 다시 불러온다.
    _repo.reviewVersion.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    _repo.reviewVersion.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final verbs = await _repo.allVerbs();
    final due = await _repo.dueReviews(limit: 100);
    final weak = await _repo.weakItems(limit: 100);
    final stats = await _repo.reviewStats();
    if (!mounted) return;
    setState(() {
      _verbs = {for (final v in verbs) v.id: v};
      _due = due;
      _weak = weak;
      _stats = stats;
      _loading = false;
    });
  }

  void _startQuiz(List<ReviewItem> items) {
    final gen = QuizGenerator();
    final questions = <QuizQuestion>[];
    for (final it in items) {
      final v = _verbs[it.verbId];
      if (v == null) continue;
      final q = gen.questionFor(v, it.form);
      if (q != null) questions.add(q);
    }
    if (questions.isEmpty) return;
    questions.shuffle();
    Navigator.of(context).push(
      QuizScreen.route(
        questions.take(_maxQuestions).toList(),
        _repo,
        // 복습도 퀴즈 설정의 문제 방식(4지선다/글자 맞추기)을 따른다.
        mode: context.read<QuizSettings>().mode,
      ),
    );
  }

  // 고른 동사의 활용표를 복습 화면 위에 연다. 뒤로 가면 복습 화면으로 돌아온다.
  void _openVerb(Verb v) => ConjugationScreen.open(context, v);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('복습'),
          actions: const [ReadingToggleButton()],
          bottom: TabBar(
            tabs: [
              Tab(text: '오늘 복습 (${_due.length})'),
              Tab(text: '오답 노트 (${_weak.length})'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _StatsBar(stats: _stats),
                  const Divider(height: 1),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _ItemList(
                          items: _due,
                          verbs: _verbs,
                          emptyText: '지금 복습할 항목이 없습니다.\n퀴즈를 풀면 기록이 쌓입니다.',
                          buttonLabel: '복습 시작',
                          showAnswer: false,
                          onStart: () => _startQuiz(_due),
                          onOpen: _openVerb,
                        ),
                        _ItemList(
                          items: _weak,
                          verbs: _verbs,
                          emptyText: '틀린 문제가 없습니다.',
                          buttonLabel: '오답 문제 풀기',
                          showAnswer: true,
                          onStart: () => _startQuiz(_weak),
                          onOpen: _openVerb,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _StatsBar extends StatelessWidget {
  const _StatsBar({required this.stats});
  final ReviewStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget cell(int value, String label) => Expanded(
      child: Column(
        children: [
          Text('$value', style: theme.textTheme.headlineSmall),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          cell(stats.total, '푼 항목'),
          cell(stats.due, '복습 대기'),
          cell(stats.mastered, '익숙함'),
        ],
      ),
    );
  }
}

class _ItemList extends StatelessWidget {
  const _ItemList({
    required this.items,
    required this.verbs,
    required this.emptyText,
    required this.buttonLabel,
    required this.showAnswer,
    required this.onStart,
    required this.onOpen,
  });

  final List<ReviewItem> items;
  final Map<int, Verb> verbs;
  final String emptyText;
  final String buttonLabel;
  final bool showAnswer;
  final VoidCallback onStart;
  final void Function(Verb) onOpen;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(child: Text(emptyText, textAlign: TextAlign.center));
    }
    final theme = Theme.of(context);
    final ruby = context.watch<VerbProvider>().showReading;
    final titleStyle = theme.textTheme.bodyLarge;
    final subStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final it = items[i];
              final v = verbs[it.verbId];
              if (v == null) return const SizedBox.shrink();
              final answer = showAnswer
                  ? const Conjugator().conjugate(v, it.form)
                  : null;
              return ListTile(
                title: Text.rich(
                  TextSpan(
                    children: [
                      furiganaSpan(
                        context,
                        v.text,
                        v.reading,
                        style: titleStyle,
                        showRuby: ruby,
                      ),
                      TextSpan(text: ' — ${it.form.label}'),
                    ],
                  ),
                  style: titleStyle,
                ),
                subtitle: Text.rich(
                  TextSpan(
                    children: [
                      if (answer != null) ...[
                        const TextSpan(text: '정답: '),
                        furiganaSpan(
                          context,
                          answer.text,
                          answer.reading,
                          style: subStyle,
                          showRuby: ruby,
                        ),
                        const TextSpan(text: '\n'),
                      ],
                      TextSpan(
                        text:
                            '맞힘 ${it.correct} · 틀림 ${it.wrong} · 상자 ${it.box}/5',
                      ),
                    ],
                  ),
                  style: subStyle,
                ),
                isThreeLine: answer != null,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => onOpen(v),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: onStart, child: Text(buttonLabel)),
          ),
        ),
      ],
    );
  }
}
