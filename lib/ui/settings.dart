import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/models.dart';
import '../data/store.dart';
import 'common.dart';

const filesChannel = MethodChannel('cn.bingbing.dayblocks/files');

class SettingsPage extends StatefulWidget {
  final LedgerStore store;
  final SettingsData settings;
  const SettingsPage({super.key, required this.store, required this.settings});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool busy = false;
  Future<void> run(Future<void> Function() action) async {
    setState(() => busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) await inform(context, '操作未完成', '$e\n\n原数据不会因无效备份被替换。');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> nicknames() async {
    final me = TextEditingController(text: widget.settings.me),
        partner = TextEditingController(text: widget.settings.partner);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('给你们起个昵称'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: me,
                maxLength: 20,
                decoration: const InputDecoration(labelText: '我的昵称'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: partner,
                maxLength: 20,
                decoration: const InputDecoration(labelText: '对象的昵称'),
              ),
              const Text(
                '昵称用于区分事项归属，不代表账号或设备连接。',
                style: TextStyle(fontSize: 12, color: green),
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
            onPressed: () => Navigator.pop(c, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    final a = me.text.trim(), b = partner.text.trim();
    // Controllers are released after the dialog's exit animation.
    Future<void>.delayed(const Duration(milliseconds: 350), () {
      me.dispose();
      partner.dispose();
    });
    if (ok == true) {
      await widget.store.saveSettings(
        SettingsData(me: a, partner: b, blocks: widget.settings.blocks),
      );
    }
  }

  Future<void> export() async {
    final text = await widget.store.exportJson();
    final result = await filesChannel.invokeMethod<bool>('export', {
      'text': text,
      'name': '三段日程_${dateKey(DateTime.now())}.json',
    });
    if (result == true && mounted) {
      await inform(context, '备份已导出', '已保存到你选择的位置。请妥善保存 JSON 文件，恢复会完整替换本机数据。');
    }
  }

  Future<void> restore() async {
    final text = await filesChannel.invokeMethod<String>('import');
    if (text == null) return;
    final backup = LedgerStore.validateBackup(text);
    if (!mounted) return;
    if (!await confirm(
      context,
      '完整恢复并替换？',
      '文件已通过校验：\n${backup.days.length} 个已建立日期\n${backup.entries.length} 条日程事项\n${backup.templates.length} 条模板事项\n\n恢复会替换本机全部日程、完成状态、周模板与设置，不能合并。建议先导出当前备份。',
      action: '替换并恢复',
    )) {
      return;
    }
    await widget.store.restoreJson(text);
    if (mounted) await inform(context, '恢复完成', '日程、周模板和设置已恢复。');
  }

  Future<void> clear() async {
    if (!await confirm(
      context,
      '清空全部数据？',
      '所有日程、周模板、完成状态和昵称都会删除，默认模块也会重置。建议先导出备份。',
      action: '继续',
    )) {
      return;
    }
    if (!mounted) return;
    if (!await confirm(
      context,
      '再次确认：永久清空',
      '此操作无法撤销。确定要删除本机全部数据吗？',
      action: '确认清空',
    )) {
      return;
    }
    await widget.store.clearAll();
    if (mounted) await inform(context, '已清空', '已回到空白日程，默认模块已重置。');
  }

  Widget tile(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap, {
    bool danger = false,
  }) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    leading: Container(
      width: 40,
      height: 40,
      decoration: ShapeDecoration(
        color: danger ? const Color(0xfff5e9df) : const Color(0xffeaeede),
        shape: notebookControlShape,
      ),
      child: Icon(icon, color: danger ? const Color(0xffa5483e) : green, size: 21),
    ),
    title: Text(
      title,
      style: TextStyle(
        fontWeight: FontWeight.w600,
        color: danger ? const Color(0xffa5483e) : ink,
      ),
    ),
    subtitle: Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Text(subtitle, style: const TextStyle(fontSize: 13, height: 1.5)),
    ),
    trailing: const Icon(Icons.chevron_right, size: 18, color: Color(0xff8a8877)),
    onTap: busy ? null : onTap,
  );
  @override
  Widget build(BuildContext context) => ListView(
    children: [
      const PageHeading(
        eyebrow: '让日子合你心意',
        title: '设置',
        subtitle: '在这台手机上，安心安排每一天。',
      ),
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(18),
        decoration: const ShapeDecoration(
          color: Color(0xffeaeede),
          shape: ContinuousRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(32)),
            side: BorderSide(color: Color(0xffd5dcc5)),
          ),
        ),
        child: const Row(
          children: [
            Icon(Icons.offline_bolt_outlined, color: green, size: 28),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '单机 · 离线 · 你的节奏',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '数据保存在本机。没有账号、配对或跨设备同步。',
                    style: TextStyle(fontSize: 13, color: green, height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const _SettingsSectionLabel('日常偏好'),
      Card(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            tile(
              Icons.people_outline,
              '昵称与归属',
              '${widget.settings.me} / ${widget.settings.partner} / 一起',
              () => run(nicknames),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            tile(
              Icons.tune,
              '默认三段模块',
              '名称、时间与颜色 · 只影响新建立日期',
              () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => BlocksSettingsPage(
                    store: widget.store,
                    settings: widget.settings,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      const _SettingsSectionLabel('数据与备份'),
      Card(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            tile(
              Icons.file_upload_outlined,
              '导出完整备份',
              '将全部数据保存为 JSON 文件',
              () => run(export),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            tile(
              Icons.settings_backup_restore,
              '从文件恢复',
              '校验后完整替换本机数据',
              () => run(restore),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      Card(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        child: tile(
          Icons.delete_outline,
          '清空全部数据',
          '需要两次确认，清空后无法撤销',
          () => run(clear),
          danger: true,
        ),
      ),
      if (busy)
        const Padding(
          padding: EdgeInsets.all(20),
          child: LinearProgressIndicator(),
        ),
      const Padding(
        padding: EdgeInsets.all(28),
        child: Text(
          'ModuPlan  0.1.1 · 纸间\n今天的事，一段一段来。',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Color(0xff78766a), height: 1.9),
        ),
      ),
    ],
  );
}

class _SettingsSectionLabel extends StatelessWidget {
  final String text;
  const _SettingsSectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 24, 20, 10),
    child: Text(
      text,
      style: const TextStyle(
        color: green,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1,
      ),
    ),
  );
}

class BlocksSettingsPage extends StatefulWidget {
  final LedgerStore store;
  final SettingsData settings;
  const BlocksSettingsPage({
    super.key,
    required this.store,
    required this.settings,
  });
  @override
  State<BlocksSettingsPage> createState() => _BlocksSettingsPageState();
}

class _BlocksSettingsPageState extends State<BlocksSettingsPage> {
  late final List<TextEditingController> names;
  late List<BlockSpec> blocks;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    blocks = List.of(widget.settings.blocks);
    names = blocks.map((b) => TextEditingController(text: b.name)).toList();
  }

  @override
  void dispose() {
    for (final c in names) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> time(int i, bool first) async {
    final b = blocks[i], n = first ? blocks[i].start : blocks[i].end;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: n ~/ 60, minute: n % 60),
      builder: (c, w) => MediaQuery(
        data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true),
        child: w!,
      ),
    );
    if (t != null && mounted) {
      setState(() {
        final value = t.hour * 60 + t.minute;
        blocks[i] = BlockSpec(
          b.name,
          first ? value : b.start,
          first ? b.end : value,
          b.color,
        );
      });
    }
  }

  Future<void> save() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final b = [
        for (var i = 0; i < 3; i++)
          BlockSpec(
            names[i].text.trim(),
            blocks[i].start,
            blocks[i].end,
            blocks[i].color,
          ),
      ];
      await widget.store.saveSettings(
        SettingsData(
          me: widget.settings.me,
          partner: widget.settings.partner,
          blocks: b,
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('默认三段模块')),
    body: NotebookPaper(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            '修改只影响之后新建立的日期。已建立日期保留原模块快照；周模板中的定时事项必须仍在新时间范围内。',
            style: TextStyle(color: green, height: 1.6),
          ),
          const SizedBox(height: 18),
          for (var i = 0; i < 3; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: ShapeDecoration(
                color: Color.lerp(paperSurface, Color(blocks[i].color), .32),
                shape: const ContinuousRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(32)),
                  side: BorderSide(color: notebookLine),
                ),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: names[i],
                    maxLength: 16,
                    decoration: InputDecoration(
                      labelText: '模块 ${i + 1} 名称',
                      fillColor: Colors.white,
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: busy ? null : () => time(i, true),
                          child: Text('开始 ${timeText(blocks[i].start)}'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: busy ? null : () => time(i, false),
                          child: Text('结束 ${timeText(blocks[i].end)}'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var c = 0; c < blockColors.length; c++)
                        Semantics(
                          label: '配色 ${c + 1}',
                          selected: blocks[i].color == blockColors[c],
                          child: InkWell(
                            onTap: busy
                                ? null
                                : () => setState(
                                    () => blocks[i] = BlockSpec(
                                      blocks[i].name,
                                      blocks[i].start,
                                      blocks[i].end,
                                      blockColors[c],
                                    ),
                                  ),
                            borderRadius: BorderRadius.circular(24),
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Color(blockColors[c]),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: blocks[i].color == blockColors[c]
                                      ? ink
                                      : Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: blocks[i].color == blockColors[c]
                                  ? const Icon(Icons.check, color: ink, size: 18)
                                  : null,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  height: 1.6,
                ),
              ),
            ),
          FilledButton(
            onPressed: busy ? null : save,
            child: Text(busy ? '保存中…' : '保存默认模块'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    ),
  );
}
