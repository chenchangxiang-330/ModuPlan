import 'package:flutter/material.dart';
import '../data/models.dart';
import '../data/store.dart';
import 'common.dart';
import 'entry_editor.dart';
import 'settings.dart';
import 'templates.dart';
import 'page_turn.dart';

class HomePage extends StatefulWidget {
  final LedgerStore store;
  const HomePage({super.key, required this.store});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  DateTime selected = dateOnly(DateTime.now());
  late DateTime week = monday(selected),
      month = DateTime(selected.year, selected.month);
  int tab = 0, generation = 0, turnDirection = 1;
  double dragDistance = 0;
  String filter = 'all';
  SettingsData settings = const SettingsData();
  DayView? day;
  List<DayView> days = [];
  Map<String, int> counts = {};
  bool applying = false;
  String? loadError;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.store.addListener(reload);
    reload();
  }

  @override
  void dispose() {
    widget.store.removeListener(reload);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) reload();
  }

  Future<void> reload() async {
    final seq = ++generation;
    final requestedDate = selected, requestedWeek = week, requestedMonth = month;
    try {
      final s = await widget.store.settings(),
          d = await widget.store.readDay(requestedDate),
          w = await widget.store.readWeek(requestedWeek),
          c = await widget.store.monthCounts(requestedMonth);
      if (mounted && seq == generation) {
        setState(() {
          settings = s;
          day = d;
          days = w;
          counts = c;
          loadError = null;
        });
      }
    } catch (e) {
      if (mounted && seq == generation) setState(() => loadError = '$e');
    }
  }

  void choose(DateTime d) {
    if (d.year < 1900 || d.year > 2100) return;
    setState(() {
      turnDirection = d.isBefore(selected) ? -1 : 1;
      selected = dateOnly(d);
      week = monday(d);
      month = DateTime(d.year, d.month);
      tab = 0;
    });
    reload();
  }

  Future<void> edit(int b, [Entry? entry]) => editEntry(
    context,
    widget.store,
    settings,
    date: selected,
    block: b,
    entry: entry,
    rank: day == null || day!.entries.isEmpty
        ? 0
        : day!.entries.map((e) => e.rank).reduce((a, b) => a > b ? a : b) + 1,
  );
  Future<void> toggle(Entry e, bool done) async {
    try {
      await widget.store.setDone(e.id, done);
    } catch (error) {
      if (mounted) await inform(context, '保存失败', '$error');
    }
  }

  Widget navDate(
    String title,
    VoidCallback back,
    VoidCallback forward, {
    VoidCallback? pick,
  }) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
    child: Row(
      children: [
        IconButton(
          onPressed: back,
          tooltip: '上一个',
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: TextButton(
            onPressed: pick,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: ink,
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: forward,
          tooltip: '下一个',
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    ),
  );
  Widget schedule() {
    final shownDate = day == null ? selected : parseDate(day!.day);
    final today = dateOnly(DateTime.now()), weekStart = monday(shownDate);
    final visible =
        day?.entries
            .where((e) => filter == 'all' || e.owner == filter)
            .toList() ??
        <Entry>[];
    final done = visible.where((e) => e.done).length;
    return ListView(
      key: ValueKey('day-${dateKey(shownDate)}'),
      children: [
        PageHeading(
          eyebrow: '三段日程 · 一段一段来',
          title: '${shownDate.month}月${shownDate.day}日',
          subtitle:
              '${shownDate.year}年 · 星期${weekdays[shownDate.weekday - 1]}  /  ${dateKey(shownDate) == dateKey(today) ? '今天' : '所选日期'}',
          trailing: TextButton(
            onPressed: () => choose(today),
            child: const Text('回到今天'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              IconButton(
                tooltip: '前一天',
                onPressed: () => choose(plusDays(selected, -1)),
                icon: const Icon(Icons.west_rounded, size: 20),
              ),
              const Expanded(
                child: Text(
                  '左右轻扫，翻过一天',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: green),
                ),
              ),
              IconButton(
                tooltip: '后一天',
                onPressed: () => choose(plusDays(selected, 1)),
                icon: const Icon(Icons.east_rounded, size: 20),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
          child: Row(
            children: [
              IconButton(
                onPressed: () => choose(plusDays(selected, -7)),
                tooltip: '上一周',
                icon: const Icon(Icons.chevron_left),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 44),
                style: IconButton.styleFrom(
                  minimumSize: const Size(28, 44),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Builder(
                    builder: (_) {
                      final d = plusDays(weekStart, i),
                          active =
                              dateKey(plusDays(weekStart, i)) ==
                              dateKey(shownDate),
                          isToday =
                              dateKey(plusDays(weekStart, i)) == dateKey(today);
                      return Semantics(
                        label: friendlyDate(d),
                        selected: active,
                        child: InkWell(
                          onTap: () => choose(d),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: ShapeDecoration(
                              color: active ? green : const Color(0xffeee8db),
                              shape: ContinuousRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: isToday
                                    ? const BorderSide(color: green, width: 1.5)
                                    : BorderSide.none,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  weekdays[i],
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: active
                                        ? Colors.white
                                        : const Color(0xff75806f),
                                  ),
                                ),
                                const SizedBox(height: 9),
                                Text(
                                  '${d.day}',
                                  style: TextStyle(
                                    fontSize: 17,
                                    color: active ? Colors.white : ink,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              IconButton(
                onPressed: () => choose(plusDays(selected, 7)),
                tooltip: '下一周',
                icon: const Icon(Icons.chevron_right),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 44),
                style: IconButton.styleFrom(
                  minimumSize: const Size(28, 44),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              const Icon(Icons.check_circle_outline, size: 18, color: green),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  visible.isEmpty
                      ? '还没有事项，按自己的节奏安排'
                      : '$done / ${visible.length} 项已完成',
                  style: const TextStyle(fontSize: 13, color: green),
                ),
              ),
              IconButton(
                onPressed: () async {
                  final d = await pickDate(context, selected);
                  if (d != null) choose(d);
                },
                tooltip: '选择日期',
                icon: const Icon(Icons.calendar_month_outlined, size: 22),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 18),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final o in ['all', 'me', 'partner', 'both'])
                ChoiceChip(
                  label: Text(
                    {'all': '全部', 'me': '我', 'partner': '对象', 'both': '一起'}[o]!,
                  ),
                  selected: filter == o,
                  onSelected: (_) => setState(() => filter = o),
                ),
            ],
          ),
        ),
        if (day == null)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: CircularProgressIndicator(),
            ),
          )
        else
          for (var i = 0; i < 3; i++)
            BlockCard(
              block: day!.blocks[i],
              index: i,
              entries: visible.where((e) => e.block == i).toList(),
              settings: settings,
              onAdd: () => edit(i),
              onEdit: (e) => edit(i, e),
              onDone: toggle,
              emptyText: filter == 'all' ? null : '当前归属下暂无事项',
            ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 2, 20, 24),
          child: Text(
            '未完成的事会留在当天，下一步由你决定。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Color(0xff777363)),
          ),
        ),
      ],
    );
  }

  Future<void> apply() async {
    final end = plusDays(week, 6);
    if (!await confirm(
      context,
      '应用模板到这一周？',
      '目标范围：\n${dateKey(week)} 至 ${dateKey(end)}\n\n只填充不早于今天、且尚未建立日程的日期。已建立的日期会跳过。空白模板也会建立日期，之后不会重复生成。',
      action: '应用模板',
    )) {
      return;
    }
    if (!mounted) return;
    setState(() => applying = true);
    try {
      final r = await widget.store.applyWeek(week);
      if (mounted) {
        await inform(
          context,
          '模板应用完成',
          '新建立 ${r.created.length} 天${r.created.isEmpty ? '' : '：\n${r.created.join('、')}'}\n\n已建立，保持原样 ${r.existing.length} 天${r.existing.isEmpty ? '' : '：\n${r.existing.join('、')}'}\n\n早于今天，跳过 ${r.past.length} 天${r.past.isEmpty ? '' : '：\n${r.past.join('、')}'}',
        );
      }
    } catch (e) {
      if (mounted) await inform(context, '应用失败', '$e');
    } finally {
      if (mounted) setState(() => applying = false);
    }
  }

  void moveWeek(int n) {
    final next = plusDays(week, n * 7);
    if (next.year < 1900 || plusDays(next, 6).year > 2100) return;
    setState(() => week = next);
    reload();
  }

  Widget weekPage() => ListView(
    children: [
      PageHeading(
        eyebrow: '给一周留出空间',
        title: '周计划',
        subtitle: '这里展示每天真实的安排，点一天继续编辑。',
        trailing: TextButton(
          onPressed: () {
            setState(() => week = monday(DateTime.now()));
            reload();
          },
          child: const Text('本周'),
        ),
      ),
      navDate(
        '${week.year}年 ${week.month}/${week.day}—${plusDays(week, 6).month}/${plusDays(week, 6).day}',
        () => moveWeek(-1),
        () => moveWeek(1),
        pick: () async {
          final d = await pickDate(context, week);
          if (d != null) {
            setState(() => week = monday(d));
            reload();
          }
        },
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => TemplatePage(store: widget.store),
                ),
              ),
              icon: const Icon(Icons.edit_calendar_outlined, size: 18),
              label: const Text('编辑周模板'),
            ),
            FilledButton.icon(
              onPressed: applying ? null : apply,
              icon: const Icon(Icons.playlist_add, size: 18),
              label: Text(applying ? '应用中…' : '应用模板到这一周'),
            ),
          ],
        ),
      ),
      for (final d in days)
        Card(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: InkWell(
            customBorder: notebookShape,
            onTap: () => choose(parseDate(d.day)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${d.day.substring(5).replaceAll('-', '/')}  周${weekdays[parseDate(d.day).weekday - 1]}${d.day == dateKey(DateTime.now()) ? ' · 今天' : ''}',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        d.established
                            ? '${d.entries.where((e) => e.done).length}/${d.entries.length} 已完成'
                            : '尚未建立',
                        style: const TextStyle(fontSize: 11, color: green),
                      ),
                      const Icon(Icons.chevron_right, size: 18),
                    ],
                  ),
                  const SizedBox(height: 14),
                  for (var b = 0; b < 3; b++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Color(d.blocks[b].color),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 80),
                              child: Text(
                                d.blocks[b].name,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: ink,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              d.entries.where((e) => e.block == b).isEmpty
                                  ? '留白'
                                  : d.entries
                                        .where((e) => e.block == b)
                                        .map(
                                          (e) =>
                                              '${e.done ? '✓ ' : ''}${e.title}',
                                        )
                                        .join(' · '),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                height: 1.7,
                                color: Color(0xff667464),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      const SizedBox(height: 14),
    ],
  );
  void moveMonth(int n) {
    final next = DateTime(month.year, month.month + n);
    if (next.year < 1900 || next.year > 2100) return;
    setState(() => month = next);
    reload();
  }

  Widget monthPage() {
    final first = DateTime(month.year, month.month),
        offset = DateTime(month.year, month.month).weekday - 1,
        total = DateTime(month.year, month.month + 1, 0).day;
    final cells = ((offset + total + 6) ~/ 7) * 7;
    return ListView(
      children: [
        PageHeading(
          eyebrow: '把日子铺开看',
          title: '月历',
          subtitle: '数字表示当天事项数，点击日期进入日程。',
          trailing: TextButton(
            onPressed: () {
              setState(
                () =>
                    month = DateTime(DateTime.now().year, DateTime.now().month),
              );
              reload();
            },
            child: const Text('本月'),
          ),
        ),
        navDate(
          '${month.year}年 ${month.month}月',
          () => moveMonth(-1),
          () => moveMonth(1),
          pick: () async {
            final d = await pickDate(context, month);
            if (d != null) {
              setState(() => month = DateTime(d.year, d.month));
              reload();
            }
          },
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 16),
          decoration: const ShapeDecoration(
            color: Color(0xfffffcf4),
            shape: ContinuousRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(32)),
              side: BorderSide(color: Color(0xffded6c4)),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  for (final w in weekdays)
                    Expanded(
                      child: Center(
                        child: Text(
                          w,
                          style: const TextStyle(fontSize: 12, color: green),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: cells,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisExtent:
                      66 * MediaQuery.textScalerOf(context).scale(1),
                ),
                itemBuilder: (c, i) {
                  final n = i - offset + 1;
                  if (n < 1 || n > total) return const SizedBox.shrink();
                  final date = DateTime(first.year, first.month, n),
                      key = dateKey(DateTime(first.year, first.month, n)),
                      active =
                          dateKey(selected) ==
                          dateKey(DateTime(first.year, first.month, n)),
                      today =
                          dateKey(DateTime.now()) ==
                          dateKey(DateTime(first.year, first.month, n));
                  return Semantics(
                    label: '${friendlyDate(date)}，${counts[key] ?? 0}项',
                    selected: active,
                    child: InkWell(
                      onTap: () => choose(date),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: active
                              ? green
                              : today
                              ? const Color(0xffedf1e7)
                              : null,
                          border: today
                              ? Border.all(color: green, width: 2)
                              : null,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$n',
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: active ? Colors.white : ink,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              (counts[key] ?? 0) > 0
                                  ? '${counts[key]}项'
                                  : (today ? '今天' : ''),
                              style: TextStyle(
                                fontSize: 9,
                                color: active ? Colors.white : green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(22),
          child: Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              const Text('描边：今天', style: TextStyle(fontSize: 12, color: green)),
              const Text(
                '深色：选中日期',
                style: TextStyle(fontSize: 12, color: green),
              ),
              Text(
                '本月 ${counts.length} 天有安排',
                style: const TextStyle(fontSize: 12, color: green),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget bookContent() => switch (tab) {
    0 => GestureDetector(
      onHorizontalDragStart: (_) => dragDistance = 0,
      onHorizontalDragUpdate: (details) => dragDistance += details.delta.dx,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (dragDistance.abs() < 64 && velocity.abs() < 450) return;
        final forward = dragDistance.abs() >= 64 ? dragDistance < 0 : velocity < 0;
        choose(plusDays(selected, forward ? 1 : -1));
      },
      child: NotebookPageTurn(
        pageKey: day?.day ?? dateKey(selected),
        direction: turnDirection,
        paperColor: paper,
        child: NotebookPaper(
          child: IgnorePointer(
            ignoring: day != null && day!.day != dateKey(selected),
            child: schedule(),
          ),
        ),
      ),
    ),
    1 => NotebookPaper(child: weekPage()),
    2 => NotebookPaper(child: monthPage()),
    _ => NotebookPaper(
      child: SettingsPage(store: widget.store, settings: settings),
    ),
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: cover,
    body: SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: paper,
            shape: notebookShape,
            shadows: const [
              BoxShadow(color: Color(0x55000000), blurRadius: 12, offset: Offset(0, 3)),
              BoxShadow(color: Color(0xffd8cebb), offset: Offset(2, 3)),
            ],
          ),
          child: ClipPath(
            clipper: const ShapeBorderClipper(shape: notebookShape),
            child: loadError != null
                ? NotebookPaper(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('读取失败：$loadError'),
                            const SizedBox(height: 16),
                            FilledButton(onPressed: reload, child: const Text('重试')),
                          ],
                        ),
                      ),
                    ),
                  )
                : bookContent(),
          ),
        ),
      ),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: tab,
      onDestinationSelected: (i) {
        setState(() => tab = i);
        reload();
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.view_agenda_outlined),
          selectedIcon: Icon(Icons.view_agenda),
          label: '日程',
        ),
        NavigationDestination(
          icon: Icon(Icons.date_range_outlined),
          selectedIcon: Icon(Icons.date_range),
          label: '周计划',
        ),
        NavigationDestination(
          icon: Icon(Icons.calendar_month_outlined),
          selectedIcon: Icon(Icons.calendar_month),
          label: '月历',
        ),
        NavigationDestination(icon: Icon(Icons.tune), label: '设置'),
      ],
    ),
  );
}
