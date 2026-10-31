import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../models/study_scope.dart';
import '../models/verb.dart';
import '../models/verb_extras.dart';
import '../services/verb_repository.dart';

/// 동사 목록의 정렬 방식
enum VerbSort {
  reading, // 발음(히라가나) 순: あいうえお
  meaning, // 뜻의 한글 가나다 순
  group, // 그룹별: 1단 → 5단 → 불규칙 (같은 그룹 안에서는 발음순)
}

extension VerbSortLabel on VerbSort {
  /// 정렬 메뉴에 보이는 이름
  String get label => switch (this) {
    VerbSort.reading => '발음순 (あいうえお)',
    VerbSort.meaning => '뜻 가나다순',
    VerbSort.group => '그룹별 (1단·5단·불규칙)',
  };

  /// 개수 줄 옆에 보이는 짧은 이름
  String get shortLabel => switch (this) {
    VerbSort.reading => '발음순',
    VerbSort.meaning => '뜻 가나다순',
    VerbSort.group => '그룹별',
  };
}

/// 동사 목록, 검색·필터·정렬 상태, 읽기 표시 여부를 관리한다.
class VerbProvider extends ChangeNotifier {
  VerbProvider(this._repo) {
    // 퀴즈에서 답을 기록할 때마다 학습 진도를 다시 센다.
    _repo.reviewVersion.addListener(_loadProgress);
  }

  @override
  void dispose() {
    _repo.reviewVersion.removeListener(_loadProgress);
    super.dispose();
  }

  /// 이 상자 번호 이상이면 '익숙한' 동사로 본다. (복습 화면의 '익숙함'과 같은 기준)
  static const int masteredBox = 4;

  final VerbRepository _repo;

  /// 5단동사 어미 행 (필터 칩에 쓴다)
  static const List<String> godanEndings = [
    'う',
    'く',
    'ぐ',
    'す',
    'つ',
    'ぬ',
    'ぶ',
    'む',
    'る',
  ];

  List<Verb> _all = [];
  List<Verb> _sorted = []; // _all을 현재 정렬 방식대로 늘어놓은 것
  VerbSort _sort = VerbSort.reading;
  bool _loading = true;
  VerbGroup? _group;
  String? _ending;
  String _query = '';
  StudyScope? _scope; // 학습 화면에서 고른 범위 (null = 전체 동사)
  bool _showReading = true;
  bool _favoritesOnly = false; // 동사 목록에서 즐겨찾기만 보기
  Set<int> _favorites = {};
  Map<int, int> _bestBox = {}; // 동사 번호 → 가장 높은 상자 (푼 동사만)
  Verb? _selected; // 활용표 화면에 보여 줄 동사

  bool get loading => _loading;
  Verb? get selectedVerb => _selected;
  VerbGroup? get group => _group;
  String? get ending => _ending;
  bool get showReading => _showReading;
  int get totalCount => _all.length;
  VerbSort get sort => _sort;
  StudyScope? get scope => _scope;
  List<Verb> get allVerbs => _all;

  /// 범위에 드는 동사 수 (학습 메뉴에 표시)
  int countIn(StudyScope s) => _all.where(s.matches).length;

  Map<int, VerbExample> _examples = {};
  Map<int, List<VerbPartner>> _partners = {};

  /// 동사의 예문 (없으면 null)
  VerbExample? exampleOf(Verb v) => _examples[v.id];

  /// 동사의 자동사·타동사 짝 (없으면 빈 목록)
  List<VerbPartner> partnersOf(Verb v) => _partners[v.id] ?? const [];

  bool get favoritesOnly => _favoritesOnly;
  int get favoriteCount => _favorites.length;
  bool isFavorite(Verb v) => _favorites.contains(v.id);

  /// 즐겨찾기 동사 (현재 정렬 순서대로)
  List<Verb> get favoriteVerbs =>
      _sorted.where((v) => _favorites.contains(v.id)).toList();

  /// 즐겨찾기를 켜고 끈다. DB에도 바로 저장한다.
  Future<void> toggleFavorite(Verb v) async {
    final on = !_favorites.contains(v.id);
    on ? _favorites.add(v.id) : _favorites.remove(v.id);
    notifyListeners();
    await _repo.setFavorite(v.id, on);
  }

  void setFavoritesOnly(bool on) {
    _favoritesOnly = on;
    notifyListeners();
  }

  /// 범위의 학습 진도
  ScopeProgress progressIn(bool Function(Verb) test) {
    var total = 0, solved = 0, mastered = 0;
    for (final v in _all) {
      if (!test(v)) continue;
      total++;
      final box = _bestBox[v.id];
      if (box == null) continue;
      solved++;
      if (box >= masteredBox) mastered++;
    }
    return ScopeProgress(total: total, solved: solved, mastered: mastered);
  }

  Future<void> _loadProgress() async {
    _bestBox = await _repo.verbProgress();
    notifyListeners();
  }

  Future<void> load() async {
    _all = await _repo.allVerbs();
    await _loadExtras();
    _favorites = await _repo.favoriteIds();
    _bestBox = await _repo.verbProgress();
    _resort();
    _loading = false;
    notifyListeners();
  }

