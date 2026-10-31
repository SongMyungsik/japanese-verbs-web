import 'dart:convert';

import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/verb.dart';
import 'db_platform.dart';

/// 한 동사의 한 활용형에 대한 복습 기록.
class ReviewItem {
  final int verbId;
  final FormType form;
  final int box; // 0~5 (라이트너 상자)
  final int correct;
  final int wrong;
  final DateTime nextDue;

  const ReviewItem({
    required this.verbId,
    required this.form,
    required this.box,
    required this.correct,
    required this.wrong,
    required this.nextDue,
  });

  factory ReviewItem.fromRow(Map<String, Object?> r) => ReviewItem(
    verbId: r['verb_id'] as int,
    form: FormType.values.byName(r['form'] as String),
    box: r['box'] as int,
    correct: r['correct'] as int,
    wrong: r['wrong'] as int,
    nextDue: DateTime.fromMillisecondsSinceEpoch(r['next_due'] as int),
  );
}

/// 복습 화면 상단에 보여 주는 요약
class ReviewStats {
  final int total; // 한 번이라도 푼 (동사, 활용형) 항목 수
  final int due; // 지금 복습할 시기가 된 항목 수
  final int mastered; // 상자 4 이상(익숙한 항목) 수

  const ReviewStats({
    required this.total,
    required this.due,
    required this.mastered,
  });
}

class VerbRepository {
  VerbRepository._(this._db);
  final Database _db;

  /// 복습 기록이 바뀔 때마다 1씩 늘어난다. 복습 화면이 이것을 보고 새로 불러온다.
  final ValueNotifier<int> reviewVersion = ValueNotifier<int>(0);

  /// 상자(box)별 다음 복습까지의 간격(일).
  static const List<int> _intervalDays = [0, 1, 3, 7, 14, 30];
  static const int _maxBox = 5;

  /// 플랫폼에 맞는 DB 구현을 고른다 (db_platform.dart).
  static void initPlatform() => initDatabasePlatform();

