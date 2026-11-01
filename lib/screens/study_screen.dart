import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/study_scope.dart';
import '../providers/app_nav.dart';
import '../providers/quiz_settings.dart';
import '../providers/verb_provider.dart';
import '../services/verb_repository.dart';
import '../widgets/common.dart';
import 'quiz_setup_screen.dart';
import 'review_screen.dart';
import 'verb_list_screen.dart';

/// 학습·퀴즈 탭. 탭 안에 자체 Navigator를 두어서 하위 화면을 열어도 하단 내비게이션이 보인다.
class TabNavigator extends StatelessWidget {
  const TabNavigator({
    super.key,
    required this.navigatorKey,
    required this.root,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget root;

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => root),
    );
  }
}

/// 학습 선택: 동사 목록 / 단계별 / 주제별 / JLPT / 퀴즈 / 오늘의 복습
class StudyMenuScreen extends StatefulWidget {
  const StudyMenuScreen({super.key});

  @override
  State<StudyMenuScreen> createState() => _StudyMenuScreenState();
}

class _StudyMenuScreenState extends State<StudyMenuScreen> {
  late final VerbRepository _repo;
  int _due = 0;

  @override
  void initState() {
    super.initState();
    _repo = context.read<VerbRepository>();
    // 퀴즈에서 답을 기록할 때마다 복습 대기 수를 다시 센다.
    _repo.reviewVersion.addListener(_loadStats);
    _loadStats();
  }

  @override
  void dispose() {
    _repo.reviewVersion.removeListener(_loadStats);
    super.dispose();
  }

  Future<void> _loadStats() async {
    final stats = await _repo.reviewStats();
    if (!mounted) return;
    setState(() => _due = stats.due);
  }

  void _push(Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final p = context.watch<VerbProvider>();
    final total = p.totalCount;
    final mastered = p.progressIn((_) => true).mastered;
    final favorites = p.favoriteCount;
    return Scaffold(
      appBar: AppBar(title: const Text('학습 선택')),
      body: GridView(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: 124, // 타일 높이 (아이콘·제목 한 줄 + 설명 두 줄)
        ),
        children: [
          _MenuTile(
            color: Pastel.pink,
            title: '동사 목록',
            subtitle: '전체 동사 $total개\n익숙함 $mastered · 즐겨찾기 $favorites',
            onTap: () => _push(const VerbListScreen()),
          ),
          _MenuTile(
            color: Pastel.peach,
            title: '단계별 학습',
            subtitle: '생활 필수 동사부터\n경어·고급 표현까지',
            onTap: () => _push(
              const ScopeMenuScreen(title: '단계별 학습', scopes: StudyScope.stages),
            ),
          ),
          _MenuTile(
            color: Pastel.mint,
            title: '주제별 학습',
            subtitle: '일상생활 · 이동/여행\n학습/감정 · 직장/사회',
            onTap: () => _push(
              const ScopeMenuScreen(title: '주제별 학습', scopes: StudyScope.topics),
            ),
          ),
          _MenuTile(
            color: Pastel.sky,
            title: 'JLPT 학습',
            subtitle: 'N5 ~ N1\n급수별 동사',
            onTap: () => _push(
              const ScopeMenuScreen(title: 'JLPT 학습', scopes: StudyScope.jlpt),
            ),
          ),
          _MenuTile(
            color: Pastel.lavender,
            title: '퀴즈',
            subtitle: '활용형 퀴즈\n복습/오답 노트',
            // 퀴즈는 하단 '퀴즈' 탭에 있으므로 그 탭으로 옮긴다.
            onTap: () => context.read<AppNav>().go(AppNav.quiz),
          ),
          _MenuTile(
            color: Pastel.lemon,
            title: '오늘의 복습',
            subtitle: _due > 0 ? '복습할 항목\n$_due개' : '지금 복습할\n항목이 없습니다',
            badge: _due > 0 ? '$_due' : null,
            onTap: () => _push(const ReviewScreen()),
          ),
        ],
      ),
    );
  }
}

