import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_verbs_app/models/study_scope.dart';
import 'package:japanese_verbs_app/models/verb.dart';
import 'package:japanese_verbs_app/providers/quiz_controller.dart';
import 'package:japanese_verbs_app/providers/quiz_settings.dart';
import 'package:japanese_verbs_app/services/verb_repository.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// DB: 즐겨찾기, 학습 진도, 예전 버전(v3) DB에서 올라올 때 복습 기록이 남는지.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('verbs_db_test');
  });

  tearDown(() async {
    await dir.delete(recursive: true);
  });

  test('즐겨찾기를 저장하고 뺄 수 있다', () async {
    final repo = await VerbRepository.open(path: p.join(dir.path, 'a.db'));
    expect(await repo.favoriteIds(), isEmpty);
    await repo.setFavorite(1, true);
    await repo.setFavorite(2, true);
    await repo.setFavorite(1, true); // 두 번 넣어도 하나
    expect(await repo.favoriteIds(), {1, 2});
    await repo.setFavorite(1, false);
    expect(await repo.favoriteIds(), {2});
    await repo.close();
  });

  test('학습 진도: 동사별로 가장 높은 상자 번호', () async {
    final repo = await VerbRepository.open(path: p.join(dir.path, 'b.db'));
    for (var i = 0; i < 3; i++) {
      await repo.recordReview(verbId: 1, form: FormType.masu, correct: true);
    }
    await repo.recordReview(verbId: 1, form: FormType.te, correct: false);
    await repo.recordReview(verbId: 2, form: FormType.nai, correct: true);
    expect(await repo.verbProgress(), {1: 3, 2: 1});
    await repo.close();
  });

  test('v3 DB에서 올라오면 복습 기록은 그대로이고 즐겨찾기 표가 생긴다', () async {
    final path = p.join(dir.path, 'old.db');
    VerbRepository.initPlatform();
    // 즐겨찾기 표가 없던 v3 모양의 DB를 만든다.
    final old = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE verbs (
              id INTEGER PRIMARY KEY, text TEXT NOT NULL, reading TEXT NOT NULL,
              meaning TEXT NOT NULL, verb_group TEXT NOT NULL, ending TEXT NOT NULL,
              note TEXT NOT NULL DEFAULT '', stative INTEGER NOT NULL DEFAULT 0,
              topics TEXT NOT NULL DEFAULT '',
              learning_stage INTEGER NOT NULL DEFAULT 0,
              jlpt_level TEXT NOT NULL DEFAULT '',
              jlpt_verified INTEGER NOT NULL DEFAULT 0)''');
          await db.execute('''
            CREATE TABLE reviews (
              verb_id INTEGER NOT NULL, form TEXT NOT NULL,
              box INTEGER NOT NULL DEFAULT 0, correct INTEGER NOT NULL DEFAULT 0,
              wrong INTEGER NOT NULL DEFAULT 0, next_due INTEGER NOT NULL,
              PRIMARY KEY (verb_id, form))''');
          await db.insert('reviews', {
            'verb_id': 1,
            'form': 'masu',
            'box': 2,
            'correct': 2,
            'wrong': 0,
            'next_due': 0,
          });
        },
      ),
    );
    await old.close();

    final repo = await VerbRepository.open(path: path);
    expect(await repo.verbProgress(), {1: 2});
    expect(await repo.favoriteIds(), isEmpty);
    await repo.setFavorite(5, true);
    expect(await repo.favoriteIds(), {5});
    // v5에서 추가한 설정 표도 생긴다.
    await repo.saveSetting('k', 'v');
    expect(await repo.setting('k'), 'v');
    await repo.close();
  });

  test('퀴즈 설정은 앱을 다시 켜도 유지된다', () async {
    final path = p.join(dir.path, 'c.db');
    var repo = await VerbRepository.open(path: path);
    final s = QuizSettings(repo)
      ..setScope(StudyScope.jlpt.first)
      ..setGroup(VerbGroup.godan)
      ..toggleForm(FormType.potential, true)
      ..toggleForm(FormType.masu, false)
      ..setCount(20)
      ..setMode(QuizMode.tiles)
      ..setAutoSpeak(false);
    await repo.setting('quiz_settings'); // 저장이 끝날 때까지 기다린다
    await repo.close();

    // 앱을 다시 켠 것처럼 DB를 새로 열어 읽는다.
    repo = await VerbRepository.open(path: path);
    final again = QuizSettings(repo);
    await again.load();
    expect(again.scope, StudyScope.jlpt.first);
    expect(again.group, VerbGroup.godan);
    expect(again.forms, s.forms);
    expect(again.count, 20);
    expect(again.mode, QuizMode.tiles);
    expect(again.autoSpeak, isFalse);
    expect(again.favoritesOnly, isFalse);

    // 즐겨찾기 범위도 유지된다.
    again.setFavoritesOnly();
    await repo.setting('quiz_settings');
    final third = QuizSettings(repo);
    await third.load();
    expect(third.favoritesOnly, isTrue);
    expect(third.scope, isNull);
    await repo.close();
  });

  test('저장된 퀴즈 설정이 깨져 있으면 기본값으로 시작한다', () async {
    final repo = await VerbRepository.open(path: p.join(dir.path, 'd.db'));
    await repo.saveSetting('quiz_settings', '{망가진 값');
    final s = QuizSettings(repo);
    await s.load();
    expect(s.count, 10);
    expect(s.mode, QuizMode.choice);
    await repo.close();
  });
}
