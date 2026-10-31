import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/app_nav.dart';
import 'providers/quiz_settings.dart';
import 'providers/verb_provider.dart';
import 'screens/app_shell.dart';
import 'services/speech_service.dart';
import 'services/verb_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repo = await VerbRepository.open();

  runApp(
    MultiProvider(
      providers: [
        Provider<VerbRepository>.value(value: repo),
        Provider<SpeechService>(
          create: (_) => SpeechService(),
          dispose: (_, s) => s.stop(),
        ),
        ChangeNotifierProvider(create: (_) => VerbProvider(repo)..load()),
        ChangeNotifierProvider(create: (_) => AppNav()),
        ChangeNotifierProvider(create: (_) => QuizSettings(repo)..load()),
      ],
      child: const VerbApp(),
    ),
  );
}

class VerbApp extends StatelessWidget {
  const VerbApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '일본어 동사 활용',
      // 가나·한자는 앱에 넣은 고딕 글꼴(Noto Sans JP)로 그린다. 이 글꼴에 없는 한글은
      // 기기의 기본 한글 고딕으로 그려져서, 두 글꼴 모두 고딕 계열로 어울린다.
      // (기기의 일본어 기본 글꼴은 명조 계열인 경우가 있어 쓰지 않는다.)
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
        fontFamily: 'NotoSansJP',
      ),
      home: const AppShell(),
    );
  }
}
