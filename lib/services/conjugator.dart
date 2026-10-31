import '../models/verb.dart';

/// 일본어 동사 활용 규칙 엔진.
///
/// 활용형 = (사전형에서 마지막 글자를 뺀 어간) + 접미사.
/// 표기(text)와 읽기(reading)에 같은 접미사를 각각 붙여서 만든다.
class Conjugator {
  const Conjugator();

  /// 5단동사: 어미 → [あ단(ない), い단(ます), え단(가능·명령·가정), お단(의지), て, た]
  static const Map<String, List<String>> _godan = {
    'う': ['わ', 'い', 'え', 'お', 'って', 'った'],
    'く': ['か', 'き', 'け', 'こ', 'いて', 'いた'],
    'ぐ': ['が', 'ぎ', 'げ', 'ご', 'いで', 'いだ'],
    'す': ['さ', 'し', 'せ', 'そ', 'して', 'した'],
    'つ': ['た', 'ち', 'て', 'と', 'って', 'った'],
    'ぬ': ['な', 'に', 'ね', 'の', 'んで', 'んだ'],
    'ぶ': ['ば', 'び', 'べ', 'ぼ', 'んで', 'んだ'],
    'む': ['ま', 'み', 'め', 'も', 'んで', 'んだ'],
    'る': ['ら', 'り', 'れ', 'ろ', 'って', 'った'],
  };

  /// 불규칙동사: 사전형 → 활용형 → [표기, 읽기]
  static const Map<String, Map<FormType, List<String>>> _irregular = {
    'する': {
      FormType.masu: ['します', 'します'],
      FormType.nai: ['しない', 'しない'],
      FormType.te: ['して', 'して'],
      FormType.ta: ['した', 'した'],
      FormType.potential: ['できる', 'できる'],
      FormType.volitional: ['しよう', 'しよう'],
      FormType.imperative: ['しろ', 'しろ'],
      FormType.conditional: ['すれば', 'すれば'],
      FormType.passive: ['される', 'される'],
      FormType.causative: ['させる', 'させる'],
      FormType.causativePassive: ['させられる', 'させられる'],
      FormType.desire: ['したい', 'したい'],
      FormType.negativePast: ['しなかった', 'しなかった'],
    },
    '来る': {
      FormType.masu: ['来ます', 'きます'],
      FormType.nai: ['来ない', 'こない'],
      FormType.te: ['来て', 'きて'],
      FormType.ta: ['来た', 'きた'],
      FormType.potential: ['来られる', 'こられる'],
      FormType.volitional: ['来よう', 'こよう'],
      FormType.imperative: ['来い', 'こい'],
      FormType.conditional: ['来れば', 'くれば'],
      FormType.passive: ['来られる', 'こられる'],
      FormType.causative: ['来させる', 'こさせる'],
      FormType.causativePassive: ['来させられる', 'こさせられる'],
      FormType.desire: ['来たい', 'きたい'],
      FormType.negativePast: ['来なかった', 'こなかった'],
    },
  };

  /// 상태동사(ある, できる, 分かる 등)에서는 만들지 않는 활용형
  static const Set<FormType> _noneWhenStative = {
    FormType.potential,
    FormType.imperative,
    FormType.passive,
    FormType.causative,
    FormType.causativePassive,
  };

  /// 활용형을 만든다. 활용이 성립하지 않는 경우(예: できる의 가능형)는 null.
  Conjugation? conjugate(Verb verb, FormType form) {
    if (verb.stative) {
      if (_noneWhenStative.contains(form)) return null;
      // ある의 부정은 あらない가 아니라 ない
      if (verb.text == 'ある') {
        if (form == FormType.nai) return const Conjugation('ない', 'ない');
        if (form == FormType.negativePast) {
          return const Conjugation('なかった', 'なかった');
        }
      }
    }
    final special = _special(verb, form);
    if (special != null) return special.$1;
    switch (verb.group) {
      case VerbGroup.irregular:
        return _conjugateIrregular(verb, form);
      case VerbGroup.ichidan:
        return _conjugateIchidan(verb, form);
      case VerbGroup.godan:
        return _conjugateGodan(verb, form);
    }
  }

  /// 모든 활용형을 한 번에 만든다.
  Map<FormType, Conjugation?> conjugateAll(Verb verb) => {
    for (final f in FormType.values) f: conjugate(verb, f),
  };

  Conjugation? _conjugateIrregular(Verb verb, FormType form) {
    final direct = _irregular[verb.text]?[form];
    if (direct != null) return Conjugation(direct[0], direct[1]);

    // 勉強する처럼 'する'로 끝나는 복합동사는 する의 활용을 그대로 따른다.
    if (verb.text.endsWith('する') && verb.reading.endsWith('する')) {
      final row = _irregular['する']?[form];
      if (row == null) return null;
      return Conjugation(
        verb.text.substring(0, verb.text.length - 2) + row[0],
        verb.reading.substring(0, verb.reading.length - 2) + row[1],
      );
    }
    return null;
  }

