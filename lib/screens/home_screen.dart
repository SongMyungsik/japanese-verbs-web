import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/verb.dart';
import '../providers/app_nav.dart';
import '../providers/verb_provider.dart';
import '../services/verb_repository.dart';
import 'review_screen.dart';

// 홈은 다른 화면과 달리 진한 그라데이션 바탕이라 밝은 글자를 쓴다.
const _gradient = [Color(0xFF312E81), Color(0xFF5B3FA8), Color(0xFF9A4A9E)];
const _highlight = Color(0xFFFFF0B8); // 제목·숫자·시작 버튼
const _onHighlight = Color(0xFF3F2A75);

/// 홈 탭: 앱 소개(스플래시) 화면. 동사 수, 활용형 수, 복습 대기 수를 보여 준다.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = context.watch<VerbProvider>().totalCount;
    final nav = context.read<AppNav>();

    return Scaffold(
      extendBody: true, // 버전 표시 뒤까지 그라데이션이 이어지게
      // 하단 내비게이션 바로 위에 버전 표시
      bottomNavigationBar: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 12),
          child: Text(
            'Japanese verbs ver. 1.0',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
        ),
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _gradient,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '日本語\n動詞活用',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _highlight,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'どうしかつよう',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '일본어 동사 활용',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '1단·5단·불규칙 동사를 활용형별로 익히고\n퀴즈와 복습으로 기억하세요.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: _Stat(value: '$total개', label: '동사'),
                        ),
                        Expanded(
                          child: _Stat(
                            value: '${FormType.values.length}가지',
                            label: '활용형',
                          ),
                        ),
                        Expanded(
                          child: _Stat(value: '$_due개', label: '복습 대기'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: _highlight,
                          foregroundColor: _onHighlight,
                        ),
                        onPressed: () => nav.go(AppNav.study),
                        icon: const Icon(Icons.school),
                        label: const Text('학습 시작'),
                      ),
                    ),
                    if (_due > 0) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonalIcon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ReviewScreen(),
                            ),
                          ),
                          icon: const Icon(Icons.history),
                          label: Text('복습하기 ($_due)'),
                        ),
                      ),
                    ],
                    // 홈에는 하단 내비게이션이 없으므로 앱 소개로 가는 링크를 둔다.
                    const SizedBox(height: 4),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => nav.go(AppNav.about),
                      icon: const Icon(Icons.info_outline, size: 18),
                      label: const Text('앱 소개'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: _highlight,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.white),
        ),
      ],
    );
  }
}
