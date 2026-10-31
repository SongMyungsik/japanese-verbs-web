// 활용 엔진이 만든 모든 동사의 활용형을 JSON으로 내보낸다. (정답 검토용)
//
//   dart run tool/dump_forms.dart forms.json
//
// 형식은 expected_forms.json과 같다: { "id": { "masu": ["표기", "읽기"], ... } }
// 활용이 성립하지 않거나 쓰지 않는 칸은 null로 적는다.
import 'dart:convert';
import 'dart:io';

import 'package:japanese_verbs_app/models/verb.dart';
import 'package:japanese_verbs_app/services/conjugator.dart';

void main(List<String> args) {
  final verbs =
      (jsonDecode(File('assets/data/verbs.json').readAsStringSync()) as List)
          .map((e) => Verb.fromJson(e as Map<String, dynamic>));
  const conjugator = Conjugator();
  final out = <String, Map<String, List<String>?>>{
    for (final v in verbs)
      '${v.id}': {
        for (final e in conjugator.conjugateAll(v).entries)
          e.key.name: e.value == null
              ? null
              : [e.value!.text, e.value!.reading],
      },
  };
  // dart run이 화면에 진행 메시지를 섞어 쓰므로 파일로 바로 저장한다.
  File(
    args.single,
  ).writeAsStringSync(const JsonEncoder.withIndent(' ').convert(out));
}
