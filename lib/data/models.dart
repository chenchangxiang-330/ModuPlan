import 'dart:math';

String newId() {
  final r = Random.secure();
  return List.generate(
    16,
    (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime plusDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);
DateTime monday(DateTime d) => plusDays(dateOnly(d), 1 - d.weekday);
const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
String timeText(int t) =>
    '${(t ~/ 60).toString().padLeft(2, '0')}:${(t % 60).toString().padLeft(2, '0')}';
int? parseTime(String s) {
  if (!RegExp(r'^\d{1,2}:\d{2}$').hasMatch(s)) return null;
  final p = s.split(':').map(int.parse).toList();
  return p[0] < 24 && p[1] < 60 ? p[0] * 60 + p[1] : null;
}

DateTime parseDate(String s) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s)) {
    throw const FormatException('日期格式应为 YYYY-MM-DD');
  }
  final d = DateTime.parse(s);
  if (dateKey(d) != s || d.year < 1900 || d.year > 2100) {
    throw const FormatException('日期不合法（支持 1900—2100 年）');
  }
  return d;
}

class RuleError implements Exception {
  final String message;
  const RuleError(this.message);
  @override
  String toString() => message;
}

Map<String, dynamic> objectOf(dynamic v) {
  if (v is! Map<String, dynamic>) throw const FormatException('应为 JSON 对象');
  return v;
}

int integerOf(dynamic v, int min, int max) {
  if (v is! int || v < min || v > max) throw const FormatException('数值不合法');
  return v;
}

String stringOf(dynamic v, int max, {bool allowEmpty = false}) {
  if (v is! String || v.length > max || (!allowEmpty && v.trim().isEmpty)) {
    throw const FormatException('文本不合法');
  }
  return v;
}

void validTimestamp(dynamic s) {
  if (s is! String || DateTime.tryParse(s) == null) {
    throw const FormatException('时间戳不合法');
  }
}

class BlockSpec {
  final String name;
  final int start, end, color;
  const BlockSpec(this.name, this.start, this.end, this.color);
  Map<String, dynamic> toJson() => {
    'name': name,
    'start': start,
    'end': end,
    'color': color,
  };
  factory BlockSpec.fromJson(dynamic value) {
    final j = objectOf(value);
    return BlockSpec(
      stringOf(j['name'], 16),
      integerOf(j['start'], 0, 1439),
      integerOf(j['end'], 0, 1439),
      integerOf(j['color'], 0xff000000, 0xffffffff),
    );
  }
  String get range => '${timeText(start)}—${timeText(end)}';
}

const initialBlocks = [
  BlockSpec('上午', 480, 720, 0xffffe4c7),
  BlockSpec('下午', 720, 1080, 0xffd8eee5),
  BlockSpec('晚上', 1080, 1320, 0xffe8dff4),
];
const blockColors = [
  0xffffe4c7,
  0xffd8eee5,
  0xffe8dff4,
  0xfff4dbe2,
  0xffdceafa,
  0xffeee7cd,
];
void validateBlocks(List<BlockSpec> blocks) {
  if (blocks.length != 3) throw const RuleError('必须保留三个模块');
  for (var i = 0; i < 3; i++) {
    final b = blocks[i];
    if (b.name.trim().isEmpty || b.name.length > 16) {
      throw const RuleError('模块名称请填写 1—16 个字');
    }
    if (b.start < 0 || b.end > 1439 || b.start >= b.end) {
      throw RuleError('${b.name}：开始时间必须早于结束时间，且在同一天内');
    }
    for (var k = 0; k < i; k++) {
      if (b.start < blocks[k].end && blocks[k].start < b.end) {
        throw RuleError('${blocks[k].name}与${b.name}的时间不能重叠');
      }
    }
  }
}

int? blockAt(List<BlockSpec> blocks, int minute) {
  for (var i = 0; i < blocks.length; i++) {
    if (minute >= blocks[i].start && minute < blocks[i].end) return i;
  }
  return null;
}

