import 'package:day_blocks_demo/ui/page_turn.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const overlayKey = ValueKey('notebook.pageTurn.overlay');

  Widget page(
    int day, {
    bool reducedMotion = false,
    int direction = 1,
    String? label,
    VoidCallback? onTap,
  }) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reducedMotion),
      child: Center(
        child: SizedBox(
          width: 320,
          height: 480,
          child: NotebookPageTurn(
            pageKey: day,
            direction: direction,
            child: ColoredBox(
              color: const Color(0xfffaf8f3),
              child: Center(
                child: TextButton(
                  onPressed: onTap ?? () {},
                  child: Text(label ?? '第 $day 页'),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  // Snapshot completion is a real engine future, outside the fake test clock.
  Future<void> completeCapture(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
      if (find.byKey(overlayKey).evaluate().isNotEmpty) return;
    }
  }

  testWidgets('前后翻页使用旧页快照，完成后恢复新页操作', (tester) async {
    var taps = 0;
    await tester.pumpWidget(page(1));
    await tester.pumpWidget(page(2, onTap: () => taps++));
    await completeCapture(tester);
    expect(find.byKey(overlayKey), findsOneWidget);
    expect(find.text('第 2 页'), findsOneWidget);
    // Animation overlays are inert; a visible old task cannot activate the
    // incoming day's task before the page has finished turning.
    final button = find.widgetWithText(TextButton, '第 2 页');
    expect(tester.widget<IgnorePointer>(find.ancestor(
      of: button,
      matching: find.byType(IgnorePointer),
    ).first).ignoring, isTrue);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.tap(button);
    expect(taps, 1);
    expect(find.byKey(overlayKey), findsNothing);

    await tester.pumpWidget(page(1, direction: -1));
    await completeCapture(tester);
    expect(find.byKey(overlayKey), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('第 1 页'), findsOneWidget);
    expect(find.byKey(overlayKey), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('连续切换和卸载不会留下旧页或已释放的快照', (tester) async {
    await tester.pumpWidget(page(1));
    await tester.pumpWidget(page(2));
    await completeCapture(tester);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpWidget(page(3));
    await tester.pumpWidget(page(4));
    await completeCapture(tester);
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('第 4 页'), findsOneWidget);
    expect(find.byKey(overlayKey), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(page(5));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('减少动态效果直接切页，并能中断进行中的翻页', (tester) async {
    await tester.pumpWidget(page(1, reducedMotion: true));
    await tester.pumpWidget(page(2, reducedMotion: true));
    expect(find.text('第 2 页'), findsOneWidget);
    expect(find.byKey(overlayKey), findsNothing);
    await tester.pumpWidget(page(2));
    await tester.pumpWidget(page(3));
    await completeCapture(tester);
    expect(find.byKey(overlayKey), findsOneWidget);
    await tester.pumpWidget(page(4, reducedMotion: true));
    expect(find.text('第 4 页'), findsOneWidget);
    expect(find.byKey(overlayKey), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('同一天的内容更新不会触发翻页或阻塞操作', (tester) async {
    var taps = 0;
    await tester.pumpWidget(page(1));
    await tester.pumpWidget(page(1, label: '已完成', onTap: () => taps++));
    await tester.tap(find.text('已完成'));
    expect(taps, 1);
    expect(find.byKey(overlayKey), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
