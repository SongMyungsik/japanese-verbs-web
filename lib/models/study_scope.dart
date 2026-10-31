import 'verb.dart';

/// 학습 범위의 종류
enum ScopeKind { stage, topic, jlpt }

/// 학습 화면에서 고른 동사 범위. 예: 1단계, '일상생활' 주제, N5
class StudyScope {
  final ScopeKind kind;
  final String key; // 단계 번호('1'), 주제 이름, JLPT 급수('N5')
  final String title; // 목록 화면 제목
  final String description;

  const StudyScope(this.kind, this.key, this.title, [this.description = '']);

  bool matches(Verb v) => switch (kind) {
    ScopeKind.stage => '${v.learningStage}' == key,
    ScopeKind.topic => v.topics.contains(key),
    ScopeKind.jlpt => v.jlptLevel == key,
  };

  /// 단계별 학습
  static const List<StudyScope> stages = [
    StudyScope(ScopeKind.stage, '1', '1단계', '생활 필수 동사'),
    StudyScope(ScopeKind.stage, '2', '2단계', '일상에 자주 쓰는 기본 동사'),
    StudyScope(ScopeKind.stage, '3', '3단계', '문법/표현 확장에 유용한 동사'),
    StudyScope(ScopeKind.stage, '4', '4단계', '사회생활/업무 등 상황별 동사'),
    StudyScope(ScopeKind.stage, '5', '5단계', '문어적/추상적 동사'),
    StudyScope(ScopeKind.stage, '6', '6단계', '경어/격식/고급 표현 (존경어, 겸양어)'),
  ];

  /// 주제별 학습
  static const List<StudyScope> topics = [
    StudyScope(ScopeKind.topic, '일상생활', '일상생활'),
    StudyScope(ScopeKind.topic, '이동/교통/여행', '이동/교통/여행'),
    StudyScope(ScopeKind.topic, '학습/사고/감정', '학습/사고/감정'),
    StudyScope(ScopeKind.topic, '직장/사회/실용', '직장/사회/실용'),
    StudyScope(ScopeKind.topic, '기타', '기타'),
  ];

  /// JLPT 학습
  static const List<StudyScope> jlpt = [
    StudyScope(ScopeKind.jlpt, 'N5', 'JLPT N5'),
    StudyScope(ScopeKind.jlpt, 'N4', 'JLPT N4'),
    StudyScope(ScopeKind.jlpt, 'N3', 'JLPT N3'),
    StudyScope(ScopeKind.jlpt, 'N2', 'JLPT N2'),
    StudyScope(ScopeKind.jlpt, 'N1', 'JLPT N1'),
    StudyScope(ScopeKind.jlpt, '미분류', 'JLPT 미분류', 'JLPT 급수가 정해지지 않은 동사'),
  ];

  @override
  bool operator ==(Object other) =>
      other is StudyScope && other.kind == kind && other.key == key;

  @override
  int get hashCode => Object.hash(kind, key);
}
