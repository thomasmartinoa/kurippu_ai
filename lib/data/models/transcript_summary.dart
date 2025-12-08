import 'package:hive/hive.dart';

class TranscriptSummary extends HiveObject {
  late String id;
  late String recordingId;
  late String transcript;
  String keyPoints = '[]';
  String actionItems = '[]';
  String? summary;
  String language = 'en';
  double confidence = 0.0;
  DateTime generatedAt = DateTime.now();
  String? rawResponse;

  TranscriptSummary();

  TranscriptSummary.create({
    required this.id,
    required this.recordingId,
    required this.transcript,
    this.keyPoints = '[]',
    this.actionItems = '[]',
    this.summary,
    this.language = 'en',
    this.confidence = 0.0,
    this.rawResponse,
  }) : generatedAt = DateTime.now();
}

class TranscriptSummaryAdapter extends TypeAdapter<TranscriptSummary> {
  @override
  final int typeId = 3;

  @override
  TranscriptSummary read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TranscriptSummary()
      ..id = fields[0] as String
      ..recordingId = fields[1] as String
      ..transcript = fields[2] as String
      ..keyPoints = fields[3] as String
      ..actionItems = fields[4] as String
      ..summary = fields[5] as String?
      ..language = fields[6] as String
      ..confidence = fields[7] as double
      ..generatedAt = fields[8] as DateTime
      ..rawResponse = fields[9] as String?;
  }

  @override
  void write(BinaryWriter writer, TranscriptSummary obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.recordingId)
      ..writeByte(2)
      ..write(obj.transcript)
      ..writeByte(3)
      ..write(obj.keyPoints)
      ..writeByte(4)
      ..write(obj.actionItems)
      ..writeByte(5)
      ..write(obj.summary)
      ..writeByte(6)
      ..write(obj.language)
      ..writeByte(7)
      ..write(obj.confidence)
      ..writeByte(8)
      ..write(obj.generatedAt)
      ..writeByte(9)
      ..write(obj.rawResponse);
  }
}
