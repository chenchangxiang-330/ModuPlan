// CI-only visual evidence. These fixtures are never bundled into the app.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:day_blocks_demo/main.dart';
import 'package:day_blocks_demo/data/models.dart';
import 'package:day_blocks_demo/data/store.dart';

void main() {
  const fontDirectory = String.fromEnvironment('PREVIEW_FONT_DIR');
  testWidgets('export paperbook review images', (t) async {
    sqfliteFfiInit();
    late LedgerStore store;
    late Directory folder;
    await t.runAsync(() async {
      for (final font in {
        'Roboto': 'NotoSansCJK-Regular.ttc',
        'serif': 'NotoSerifCJK-Regular.ttc',
      }.entries) {
        final loader = FontLoader(font.key);
        final bytes = await File('$fontDirectory/${font.value}').readAsBytes();
        loader.addFont(Future.value(ByteData.sublistView(bytes)));
        await loader.load();
      }
      folder = await Directory.systemTemp.createTemp('moduplan_preview_');
      store = await LedgerStore.open(
        factory: databaseFactoryFfi, path: '${folder.path}/preview.sqlite',
      );
      final now = DateTime.now().toUtc().toIso8601String();
      for (final item in [
        ('整理本周的阅读笔记', 0, 'me', true),
        ('一起去图书馆', 1, 'both', false),
        ('散步，给今天留一点空白', 2, 'me', false),
      ]) {
        await store.saveEntry(Entry(
          id: newId(), day: dateKey(DateTime.now()), block: item.$2,
          title: item.$1, owner: item.$3, done: item.$4,
          createdAt: now, updatedAt: now,
        ));
      }
    });
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final boundary = GlobalKey();
    Future<void> settle() async {
      for (var i = 0; i < 12; i++) {
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
        await t.pump(const Duration(milliseconds: 100));
      }
    }
    Future<void> capture(String name) async {
      await t.runAsync(() async {
        final render = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await render.toImage(pixelRatio: 2);
        try {
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('build/previews/$name.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
        } finally {
          image.dispose();
        }
      });
    }
    try {
      await t.pumpWidget(RepaintBoundary(key: boundary, child: DayBlocksApp(store: store)));
      await settle();
      await capture('01-schedule');
      for (final target in [('周计划', '02-week'), ('月历', '03-month'), ('设置', '04-settings')]) {
        await t.tap(find.widgetWithText(NavigationDestination, target.$1));
        await settle();
        await capture(target.$2);
      }
      await t.tap(find.widgetWithText(NavigationDestination, '日程'));
      await settle();
      await t.ensureVisible(find.text('添加事项').first);
    await t.tap(find.text('添加事项').first);
      await settle();
      await capture('05-editor');
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
    } finally {
      await t.runAsync(() async {
        await store.close();
        await folder.delete(recursive: true);
      });
    }
  }, skip: fontDirectory.isEmpty);
}
