import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/study_scope.dart';
import '../models/verb.dart';
import '../providers/quiz_controller.dart';
import '../providers/quiz_settings.dart';
import '../providers/verb_provider.dart';
import '../widgets/common.dart';

/// 퀴즈 범위(동사 그룹·활용형·문제 수)를 정하는 화면
class QuizSetupScreen extends StatefulWidget {
  const QuizSetupScreen({super.key});

  @override
  State<QuizSetupScreen> createState() => _QuizSetupScreenState();
}

class _QuizSetupScreenState extends State<QuizSetupScreen> {
  bool _starting = false;

  Future<void> _start() async {
    setState(() => _starting = true);
    await context.read<QuizSettings>().start(context);
    if (mounted) setState(() => _starting = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = context.watch<QuizSettings>();
    return Scaffold(
      appBar: AppBar(title: const Text('퀴즈 설정')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('문제 방식', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<QuizMode>(
            segments: [
              for (final m in QuizMode.values)
                ButtonSegment(value: m, label: Text(m.label)),
            ],
            selected: {s.mode},
            onSelectionChanged: (v) => s.setMode(v.first),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('정답 자동 읽어 주기'),
            subtitle: const Text('답을 고르면 정답을 일본어로 읽어 줍니다'),
            value: s.autoSpeak,
            onChanged: s.setAutoSpeak,
          ),
          const SizedBox(height: 24),
          Text('학습 범위', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          const _ScopePicker(),
          const SizedBox(height: 24),
          Text('동사 그룹', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('전체'),
                selected: s.group == null,
                onSelected: (_) => s.setGroup(null),
              ),
              for (final g in VerbGroup.values)
                ChoiceChip(
                  label: Text(groupLabel(g)),
                  selected: s.group == g,
                  onSelected: (_) => s.setGroup(g),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Text('묻고 싶은 활용형', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final f in FormType.values)
                FilterChip(
                  label: Text(f.label),
                  selected: s.forms.contains(f),
                  onSelected: (on) => s.toggleForm(f, on),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Text('문제 수', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 10, label: Text('10')),
              ButtonSegment(value: 20, label: Text('20')),
              ButtonSegment(value: 30, label: Text('30')),
            ],
            selected: {s.count},
            onSelectionChanged: (v) => s.setCount(v.first),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            icon: const Icon(Icons.play_arrow),
            label: const Text('시작하기'),
            onPressed: (s.forms.isEmpty || _starting) ? null : _start,
          ),
        ],
      ),
    );
  }
}

/// 학습 범위의 종류 (퀴즈 설정 화면에서만 쓴다)
enum _Range { all, stage, topic, jlpt, favorites }

/// 학습 범위 고르기: 전체 / 단계 / 주제 / JLPT / 즐겨찾기 → 단계·주제·JLPT는 그 안의 항목도 고른다
class _ScopePicker extends StatefulWidget {
  const _ScopePicker();

  @override
  State<_ScopePicker> createState() => _ScopePickerState();
}

class _ScopePickerState extends State<_ScopePicker> {
  late _Range _range;

  @override
  void initState() {
    super.initState();
    final s = context.read<QuizSettings>();
    _range = s.favoritesOnly
        ? _Range.favorites
        : switch (s.scope?.kind) {
            null => _Range.all,
            ScopeKind.stage => _Range.stage,
            ScopeKind.topic => _Range.topic,
            ScopeKind.jlpt => _Range.jlpt,
          };
  }

  static List<StudyScope> _scopesOf(_Range r) => switch (r) {
    _Range.stage => StudyScope.stages,
    _Range.topic => StudyScope.topics,
    _Range.jlpt => StudyScope.jlpt,
    _Range.all || _Range.favorites => const [],
  };

  void _setRange(_Range r) {
    setState(() => _range = r);
    final s = context.read<QuizSettings>();
    switch (r) {
      case _Range.all:
        s.setScope(null);
      case _Range.favorites:
        s.setFavoritesOnly();
      case _Range.stage || _Range.topic || _Range.jlpt:
        // 종류를 바꾸면 그 종류의 첫 항목(동사가 있는 것)을 고른다.
        final p = context.read<VerbProvider>();
        final scopes = _scopesOf(r);
        if (!scopes.contains(s.scope)) {
          s.setScope(scopes.firstWhere((e) => p.countIn(e) > 0));
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<QuizSettings>();
    final p = context.watch<VerbProvider>();
    final scopes = _scopesOf(_range);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<_Range>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: _Range.all, label: Text('전체')),
            ButtonSegment(value: _Range.stage, label: Text('단계')),
            ButtonSegment(value: _Range.topic, label: Text('주제')),
            ButtonSegment(value: _Range.jlpt, label: Text('JLPT')),
            ButtonSegment(value: _Range.favorites, icon: Icon(Icons.star)),
          ],
          selected: {_range},
          onSelectionChanged: (v) => _setRange(v.first),
        ),
        if (_range == _Range.favorites) ...[
          const SizedBox(height: 8),
          Text('즐겨찾기한 동사 ${p.favoriteCount}개에서 출제합니다.'),
        ],
        if (scopes.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final e in scopes)
                if (p.countIn(e) > 0)
                  ChoiceChip(
                    label: Text('${e.title} (${p.countIn(e)})'),
                    selected: s.scope == e,
                    onSelected: (_) => s.setScope(e),
                  ),
            ],
          ),
        ],
      ],
    );
  }
}
