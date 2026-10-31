enum VerbGroup { ichidan, godan, irregular }

enum FormType {
  masu, // ます형
  nai, // ない형
  te, // て형
  ta, // た형
  potential, // 가능형
  volitional, // 의지·권유형
  imperative, // 명령형
  conditional, // 가정형(ば)
  passive, // 수동형
  causative, // 사역형
  causativePassive, // 사역수동형
  desire, // 희망형(たい)
  negativePast, // 부정과거(なかった)
}

extension FormTypeLabel on FormType {
  String get label => switch (this) {
    FormType.masu => 'ます형',
    FormType.nai => 'ない형',
    FormType.te => 'て형',
    FormType.ta => 'た형',
    FormType.potential => '가능형',
    FormType.volitional => '의지형',
    FormType.imperative => '명령형',
    FormType.conditional => '가정형(ば)',
    FormType.passive => '수동형',
    FormType.causative => '사역형',
    FormType.causativePassive => '사역수동형',
    FormType.desire => '희망형(たい)',
    FormType.negativePast => '부정과거(なかった)',
  };

  /// 활용표 화면용: 이름 뒤에 한국어 뜻을 괄호로 붙인다. 예: ます형(합니다)
  String get glossLabel => switch (this) {
    FormType.masu => 'ます형(합니다)',
    FormType.nai => 'ない형(~하지 않다)',
    FormType.te => 'て형(~하고)',
    FormType.ta => 'た형(~했다)',
    FormType.potential => '가능형(~할 수 있다)',
    FormType.volitional => '의지형(~하자)',
    FormType.imperative => '명령형(~해라)',
    FormType.conditional => '가정형(~하면)',
    FormType.passive => '수동형(~당하다)',
    FormType.causative => '사역형(~시키다)',
    FormType.causativePassive => '사역수동형(억지로 ~하다)',
    FormType.desire => '희망형(~하고 싶다)',
    FormType.negativePast => '부정과거(~하지 않았다)',
  };
}

class Verb {
  final int id;
  final String text; // 사전형 (한자 포함 표기), 예: 買う
  final String reading; // 사전형 읽기, 예: かう
  final String meaning;
  final VerbGroup group;
  final String ending; // 사전형의 마지막 글자 (5단 활용 행 판별에 사용)
  final String note;

  /// 상태를 나타내는 동사(ある, できる, 分かる 등).
  /// 가능·수동·사역·명령형이 성립하지 않는다.
  final bool stative;

  /// 주제 (여러 개일 수 있다). 예: ['일상생활', '이동/교통/여행']
  final List<String> topics;

  /// 학습 단계 1~6 (0 = 미지정)
  final int learningStage;

  /// JLPT 급수: 'N5'~'N1' 또는 '미분류'
  final String jlptLevel;

  /// JLPT 급수가 확인된 것인지 여부
  final bool jlptVerified;

  const Verb({
    required this.id,
    required this.text,
    required this.reading,
    required this.meaning,
    required this.group,
    required this.ending,
    this.note = '',
    this.stative = false,
    this.topics = const [],
    this.learningStage = 0,
    this.jlptLevel = '',
    this.jlptVerified = false,
  });

  /// JSON의 참/거짓은 true/false 또는 엑셀에서 온 "TRUE"/"FALSE" 문자열일 수 있다.
  static bool _bool(Object? v) => switch (v) {
    bool b => b,
    String s => s.trim().toUpperCase() == 'TRUE',
    num n => n != 0,
    _ => false,
  };

  /// 'A|B' 형태의 주제 문자열 → ['A', 'B']
  static List<String> _topics(Object? v) => switch (v) {
    List l => l.map((e) => '$e'.trim()).where((e) => e.isNotEmpty).toList(),
    String s =>
      s.split('|').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
    _ => const [],
  };

  factory Verb.fromJson(Map<String, dynamic> j) => Verb(
    id: j['id'] as int,
    text: j['text'] as String,
    reading: j['reading'] as String,
    meaning: j['meaning'] as String,
    group: VerbGroup.values.byName(j['group'] as String),
    ending: j['ending'] as String,
    note: (j['note'] as String?) ?? '',
    stative: _bool(j['stative']),
    topics: _topics(j['topics']),
    learningStage: (j['learning_stage'] as num?)?.toInt() ?? 0,
    jlptLevel: ((j['jlpt_level'] as String?) ?? '').trim(),
    jlptVerified: _bool(j['jlpt_verified']),
  );

  Map<String, Object?> toRow() => {
    'id': id,
    'text': text,
    'reading': reading,
    'meaning': meaning,
    'verb_group': group.name,
    'ending': ending,
    'note': note,
    'stative': stative ? 1 : 0,
    'topics': topics.join('|'),
    'learning_stage': learningStage,
    'jlpt_level': jlptLevel,
    'jlpt_verified': jlptVerified ? 1 : 0,
  };

  factory Verb.fromRow(Map<String, Object?> r) => Verb(
    id: r['id'] as int,
    text: r['text'] as String,
    reading: r['reading'] as String,
    meaning: r['meaning'] as String,
    group: VerbGroup.values.byName(r['verb_group'] as String),
    ending: r['ending'] as String,
    note: (r['note'] as String?) ?? '',
    stative: ((r['stative'] as int?) ?? 0) == 1,
    topics: _topics(r['topics']),
    learningStage: (r['learning_stage'] as int?) ?? 0,
    jlptLevel: (r['jlpt_level'] as String?) ?? '',
    jlptVerified: ((r['jlpt_verified'] as int?) ?? 0) == 1,
  );

  /// 한자 옆에 히라가나를 ( )로 붙인 표기. 히라가나만 쓰는 동사는 그대로.
  String get display => text == reading ? text : '$text($reading)';
}

/// 활용 결과: 표기(한자 포함)와 읽기(히라가나).
class Conjugation {
  final String text;
  final String reading;
  const Conjugation(this.text, this.reading);

  String get display => text == reading ? text : '$text($reading)';

  @override
  bool operator ==(Object other) =>
      other is Conjugation && other.text == text && other.reading == reading;

  @override
  int get hashCode => Object.hash(text, reading);

  @override
  String toString() => display;
}
