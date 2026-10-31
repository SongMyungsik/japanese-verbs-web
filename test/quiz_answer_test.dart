import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_verbs_app/providers/quiz_controller.dart';

/// 글자 맞추기 퀴즈의 답 다듬기: 공백은 없애고 가타카나는 히라가나로 바꾼다.
void main() {
  test('공백(반각·전각)을 없앤다', () {
    expect(normalizeAnswer(' かき ます　'), 'かきます');
  });

  test('가타카나는 히라가나로 바꾼다', () {
    expect(normalizeAnswer('カキマス'), 'かきます');
    expect(normalizeAnswer('ヴ'), 'ゔ');
  });

  test('한자와 장음은 그대로 둔다', () {
    expect(normalizeAnswer('書きます'), '書きます');
    expect(normalizeAnswer('ー'), 'ー');
  });
}
