import 'package:hive_flutter/hive_flutter.dart';

import '../../data/models/meeting.dart';
import '../../data/models/recording.dart';
import '../../data/models/transcript_summary.dart';

class StorageService {
  static const String _meetingsBox = 'meetings';
  static const String _recordingsBox = 'recordings';
  static const String _transcriptSummariesBox = 'transcriptSummaries';

  late Box<Meeting> _meetingsBoxRef;
  late Box<Recording> _recordingsBoxRef;
  late Box<TranscriptSummary> _transcriptSummariesBoxRef;

  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;

    await Hive.initFlutter();

    // Register adapters
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(MeetingAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(RecordingAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(RecordingStatusAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(TranscriptSummaryAdapter());
    }

    // Open boxes
    _meetingsBoxRef = await Hive.openBox<Meeting>(_meetingsBox);
    _recordingsBoxRef = await Hive.openBox<Recording>(_recordingsBox);
    _transcriptSummariesBoxRef =
        await Hive.openBox<TranscriptSummary>(_transcriptSummariesBox);

    _isInitialized = true;
  }

  // ============ Meeting Operations ============

  Future<String> saveMeeting(Meeting meeting) async {
    await _meetingsBoxRef.put(meeting.id, meeting);
    return meeting.id;
  }

  Future<Meeting?> getMeetingById(String id) async {
    return _meetingsBoxRef.get(id);
  }

  Future<Meeting?> getMeetingByCalendarEventId(String calendarEventId) async {
    try {
      return _meetingsBoxRef.values.firstWhere(
        (m) => m.calendarEventId == calendarEventId,
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<Meeting>> getAllMeetings() async {
    final meetings = _meetingsBoxRef.values.toList();
    meetings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return meetings;
  }

  Future<List<Meeting>> getMeetingsWithRecordings() async {
    final meetings =
        _meetingsBoxRef.values.where((m) => m.hasRecording).toList();
    meetings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return meetings;
  }

  Future<void> deleteMeeting(String id) async {
    await _meetingsBoxRef.delete(id);
  }

  // ============ Recording Operations ============

  Future<String> saveRecording(Recording recording) async {
    await _recordingsBoxRef.put(recording.id, recording);
    return recording.id;
  }

  Future<Recording?> getRecordingById(String id) async {
    return _recordingsBoxRef.get(id);
  }

  Future<Recording?> getRecordingByMeetingId(String meetingId) async {
    try {
      return _recordingsBoxRef.values.firstWhere(
        (r) => r.meetingId == meetingId,
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<Recording>> getAllRecordings() async {
    final recordings = _recordingsBoxRef.values.toList();
    recordings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return recordings;
  }

  Future<List<Recording>> getCompletedRecordings() async {
    final recordings = _recordingsBoxRef.values
        .where((r) => r.status == RecordingStatus.completed)
        .toList();
    recordings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return recordings;
  }

  Future<void> updateRecordingStatus(String id, RecordingStatus status) async {
    final recording = _recordingsBoxRef.get(id);
    if (recording != null) {
      recording.status = status;
      if (status == RecordingStatus.completed) {
        recording.completedAt = DateTime.now();
      }
      await recording.save();
    }
  }

  Future<void> deleteRecording(String id) async {
    await _recordingsBoxRef.delete(id);
  }

  // ============ TranscriptSummary Operations ============

  Future<String> saveTranscriptSummary(TranscriptSummary transcriptSummary) async {
    await _transcriptSummariesBoxRef.put(transcriptSummary.id, transcriptSummary);
    return transcriptSummary.id;
  }

  Future<TranscriptSummary?> getTranscriptSummaryById(String id) async {
    return _transcriptSummariesBoxRef.get(id);
  }

  Future<TranscriptSummary?> getTranscriptSummaryByRecordingId(
      String recordingId) async {
    try {
      return _transcriptSummariesBoxRef.values.firstWhere(
        (t) => t.recordingId == recordingId,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteTranscriptSummary(String id) async {
    await _transcriptSummariesBoxRef.delete(id);
  }

  // ============ Cleanup Operations ============

  Future<void> deleteAllData() async {
    await _meetingsBoxRef.clear();
    await _recordingsBoxRef.clear();
    await _transcriptSummariesBoxRef.clear();
  }

  Future<void> close() async {
    await Hive.close();
    _isInitialized = false;
  }
}
