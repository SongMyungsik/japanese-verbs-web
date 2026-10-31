import 'dart:io';

import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Windows·Linux·macOS 데스크톱은 sqflite_common_ffi를 쓰고,
/// Android·iOS는 기본 sqflite를 그대로 쓴다.
void initDatabasePlatform() {
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
}
