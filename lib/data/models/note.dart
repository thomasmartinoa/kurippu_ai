import 'package:hive/hive.dart';

enum NoteType {
  text,
  meeting,
  voice,
  checklist,
}

enum NotePriority {
  low,
  normal,
  high,
}

class Note extends HiveObject {
  late String id;
  late String title;
  String content = '';
  String? plainTextContent; // For search
  NoteType type = NoteType.text;
  NotePriority priority = NotePriority.normal;
  String? folderId;
  List<String> tags = [];
  bool isPinned = false;
  bool isFavorite = false;
  bool isArchived = false;
  bool isDeleted = false;
  String? meetingId; // Link to meeting if it's a meeting note
  String? recordingId; // Link to recording
  String? transcriptSummaryId; // Link to AI transcript
  List<String> attachments = []; // File paths
  String? color; // Note card color
  DateTime createdAt = DateTime.now();
  DateTime updatedAt = DateTime.now();
  DateTime? deletedAt;
  DateTime? reminderAt;

  Note();

  Note.create({
    required this.id,
    required this.title,
    this.content = '',
    this.plainTextContent,
    this.type = NoteType.text,
    this.priority = NotePriority.normal,
    this.folderId,
    this.tags = const [],
    this.isPinned = false,
    this.isFavorite = false,
    this.isArchived = false,
    this.isDeleted = false,
    this.meetingId,
    this.recordingId,
    this.transcriptSummaryId,
    this.attachments = const [],
    this.color,
    this.reminderAt,
  }) : createdAt = DateTime.now(),
       updatedAt = DateTime.now();

  void updateContent(String newContent) {
    content = newContent;
    plainTextContent = _stripHtml(newContent);
    updatedAt = DateTime.now();
  }

  String _stripHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '').trim();
  }

  bool matchesSearch(String query) {
    final lowerQuery = query.toLowerCase();
    return title.toLowerCase().contains(lowerQuery) ||
           (plainTextContent?.toLowerCase().contains(lowerQuery) ?? false) ||
           content.toLowerCase().contains(lowerQuery) ||
           tags.any((tag) => tag.toLowerCase().contains(lowerQuery));
  }
}

class Folder extends HiveObject {
  late String id;
  late String name;
  String? parentId;
  String? icon;
  String? color;
  int noteCount = 0;
  DateTime createdAt = DateTime.now();
  DateTime updatedAt = DateTime.now();

  Folder();

  Folder.create({
    required this.id,
    required this.name,
    this.parentId,
    this.icon,
    this.color,
  }) : createdAt = DateTime.now(),
       updatedAt = DateTime.now();
}

class Tag extends HiveObject {
  late String id;
  late String name;
  String? color;
  int noteCount = 0;
  DateTime createdAt = DateTime.now();

  Tag();

  Tag.create({
    required this.id,
    required this.name,
    this.color,
  }) : createdAt = DateTime.now();
}

// ============ Hive Adapters ============

class NoteTypeAdapter extends TypeAdapter<NoteType> {
  @override
  final int typeId = 10;

  @override
  NoteType read(BinaryReader reader) {
    return NoteType.values[reader.readByte()];
  }

  @override
  void write(BinaryWriter writer, NoteType obj) {
    writer.writeByte(obj.index);
  }
}

class NotePriorityAdapter extends TypeAdapter<NotePriority> {
  @override
  final int typeId = 11;

  @override
  NotePriority read(BinaryReader reader) {
    return NotePriority.values[reader.readByte()];
  }

  @override
  void write(BinaryWriter writer, NotePriority obj) {
    writer.writeByte(obj.index);
  }
}

class NoteAdapter extends TypeAdapter<Note> {
  @override
  final int typeId = 4;

  @override
  Note read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Note()
      ..id = fields[0] as String
      ..title = fields[1] as String
      ..content = fields[2] as String
      ..plainTextContent = fields[3] as String?
      ..type = fields[4] as NoteType
      ..priority = fields[5] as NotePriority
      ..folderId = fields[6] as String?
      ..tags = (fields[7] as List).cast<String>()
      ..isPinned = fields[8] as bool
      ..isFavorite = fields[9] as bool
      ..isArchived = fields[10] as bool
      ..isDeleted = fields[11] as bool
      ..meetingId = fields[12] as String?
      ..recordingId = fields[13] as String?
      ..transcriptSummaryId = fields[14] as String?
      ..attachments = (fields[15] as List).cast<String>()
      ..color = fields[16] as String?
      ..createdAt = fields[17] as DateTime
      ..updatedAt = fields[18] as DateTime
      ..deletedAt = fields[19] as DateTime?
      ..reminderAt = fields[20] as DateTime?;
  }

  @override
  void write(BinaryWriter writer, Note obj) {
    writer
      ..writeByte(21)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.content)
      ..writeByte(3)
      ..write(obj.plainTextContent)
      ..writeByte(4)
      ..write(obj.type)
      ..writeByte(5)
      ..write(obj.priority)
      ..writeByte(6)
      ..write(obj.folderId)
      ..writeByte(7)
      ..write(obj.tags)
      ..writeByte(8)
      ..write(obj.isPinned)
      ..writeByte(9)
      ..write(obj.isFavorite)
      ..writeByte(10)
      ..write(obj.isArchived)
      ..writeByte(11)
      ..write(obj.isDeleted)
      ..writeByte(12)
      ..write(obj.meetingId)
      ..writeByte(13)
      ..write(obj.recordingId)
      ..writeByte(14)
      ..write(obj.transcriptSummaryId)
      ..writeByte(15)
      ..write(obj.attachments)
      ..writeByte(16)
      ..write(obj.color)
      ..writeByte(17)
      ..write(obj.createdAt)
      ..writeByte(18)
      ..write(obj.updatedAt)
      ..writeByte(19)
      ..write(obj.deletedAt)
      ..writeByte(20)
      ..write(obj.reminderAt);
  }
}

class FolderAdapter extends TypeAdapter<Folder> {
  @override
  final int typeId = 5;

  @override
  Folder read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Folder()
      ..id = fields[0] as String
      ..name = fields[1] as String
      ..parentId = fields[2] as String?
      ..icon = fields[3] as String?
      ..color = fields[4] as String?
      ..noteCount = fields[5] as int
      ..createdAt = fields[6] as DateTime
      ..updatedAt = fields[7] as DateTime;
  }

  @override
  void write(BinaryWriter writer, Folder obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.parentId)
      ..writeByte(3)
      ..write(obj.icon)
      ..writeByte(4)
      ..write(obj.color)
      ..writeByte(5)
      ..write(obj.noteCount)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.updatedAt);
  }
}

class TagAdapter extends TypeAdapter<Tag> {
  @override
  final int typeId = 6;

  @override
  Tag read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Tag()
      ..id = fields[0] as String
      ..name = fields[1] as String
      ..color = fields[2] as String?
      ..noteCount = fields[3] as int
      ..createdAt = fields[4] as DateTime;
  }

  @override
  void write(BinaryWriter writer, Tag obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.color)
      ..writeByte(3)
      ..write(obj.noteCount)
      ..writeByte(4)
      ..write(obj.createdAt);
  }
}
