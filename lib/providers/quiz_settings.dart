import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/study_scope.dart';
import '../models/verb.dart';
import '../screens/quiz_screen.dart';
import '../services/quiz_generator.dart';
import '../services/verb_repository.dart';
import '../widgets/common.dart';
import 'verb_provider.dart';
import 'quiz_controller.dart';

/// 퀴즈 범위(학습 범위·동사 그룹·활용형·문제 수)와 문제 방식.
/// '퀴즈 설정' 화면에서 바꾸고, '퀴즈 시작' 메뉴는 이 설정 그대로 바로 시작한다.
/// 바꿀 때마다 DB에 저장해서 앱을 다시 켜도 유지된다.
class QuizSettings extends ChangeNotifier {
  QuizSettings(this._repo);

  final VerbRepository _repo;
  static const String _key = 'quiz_settings';

  StudyScope? _scope; // 단계·주제·JLPT 중 하나 (null = 전체 동사)
  bool _favoritesOnly = false; // 즐겨찾기 동사만 (켜면 _scope는 null)
  bool _autoSpeak = true; // 답하면 정답을 읽어 준다
  VerbGroup? _group; // null = 전체
  final Set<FormType> _forms = {
    FormType.masu,
    FormType.nai,
    FormType.te,
    FormType.ta,
  };
  int _count = 10;
  QuizMode _mode = QuizMode.choice;

  StudyScope? get scope => _scope;
  bool get favoritesOnly => _favoritesOnly;
  bool get autoSpeak => _autoSpeak;
  VerbGroup? get group => _group;
  Set<FormType> get forms => Set.unmodifiable(_forms);
  int get count => _count;
  QuizMode get mode => _mode;

  void setScope(StudyScope? s) {
    _scope = s;
    _favoritesOnly = false;
    _changed();
  }

  void setFavoritesOnly() {
    _scope = null;
    _favoritesOnly = true;
    _changed();
  }

  void setAutoSpeak(bool on) {
    _autoSpeak = on;
    _changed();
  }

  void setGroup(VerbGroup? g) {
    _group = g;
    _changed();
  }

  void toggleForm(FormType f, bool on) {
    on ? _forms.add(f) : _forms.remove(f);
    _changed();
  }

  void setCount(int c) {
    _count = c;
    _changed();
  }

  void setMode(QuizMode m) {
    _mode = m;
    _changed();
  }

  void _changed() {
    notifyListeners();
    _repo.saveSetting(_key, jsonEncode(_toJson()));
  }

  Map<String, Object?> _toJson() => {
    'scope': _scope == null
        ? null
        : {'kind': _scope!.kind.name, 'key': _scope!.key},
    'favoritesOnly': _favoritesOnly,
    'autoSpeak': _autoSpeak,
    'group': _group?.name,
    'forms': [
      for (final f in FormType.values)
        if (_forms.contains(f)) f.name,
    ],
    'count': _count,
    'mode': _mode.name,
  };

  /// 저장해 둔 설정을 읽는다. 없거나 읽을 수 없는 값은 기본값 그대로 둔다.
  Future<void> load() async {
    try {
      final raw = await _repo.setting(_key);
      if (raw == null) return;
      final j = jsonDecode(raw) as Map<String, dynamic>;
      T? byName<T extends Enum>(List<T> values, Object? name) {
        for (final v in values) {
          if (v.name == name) return v;
        }
        return null;
      }

      final scope = j['scope'] as Map<String, dynamic>?;
      if (scope != null) {
        final all = [
          ...StudyScope.stages,
          ...StudyScope.topics,
          ...StudyScope.jlpt,
        ];
        _scope = all
            .where((e) => e.kind.name == scope['kind'] && e.key == scope['key'])
            .firstOrNull;
      }
      _favoritesOnly = j['favoritesOnly'] == true && _scope == null;
      _autoSpeak = j['autoSpeak'] != false;
      _group = byName(VerbGroup.values, j['group']);
      final forms = [
        for (final n in (j['forms'] as List? ?? const []))
          ?byName(FormType.values, n),
      ];
      if (forms.isNotEmpty) {
        _forms
          ..clear()
          ..addAll(forms);
      }
      final count = j['count'];
      if (count is int && count > 0) _count = count;
      _mode = byName(QuizMode.values, j['mode']) ?? QuizMode.choice;
      notifyListeners();
    } catch (e) {
      debugPrint('퀴즈 설정을 읽지 못했습니다: $e');
    }
  }

  /// 설정 요약 (퀴즈 메뉴에 표시). 예: 'JLPT N5 · 5단 · 10문제 · 글자 맞추기'
  String get summary => [
    _favoritesOnly ? '즐겨찾기' : (_scope?.title ?? '전체 동사'),
    if (_group != null) groupLabel(_group!),
    '$_count문제',
    _mode.label,
  ].join(' · ');

  /// 범위와 그룹에 맞는 동사. [isFavorite]는 즐겨찾기 범위일 때 쓴다.
  bool matches(Verb v, bool Function(Verb) isFavorite) =>
      (_scope == null || _scope!.matches(v)) &&
      (!_favoritesOnly || isFavorite(v)) &&
      (_group == null || v.group == _group);

  /// 현재 설정으로 문제를 만들어 퀴즈 화면을 연다.
  Future<void> start(BuildContext context) async {
    final repo = context.read<VerbRepository>();
    final isFavorite = context.read<VerbProvider>().isFavorite;
    final verbs = (await repo.allVerbs())
        .where((v) => matches(v, isFavorite))
        .toList();
    final forms = FormType.values.where(_forms.contains).toList();
    final questions = QuizGenerator().generate(
      verbs: verbs,
      forms: forms,
      count: _count,
    );
    if (!context.mounted) return;
    if (questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _favoritesOnly && verbs.isEmpty
                ? '즐겨찾기한 동사가 없습니다. 활용표의 ☆를 눌러 추가해 보세요.'
                : '출제할 문제가 없습니다. 범위를 바꿔 보세요.',
          ),
        ),
      );
      return;
    }
    Navigator.of(context).push(QuizScreen.route(questions, repo, mode: _mode));
  }
}
