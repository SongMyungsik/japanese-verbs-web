// 웹에서만 브라우저 음성 기능을 직접 쓴다. 네이티브는 flutter_tts를 쓰므로 빈 구현이다.
export 'web_speech_stub.dart'
    if (dart.library.js_interop) 'web_speech_web.dart';
