import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/models.dart';
import '../data/store.dart';
import 'common.dart';

Future<void> editEntry(
  BuildContext context,
  LedgerStore store,
  SettingsData settings, {
  required DateTime date,
  required int block,
  Entry? entry,
  int? weekday,
  int rank = 0,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: paper,
  barrierColor: const Color(0x6655463c),
  clipBehavior: Clip.antiAlias,
  shape: const ContinuousRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
    side: BorderSide(color: Color(0xffe0dbcd)),
  ),
  constraints: const BoxConstraints(maxWidth: 640),
  sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
      ? AnimationStyle.noAnimation
      : const AnimationStyle(
          duration: Duration(milliseconds: 380),
          reverseDuration: Duration(milliseconds: 260),
        ),
  builder: (_) => NotebookPaper(
    child: EntryEditor(
      store: store,
      settings: settings,
      date: date,
      block: block,
      entry: entry,
      weekday: weekday,
      rank: rank,
    ),
  ),
);

class EntryEditor extends StatefulWidget {
  final LedgerStore store;
  final SettingsData settings;
  final DateTime date;
  final int block, rank;
  final int? weekday;
  final Entry? entry;
  const EntryEditor({
    super.key,
    required this.store,
    required this.settings,
    required this.date,
    required this.block,
    required this.rank,
    this.entry,
    this.weekday,
  });
  @override
  State<EntryEditor> createState() => _EntryEditorState();
}

