import 'package:hive/hive.dart';

class Meeting extends HiveObject {
  late String id;
  late String calendarEventId;
  late String title;
  String? description;
  late DateTime startTime;
  late DateTime endTime;
  String? location;
  List<String> attendees = [];
  DateTime createdAt = DateTime.now();
  bool hasRecording = false;
  String? recordingId;

  Meeting();

  Meeting.create({
    required this.id,
    required this.calendarEventId,
    required this.title,
    this.description,
    required this.startTime,
    required this.endTime,
    this.location,
    this.attendees = const [],
    this.hasRecording = false,
    this.recordingId,
  }) : createdAt = DateTime.now();
}

class MeetingAdapter extends TypeAdapter<Meeting> {
  @override
  final int typeId = 0;

  @override
  Meeting read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Meeting()
      ..id = fields[0] as String
      ..calendarEventId = fields[1] as String
      ..title = fields[2] as String
      ..description = fields[3] as String?
      ..startTime = fields[4] as DateTime
      ..endTime = fields[5] as DateTime
      ..location = fields[6] as String?
      ..attendees = (fields[7] as List).cast<String>()
      ..createdAt = fields[8] as DateTime
      ..hasRecording = fields[9] as bool
      ..recordingId = fields[10] as String?;
  }

  @override
  void write(BinaryWriter writer, Meeting obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.calendarEventId)
      ..writeByte(2)
      ..write(obj.title)
      ..writeByte(3)
      ..write(obj.description)
      ..writeByte(4)
      ..write(obj.startTime)
      ..writeByte(5)
      ..write(obj.endTime)
      ..writeByte(6)
      ..write(obj.location)
      ..writeByte(7)
      ..write(obj.attendees)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.hasRecording)
      ..writeByte(10)
      ..write(obj.recordingId);
  }
}

