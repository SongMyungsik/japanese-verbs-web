import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'web_speech.dart';

/// 일본어 읽어주기. 기기에 들어 있는 음성 합성(TTS) 엔진을 쓰므로 인터넷이 필요 없다.
///
/// 한자 표기는 엔진이 다르게 읽을 수 있어서 히라가나 읽기를 넘긴다.
class SpeechService {
  final FlutterTts _tts = FlutterTts();
  Future<bool>? _ready;

  /// 일본어 음성이 있는지 확인하고 언어·속도를 맞춘다. 처음 말할 때 한 번만 한다.
  Future<bool> _init() async {
    try {
      // 확인 기능이 없는 플랫폼(데스크톱 등)도 있어서, 확인에 실패하면 그냥 시도한다.
      Object? available;
      try {
        available = await _tts.isLanguageAvailable('ja-JP');
      } catch (_) {}
      if (available == false) return false;
      await _tts.setLanguage('ja-JP');
      await _tts.setSpeechRate(0.45); // 학습용으로 조금 천천히 (0.5가 보통 속도)
      await _tts.awaitSpeakCompletion(false);
      return true;
    } catch (e) {
      debugPrint('TTS 초기화 실패: $e');
      return false;
    }
  }

  /// [text]를 읽는다. 읽는 중이면 멈추고 새로 읽는다.
  /// 일본어 음성이 없으면 false를 돌려준다.
  Future<bool> speak(String text) async {
    if (kIsWeb) return speakOnWeb(text);
    final ok = await (_ready ??= _init());
    if (!ok) {
      _ready = null; // 나중에 음성을 설치했을 수도 있으니 다음에 다시 확인한다.
      return false;
    }
    await _tts.stop();
    await _tts.speak(text);
    return true;
  }

  Future<void> stop() async {
    if (kIsWeb) return stopOnWeb();
    await _tts.stop();
  }
}
