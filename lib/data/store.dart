import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'models.dart';

class ApplyResult {
  final List<String> created, existing, past;
  const ApplyResult(this.created, this.existing, this.past);
}

class BackupData {
  final SettingsData settings;
  final List<Map<String, Object?>> days;
  final List<Entry> entries, templates;
  const BackupData(this.settings, this.days, this.entries, this.templates);
}

class LedgerStore extends ChangeNotifier {
  final Database db;
  LedgerStore._(this.db);
  static Future<LedgerStore> open({
    DatabaseFactory? factory,
    String? path,
  }) async {
    final f = factory ?? databaseFactory;
    final location =
        path ?? p.join(await f.getDatabasesPath(), 'day_blocks_demo_v1.sqlite');
    final db = await f.openDatabase(
      location,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (d) async => d.execute('PRAGMA foreign_keys = ON'),
        onCreate: (d, _) async {
          await d.execute(
            'CREATE TABLE settings (id INTEGER PRIMARY KEY CHECK(id=1), value TEXT NOT NULL)',
          );
          await d.execute(
            'CREATE TABLE days (day TEXT PRIMARY KEY, blocks TEXT NOT NULL, created_at TEXT NOT NULL, updated_at TEXT NOT NULL)',
          );
          const fields =
              '''id TEXT PRIMARY KEY, block INTEGER NOT NULL CHECK(block BETWEEN 0 AND 2),
          title TEXT NOT NULL CHECK(length(trim(title)) BETWEEN 1 AND 120), note TEXT NOT NULL,
          owner TEXT NOT NULL CHECK(owner IN ('me','partner','both')),
          start INTEGER, end INTEGER, rank INTEGER NOT NULL CHECK(rank>=0),
          created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
          CHECK((start IS NULL AND end IS NULL) OR (start IS NOT NULL AND end IS NOT NULL AND start>=0 AND end<=1439 AND start<end))''';
          await d.execute(
            'CREATE TABLE entries (day TEXT NOT NULL REFERENCES days(day) ON DELETE CASCADE, done INTEGER NOT NULL CHECK(done IN (0,1)), $fields)',
          );
          await d.execute(
            'CREATE INDEX entries_day ON entries(day, block, rank)',
          );
          await d.execute(
            'CREATE TABLE templates (weekday INTEGER NOT NULL CHECK(weekday BETWEEN 1 AND 7), $fields)',
          );
          await d.insert('settings', {
            'id': 1,
            'value': jsonEncode(const SettingsData().toJson()),
          });
        },
      ),
    );
    return LedgerStore._(db);
  }

  Future<SettingsData> _settings(DatabaseExecutor tx) async =>
      SettingsData.fromJson(
        jsonDecode((await tx.query('settings')).single['value'] as String),
      );
  Future<SettingsData> settings() => _settings(db);
  List<BlockSpec> _blocks(Object? json) =>
      (jsonDecode(json as String) as List).map(BlockSpec.fromJson).toList();
  Future<List<BlockSpec>> _dayBlocks(DatabaseExecutor tx, String day) async {
    final rows = await tx.query('days', where: 'day=?', whereArgs: [day]);
    return rows.isEmpty
        ? (await _settings(tx)).blocks
        : _blocks(rows.single['blocks']);
  }

  Future<DayView> readDay(DateTime date) async {
    final day = dateKey(date);
    final days = await db.query('days', where: 'day=?', whereArgs: [day]);
    final rows = await db.query(
      'entries',
      where: 'day=?',
      whereArgs: [day],
      orderBy: 'block, rank, created_at, id',
    );
    return DayView(
      day,
      days.isNotEmpty,
      days.isEmpty ? (await settings()).blocks : _blocks(days.single['blocks']),
      rows.map((r) => Entry.fromRow(r)).toList(),
    );
  }

  Future<List<DayView>> readWeek(DateTime date) async {
    final start = monday(date);
    return [for (var i = 0; i < 7; i++) await readDay(plusDays(start, i))];
  }

  Future<Map<String, int>> monthCounts(DateTime date) async {
    final start = dateKey(DateTime(date.year, date.month));
    final end = dateKey(DateTime(date.year, date.month + 1));
    final rows = await db.rawQuery(
      'SELECT day, COUNT(*) AS n FROM entries WHERE day>=? AND day<? GROUP BY day',
      [start, end],
    );
    return {for (final r in rows) r['day'] as String: r['n'] as int};
  }

  Future<List<Entry>> templates([int? weekday]) async => (await db.query(
    'templates',
    where: weekday == null ? null : 'weekday=?',
    whereArgs: weekday == null ? null : [weekday],
    orderBy: 'weekday, block, rank, created_at, id',
  )).map((r) => Entry.fromRow(r, template: true)).toList();
  Future<void> _establish(
    DatabaseExecutor tx,
    String day,
    List<BlockSpec> blocks,
  ) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await tx.insert('days', {
      'day': day,
      'blocks': jsonEncode(blocks.map((b) => b.toJson()).toList()),
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  void _validateEntry(Entry entry, List<BlockSpec> blocks, bool template) {
    Entry.fromRow(entry.toRow(template: template), template: template);
    validateTimes(entry.start, entry.end, blocks[entry.block]);
  }

  Future<void> saveEntry(Entry entry, {bool template = false}) async {
    await db.transaction((tx) async {
      final blocks = template
          ? (await _settings(tx)).blocks
          : await _dayBlocks(tx, entry.day!);
      _validateEntry(entry, blocks, template);
      if (!template) await _establish(tx, entry.day!, blocks);
      final table = template ? 'templates' : 'entries';
      final old = await tx.query(table, where: 'id=?', whereArgs: [entry.id]);
      if (old.isEmpty) {
        await tx.insert(table, entry.toRow(template: template));
      } else {
        await tx.update(
          table,
          entry.toRow(template: template),
          where: 'id=?',
          whereArgs: [entry.id],
        );
      }
      if (!template) {
        await tx.update(
          'days',
          {'updated_at': entry.updatedAt},
          where: 'day=?',
          whereArgs: [entry.day],
        );
        if (old.isNotEmpty && old.single['day'] != entry.day) {
          await tx.update(
            'days',
            {'updated_at': entry.updatedAt},
            where: 'day=?',
            whereArgs: [old.single['day']],
          );
        }
      }
    });
    notifyListeners();
  }

  Future<void> setDone(String id, bool done) async {
    await db.transaction((tx) async {
      final rows = await tx.query('entries', where: 'id=?', whereArgs: [id]);
      if (rows.isEmpty) return;
      final now = DateTime.now().toUtc().toIso8601String();
      await tx.update(
        'entries',
        {'done': done ? 1 : 0, 'updated_at': now},
        where: 'id=?',
        whereArgs: [id],
      );
      await tx.update(
        'days',
        {'updated_at': now},
        where: 'day=?',
        whereArgs: [rows.single['day']],
      );
    });
    notifyListeners();
  }

  Future<void> deleteEntry(String id, {bool template = false}) async {
    await db.transaction((tx) async {
      if (!template) {
        final rows = await tx.query('entries', where: 'id=?', whereArgs: [id]);
        if (rows.isNotEmpty) {
          await tx.update(
            'days',
            {'updated_at': DateTime.now().toUtc().toIso8601String()},
            where: 'day=?',
            whereArgs: [rows.single['day']],
          );
        }
      }
      await tx.delete(
        template ? 'templates' : 'entries',
        where: 'id=?',
        whereArgs: [id],
      );
    });
    notifyListeners();
  }

  Future<void> saveSettings(SettingsData s) async {
    SettingsData.fromJson(s.toJson());
    await db.transaction((tx) async {
      final conflicts = <String>[];
      for (final row in await tx.query('templates')) {
        final t = Entry.fromRow(row, template: true);
        try {
          validateTimes(t.start, t.end, s.blocks[t.block]);
        } on RuleError {
          conflicts.add(
            '周${weekdays[t.weekday! - 1]} · ${s.blocks[t.block].name} · ${t.title} (${timeText(t.start!)}—${timeText(t.end!)})',
          );
        }
      }
      if (conflicts.isNotEmpty) {
        throw RuleError(
          '以下周模板事项超出新模块时间，请先到「编辑周模板」调整或清除具体时间：\n\n${conflicts.join('\n')}',
        );
      }
      await tx.update('settings', {
        'value': jsonEncode(s.toJson()),
      }, where: 'id=1');
    });
    notifyListeners();
  }

  Future<void> copyTemplate(int source, Set<int> targets) async {
    if (source < 1 ||
        source > 7 ||
        targets.any((d) => d < 1 || d > 7 || d == source)) {
      throw const RuleError('复制目标不合法');
    }
    await db.transaction((tx) async {
      final sourceRows = await tx.query(
        'templates',
        where: 'weekday=?',
        whereArgs: [source],
      );
      final now = DateTime.now().toUtc().toIso8601String();
      for (final d in targets) {
        await tx.delete('templates', where: 'weekday=?', whereArgs: [d]);
        for (final row in sourceRows) {
          final e = Entry.fromRow(
            row,
            template: true,
          ).copy(id: newId(), weekday: d, createdAt: now, updatedAt: now);
          await tx.insert('templates', e.toRow(template: true));
        }
      }
    });
    notifyListeners();
  }

  Future<ApplyResult> applyWeek(DateTime week, {DateTime? today}) async {
    final start = monday(week), threshold = dateKey(today ?? DateTime.now());
    final created = <String>[], existing = <String>[], past = <String>[];
    await db.transaction((tx) async {
      final defaults = (await _settings(tx)).blocks;
      for (var i = 0; i < 7; i++) {
        final date = plusDays(start, i), key = dateKey(plusDays(start, i));
        parseDate(key);
        if (key.compareTo(threshold) < 0) {
          past.add(key);
          continue;
        }
        if ((await tx.query(
          'days',
          where: 'day=?',
          whereArgs: [key],
        )).isNotEmpty) {
          existing.add(key);
          continue;
        }
        await _establish(tx, key, defaults);
        final now = DateTime.now().toUtc().toIso8601String();
        for (final row in await tx.query(
          'templates',
          where: 'weekday=?',
          whereArgs: [date.weekday],
        )) {
          final e = Entry.fromRow(row, template: true).copy(
            id: newId(),
            day: key,
            done: false,
            createdAt: now,
            updatedAt: now,
          );
          _validateEntry(e, defaults, false);
          await tx.insert('entries', e.toRow());
        }
        created.add(key);
      }
    });
    notifyListeners();
    return ApplyResult(created, existing, past);
  }

  Future<String> exportJson() => db.transaction((tx) async {
    final days = await tx.query('days', orderBy: 'day');
    return const JsonEncoder.withIndent('  ').convert({
      'app': 'day_blocks_demo',
      'format_version': 1,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'settings': (await _settings(tx)).toJson(),
      'days': days
          .map((d) => {...d, 'blocks': jsonDecode(d['blocks'] as String)})
          .toList(),
      'entries': await tx.query('entries', orderBy: 'day, block, rank, id'),
      'templates': await tx.query(
        'templates',
        orderBy: 'weekday, block, rank, id',
      ),
    });
  });
  static BackupData validateBackup(String source) {
    if (utf8.encode(source).length > 10 * 1024 * 1024) {
      throw const FormatException('备份超过 10 MB');
    }
    final j = objectOf(jsonDecode(source));
    if (j['app'] != 'day_blocks_demo' ||
        j['format_version'] is! int ||
        j['format_version'] != 1) {
      throw const FormatException('不是支持的三段日程备份（格式版本 1）');
    }
    validTimestamp(j['exported_at']);
    final s = SettingsData.fromJson(j['settings']);
    for (final key in ['days', 'entries', 'templates']) {
      if (j[key] is! List || (j[key] as List).length > 50000) {
        throw FormatException('$key 数据不合法或过多');
      }
    }
    final byDay = <String, List<BlockSpec>>{}, days = <Map<String, Object?>>[];
    for (final value in j['days']) {
      final d = objectOf(value), key = stringOf(objectOf(value)['day'], 10);
      parseDate(key);
      validTimestamp(d['created_at']);
      validTimestamp(d['updated_at']);
      if (byDay.containsKey(key) || d['blocks'] is! List) {
        throw const FormatException('日期重复或缺少快照');
      }
      final b = (d['blocks'] as List).map(BlockSpec.fromJson).toList();
      validateBlocks(b);
      byDay[key] = b;
      days.add({
        'day': key,
        'blocks': jsonEncode(b.map((b) => b.toJson()).toList()),
        'created_at': d['created_at'],
        'updated_at': d['updated_at'],
      });
    }
    List<Entry> parseEntries(String field, bool template) {
      final ids = <String>{}, result = <Entry>[];
      for (final value in j[field]) {
        final e = Entry.fromRow(objectOf(value), template: template);
        if (!ids.add(e.id)) throw const FormatException('事项 ID 重复');
        final b = template ? s.blocks : byDay[e.day];
        if (b == null) throw const FormatException('事项缺少对应日期快照');
        validateTimes(e.start, e.end, b[e.block]);
        result.add(e);
      }
      return result;
    }

    return BackupData(
      s,
      days,
      parseEntries('entries', false),
      parseEntries('templates', true),
    );
  }

  Future<void> restoreJson(String source) async {
    final backup = validateBackup(source);
    await db.transaction((tx) async {
      await tx.delete('entries');
      await tx.delete('days');
      await tx.delete('templates');
      await tx.update('settings', {
        'value': jsonEncode(backup.settings.toJson()),
      }, where: 'id=1');
      final batch = tx.batch();
      for (final d in backup.days) {
        batch.insert('days', d);
      }
      for (final e in backup.entries) {
        batch.insert('entries', e.toRow());
      }
      for (final t in backup.templates) {
        batch.insert('templates', t.toRow(template: true));
      }
      await batch.commit(noResult: true);
    });
    notifyListeners();
  }

  Future<void> clearAll() async {
    await db.transaction((tx) async {
      await tx.delete('entries');
      await tx.delete('days');
      await tx.delete('templates');
      await tx.update('settings', {
        'value': jsonEncode(const SettingsData().toJson()),
      }, where: 'id=1');
    });
    notifyListeners();
  }

  Future<void> close() => db.close();
}
