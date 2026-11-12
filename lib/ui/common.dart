import 'package:flutter/material.dart';
import '../data/models.dart';
export 'notebook_paper.dart';

const ink = Color(0xff37382f);
const paper = Color(0xfff8f3e7);
const paperSurface = Color(0xfffffdf7);
const green = Color(0xff62705a);
const cover = Color(0xff55463c);
const notebookLine = Color(0xffded8c8);
const notebookShape = ContinuousRectangleBorder(
  borderRadius: BorderRadius.all(Radius.circular(32)),
);
const notebookControlShape = ContinuousRectangleBorder(
  borderRadius: BorderRadius.all(Radius.circular(20)),
);
const blockIcons = [
  Icons.wb_sunny_outlined,
  Icons.wb_twilight,
  Icons.nights_stay_outlined,
];
Future<bool> confirm(
  BuildContext context,
  String title,
  String message, {
  String action = '确认',
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(message)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;
Future<void> inform(BuildContext context, String title, String message) =>
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(message)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
Future<DateTime?> pickDate(BuildContext context, DateTime date) =>
    showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100, 12, 31),
      helpText: '选择日程日期',
      cancelText: '取消',
      confirmText: '确定',
    );
String friendlyDate(DateTime d) =>
    '${d.year}年${d.month}月${d.day}日 · 星期${weekdays[d.weekday - 1]}';

class PageHeading extends StatelessWidget {
  final String eyebrow, title, subtitle;
  final Widget? trailing;
  const PageHeading({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.trailing,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: const TextStyle(
            color: green,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 30,
                  fontFamily: 'serif',
                  fontWeight: FontWeight.w600,
                  letterSpacing: .5,
                  height: 1.25,
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xff726e60),
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ],
    ),
  );
}

class TaskLine extends StatelessWidget {
  final Entry entry;
  final SettingsData settings;
  final VoidCallback onTap;
  final ValueChanged<bool>? onDone;
  const TaskLine({
    super.key,
    required this.entry,
    required this.settings,
    required this.onTap,
    this.onDone,
  });
  @override
  Widget build(BuildContext context) => Semantics(
    label: '${entry.title}，${entry.done ? '已完成' : '未完成'}',
    child: InkWell(
      onTap: onTap,
      customBorder: notebookControlShape,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (onDone != null)
              SizedBox(
                width: 48,
                height: 48,
                child: Checkbox(
                  value: entry.done,
                  onChanged: (v) => onDone!(v!),
                  semanticLabel: '${entry.done ? '取消完成' : '完成'} ${entry.title}',
                  shape: ContinuousRectangleBorder(
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.fromLTRB(10, 10, 12, 0),
                child: Icon(Icons.drag_handle, size: 18, color: green),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: entry.done ? const Color(0xff67746c) : ink,
                        decoration: entry.done
                            ? TextDecoration.lineThrough
                            : null,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 5,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (entry.start != null)
                          Text(
                            '${timeText(entry.start!)}—${timeText(entry.end!)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xff58675c),
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: const ShapeDecoration(
                            color: Color(0xffecefdf),
                            shape: ContinuousRectangleBorder(
                              borderRadius: BorderRadius.all(Radius.circular(9)),
                            ),
                          ),
                          child: Text(
                            settings.ownerLabel(entry.owner),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xff455c4c),
                            ),
                          ),
                        ),
                        if (entry.done)
                          const Text(
                            '已完成',
                            style: TextStyle(fontSize: 12, color: green),
                          ),
                        if (entry.note.isNotEmpty)
                          const Icon(
                            Icons.notes,
                            size: 14,
                            color: Color(0xff738276),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 12, right: 4, left: 8),
              child: Icon(
                Icons.chevron_right,
                size: 18,
                color: Color(0xff87958a),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class BlockCard extends StatelessWidget {
  final BlockSpec block;
  final int index;
  final List<Entry> entries;
  final SettingsData settings;
  final VoidCallback onAdd;
  final ValueChanged<Entry> onEdit;
  final void Function(Entry, bool)? onDone;
  final String? emptyText;
  const BlockCard({
    super.key,
    required this.block,
    required this.index,
    required this.entries,
    required this.settings,
    required this.onAdd,
    required this.onEdit,
    this.onDone,
    this.emptyText,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
    child: Material(
      color: Color.alphaBlend(Color(block.color).withValues(alpha: .22), paper),
      shape: notebookShape.copyWith(
        side: const BorderSide(color: notebookLine),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: ShapeDecoration(
                    color: Color.alphaBlend(
                      Color(block.color).withValues(alpha: .45),
                      paperSurface,
                    ),
                    shape: notebookControlShape,
                  ),
                  child: Icon(blockIcons[index], color: green, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        block.name,
                        style: const TextStyle(
                          fontSize: 19,
                          fontFamily: 'serif',
                          fontWeight: FontWeight.w600,
                          color: ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Wrap(
                        spacing: 8,
                        runSpacing: 3,
                        children: [
                          Text(
                            block.range,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xff726e60),
                            ),
                          ),
                          Text(
                            onDone == null
                                ? '${entries.length} 项'
                                : '${entries.where((e) => e.done).length} / ${entries.length}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '添加事项',
                  onPressed: onAdd,
                  style: IconButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    backgroundColor: paperSurface,
                    shape: notebookControlShape,
                  ),
                  icon: const Icon(Icons.add_rounded, size: 23),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(
              children: [
                if (entries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        emptyText ?? '留一点空白，安排想做的事',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xff747360),
                        ),
                      ),
                    ),
                  ),
                for (final entry in entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Material(
                      color: paperSurface,
                      shape: notebookControlShape,
                      clipBehavior: Clip.antiAlias,
                      child: TaskLine(
                        entry: entry,
                        settings: settings,
                        onTap: () => onEdit(entry),
                        onDone: onDone == null ? null : (v) => onDone!(entry, v),
                      ),
                    ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('添加事项'),
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
