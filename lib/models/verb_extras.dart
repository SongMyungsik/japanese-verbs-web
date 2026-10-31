import 'verb.dart';

/// 동사 예문 (assets/data/examples.json). 표기·히라가나 읽기·한국어 뜻.
class VerbExample {
  final String ja;
  final String reading;
  final String ko;

  const VerbExample(this.ja, this.reading, this.ko);

  factory VerbExample.fromJson(Map<String, dynamic> j) =>
      VerbExample(j['ja'] as String, j['reading'] as String, j['ko'] as String);
}

/// 자동사·타동사 짝의 상대 동사 (assets/data/verb_pairs.json)
class VerbPartner {
  final Verb verb;

  /// 상대가 타동사인지 (false면 상대가 자동사)
  final bool transitive;

  const VerbPartner(this.verb, {required this.transitive});

  String get roleLabel => transitive ? '타동사' : '자동사';
}
