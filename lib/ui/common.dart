import 'package:flutter/material.dart';
import '../data/models.dart';

const ink = Color(0xff2f3532);
const paper = Color(0xfffaf8f3);
const green = Color(0xff446b5a);
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
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: const TextStyle(
            color: green,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
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
            color: Color(0xff66716a),
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
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (onDone != null)
              SizedBox(
                width: 40,
                height: 40,
                child: Checkbox(
                  value: entry.done,
                  onChanged: (v) => onDone!(v!),
                  semanticLabel: '${entry.done ? '取消完成' : '完成'} ${entry.title}',
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
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
                        fontWeight: FontWeight.w600,
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
                          decoration: BoxDecoration(
                            color: const Color(0xfff0f1ed),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            settings.ownerLabel(entry.owner),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xff455c4c),
                            ),
                          ),
                        ),
                        if (entry.done)
                          const Text(
                            '已完成',
                            style: TextStyle(fontSize: 11, color: green),
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
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xffe8ebe4)),
    ),
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Color(block.color),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(23)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .60),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(blockIcons[index], color: ink, size: 23),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      block.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      block.range,
                      style: const TextStyle(fontSize: 12, color: ink),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                onDone == null
                    ? '${entries.length} 项'
                    : '${entries.where((e) => e.done).length} / ${entries.length}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: ink,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              if (entries.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 22, 12, 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      emptyText ?? '留一点空白，安排想做的事',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xff788276),
                      ),
                    ),
                  ),
                ),
              for (var i = 0; i < entries.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: Color(0xffedf0e9)),
                TaskLine(
                  entry: entries[i],
                  settings: settings,
                  onTap: () => onEdit(entries[i]),
                  onDone: onDone == null ? null : (v) => onDone!(entries[i], v),
                ),
              ],
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
  );
}