  /// DB를 열고 verbs.json 내용을 동기화한다. (복습 기록은 건드리지 않음)
  static Future<VerbRepository> open({String? path}) async {
    initPlatform();
    final dbPath =
        path ?? p.join(await getDatabasesPath(), 'japanese_verbs.db');
    final db = await openDatabase(
      dbPath,
      version: 5,
      // v1 → v2: 상태동사 표시(stative) 칸 추가.
      // v2 → v3: 주제·학습 단계·JLPT 칸 추가.
      // v3 → v4: 즐겨찾기(favorites) 표 추가.
      // v4 → v5: 설정(settings) 표 추가. 복습 기록(reviews)은 건드리지 않는다.
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE verbs ADD COLUMN stative INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldVersion < 3) {
          for (final col in const [
            "topics TEXT NOT NULL DEFAULT ''",
            'learning_stage INTEGER NOT NULL DEFAULT 0',
            "jlpt_level TEXT NOT NULL DEFAULT ''",
            'jlpt_verified INTEGER NOT NULL DEFAULT 0',
          ]) {
            await db.execute('ALTER TABLE verbs ADD COLUMN $col');
          }
        }
        if (oldVersion < 4) await _createFavorites(db);
        if (oldVersion < 5) await _createSettings(db);
      },
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE verbs (
            id INTEGER PRIMARY KEY,
            text TEXT NOT NULL,
            reading TEXT NOT NULL,
            meaning TEXT NOT NULL,
            verb_group TEXT NOT NULL,
            ending TEXT NOT NULL,
            note TEXT NOT NULL DEFAULT '',
            stative INTEGER NOT NULL DEFAULT 0,
            topics TEXT NOT NULL DEFAULT '',
            learning_stage INTEGER NOT NULL DEFAULT 0,
            jlpt_level TEXT NOT NULL DEFAULT '',
            jlpt_verified INTEGER NOT NULL DEFAULT 0
          )''');
        await db.execute('''
          CREATE TABLE reviews (
            verb_id INTEGER NOT NULL,
            form TEXT NOT NULL,
            box INTEGER NOT NULL DEFAULT 0,
            correct INTEGER NOT NULL DEFAULT 0,
            wrong INTEGER NOT NULL DEFAULT 0,
            next_due INTEGER NOT NULL,
            PRIMARY KEY (verb_id, form)
          )''');
        await db.execute('CREATE INDEX idx_reviews_due ON reviews(next_due)');
        await _createFavorites(db);
        await _createSettings(db);
      },
    );
    final repo = VerbRepository._(db);
    await repo.syncFromAsset();
    return repo;
  }

  /// assets/data/verbs.json → verbs 테이블 (id 기준으로 덮어쓰기)
  /// JSON에서 빠진 동사는 테이블과 복습 기록에서 지운다.
  Future<void> syncFromAsset({String asset = 'assets/data/verbs.json'}) async {
    final raw = await rootBundle.loadString(asset);
    final verbs = (jsonDecode(raw) as List)
        .map((e) => Verb.fromJson(e as Map<String, dynamic>))
        .toList();
    final ids = verbs.map((v) => v.id).join(',');
    final batch = _db.batch();
    batch.delete('verbs', where: 'id NOT IN ($ids)');
    batch.delete('reviews', where: 'verb_id NOT IN ($ids)');
    batch.delete('favorites', where: 'verb_id NOT IN ($ids)');
    for (final v in verbs) {
      batch.insert(
        'verbs',
        v.toRow(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Verb>> allVerbs({VerbGroup? group, String? ending}) async {
    final where = <String>[];
    final args = <Object?>[];
    if (group != null) {
      where.add('verb_group = ?');
      args.add(group.name);
    }
    if (ending != null) {
      where.add('ending = ?');
      args.add(ending);
    }
    final rows = await _db.query(
      'verbs',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'id',
    );
    return rows.map(Verb.fromRow).toList();
  }

  Future<Verb?> verbById(int id) async {
    final rows = await _db.query('verbs', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Verb.fromRow(rows.first);
  }

  /// 퀴즈 결과를 기록하고 다음 복습일을 정한다.
  /// 맞히면 상자가 한 칸 올라가고, 틀리면 0번 상자(즉시 복습 대상)로 돌아간다.
  Future<void> recordReview({
    required int verbId,
    required FormType form,
    required bool correct,
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    final rows = await _db.query(
      'reviews',
      where: 'verb_id = ? AND form = ?',
      whereArgs: [verbId, form.name],
    );
    final prev = rows.isEmpty ? null : ReviewItem.fromRow(rows.first);

    final int box = correct
        ? ((prev?.box ?? 0) + 1).clamp(0, _maxBox).toInt()
        : 0;
    final due = at.add(Duration(days: _intervalDays[box]));

    await _db.insert('reviews', {
      'verb_id': verbId,
      'form': form.name,
      'box': box,
      'correct': (prev?.correct ?? 0) + (correct ? 1 : 0),
      'wrong': (prev?.wrong ?? 0) + (correct ? 0 : 1),
      'next_due': due.millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    reviewVersion.value++;
  }

  /// 복습 시기가 된 항목 (오래 밀린 것부터)
  Future<List<ReviewItem>> dueReviews({DateTime? now, int limit = 20}) async {
    final at = (now ?? DateTime.now()).millisecondsSinceEpoch;
    final rows = await _db.query(
      'reviews',
      where: 'next_due <= ?',
      whereArgs: [at],
      orderBy: 'next_due ASC',
      limit: limit,
    );
    return rows.map(ReviewItem.fromRow).toList();
  }

  /// 오답이 많은 항목 (오답 노트용)
  Future<List<ReviewItem>> weakItems({int limit = 20}) async {
    final rows = await _db.query(
      'reviews',
      where: 'wrong > 0',
      orderBy: 'wrong DESC, box ASC',
      limit: limit,
    );
    return rows.map(ReviewItem.fromRow).toList();
  }

  Future<ReviewStats> reviewStats({DateTime? now}) async {
    final at = (now ?? DateTime.now()).millisecondsSinceEpoch;
    final rows = await _db.rawQuery(
      '''
      SELECT
        COUNT(*) AS total,
        COALESCE(SUM(CASE WHEN next_due <= ? THEN 1 ELSE 0 END), 0) AS due,
        COALESCE(SUM(CASE WHEN box >= 4 THEN 1 ELSE 0 END), 0) AS mastered
      FROM reviews''',
      [at],
    );
    final r = rows.first;
    return ReviewStats(
      total: (r['total'] as num).toInt(),
      due: (r['due'] as num).toInt(),
      mastered: (r['mastered'] as num).toInt(),
    );
  }

  static Future<void> _createFavorites(Database db) => db.execute('''
    CREATE TABLE favorites (
      verb_id INTEGER PRIMARY KEY,
      added_at INTEGER NOT NULL
    )''');

  static Future<void> _createSettings(Database db) => db.execute('''
    CREATE TABLE settings (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )''');

  /// 저장해 둔 설정 값 (없으면 null). 값은 JSON 등 문자열로 저장한다.
  Future<String?> setting(String key) async {
    final rows = await _db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> saveSetting(String key, String value) => _db.insert('settings', {
    'key': key,
    'value': value,
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  /// 즐겨찾기한 동사 번호
  Future<Set<int>> favoriteIds() async {
    final rows = await _db.query('favorites', columns: ['verb_id']);
    return {for (final r in rows) r['verb_id'] as int};
  }

  Future<void> setFavorite(int verbId, bool on) async {
    if (on) {
      await _db.insert('favorites', {
        'verb_id': verbId,
        'added_at': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    } else {
      await _db.delete('favorites', where: 'verb_id = ?', whereArgs: [verbId]);
    }
  }

  /// 동사별 학습 진도: 동사 번호 → 그 동사의 활용형 중 가장 높은 상자 번호.
  /// 기록이 없는 동사(한 번도 풀지 않은 동사)는 들어 있지 않다.
  Future<Map<int, int>> verbProgress() async {
    final rows = await _db.rawQuery(
      'SELECT verb_id, MAX(box) AS best FROM reviews GROUP BY verb_id',
    );
    return {
      for (final r in rows) r['verb_id'] as int: (r['best'] as num).toInt(),
    };
  }

  Future<void> close() => _db.close();
}
