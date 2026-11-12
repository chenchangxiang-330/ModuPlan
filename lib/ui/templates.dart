import 'package:flutter/material.dart';
import '../data/models.dart';
import '../data/store.dart';
import 'common.dart';
import 'entry_editor.dart';

class TemplatePage extends StatefulWidget {
  final LedgerStore store;
  const TemplatePage({super.key, required this.store});
  @override
  State<TemplatePage> createState() => _TemplatePageState();
}

class _TemplatePageState extends State<TemplatePage> {
  int weekday = DateTime.now().weekday;
  SettingsData settings = const SettingsData();
  List<Entry> entries = [];
  bool busy = false;
  @override
  void initState() {
    super.initState();
    widget.store.addListener(reload);
    reload();
  }

  @override
  void dispose() {
    widget.store.removeListener(reload);
    super.dispose();
  }

  Future<void> reload() async {
    try {
      final s = await widget.store.settings(),
          rows = await widget.store.templates();
      if (mounted) {
        setState(() {
          settings = s;
          entries = rows;
        });
      }
    } catch (e) {
      if (mounted) await inform(context, '读取失败', '$e');
    }
  }

  Future<void> copy() async {
    final targets = <int>{};
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, change) => AlertDialog(
          title: Text('复制周${weekdays[weekday - 1]}模板'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('所选星期的原模板将被替换。已建立的日期不受影响。'),
                const SizedBox(height: 10),
                for (var i = 1; i <= 7; i++)
                  if (i != weekday)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('星期${weekdays[i - 1]}'),
                      value: targets.contains(i),
                      onChanged: (v) => change(() {
                        v! ? targets.add(i) : targets.remove(i);
                      }),
                    ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: targets.isEmpty ? null : () => Navigator.pop(c, true),
              child: const Text('确认替换'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => busy = true);
    try {
      await widget.store.copyTemplate(weekday, targets);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已复制；已生成的日程保持不变')));
      }
    } catch (e) {
      if (mounted) await inform(context, '复制失败', '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = entries.where((e) => e.weekday == weekday).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('编辑周模板')),
      body: NotebookPaper(
        child: ListView(
          children: [
            const PageHeading(
              eyebrow: '每周的小习惯',
              title: '一周的底稿',
              subtitle: '先写好常做的事，再把留白交给每一天。',
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 18),
              child: Text(
                '把常做的事放进模板，再主动应用到某一周。\n这里的更改不会回写已建立的日程。',
                style: TextStyle(color: Color(0xff78766a), height: 1.6),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (var i = 1; i <= 7; i++)
                    ChoiceChip(
                      label: Text('周${weekdays[i - 1]}'),
                      selected: weekday == i,
                      onSelected: busy
                          ? null
                          : (_) => setState(() => weekday = i),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
              child: Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: busy ? null : copy,
                  icon: const Icon(Icons.copy_all_outlined, size: 18),
                  label: const Text('复制到其他星期'),
                ),
              ),
            ),
            for (var i = 0; i < 3; i++)
              BlockCard(
                block: settings.blocks[i],
                index: i,
                entries: current.where((e) => e.block == i).toList(),
                settings: settings,
                onAdd: () => editEntry(
                  context,
                  widget.store,
                  settings,
                  date: DateTime.now(),
                  block: i,
                  weekday: weekday,
                  rank: current.isEmpty
                      ? 0
                      : current
                                .map((e) => e.rank)
                                .reduce((a, b) => a > b ? a : b) +
                            1,
                ),
                onEdit: (e) => editEntry(
                  context,
                  widget.store,
                  settings,
                  date: DateTime.now(),
                  block: i,
                  weekday: weekday,
                  entry: e,
                ),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
