import 'package:flutter/widgets.dart';

/// 하단 내비게이션의 현재 탭.
/// 다른 화면에서도 `context.read<AppNav>().go(AppNav.quiz)`처럼 탭을 옮길 수 있다.
class AppNav extends ChangeNotifier {
  static const int home = 0; // 홈
  static const int study = 1; // 학습 (동사 목록·단계별·주제별·JLPT·퀴즈·복습)
  static const int quiz = 2; // 퀴즈 (퀴즈 설정·퀴즈·복습/오답 노트)
  static const int about = 3; // 앱 소개

  /// 탭 안에 자체 Navigator가 있는 탭(학습·퀴즈)의 키. 뒤로 가기와 탭 다시 누르기에 쓴다.
  final Map<int, GlobalKey<NavigatorState>> tabNavigatorKeys = {
    study: GlobalKey<NavigatorState>(),
    quiz: GlobalKey<NavigatorState>(),
  };

  int _index = home;
  int get index => _index;

  /// 활용표 화면의 route 이름. 탭을 옮길 때 이 화면만 닫는다.
  static const String conjugationRoute = 'conjugation';

  /// 탭 [i]로 옮긴다.
  /// 다른 탭으로 옮기면 그 탭 위에 열어 둔 활용표만 닫고 보던 목록 등은 남긴다.
  /// 지금 탭을 다시 누르면 그 탭의 첫 화면으로 돌아간다.
  void go(int i) {
    if (i == _index) {
      resetTab(i);
      return;
    }
    tabNavigatorKeys[i]?.currentState?.popUntil(
      (route) => route.settings.name != conjugationRoute,
    );
    _index = i;
    notifyListeners();
  }

  /// 탭 [i]를 첫 화면으로 되돌린다.
  void resetTab(int i) =>
      tabNavigatorKeys[i]?.currentState?.popUntil((route) => route.isFirst);

  /// 현재 탭 안의 화면을 하나 닫는다. 닫을 화면이 없으면 false.
  Future<bool> popInTab() async =>
      await tabNavigatorKeys[_index]?.currentState?.maybePop() ?? false;
}
