import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:day_blocks_demo/main.dart';
import 'package:day_blocks_demo/data/models.dart';
import 'package:day_blocks_demo/data/store.dart';
import 'package:day_blocks_demo/ui/entry_editor.dart';

void main() {
  sqfliteFfiInit();
  late LedgerStore store;
  late Directory folder;
  setUp(() async {
    folder = await Directory.systemTemp.createTemp('day_blocks_ui_');
    store = await LedgerStore.open(
      factory: databaseFactoryFfi,
      path: '${folder.path}/test.sqlite',
    );
  });
  tearDown(() async {
    await store.close();
    await folder.delete(recursive: true);
  });
  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 12; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('小屏空白四页可浏览，查看不建立日期，表单键盘和返回正常', (t) async {
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(DayBlocksApp(store: store));
    await settle(t);
    expect(find.text('三段日程 · 一段一段来'), findsOneWidget);
    expect(t.takeException(), isNull);
    for (final name in ['周计划', '月历', '设置', '日程']) {
      await t.tap(find.widgetWithText(NavigationDestination, name));
      await settle(t);
      expect(t.takeException(), isNull);
    }
    expect(await t.runAsync(() => store.db.query('days')), isEmpty);
    await t.tap(find.text('添加事项').first);
    await settle(t);
    expect(find.byType(EntryEditor), findsOneWidget);
    await t.enterText(
      find.byType(TextField).first,
      '长标题：在图书馆完成论文修改并和对象一起核对周末安排' * 2,
    );
    t.view.viewInsets = const FakeViewPadding(bottom: 260);
    await t.pump();
    expect(t.takeException(), isNull);
    t.view.resetViewInsets();
    await t.pump();
    await t.binding.handlePopRoute();
    await settle(t);
    expect(find.byType(EntryEditor), findsNothing);
    expect(await t.runAsync(() => store.db.query('days')), isEmpty);
    await t.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('真实新增与完成，归属筛选的列表和数量一致', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(DayBlocksApp(store: store));
    await settle(t);
    await t.tap(find.text('添加事项').first);
    await settle(t);
    await t.enterText(find.byType(TextField).first, '写论文');
    await t.ensureVisible(find.text('保存事项'));
    await t.tap(find.text('保存事项'));
    await settle(t);
    expect(
      ((await t.runAsync(
        () => store.readDay(DateTime.now()),
      ))!).entries.single.title,
      '写论文',
    );
    await t.tap(find.byType(Checkbox).first);
    await settle(t);
    expect(
      ((await t.runAsync(
        () => store.readDay(DateTime.now()),
      ))!).entries.single.done,
      true,
    );
    await t.tap(find.widgetWithText(ChoiceChip, '对象'));
    await settle(t);
    expect(find.text('写论文'), findsNothing);
    expect(find.text('还没有事项，按自己的节奏安排'), findsOneWidget);
    await t.tap(find.widgetWithText(ChoiceChip, '我'));
    await settle(t);
    expect(find.text('写论文'), findsOneWidget);
    expect(find.text('1 / 1 项已完成'), findsOneWidget);
    await t.tap(find.byType(Checkbox).first);
    await settle(t);
    expect(
      ((await t.runAsync(
        () => store.readDay(DateTime.now()),
      ))!).entries.single.done,
      false,
    );
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('长昵称和字体放大不产生布局溢出', (t) async {
    await t.runAsync(
      () => store.saveSettings(
        const SettingsData(me: '昵称很长也能阅读', partner: '对象昵称也比较长'),
      ),
    );
    final now = DateTime.now().toUtc().toIso8601String();
    await t.runAsync(
      () => store.saveEntry(
        Entry(
          id: newId(),
          day: dateKey(DateTime.now()),
          block: 0,
          title: '这是一条比较长的学习安排，需要正确换行展示并保留归属标签',
          owner: 'partner',
          createdAt: now,
          updatedAt: now,
        ),
      ),
    );
    t.view.physicalSize = const Size(360, 740);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    t.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await t.pumpWidget(DayBlocksApp(store: store));
    await settle(t);
    expect(t.takeException(), isNull);
    await t.tap(find.widgetWithText(NavigationDestination, '月历'));
    await settle(t);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
  });
}
