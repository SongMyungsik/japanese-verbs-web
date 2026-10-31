import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/verb.dart';
import '../providers/app_nav.dart';
import '../providers/verb_provider.dart';
import '../services/conjugator.dart';
import '../widgets/common.dart';
import '../widgets/furigana.dart';

/// 동사 활용표: 동사 목록·복습에서 고른 동사 하나의 13가지 활용형을 보여 준다.
class ConjugationScreen extends StatelessWidget {
  const ConjugationScreen({super.key});

  /// [verb]를 고르고 지금 탭 안에서 활용표를 연다.
  static void open(BuildContext context, Verb verb) {
    context.read<VerbProvider>().select(verb);
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: AppNav.conjugationRoute),
        builder: (_) => const ConjugationScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<VerbProvider>();
    final verb = p.selectedVerb;

    return Scaffold(
      appBar: AppBar(
        title: const Text('동사 활용표'),
        actions: [
          // 현재 목록(검색·필터 결과)에서 이전/다음 동사로 넘긴다.
          IconButton(
            tooltip: '이전 동사',
            icon: const Icon(Icons.chevron_left),
            onPressed: p.hasPrev ? () => p.stepSelected(-1) : null,
          ),
          IconButton(
            tooltip: '다음 동사',
            icon: const Icon(Icons.chevron_right),
            onPressed: p.hasNext ? () => p.stepSelected(1) : null,
          ),
          if (verb != null)
            IconButton(
              tooltip: p.isFavorite(verb) ? '즐겨찾기 빼기' : '즐겨찾기에 추가',
              icon: Icon(p.isFavorite(verb) ? Icons.star : Icons.star_border),
              onPressed: () => p.toggleFavorite(verb),
            ),
          const ReadingToggleButton(),
        ],
      ),
      body: verb == null
          ? const _EmptyState()
          : _ConjugationTable(verb: verb, showReading: p.showReading),
    );
  }
}

/// 아직 동사를 고르지 않았을 때
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.table_chart_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            const Text(
              '동사 목록에서 동사를 선택하면\n활용표가 여기에 나타납니다.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ConjugationTable extends StatelessWidget {
  const _ConjugationTable({required this.verb, required this.showReading});

  final Verb verb;
  final bool showReading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = groupColors(context, verb.group);
    final forms = const Conjugator().conjugateAll(verb);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 목록 화면과 같은 그룹 색의 머리말 박스
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 표제 동사(한자 위에 읽기) 오른쪽에 한글 뜻
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Furigana(
                        text: verb.text,
                        reading: verb.reading,
                        showRuby: showReading,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: colors.foreground,
                        ),
                      ),
                    ),
                  ),
                  SpeakButton(reading: verb.reading, color: colors.foreground),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        verb.meaning,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colors.foreground,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  Chip(label: Text('${groupLabel(verb.group)}동사')),
                  if (verb.group == VerbGroup.godan)
                    Chip(label: Text('어미 ${verb.ending}')),
                ],
              ),
              if (verb.note.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  verb.note,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.foreground,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _ExtrasCard(verb: verb, showReading: showReading),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              for (final f in FormType.values) ...[
                // 왼쪽: 활용형 이름(뜻) / 오른쪽: 활용 결과(한자 위에 읽기).
                // 항상 한 줄에 놓고, 좁은 화면에서 넘치면 글자를 조금 줄인다.
                // 줄을 누르면 활용 결과를 읽어 준다.
                InkWell(
                  onTap: forms[f] == null
                      ? null
                      : () => speakJapanese(context, forms[f]!.reading),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 5,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              f.glossLabel,
                              maxLines: 1,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 4,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: _cell(forms[f], theme.textTheme.bodyLarge),
                          ),
                        ),
                        // 누르면 읽어 준다는 표시
                        SizedBox(
                          width: 28,
                          child: forms[f] == null
                              ? null
                              : Icon(
                                  Icons.volume_up_outlined,
                                  size: 18,
                                  color: theme.colorScheme.outline,
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (f != FormType.values.last) const Divider(height: 1),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// 활용 결과 칸. 활용이 성립하지 않는 칸(예: できる의 가능형)은 '―'로 표시
  Widget _cell(Conjugation? c, TextStyle? style) {
    if (c == null) return Text('―', style: style);
    return Furigana(
      text: c.text,
      reading: c.reading,
      showRuby: showReading,
      style: style,
    );
  }
}

/// 예문과 자동사·타동사 짝. 둘 다 없으면 보이지 않는다.
class _ExtrasCard extends StatelessWidget {
  const _ExtrasCard({required this.verb, required this.showReading});

  final Verb verb;
  final bool showReading;

  @override
  Widget build(BuildContext context) {
    final p = context.watch<VerbProvider>();
    final example = p.exampleOf(verb);
    final partners = p.partnersOf(verb);
    if (example == null && partners.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (example != null) ...[
              Row(
                children: [
                  Text(
                    '예문',
                    style: theme.textTheme.labelLarge?.copyWith(color: muted),
                  ),
                  const Spacer(),
                  SpeakButton(reading: example.reading, size: 20),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Furigana(
                  text: example.ja,
                  reading: example.reading,
                  showRuby: showReading,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                example.ko,
                style: theme.textTheme.bodyMedium?.copyWith(color: muted),
              ),
            ],
            if (example != null && partners.isNotEmpty)
              const Divider(height: 24),
            if (partners.isNotEmpty) ...[
              Text(
                '자동사·타동사 짝',
                style: theme.textTheme.labelLarge?.copyWith(color: muted),
              ),
              const SizedBox(height: 6),
              // 누르면 짝 동사의 활용표를 연다.
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final partner in partners)
                    ActionChip(
                      label: Text(
                        '${partner.roleLabel}  ${partner.verb.text}  '
                        '${partner.verb.meaning}',
                      ),
                      onPressed: () =>
                          ConjugationScreen.open(context, partner.verb),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
