import 'package:hive/hive.dart';

enum RecordingStatus {
  recording,
  completed,
  processing,
  failed,
}

class Recording extends HiveObject {
  late String id;
  late String meetingId;
  late String filePath;
  int duration = 0;
  RecordingStatus status = RecordingStatus.recording;
  DateTime createdAt = DateTime.now();
  DateTime? completedAt;
  int fileSize = 0;
  String? transcriptSummaryId;

  Recording();

  Recording.create({
    required this.id,
    required this.meetingId,
    required this.filePath,
    this.duration = 0,
    this.status = RecordingStatus.recording,
    this.fileSize = 0,
    this.transcriptSummaryId,
  }) : createdAt = DateTime.now();
}

class RecordingStatusAdapter extends TypeAdapter<RecordingStatus> {
  @override
  final int typeId = 2;

  @override
  RecordingStatus read(BinaryReader reader) {
    return RecordingStatus.values[reader.readByte()];
  }

  @override
  void write(BinaryWriter writer, RecordingStatus obj) {
    writer.writeByte(obj.index);
  }
}

class RecordingAdapter extends TypeAdapter<Recording> {
  @override
  final int typeId = 1;

  @override
  Recording read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Recording()
      ..id = fields[0] as String
      ..meetingId = fields[1] as String
      ..filePath = fields[2] as String
      ..duration = fields[3] as int
      ..status = fields[4] as RecordingStatus
      ..createdAt = fields[5] as DateTime
      ..completedAt = fields[6] as DateTime?
      ..fileSize = fields[7] as int
      ..transcriptSummaryId = fields[8] as String?;
  }

  @override
  void write(BinaryWriter writer, Recording obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.meetingId)
      ..writeByte(2)
      ..write(obj.filePath)
      ..writeByte(3)
      ..write(obj.duration)
      ..writeByte(4)
      ..write(obj.status)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.completedAt)
      ..writeByte(7)
      ..write(obj.fileSize)
      ..writeByte(8)
      ..write(obj.transcriptSummaryId);
  }
}