/// 학습 선택 화면의 타일: 제목 · 설명
class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  final Pastel color;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final bg = color.background(dark);
    final fg = color.foreground(dark);
    final radius = BorderRadius.circular(20);

    return Material(
      color: bg,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 제목은 잘리지 않게, 넘치면 글자를 줄여 한 줄에 둔다. 배지(복습 수)는 제목 오른쪽.
              Row(
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        title,
                        maxLines: 1,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: fg,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  if (badge != null) ...[
                    const SizedBox(width: 8),
                    Badge(label: Text(badge!)),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: fg.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 범위(단계·주제·JLPT) 목록. 고르면 그 범위의 동사 목록을 연다.
class ScopeMenuScreen extends StatelessWidget {
  const ScopeMenuScreen({super.key, required this.title, required this.scopes});

  final String title;
  final List<StudyScope> scopes;

  @override
  Widget build(BuildContext context) {
    final p = context.watch<VerbProvider>();
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          for (final (i, s) in scopes.indexed)
            Builder(
              builder: (context) {
                final n = p.countIn(s);
                final color = Pastel.values[i % Pastel.values.length];
                return _MenuCard(
                  color: color,
                  title: s.title,
                  subtitle: [
                    if (s.description.isNotEmpty) s.description,
                    n > 0 ? '동사 $n개' : '준비 중',
                  ].join('\n'),
                  footer: n == 0
                      ? null
                      : _ProgressBar(p.progressIn(s.matches), color: color),
                  onTap: n == 0
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => VerbListScreen(scope: s),
                          ),
                        ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// '퀴즈' 탭의 첫 화면: 퀴즈 설정 / 퀴즈 / 복습·오답 노트
class QuizMenuScreen extends StatelessWidget {
  const QuizMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<QuizSettings>();
    final forms = s.forms;
    return Scaffold(
      appBar: AppBar(title: const Text('퀴즈')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _MenuCard(
            color: Pastel.lavender,
            icon: Icons.tune,
            title: '퀴즈 설정',
            subtitle: '동사 그룹 · 활용형 · 문제 수 정하기',
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const QuizSetupScreen())),
          ),
          _MenuCard(
            color: Pastel.mint,
            icon: Icons.play_arrow,
            title: '퀴즈 시작',
            subtitle: forms.isEmpty
                ? '퀴즈 설정에서 활용형을 골라 주세요'
                : '${s.summary} · 활용형 ${forms.length}가지',
            onTap: forms.isEmpty ? null : () => s.start(context),
          ),
          _MenuCard(
            color: Pastel.peach,
            icon: Icons.fact_check_outlined,
            title: '복습 / 오답 노트',
            subtitle: '푼 기록을 바탕으로 다시 풀기',
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const ReviewScreen())),
          ),
        ],
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.icon,
    this.footer,
  });

  final Pastel color;
  final IconData? icon;
  final String title;
  final String subtitle;
  final Widget? footer; // 설명 아래에 붙는 위젯 (진도 막대 등)
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = color.background(dark);
    final fg = color.foreground(dark);
    return Card(
      color: bg,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias, // 누를 때 물결이 둥근 모서리 밖으로 나가지 않게
      child: ListTile(
        enabled: onTap != null,
        textColor: fg,
        iconColor: fg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: icon == null
            ? null
            : CircleAvatar(
                backgroundColor: fg,
                foregroundColor: bg,
                child: Icon(icon),
              ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: footer == null
            ? Text(subtitle)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Text(subtitle), const SizedBox(height: 6), footer!],
              ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

/// 학습 진도 막대: 진한 부분 = 익숙한 동사, 옅은 부분 = 풀어 본 동사
class _ProgressBar extends StatelessWidget {
  const _ProgressBar(this.progress, {required this.color});
  final ScopeProgress progress;
  final Pastel color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = color.foreground(theme.brightness == Brightness.dark);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 8,
            child: Stack(
              fit: StackFit.expand,
              children: [
                LinearProgressIndicator(
                  value: progress.solvedRatio,
                  backgroundColor: fg.withValues(alpha: 0.12),
                  color: fg.withValues(alpha: 0.35),
                ),
                LinearProgressIndicator(
                  value: progress.masteredRatio,
                  backgroundColor: Colors.transparent,
                  color: fg,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '익숙함 ${progress.mastered} · 풀어 봄 ${progress.solved} / ${progress.total}',
          style: theme.textTheme.bodySmall?.copyWith(color: fg),
        ),
      ],
    );
  }
}