  Conjugation? _conjugateIchidan(Verb verb, FormType form) {
    final suffix = switch (form) {
      FormType.masu => 'ます',
      FormType.nai => 'ない',
      FormType.te => 'て',
      FormType.ta => 'た',
      FormType.potential => 'られる',
      FormType.volitional => 'よう',
      FormType.imperative => 'ろ',
      FormType.conditional => 'れば',
      FormType.passive => 'られる',
      FormType.causative => 'させる',
      FormType.causativePassive => 'させられる',
      FormType.desire => 'たい',
      FormType.negativePast => 'なかった',
    };
    return _attach(verb, suffix);
  }

  Conjugation? _conjugateGodan(Verb verb, FormType form) {
    final row = _godan[verb.ending];
    if (row == null) return null;
    final a = row[0], i = row[1], e = row[2], o = row[3];
    var te = row[4], ta = row[5];

    // 行く의 て·た형은 예외다. (行いて ✕)
    if (verb.text.endsWith('行く') && verb.reading.endsWith('いく')) {
      te = 'って';
      ta = 'った';
    }

    final suffix = switch (form) {
      FormType.masu => '$iます',
      FormType.nai => '$aない',
      FormType.te => te,
      FormType.ta => ta,
      FormType.potential => '$eる',
      FormType.volitional => '$oう',
      FormType.imperative => e,
      FormType.conditional => '$eば',
      FormType.passive => '$aれる',
      FormType.causative => '$aせる',
      // 5단의 사역수동은 줄인 형태(書かされる)가 일반적이다.
      // 단, す로 끝나는 동사는 줄이지 않는다. (話させられる)
      FormType.causativePassive => verb.ending == 'す' ? '$aせられる' : '$aされる',
      FormType.desire => '$iたい',
      FormType.negativePast => '$aなかった',
    };
    return _attach(verb, suffix);
  }

  /// くださる형 존경어 동사 (사전 품사 v5aru)
  static const List<String> _honorificAru = ['くださる', 'なさる', 'おっしゃる', 'いらっしゃる'];

  /// 존경어·くれる에서 실제로는 쓰지 않아 비워 두는 활용형
  static const Set<FormType> _unusedHonorific = {
    FormType.potential,
    FormType.volitional,
    FormType.passive,
    FormType.causative,
    FormType.causativePassive,
    FormType.desire,
  };

  /// 한 글자 한자 + する 중 5단 '~す'처럼 활용하는 동사 (사전 품사 vs-s)
  static const Set<String> _suToGodan = {'愛する'};

  /// 규칙에서 벗어나는 동사. 해당하면 (결과)를, 아니면 null을 돌려준다.
  /// 결과 안의 null은 '쓰지 않는 활용형'이라는 뜻이다.
  (Conjugation?,)? _special(Verb verb, FormType form) {
    // くださる·なさる·おっしゃる·いらっしゃる: くださいます / ください
    if (verb.group == VerbGroup.godan &&
        _honorificAru.any(verb.reading.endsWith)) {
      if (_unusedHonorific.contains(form)) return (null,);
      return switch (form) {
        FormType.masu => (_attach(verb, 'います'),),
        FormType.imperative => (_attach(verb, 'い'),),
        _ => (_conjugateGodan(verb, form),),
      };
    }
    // くれる(주다): 명령형이 くれろ가 아니라 くれ
    // 읽기가 같은 暮れる(저물다)는 보통 1단이라 표기로 구분한다.
    if (verb.group == VerbGroup.ichidan &&
        (verb.text == 'くれる' || verb.text == '呉れる')) {
      if (_unusedHonorific.contains(form)) return (null,);
      if (form == FormType.imperative) return (_attach(verb, ''),);
      return (_conjugateIchidan(verb, form),);
    }
    // 愛する: 愛す(5단)처럼 활용한다. 愛さない·愛せる·愛そう·愛せ
    if (_suToGodan.contains(verb.text)) {
      final su = Verb(
        id: verb.id,
        text: verb.text.substring(0, verb.text.length - 1),
        reading: verb.reading.substring(0, verb.reading.length - 1),
        meaning: verb.meaning,
        group: VerbGroup.godan,
        ending: 'す',
      );
      // 가정형·사역·사역수동은 する 쪽 형태가 일반적이다. (愛すれば·愛させる)
      return switch (form) {
        FormType.conditional ||
        FormType.causative ||
        FormType.causativePassive => (_conjugateIrregular(verb, form),),
        _ => (_conjugateGodan(su, form),),
      };
    }
    return null;
  }

  /// 표기·읽기 각각에서 마지막 글자를 떼고 접미사를 붙인다.
  Conjugation _attach(Verb verb, String suffix) {
    final text = verb.text.substring(0, verb.text.length - 1) + suffix;
    final reading = verb.reading.substring(0, verb.reading.length - 1) + suffix;
    return Conjugation(text, reading);
  }
}
