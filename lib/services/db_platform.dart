// 웹에서는 dart:io·dart:ffi를 쓸 수 없어서 플랫폼별 파일로 나눈다.
export 'db_platform_native.dart'
    if (dart.library.js_interop) 'db_platform_web.dart';
