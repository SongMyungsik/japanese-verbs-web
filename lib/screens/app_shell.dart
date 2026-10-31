import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:provider/provider.dart';

import '../providers/app_nav.dart';
import 'about_screen.dart';
import 'home_screen.dart';
import 'study_screen.dart';

/// 하단 내비게이션: 홈 / 학습 / 퀴즈 / 앱 소개 (홈 화면에서는 숨긴다)
///
/// 동사 목록·단계별·주제별·JLPT 학습·복습은 '학습' 탭 안에서 연다.
/// 동사 활용표는 탭이 아니라 동사를 누르면 그 탭 안에서 열린다.
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<AppNav>();

    // 안드로이드 '뒤로' 버튼: 학습·퀴즈 탭에서는 탭 안의 화면을 먼저 닫고,
    // 다른 탭에서는 앱을 끝내지 않고 홈 탭으로 간다.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = context.read<AppNav>();
        if (await nav.popInTab()) return;
        if (nav.index != AppNav.home) {
          nav.go(AppNav.home);
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        // IndexedStack은 탭을 바꿔도 각 화면의 상태(검색어, 스크롤 위치 등)를 유지한다.
        body: IndexedStack(
          index: nav.index,
          children: [
            const HomeScreen(),
            TabNavigator(
              navigatorKey: nav.tabNavigatorKeys[AppNav.study]!,
              root: const StudyMenuScreen(),
            ),
            TabNavigator(
              navigatorKey: nav.tabNavigatorKeys[AppNav.quiz]!,
              root: const QuizMenuScreen(),
            ),
            const AboutScreen(),
          ],
        ),
        // 홈 화면에서는 하단 내비게이션을 숨긴다. ('학습 시작' 버튼으로 들어간다)
        bottomNavigationBar: nav.index == AppNav.home
            ? null
            : NavigationBar(
                selectedIndex: nav.index,
                // 다른 탭: 활용표만 닫고 보던 화면 유지 / 지금 탭 다시 누르기: 첫 화면으로
                onDestinationSelected: nav.go,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home),
                    label: '홈',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.school_outlined),
                    selectedIcon: Icon(Icons.school),
                    label: '학습',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.quiz_outlined),
                    selectedIcon: Icon(Icons.quiz),
                    label: '퀴즈',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.info_outline),
                    selectedIcon: Icon(Icons.info),
                    label: '앱 소개',
                  ),
                ],
              ),
      ),
    );
  }
}
