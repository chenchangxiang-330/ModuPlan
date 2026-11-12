import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:day_blocks_demo/data/models.dart';
import 'package:day_blocks_demo/data/store.dart';

void main() {
  sqfliteFfiInit();
  late LedgerStore store;
  late Directory folder;
  late String path;
  final today = DateTime(2026, 11, 4);
  final now = DateTime.utc(2026, 11, 4).toIso8601String();
  Entry entry({
    String? id,
    String? day,
    int? weekday,
    int block = 0,
    int? start,
    int? end,
    String title = '学习',
    bool done = false,
    String owner = 'me',
  }) => Entry(
    id: id ?? newId(),
    day: weekday == null ? (day ?? '2026-11-04') : null,
    weekday: weekday,
    block: block,
    title: title,
    owner: owner,
    start: start,
    end: end,
    done: done,
    createdAt: now,
    updatedAt: now,
  );
  setUp(() async {
    folder = await Directory.systemTemp.createTemp('day_blocks_test_');
    path = '${folder.path}/ledger.sqlite';
    store = await LedgerStore.open(factory: databaseFactoryFfi, path: path);
  });
  tearDown(() async {
    await store.close();
    await folder.delete(recursive: true);
  });

  test('空白读取日周月均不建立日期，默认无虚假事项', () async {
    expect((await store.readDay(today)).established, false);
    expect((await store.readWeek(today)).every((d) => d.entries.isEmpty), true);
    expect(await store.monthCounts(today), isEmpty);
    expect(await store.db.query('days'), isEmpty);
    expect(await store.templates(), isEmpty);
  });
  test('新增仅标题、同 ID 重复保存、编辑、完成和取消、删除保留日期', () async {
    final e = entry();
    await store.saveEntry(e);
    await store.saveEntry(e);
    expect((await store.readDay(today)).entries.length, 1);
    await store.saveEntry(entry(id: e.id, title: '论文修改', owner: 'both'));
    await store.setDone(e.id, true);
    var d = await store.readDay(today);
    expect(d.entries.single.title, '论文修改');
    expect(d.entries.single.done, true);
    await store.setDone(e.id, false);
    expect((await store.readDay(today)).entries.single.done, false);
    await store.deleteEntry(e.id);
    d = await store.readDay(today);
    expect(d.entries, isEmpty);
    expect(d.established, true);
  });
  test('关闭并重新打开真实磁盘 SQLite 保留日程及完成状态', () async {
    final e = entry();
    await store.saveEntry(e);
    await store.setDone(e.id, true);
    await store.close();
    store = await LedgerStore.open(factory: databaseFactoryFfi, path: path);
    expect((await store.readDay(today)).entries.single.done, true);
    expect((await store.readDay(today)).entries.single.id, e.id);
  });
  test('模块边界采用左闭右开，12 点下午、18 点晚上，允许事项重叠', () async {
    expect(blockAt(initialBlocks, 719), 0);
    expect(blockAt(initialBlocks, 720), 1);
    expect(blockAt(initialBlocks, 1080), 2);
    expect(blockAt(initialBlocks, 1320), null);
    await store.saveEntry(entry(start: 660, end: 720));
    await store.saveEntry(entry(start: 660, end: 720));
    await store.saveEntry(entry(block: 1, start: 720, end: 780));
    await store.saveEntry(entry(block: 2, start: 1080, end: 1140));
    expect((await store.readDay(today)).entries.length, 4);
    await expectLater(
      store.saveEntry(entry(start: 720, end: 780)),
      throwsA(isA<RuleError>()),
    );
    await expectLater(
      store.saveEntry(entry(start: 500)),
      throwsA(isA<RuleError>()),
    );
    await expectLater(
      store.saveEntry(entry(start: 600, end: 600)),
      throwsA(isA<RuleError>()),
    );
  });
  test('模块同日非重叠验证与间隙', () {
    expect(
      () => validateBlocks([
        initialBlocks[0],
        const BlockSpec('午后', 700, 1080, 0xffd8eee5),
        initialBlocks[2],
      ]),
      throwsA(isA<RuleError>()),
    );
    expect(
      () => validateBlocks([
        const BlockSpec('早上', 720, 480, 0xffffe4c7),
        ...initialBlocks.skip(1),
      ]),
      throwsA(isA<RuleError>()),
    );
    validateBlocks([
      const BlockSpec('早上', 480, 690, 0xffffe4c7),
      ...initialBlocks.skip(1),
    ]);
  });
  test('默认模块只影响新日期，旧日期保持快照，浏览日期使用新默认', () async {
    await store.saveEntry(entry());
    await store.readDay(plusDays(today, 1));
    final b = [
      const BlockSpec('晨间', 540, 720, 0xffeee7cd),
      ...initialBlocks.skip(1),
    ];
    await store.saveSettings(SettingsData(blocks: b));
    expect((await store.readDay(today)).blocks.first.name, '上午');
    expect((await store.readDay(plusDays(today, 1))).blocks.first.name, '晨间');
    await store.saveEntry(entry(day: '2026-11-05'));
    expect((await store.readDay(plusDays(today, 1))).blocks.first.start, 540);
  });
  test('模板定时冲突列出星期与事项并拒绝修改默认设置', () async {
    await store.saveEntry(
      entry(weekday: 1, title: '早课', start: 480, end: 540),
      template: true,
    );
    await expectLater(
      store.saveSettings(
        SettingsData(
          blocks: [
            const BlockSpec('晨间', 600, 720, 0xffffe4c7),
            ...initialBlocks.skip(1),
          ],
        ),
      ),
      throwsA(
        predicate(
          (e) =>
              e is RuleError &&
              e.message.contains('周一') &&
              e.message.contains('早课'),
        ),
      ),
    );
    expect((await store.settings()).blocks.first.start, 480);
  });
  test('跨日期与模块移动保持 ID 和完成状态，越界不能创建目标日期', () async {
    final e = entry(start: 480, end: 540, done: true);
    await store.saveEntry(e);
    await store.saveSettings(
      SettingsData(
        blocks: [
          const BlockSpec('晨间', 600, 720, 0xffffe4c7),
          ...initialBlocks.skip(1),
        ],
      ),
    );
    await expectLater(
      store.saveEntry(e.copy(day: '2026-11-05')),
      throwsA(isA<RuleError>()),
    );
    expect((await store.readDay(DateTime(2026, 11, 5))).established, false);
    expect((await store.readDay(today)).entries.single.id, e.id);
    await store.saveEntry(
      entry(id: e.id, day: '2026-11-05', block: 2, done: true),
    );
    expect((await store.readDay(today)).entries, isEmpty);
    final target = await store.readDay(DateTime(2026, 11, 5));
    expect(target.entries.single.id, e.id);
    expect(target.entries.single.block, 2);
    expect(target.entries.single.done, true);
  });
  test('模板仅建立今天以后新日期，重复应用和删除后应用不会恢复', () async {
    for (var i = 1; i <= 7; i++) {
      await store.saveEntry(entry(weekday: i), template: true);
    }
    await store.saveEntry(entry(day: '2026-11-05', title: '自己的安排'));
    final first = await store.applyWeek(today, today: today);
    expect(first.created.length, 4);
    expect(first.past.length, 2);
    expect(first.existing, ['2026-11-05']);
    expect(
      (await store.readDay(DateTime(2026, 11, 5))).entries.single.title,
      '自己的安排',
    );
    final d = await store.readDay(today);
    await store.deleteEntry(d.entries.single.id);
    final second = await store.applyWeek(today, today: today);
    expect(second.created, isEmpty);
    expect((await store.readDay(today)).entries, isEmpty);
    await store.close();
    store = await LedgerStore.open(factory: databaseFactoryFfi, path: path);
    expect((await store.applyWeek(today, today: today)).created, isEmpty);
  });
  test('空白模板也建立日期，后加模板不能填回已建立空日', () async {
    final r = await store.applyWeek(today, today: today);
    expect(r.created.length, 5);
    await store.saveEntry(entry(weekday: 3), template: true);
    await store.applyWeek(today, today: today);
    expect((await store.readDay(today)).entries, isEmpty);
    expect((await store.readDay(today)).established, true);
  });
  test('单日和模板相互隔离，完成状态按日期隔离', () async {
    final t = entry(weekday: 1);
    await store.saveEntry(t, template: true);
    await store.applyWeek(DateTime(2026, 11, 9), today: today);
    final a = (await store.readDay(DateTime(2026, 11, 9))).entries.single;
    await store.setDone(a.id, true);
    await store.saveEntry(
      entry(id: t.id, weekday: 1, title: '新模板'),
      template: true,
    );
    expect(
      (await store.readDay(DateTime(2026, 11, 9))).entries.single.title,
      '学习',
    );
    await store.applyWeek(DateTime(2026, 11, 16), today: today);
    final b = (await store.readDay(DateTime(2026, 11, 16))).entries.single;
    expect(b.title, '新模板');
    expect(b.done, false);
    expect(b.id, isNot(a.id));
    await store.saveEntry(entry(id: b.id, day: '2026-11-16', title: '只改当天'));
    expect((await store.templates()).single.title, '新模板');
    expect(
      (await store.readDay(DateTime(2026, 11, 9))).entries.single.done,
      true,
    );
  });
  test('复制星期模板使用新 ID，替换目标且不修改已生成日期', () async {
    final t = entry(weekday: 1, title: '课程');
    await store.saveEntry(t, template: true);
    await store.copyTemplate(1, {2, 3});
    expect((await store.templates()).length, 3);
    expect((await store.templates()).map((e) => e.id).toSet().length, 3);
    await store.applyWeek(today, today: today);
    await store.deleteEntry(t.id, template: true);
    await store.copyTemplate(1, {3});
    expect(await store.templates(3), isEmpty);
    expect((await store.readDay(today)).entries.single.title, '课程');
  });
  test('日周月同源一致，跨月跨年和本地日期计算', () async {
    await store.saveEntry(entry(day: '2026-12-31'));
    await store.saveEntry(entry(day: '2027-01-01', done: true));
    final w = await store.readWeek(DateTime(2027, 1, 1));
    expect(w.first.day, '2026-12-28');
    expect(w.last.day, '2027-01-03');
    expect(w.expand((d) => d.entries).length, 2);
    expect(await store.monthCounts(DateTime(2026, 12)), {'2026-12-31': 1});
    expect(await store.monthCounts(DateTime(2027, 1)), {'2027-01-01': 1});
    expect(dateKey(DateTime(2026, 11, 4, 0, 1)), '2026-11-04');
    expect(dateKey(plusDays(DateTime(2026, 12, 31), 1)), '2027-01-01');
    expect(() => parseDate('2026-02-30'), throwsFormatException);
  });
  test('备份完整恢复含设置、快照、模板、完成状态和空日期标记', () async {
    await store.saveSettings(const SettingsData(me: '饼饼', partner: '康康'));
    await store.saveEntry(entry(done: true));
    await store.saveEntry(entry(weekday: 7), template: true);
    await store.applyWeek(today, today: today);
    final backup = await store.exportJson();
    await store.clearAll();
    await store.restoreJson(backup);
    final before = jsonDecode(backup) as Map<String, dynamic>,
        after = jsonDecode(await store.exportJson()) as Map<String, dynamic>;
    before.remove('exported_at');
    after.remove('exported_at');
    expect(after, before);
    expect((await store.settings()).me, '饼饼');
    expect((await store.readDay(today)).entries.single.done, true);
  });
  test('损坏 JSON、版本、重复 ID、孤立日期、非法时间导入均不修改原数据', () async {
    await store.saveEntry(entry(done: true));
    final baseline =
        jsonDecode(await store.exportJson()) as Map<String, dynamic>;
    Future<void> reject(String input) async {
      await expectLater(store.restoreJson(input), throwsA(anything));
      final actual =
          jsonDecode(await store.exportJson()) as Map<String, dynamic>;
      actual.remove('exported_at');
      final expected = Map.of(baseline)..remove('exported_at');
      expect(actual, expected);
    }

    await reject('{broken');
    for (final kind in [
      'version',
      'duplicate',
      'orphan',
      'time',
      'date',
      'status',
    ]) {
      final v = jsonDecode(jsonEncode(baseline)) as Map<String, dynamic>;
      if (kind == 'version') v['format_version'] = 99;
      if (kind == 'duplicate') (v['entries'] as List).add(v['entries'][0]);
      if (kind == 'orphan') v['days'] = [];
      if (kind == 'time') {
        v['entries'][0]['start'] = 500;
        v['entries'][0]['end'] = 800;
      }
      if (kind == 'date') v['days'][0]['day'] = '2026-02-30';
      if (kind == 'status') v['entries'][0]['done'] = 2;
      await reject(jsonEncode(v));
    }
  });
  test('恢复写入中途失败触发事务回滚，原数据完整', () async {
    await store.saveEntry(entry(title: '原数据'));
    final backup = jsonDecode(await store.exportJson()) as Map<String, dynamic>;
    backup['entries'][0]['title'] = '触发故障';
    await store.db.execute(
      "CREATE TRIGGER reject_restore BEFORE INSERT ON entries WHEN NEW.title='触发故障' BEGIN SELECT RAISE(ABORT, 'simulated write failure'); END",
    );
    await expectLater(store.restoreJson(jsonEncode(backup)), throwsA(anything));
    expect((await store.readDay(today)).entries.single.title, '原数据');
    expect((await store.readDay(today)).established, true);
  });
  test('同时重复应用通过事务串行化，不重复生成', () async {
    await store.saveEntry(entry(weekday: 3), template: true);
    await Future.wait([
      store.applyWeek(today, today: today),
      store.applyWeek(today, today: today),
    ]);
    expect((await store.readDay(today)).entries.length, 1);
  });
}
