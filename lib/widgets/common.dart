import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/verb.dart';
import '../providers/verb_provider.dart';
import '../services/speech_service.dart';

String groupLabel(VerbGroup g) => switch (g) {
  VerbGroup.ichidan => '1단',
  VerbGroup.godan => '5단',
  VerbGroup.irregular => '불규칙',
};

/// 동사 그룹별 박스 색 (배경 / 글자)
class GroupColors {
  final Color background;
  final Color foreground;
  const GroupColors(this.background, this.foreground);
}

/// 1단 = 파랑, 5단 = 주황, 불규칙 = 보라. 다크 모드에서는 어두운 배경과 밝은 글자.
GroupColors groupColors(BuildContext context, VerbGroup g) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return switch (g) {
    VerbGroup.ichidan =>
      dark
          ? const GroupColors(Color(0xFF1F3A5F), Color(0xFFE3F0FF))
          : const GroupColors(Color(0xFFDCEBFF), Color(0xFF0D2B52)),
    VerbGroup.godan =>
      dark
          ? const GroupColors(Color(0xFF5A3A12), Color(0xFFFFEBD0))
          : const GroupColors(Color(0xFFFFE7C7), Color(0xFF4A2A00)),
    VerbGroup.irregular =>
      dark
          ? const GroupColors(Color(0xFF4A2F73), Color(0xFFF1E6FF))
          : const GroupColors(Color(0xFFEBDDFB), Color(0xFF2E1A52)),
  };
}

/// 메뉴·설명 박스의 파스텔 색 (라이트 배경·글자 / 다크 배경·글자)
enum Pastel {
  pink(
    Color(0xFFFFE1EA),
    Color(0xFF6B2340),
    Color(0xFF4A2433),
    Color(0xFFFFD9E6),
  ),
  peach(
    Color(0xFFFFE8D6),
    Color(0xFF6B3A14),
    Color(0xFF4A3222),
    Color(0xFFFFE2CC),
  ),
  mint(
    Color(0xFFD9F5E6),
    Color(0xFF1C5238),
    Color(0xFF1F3F30),
    Color(0xFFCFF2DF),
  ),
  sky(
    Color(0xFFDCEEFF),
    Color(0xFF1B4469),
    Color(0xFF1F3449),
    Color(0xFFD4E9FF),
  ),
  lavender(
    Color(0xFFEAE2FF),
    Color(0xFF3F2A75),
    Color(0xFF332A4D),
    Color(0xFFE4DAFF),
  ),
  lemon(
    Color(0xFFFFF5CC),
    Color(0xFF5E4A00),
    Color(0xFF453C1C),
    Color(0xFFFFF0B8),
  );

  const Pastel(this.lightBg, this.lightFg, this.darkBg, this.darkFg);
  final Color lightBg, lightFg, darkBg, darkFg;

  Color background(bool dark) => dark ? darkBg : lightBg;
  Color foreground(bool dark) => dark ? darkFg : lightFg;
}

/// 제목이 있는 파스텔 색 상자. 안의 아이콘은 제목과 같은 색으로 그린다.
class PastelSection extends StatelessWidget {
  const PastelSection({
    super.key,
    required this.color,
    required this.title,
    required this.child,
  });

  final Pastel color;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final fg = color.foreground(dark);
    return Card(
      color: color.background(dark),
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: fg,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            IconTheme.merge(
              data: IconThemeData(color: fg),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

/// 앱바에 넣는 '읽기 보이기/숨기기' 버튼
class ReadingToggleButton extends StatelessWidget {
  const ReadingToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<VerbProvider>();
    return IconButton(
      tooltip: p.showReading ? '읽기 숨기기' : '읽기 보이기',
      icon: Icon(p.showReading ? Icons.visibility : Icons.visibility_off),
      onPressed: p.toggleReading,
    );
  }
}

/// 일본어를 소리 내어 읽는 스피커 버튼. [reading]에는 히라가나 읽기를 넘긴다.
class SpeakButton extends StatelessWidget {
  const SpeakButton({
    super.key,
    required this.reading,
    this.size = 24,
    this.color,
  });

  final String reading;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: '읽어 주기',
      iconSize: size,
      color: color,
      visualDensity: VisualDensity.compact,
      icon: const Icon(Icons.volume_up_outlined),
      onPressed: () => speakJapanese(context, reading),
    );
  }
}

/// [reading]을 읽는다. 기기에 일본어 음성이 없으면 설치 방법을 알려 준다.
Future<void> speakJapanese(BuildContext context, String reading) async {
  final messenger = ScaffoldMessenger.of(context);
  final ok = await context.read<SpeechService>().speak(reading);
  if (ok) return;
  messenger.showSnackBar(
    const SnackBar(
      content: Text(
        '일본어 음성이 없습니다. 기기 설정 > 텍스트 음성 변환(TTS)에서 '
        '일본어 음성 데이터를 설치해 주세요.',
      ),
    ),
  );
}