void validateTimes(int? start, int? end, BlockSpec b) {
  if (start == null && end == null) return;
  if (start == null || end == null) {
    throw const RuleError('请同时填写开始和结束时间，或清除具体时间');
  }
  if (start >= end || start < b.start || end > b.end) {
    throw RuleError('具体时间须位于「${b.name} ${b.range}」内，且开始早于结束；请调整或清除具体时间');
  }
}

class Entry {
  final String id, title, note, owner, createdAt, updatedAt;
  final String? day;
  final int? weekday, start, end;
  final int block, rank;
  final bool done;
  const Entry({
    required this.id,
    required this.title,
    this.note = '',
    this.owner = 'me',
    this.day,
    this.weekday,
    this.start,
    this.end,
    required this.block,
    this.rank = 0,
    this.done = false,
    required this.createdAt,
    required this.updatedAt,
  });
  Map<String, dynamic> toRow({bool template = false}) => {
    'id': id,
    if (template) 'weekday': weekday else 'day': day,
    'block': block,
    'title': title,
    'note': note,
    'owner': owner,
    'start': start,
    'end': end,
    'rank': rank,
    if (!template) 'done': done ? 1 : 0,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };
  factory Entry.fromRow(Map<String, dynamic> j, {bool template = false}) {
    validTimestamp(j['created_at']);
    validTimestamp(j['updated_at']);
    final owner = stringOf(j['owner'], 16);
    if (!['me', 'partner', 'both'].contains(owner)) {
      throw const FormatException('归属标签不合法');
    }
    final day = template ? null : stringOf(j['day'], 10);
    if (day != null) parseDate(day);
    return Entry(
      id: stringOf(j['id'], 128),
      title: stringOf(j['title'], 120),
      note: stringOf(j['note'], 2000, allowEmpty: true),
      owner: owner,
      day: day,
      weekday: template ? integerOf(j['weekday'], 1, 7) : null,
      start: j['start'] == null ? null : integerOf(j['start'], 0, 1439),
      end: j['end'] == null ? null : integerOf(j['end'], 0, 1439),
      block: integerOf(j['block'], 0, 2),
      rank: integerOf(j['rank'], 0, 100000000),
      done: template ? false : integerOf(j['done'], 0, 1) == 1,
      createdAt: j['created_at'],
      updatedAt: j['updated_at'],
    );
  }
  Entry copy({
    String? id,
    String? day,
    int? weekday,
    int? rank,
    bool? done,
    String? createdAt,
    String? updatedAt,
  }) => Entry(
    id: id ?? this.id,
    day: day ?? this.day,
    weekday: weekday ?? this.weekday,
    title: title,
    note: note,
    owner: owner,
    block: block,
    start: start,
    end: end,
    rank: rank ?? this.rank,
    done: done ?? this.done,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

class DayView {
  final String day;
  final bool established;
  final List<BlockSpec> blocks;
  final List<Entry> entries;
  const DayView(this.day, this.established, this.blocks, this.entries);
}

class SettingsData {
  final String me, partner;
  final List<BlockSpec> blocks;
  const SettingsData({
    this.me = '我',
    this.partner = '对象',
    this.blocks = initialBlocks,
  });
  String ownerLabel(String owner) => owner == 'me'
      ? (me == '我' ? '我' : '我 · $me')
      : owner == 'partner'
      ? (partner == '对象' ? '对象' : '对象 · $partner')
      : '一起';
  Map<String, dynamic> toJson() => {
    'me': me,
    'partner': partner,
    'blocks': blocks.map((b) => b.toJson()).toList(),
  };
  factory SettingsData.fromJson(dynamic value) {
    final j = objectOf(value);
    if (j['blocks'] is! List) throw const FormatException('缺少模块设置');
    final b = (j['blocks'] as List).map(BlockSpec.fromJson).toList();
    validateBlocks(b);
    return SettingsData(
      me: stringOf(j['me'], 20),
      partner: stringOf(j['partner'], 20),
      blocks: b,
    );
  }
}