  /// 예문과 자동사·타동사 짝을 읽는다. 파일이 없거나 깨져도 앱은 그대로 쓸 수 있게 한다.
  Future<void> _loadExtras() async {
    final byId = {for (final v in _all) v.id: v};
    try {
      final ex =
          jsonDecode(await rootBundle.loadString('assets/data/examples.json'))
              as Map<String, dynamic>;
      _examples = {
        for (final e in ex.entries)
          int.parse(e.key): VerbExample.fromJson(
            e.value as Map<String, dynamic>,
          ),
      };
    } catch (e) {
      debugPrint('예문을 읽지 못했습니다: $e');
    }
    try {
      final pairs =
          jsonDecode(await rootBundle.loadString('assets/data/verb_pairs.json'))
              as List;
      final partners = <int, List<VerbPartner>>{};
      for (final p in pairs.cast<Map<String, dynamic>>()) {
        final vi = byId[p['intransitive']];
        final vt = byId[p['transitive']];
        if (vi == null || vt == null) continue;
        (partners[vi.id] ??= []).add(VerbPartner(vt, transitive: true));
        (partners[vt.id] ??= []).add(VerbPartner(vi, transitive: false));
      }
      _partners = partners;
    } catch (e) {
      debugPrint('자동사·타동사 짝을 읽지 못했습니다: $e');
    }
  }

  void setSort(VerbSort s) {
    if (s == _sort) return;
    _sort = s;
    _resort();
    notifyListeners();
  }

  void _resort() {
    final list = [..._all];
    list.sort(_compare);
    _sorted = list;
  }

  /// '(샤워 등을) 하다'처럼 앞의 괄호 설명은 빼고 뜻의 첫 낱말로 정렬한다.
  static final RegExp _leadingParen = RegExp(r'^\([^)]*\)\s*');
  String _meaningKey(Verb v) =>
      v.meaning.replaceFirst(_leadingParen, '').trim();

  int _compare(Verb a, Verb b) {
    // 히라가나는 코드 값이 あいうえお 순서(탁음은 청음 바로 뒤)로 놓여 있고,
    // 한글 음절은 가나다 순서로 놓여 있어서 문자열 비교로 충분하다.
    int c;
    switch (_sort) {
      case VerbSort.reading:
        c = a.reading.compareTo(b.reading);
      case VerbSort.meaning:
        c = _meaningKey(a).compareTo(_meaningKey(b));
      case VerbSort.group:
        c = a.group.index.compareTo(b.group.index);
        if (c == 0) c = a.reading.compareTo(b.reading);
    }
    if (c != 0) return c;
    // 같으면 읽기 → 표기 → 번호 순으로 정해서 항상 같은 순서가 나오게 한다.
    c = a.reading.compareTo(b.reading);
    if (c != 0) return c;
    c = a.text.compareTo(b.text);
    if (c != 0) return c;
    return a.id.compareTo(b.id);
  }

  /// 현재 필터·검색 조건에 맞는 동사 (현재 정렬 순서대로)
  List<Verb> get verbs {
    final q = _query.trim();
    return _sorted.where((v) {
      if (_scope != null && !_scope!.matches(v)) return false;
      if (_favoritesOnly && !_favorites.contains(v.id)) return false;
      if (_group != null && v.group != _group) return false;
      if (_ending != null && v.ending != _ending) return false;
      if (q.isNotEmpty &&
          !(v.text.contains(q) ||
              v.reading.contains(q) ||
              v.meaning.contains(q))) {
        return false;
      }
      return true;
    }).toList();
  }

  /// 목록 화면을 열 때 범위를 정하고 검색·필터를 초기화한다.
  /// 화면을 만드는 도중(initState)에 부르므로 [notify]를 끌 수 있다.
  void setScope(StudyScope? s, {bool notify = true}) {
    _scope = s;
    _group = null;
    _ending = null;
    _query = '';
    _favoritesOnly = false;
    if (notify) notifyListeners();
  }

  void setGroup(VerbGroup? g) {
    _group = g;
    _ending = null; // 그룹을 바꾸면 어미 필터는 초기화
    notifyListeners();
  }

  void setEnding(String? e) {
    _ending = e;
    notifyListeners();
  }

  void setQuery(String q) {
    _query = q;
    notifyListeners();
  }

  void toggleReading() {
    _showReading = !_showReading;
    notifyListeners();
  }

  /// 활용표 화면에서 볼 동사를 고른다.
  void select(Verb v) {
    _selected = v;
    notifyListeners();
  }

  /// 현재 목록(검색·필터 결과)에서 선택한 동사의 위치. 목록에 없으면 -1.
  int get _selectedIndex {
    final s = _selected;
    if (s == null) return -1;
    return verbs.indexWhere((v) => v.id == s.id);
  }

  bool get hasPrev => _selectedIndex > 0;

  bool get hasNext {
    final i = _selectedIndex;
    return i != -1 && i < verbs.length - 1;
  }

  /// 이전(-1) / 다음(+1) 동사로 넘어간다.
  void stepSelected(int delta) {
    final list = verbs;
    final i = _selectedIndex;
    if (i == -1) return;
    final next = (i + delta).clamp(0, list.length - 1).toInt();
    _selected = list[next];
    notifyListeners();
  }
}

/// 범위(단계·주제·JLPT 등)의 학습 진도
class ScopeProgress {
  final int total; // 범위의 동사 수
  final int solved; // 퀴즈에서 한 번이라도 푼 동사 수
  final int mastered; // 익숙한 동사 수 (VerbProvider.masteredBox 기준)

  const ScopeProgress({
    required this.total,
    required this.solved,
    required this.mastered,
  });

  double get masteredRatio => total == 0 ? 0 : mastered / total;
  double get solvedRatio => total == 0 ? 0 : solved / total;
}