class _EntryEditorState extends State<EntryEditor> {
  late final TextEditingController title, note, rank;
  late final String id, created;
  late DateTime date;
  late int block;
  late String owner;
  late List<BlockSpec> blocks;
  int? start, end;
  bool saving = false, loading = true;
  String? error;
  bool get template => widget.weekday != null;
  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    title = TextEditingController(text: e?.title ?? '');
    note = TextEditingController(text: e?.note ?? '');
    rank = TextEditingController(text: '${e?.rank ?? widget.rank}');
    id = e?.id ?? newId();
    created = e?.createdAt ?? DateTime.now().toUtc().toIso8601String();
    date = widget.date;
    block = e?.block ?? widget.block;
    owner = e?.owner ?? 'me';
    start = e?.start;
    end = e?.end;
    blocks = widget.settings.blocks;
    loadBlocks();
  }

  @override
  void dispose() {
    title.dispose();
    note.dispose();
    rank.dispose();
    super.dispose();
  }

  Future<void> loadBlocks() async {
    try {
      final b = template
          ? (await widget.store.settings()).blocks
          : (await widget.store.readDay(date)).blocks;
      if (mounted) {
        setState(() {
          blocks = b;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = '$e';
          loading = false;
        });
      }
    }
  }

  Future<void> chooseTime(bool first) async {
    final n =
        (first ? start : end) ??
        (first ? blocks[block].start : blocks[block].end);
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: n ~/ 60, minute: n % 60),
      helpText: first ? '开始时间' : '结束时间',
      builder: (c, w) => MediaQuery(
        data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true),
        child: w!,
      ),
    );
    if (t != null && mounted) {
      setState(() {
        if (first) {
          start = t.hour * 60 + t.minute;
        } else {
          end = t.hour * 60 + t.minute;
        }
        error = null;
      });
    }
  }

  Future<void> save() async {
    FocusScope.of(context).unfocus();
    if (title.text.trim().isEmpty) {
      setState(() => error = '先给这件事起个名字吧');
      return;
    }
    final position = int.tryParse(rank.text);
    if (position == null || position < 0 || position > 100000000) {
      setState(() => error = '排序序号应为 0—100000000 的整数');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.store.saveEntry(
        Entry(
          id: id,
          title: title.text.trim(),
          note: note.text.trim(),
          owner: owner,
          day: template ? null : dateKey(date),
          weekday: widget.weekday,
          block: block,
          start: start,
          end: end,
          rank: position,
          done: widget.entry?.done ?? false,
          createdAt: created,
          updatedAt: DateTime.now().toUtc().toIso8601String(),
        ),
        template: template,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          error = '$e';
          saving = false;
        });
      }
    }
  }

  Future<void> remove() async {
    if (!await confirm(
      context,
      '删除这件事？',
      template ? '仅删除当前星期的模板事项，不影响已经生成的日程。' : '删除后这一天仍保留已建立状态，应用模板不会把事项恢复。',
      action: '删除',
    )) {
      return;
    }
    setState(() => saving = true);
    try {
      await widget.store.deleteEntry(id, template: template);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          saving = false;
          error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight:
              MediaQuery.sizeOf(context).height * .90 -
              MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 34,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xffc8c2af),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                template ? '周复一周的小习惯' : '留一页给今天',
                style: const TextStyle(
                  color: green,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.entry == null
                          ? (template ? '添加模板事项' : '想做点什么？')
                          : '编辑事项',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: saving ? null : () => Navigator.pop(context),
                    tooltip: '关闭',
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: title,
                maxLength: 120,
                minLines: 1,
                maxLines: 3,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '事项标题 *',
                  hintText: '例如：去图书馆写论文',
                ),
              ),
              const SizedBox(height: 12),
              if (!template)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: notebookControlShape,
                  tileColor: const Color(0xffefeee3),
                  leading: const Icon(
                    Icons.calendar_today_outlined,
                    color: green,
                  ),
                  title: Text(friendlyDate(date)),
                  subtitle: const Text('更改日期可移动事项'),
                  trailing: const Icon(Icons.expand_more),
                  onTap: saving
                      ? null
                      : () async {
                          final d = await pickDate(context, date);
                          if (d != null && mounted) {
                            setState(() {
                              date = d;
                              loading = true;
                              error = null;
                            });
                            await loadBlocks();
                          }
                        },
                )
              else
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '周${weekdays[widget.weekday! - 1]}模板 · 修改只影响以后新生成的日程',
                    style: const TextStyle(color: green),
                  ),
                ),
              DropdownButtonFormField<int>(
                initialValue: block,
                isExpanded: true,
                decoration: const InputDecoration(labelText: '所属模块'),
                items: [
                  for (var i = 0; i < 3; i++)
                    DropdownMenuItem(
                      value: i,
                      child: Text(
                        '${blocks[i].name}  ${blocks[i].range}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: saving || loading
                    ? null
                    : (v) => setState(() {
                        block = v!;
                        error = null;
                      }),
              ),
              const SizedBox(height: 18),
              const Text('归属', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final o in ['me', 'partner', 'both'])
                    ChoiceChip(
                      label: Text(
                        widget.settings.ownerLabel(o),
                        overflow: TextOverflow.ellipsis,
                      ),
                      selected: owner == o,
                      onSelected: saving
                          ? null
                          : (_) => setState(() => owner = o),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('设置具体时间'),
                subtitle: const Text('不填写也可以保存'),
                value: start != null || end != null,
                onChanged: saving
                    ? null
                    : (v) => setState(() {
                        start = v ? blocks[block].start : null;
                        end = v
                            ? (blocks[block].start + 60).clamp(
                                0,
                                blocks[block].end,
                              )
                            : null;
                        error = null;
                      }),
              ),
              if (start != null || end != null) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => chooseTime(true),
                        icon: const Icon(Icons.schedule, size: 18),
                        label: Text(start == null ? '开始' : timeText(start!)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => chooseTime(false),
                        icon: const Icon(Icons.schedule, size: 18),
                        label: Text(end == null ? '结束' : timeText(end!)),
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: saving
                      ? null
                      : () => setState(() {
                          start = null;
                          end = null;
                          error = null;
                        }),
                  child: const Text('清除具体时间'),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: note,
                maxLength: 2000,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: '备注（可选）'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: rank,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: '排序序号',
                  helperText: '同模块内越小越靠前',
                ),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      height: 1.5,
                    ),
                  ),
                ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: saving || loading ? null : save,
                  child: Text(saving ? '保存中…' : '保存事项'),
                ),
              ),
              if (widget.entry != null)
                Center(
                  child: TextButton.icon(
                    onPressed: saving ? null : remove,
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('删除事项'),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
