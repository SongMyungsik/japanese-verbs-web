import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/verb.dart';
import '../providers/verb_provider.dart';
import '../services/conjugator.dart';
import '../widgets/common.dart';
import '../widgets/furigana.dart';

/// '앱 소개' 탭: 앱이 무엇인지, 어떻게 쓰는지, 활용형이 무엇인지 설명한다.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  /// 활용형 예시에 쓰는 동사. 예시는 규칙 엔진이 직접 만들어서 항상 실제 활용과 같다.
  static const Verb _sample = Verb(
    id: 0,
    text: '書く',
    reading: 'かく',
    meaning: '쓰다',
    group: VerbGroup.godan,
    ending: 'く',
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final total = context.watch<VerbProvider>().totalCount;
    const conjugator = Conjugator();

    return Scaffold(
      appBar: AppBar(title: const Text('앱 소개')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 머리말
          Container(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '動詞活用',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '일본어 동사 활용',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '일본어 동사의 활용을 한눈에 보고, 퀴즈로 연습하고, '
                  '틀린 것은 복습으로 익히는 학습 앱입니다.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '동사 $total개 · 활용형 ${FormType.values.length}가지',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),

          _Section(
            title: '이렇게 사용하세요',
            child: const Column(
              children: [
                _Step(
                  icon: Icons.school,
                  title: '학습',
                  text:
                      '학습 탭에서 동사 목록, 단계별·주제별·JLPT 학습, '
                      '오늘의 복습을 고릅니다. 단계·주제·급수를 '
                      '고르면 그 범위의 동사만 목록으로 보여 줍니다. 각 항목에는 학습 진도'
                      '(익숙한 동사·풀어 본 동사 수)가 막대로 나옵니다.',
                ),
                _Step(
                  icon: Icons.grid_view,
                  title: '동사 목록',
                  text:
                      '동사를 박스로 보여 줍니다. 검색, 그룹·어미 필터, '
                      '정렬(발음순·뜻 가나다순·그룹별)을 쓸 수 있고, '
                      '박스를 누르면 활용표가 열립니다. 활용표의 ☆로 즐겨찾기에 넣으면 '
                      '목록의 ★ 필터와 퀴즈 범위로 모아 볼 수 있습니다.',
                ),
                _Step(
                  icon: Icons.table_chart,
                  title: '동사 활용표',
                  text:
                      '고른 동사의 활용형을 모두 보여 줍니다. 예문과 자동사·타동사 짝도 '
                      '함께 나오고, 짝 동사를 누르면 그 동사의 활용표로 갑니다. '
                      '오른쪽 위 화살표로 앞뒤 동사로 넘어가고, 눈 아이콘으로 '
                      '히라가나 읽기를 켜고 끌 수 있습니다.',
                ),
                _Step(
                  icon: Icons.quiz,
                  title: '퀴즈',
                  text:
                      '퀴즈 탭의 퀴즈 설정에서 문제 방식(4지선다·글자 맞추기), 학습 범위'
                      '(단계·주제·JLPT), 동사 그룹, 활용형, 문제 수를 고릅니다. '
                      '글자 맞추기는 섞여 있는 히라가나 조각을 차례로 눌러 답을 만듭니다. '
                      '"퀴즈 시작"을 누르면 현재 설정으로 바로 시작하고, '
                      '결과 화면에서 틀린 문제만 다시 풀 수 있습니다.',
                ),
                _Step(
                  icon: Icons.volume_up,
                  title: '읽어 주기',
                  text:
                      '활용표에서 스피커 버튼이나 활용형 줄을 누르면 일본어로 읽어 줍니다. '
                      '동사 목록에서는 박스를 길게 누르고, 퀴즈에서는 문제 옆 스피커나 '
                      '답을 고른 뒤 보기를 누르면 됩니다. 기기에 일본어 음성이 없으면 '
                      '설정 > 텍스트 음성 변환에서 설치해 주세요.',
                ),
                _Step(
                  icon: Icons.history,
                  title: '복습',
                  text:
                      '퀴즈를 풀면 기록이 쌓입니다. 학습 탭의 "오늘의 복습"이나 '
                      '퀴즈 탭의 "복습 / 오답 노트"에서 오늘 복습할 항목과 '
                      '오답 노트를 볼 수 있습니다.',
                ),
              ],
            ),
          ),

          _Section(
            title: '동사 그룹과 색',
            child: const Column(
              children: [
                _GroupBox(
                  group: VerbGroup.ichidan,
                  title: '1단동사 (파랑)',
                  text: '끝의 る를 떼고 붙입니다.\n食べる → 食べない, 食べます',
                ),
                _GroupBox(
                  group: VerbGroup.godan,
                  title: '5단동사 (주황)',
                  text:
                      '끝 글자가 같은 행 안에서 바뀝니다.\n'
                      '書く → 書かない, 書きます, 書ける',
                ),
                _GroupBox(
                  group: VerbGroup.irregular,
                  title: '불규칙동사 (보라)',
                  text: 'する, 来る, 그리고 勉強する처럼 する가 붙은 동사입니다.',
                ),
              ],
            ),
          ),

          _Section(
            title: '활용형 ${FormType.values.length}가지 (書く의 경우)',
            child: Column(
              children: [
                for (final f in FormType.values)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(flex: 5, child: Text(f.glossLabel)),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 5,
                          child: _sampleCell(
                            conjugator.conjugate(_sample, f),
                            theme.textTheme.titleSmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '이름 뒤의 괄호는 한국어 뜻이고, 한자 위의 작은 글자는 히라가나 읽기입니다.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),

          const _Section(
            title: '복습은 이렇게 동작합니다',
            child: Column(
              children: [
                _Bullet(
                  '동사와 활용형 하나하나가 따로 기록됩니다. '
                  '예를 들어 "読む의 て형"이 한 항목입니다.',
                ),
                _Bullet(
                  '맞히면 1일 → 3일 → 7일 → 14일 → 30일 뒤에 '
                  '다시 복습 대기에 오릅니다.',
                ),
                _Bullet('틀리면 바로 복습 대기로 돌아오고, 오답 노트에 쌓입니다.'),
              ],
            ),
          ),

          const _Section(
            title: '알아 두세요',
            child: Column(
              children: [
                _Bullet(
                  'ある, できる, 分かる, 要る, 見える, 聞こえる 같은 '
                  '상태동사는 가능·수동·사역·사역수동·명령형이 없어서 "―"로 '
                  '표시됩니다. ある의 부정은 ない입니다.',
                ),
                _Bullet(
                  '5단동사의 사역수동형은 줄인 형태(書かされる)로 보여 주고, '
                  'す로 끝나는 동사만 話させられる로 보여 줍니다.',
                ),
                _Bullet(
                  '1단처럼 보이지만 5단인 동사(帰る, 入る, 走る 등)는 '
                  '메모로 표시해 두었습니다.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(text, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupBox extends StatelessWidget {
  const _GroupBox({
    required this.group,
    required this.title,
    required this.text,
  });

  final VerbGroup group;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = groupColors(context, group);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: colors.foreground,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.foreground,
            ),
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  '),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

/// 활용형 예시 칸: 한자 위에 읽기를 얹어 오른쪽 정렬
Widget _sampleCell(Conjugation? c, TextStyle? style) => Align(
  alignment: Alignment.centerRight,
  child: c == null
      ? Text('―', style: style)
      : Furigana(text: c.text, reading: c.reading, style: style),
);
