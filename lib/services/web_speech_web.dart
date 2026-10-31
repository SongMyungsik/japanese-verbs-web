import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// [text]를 일본어로 읽는다. 일본어 음성이 없으면 false를 돌려준다.
///
/// flutter_tts는 음성만 고르고 언어를 비워 둘 수 있는데, 그러면 페이지 언어(ko)로 읽힌다.
/// Android 크롬은 고른 음성보다 언어를 따르므로 lang을 반드시 ja-JP로 준다.
Future<bool> speakOnWeb(String text) async {
  final synth = web.window.speechSynthesis;
  var voices = synth.getVoices().toDart;
  // 목록이 늦게 채워진다. 바로 읽어야 사파리가 버튼을 누른 동작으로 인정하므로 있으면 기다리지 않는다.
  for (var i = 0; i < 10 && voices.isEmpty; i++) {
    await Future.delayed(const Duration(milliseconds: 200));
    voices = synth.getVoices().toDart;
  }
  // Android는 언어를 ja_JP로 적기도 한다.
  final ja = voices.where((v) => v.lang.toLowerCase().startsWith('ja'));
  // 목록을 끝내 안 주는 브라우저도 있어서, 비어 있으면 lang만 믿고 시도한다.
  if (voices.isNotEmpty && ja.isEmpty) return false;

  synth.cancel();
  final utterance = web.SpeechSynthesisUtterance(text)
    ..lang = 'ja-JP'
    ..rate = 0.9; // 웹은 1.0이 보통 속도
  if (ja.isNotEmpty) utterance.voice = ja.first;
  synth.speak(utterance);
  return true;
}

void stopOnWeb() => web.window.speechSynthesis.cancel();
