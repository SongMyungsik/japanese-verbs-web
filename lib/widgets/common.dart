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
