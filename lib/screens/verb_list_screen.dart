import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/study_scope.dart';
import '../models/verb.dart';
import '../providers/verb_provider.dart';
import '../widgets/common.dart';
import '../widgets/furigana.dart';
import 'conjugation_screen.dart';

/// 동사 목록. [scope]를 주면 그 범위(단계·주제·JLPT)의 동사만 보여 준다.
class VerbListScreen extends StatefulWidget {
  const VerbListScreen({super.key, this.scope});

  final StudyScope? scope;

  @override
  State<VerbListScreen> createState() => _VerbListScreenState();
}

class _VerbListScreenState extends State<VerbListScreen> {
  @override
  void initState() {
    super.initState();
    // 화면을 여는 중이라 알림은 보내지 않는다. 이 화면은 build에서 새 값을 읽는다.
    context.read<VerbProvider>().setScope(widget.scope, notify: false);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<VerbProvider>();
    final verbs = p.verbs;
    final scope = widget.scope;

    return Scaffold(
      appBar: AppBar(
        title: Text(scope?.title ?? '동사 목록'),
        actions: [
          // 정렬 방식 선택: 발음순 / 뜻 가나다순 / 그룹별
          PopupMenuButton<VerbSort>(
            tooltip: '정렬',
            icon: const Icon(Icons.sort),
            onSelected: p.setSort,
            itemBuilder: (context) => [
              for (final s in VerbSort.values)
                CheckedPopupMenuItem<VerbSort>(
                  value: s,
                  checked: p.sort == s,
                  child: Text(s.label),
                ),
            ],
          ),
          const ReadingToggleButton(),
        ],
      ),
      body: p.loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (scope != null && scope.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        scope.description,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: '동사·읽기·뜻 검색',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: p.setQuery,
                  ),
                ),
                _GroupChips(provider: p),
                if (p.group == VerbGroup.godan) _EndingChips(provider: p),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${verbs.length} / ${scope == null ? p.totalCount : p.countIn(scope)}개 · ${p.sort.shortLabel}',
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      for (final g in VerbGroup.values) _LegendItem(group: g),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: verbs.isEmpty
                      ? const Center(child: Text('조건에 맞는 동사가 없습니다'))
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            // 좁은 화면(휴대폰)은 한 줄에 2개, 넓은 화면은 3개
                            final columns = constraints.maxWidth >= 640 ? 3 : 2;
                            return GridView.builder(
                              padding: const EdgeInsets.all(12),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: columns,
                                    mainAxisSpacing: 8,
                                    crossAxisSpacing: 8,
                                    mainAxisExtent: 88,
                                  ),
                              itemCount: verbs.length,
                              itemBuilder: (context, i) => _VerbBox(
                                verb: verbs[i],
                                showReading: p.showReading,
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

/// 동사 하나를 나타내는 박스. 배경색으로 1단·5단·불규칙을 구분한다.
class _VerbBox extends StatelessWidget {
  const _VerbBox({required this.verb, required this.showReading});

  final Verb verb;
  final bool showReading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = groupColors(context, verb.group);
    final radius = BorderRadius.circular(12);

    return Material(
      color: colors.background,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        // 고른 동사의 활용표를 연다.
        onTap: () => ConjugationScreen.open(context, verb),
        // 길게 누르면 동사를 읽어 준다.
        onLongPress: () => speakJapanese(context, verb.reading),
        child: Stack(
          children: [
            // 즐겨찾기한 동사는 오른쪽 위에 ★
            if (context.select<VerbProvider, bool>((p) => p.isFavorite(verb)))
              Positioned(
                top: 6,
                right: 8,
                child: Icon(Icons.star, size: 16, color: colors.foreground),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 한자 위에 작은 읽기 (눈 아이콘으로 켜고 끈다). 길면 글자를 줄여 한 줄에 둔다.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Furigana(
                      text: verb.text,
                      reading: verb.reading,
                      showRuby: showReading,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colors.foreground,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    verb.meaning,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.foreground,
                    ),
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

/// 색 범례: ■ 1단 ■ 5단 ■ 불규칙
class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.group});
  final VerbGroup group;

  @override
  Widget build(BuildContext context) {
    final colors = groupColors(context, group);
    return Padding(
      padding: const EdgeInsets.only(left: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: colors.foreground, width: 0.8),
            ),
          ),
          const SizedBox(width: 4),
          Text(groupLabel(group), style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _GroupChips extends StatelessWidget {
  const _GroupChips({required this.provider});
  final VerbProvider provider;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: const Text('전체'),
              selected: provider.group == null,
              onSelected: (_) => provider.setGroup(null),
            ),
          ),
          for (final g in VerbGroup.values)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(groupLabel(g)),
                selected: provider.group == g,
                onSelected: (_) => provider.setGroup(g),
              ),
            ),
          // 그룹 필터와 함께 쓸 수 있다. (예: 즐겨찾기 중 5단동사)
          FilterChip(
            avatar: const Icon(Icons.star, size: 18),
            label: Text('즐겨찾기 ${provider.favoriteCount}'),
            selected: provider.favoritesOnly,
            onSelected: provider.setFavoritesOnly,
          ),
        ],
      ),
    );
  }
}

class _EndingChips extends StatelessWidget {
  const _EndingChips({required this.provider});
  final VerbProvider provider;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: const Text('모든 어미'),
              selected: provider.ending == null,
              onSelected: (_) => provider.setEnding(null),
            ),
          ),
          for (final e in VerbProvider.godanEndings)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(e),
                selected: provider.ending == e,
                onSelected: (_) => provider.setEnding(e),
              ),
            ),
        ],
      ),
    );
  }
}
