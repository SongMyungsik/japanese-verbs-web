import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// 브라우저 저장소(IndexedDB)에 SQLite DB를 둔다.
/// web/sqlite3.wasm과 web/sqflite_sw.js가 있어야 한다.
void initDatabasePlatform() {
  databaseFactory = databaseFactoryFfiWeb;
}
