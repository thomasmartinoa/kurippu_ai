import 'package:hive_flutter/hive_flutter.dart';

import '../../data/models/meeting.dart';
import '../../data/models/note.dart';
import '../../data/models/recording.dart';
import '../../data/models/transcript_summary.dart';

class StorageService {
  static const String _meetingsBox = 'meetings';
  static const String _recordingsBox = 'recordings';
  static const String _transcriptSummariesBox = 'transcriptSummaries';
  static const String _notesBox = 'notes';
  static const String _foldersBox = 'folders';
  static const String _tagsBox = 'tags';

  late Box<Meeting> _meetingsBoxRef;
  late Box<Recording> _recordingsBoxRef;
  late Box<TranscriptSummary> _transcriptSummariesBoxRef;
  late Box<Note> _notesBoxRef;
  late Box<Folder> _foldersBoxRef;
  late Box<Tag> _tagsBoxRef;

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
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(NoteAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(FolderAdapter());
    }
    if (!Hive.isAdapterRegistered(6)) {
      Hive.registerAdapter(TagAdapter());
    }
    if (!Hive.isAdapterRegistered(10)) {
      Hive.registerAdapter(NoteTypeAdapter());
    }
    if (!Hive.isAdapterRegistered(11)) {
      Hive.registerAdapter(NotePriorityAdapter());
    }

    // Open boxes
    _meetingsBoxRef = await Hive.openBox<Meeting>(_meetingsBox);
    _recordingsBoxRef = await Hive.openBox<Recording>(_recordingsBox);
    _transcriptSummariesBoxRef =
        await Hive.openBox<TranscriptSummary>(_transcriptSummariesBox);
    _notesBoxRef = await Hive.openBox<Note>(_notesBox);
    _foldersBoxRef = await Hive.openBox<Folder>(_foldersBox);
    _tagsBoxRef = await Hive.openBox<Tag>(_tagsBox);

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

  // ============ Note Operations ============

  Future<String> saveNote(Note note) async {
    note.updatedAt = DateTime.now();
    await _notesBoxRef.put(note.id, note);
    return note.id;
  }

  Future<Note?> getNoteById(String id) async {
    return _notesBoxRef.get(id);
  }

  Future<List<Note>> getAllNotes({bool includeDeleted = false, bool includeArchived = false}) async {
    var notes = _notesBoxRef.values.toList();
    
    if (!includeDeleted) {
      notes = notes.where((n) => !n.isDeleted).toList();
    }
    if (!includeArchived) {
      notes = notes.where((n) => !n.isArchived).toList();
    }
    
    // Sort: pinned first, then by updated date
    notes.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    
    return notes;
  }

  Future<List<Note>> getNotesByFolder(String? folderId) async {
    final notes = await getAllNotes();
    return notes.where((n) => n.folderId == folderId).toList();
  }

  Future<List<Note>> getNotesByTag(String tagName) async {
    final notes = await getAllNotes();
    return notes.where((n) => n.tags.contains(tagName)).toList();
  }

  Future<List<Note>> getFavoriteNotes() async {
    final notes = await getAllNotes();
    return notes.where((n) => n.isFavorite).toList();
  }

  Future<List<Note>> getArchivedNotes() async {
    final notes = _notesBoxRef.values
        .where((n) => n.isArchived && !n.isDeleted)
        .toList();
    notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return notes;
  }

  Future<List<Note>> getDeletedNotes() async {
    final notes = _notesBoxRef.values
        .where((n) => n.isDeleted)
        .toList();
    notes.sort((a, b) => (b.deletedAt ?? b.updatedAt).compareTo(a.deletedAt ?? a.updatedAt));
    return notes;
  }

  Future<List<Note>> searchNotes(String query) async {
    if (query.isEmpty) return [];
    final notes = await getAllNotes();
    return notes.where((n) => n.matchesSearch(query)).toList();
  }

  Future<List<Note>> getRecentNotes({int limit = 10}) async {
    final notes = await getAllNotes();
    return notes.take(limit).toList();
  }

  Future<List<Note>> getMeetingNotes() async {
    final notes = await getAllNotes();
    return notes.where((n) => n.type == NoteType.meeting || n.meetingId != null).toList();
  }

  Future<void> softDeleteNote(String id) async {
    final note = _notesBoxRef.get(id);
    if (note != null) {
      note.isDeleted = true;
      note.deletedAt = DateTime.now();
      await note.save();
    }
  }

  Future<void> restoreNote(String id) async {
    final note = _notesBoxRef.get(id);
    if (note != null) {
      note.isDeleted = false;
      note.deletedAt = null;
      await note.save();
    }
  }

  Future<void> permanentlyDeleteNote(String id) async {
    await _notesBoxRef.delete(id);
  }

  Future<void> archiveNote(String id) async {
    final note = _notesBoxRef.get(id);
    if (note != null) {
      note.isArchived = true;
      note.updatedAt = DateTime.now();
      await note.save();
    }
  }

  Future<void> unarchiveNote(String id) async {
    final note = _notesBoxRef.get(id);
    if (note != null) {
      note.isArchived = false;
      note.updatedAt = DateTime.now();
      await note.save();
    }
  }

  // ============ Folder Operations ============

  Future<String> saveFolder(Folder folder) async {
    folder.updatedAt = DateTime.now();
    await _foldersBoxRef.put(folder.id, folder);
    return folder.id;
  }

  Future<Folder?> getFolderById(String id) async {
    return _foldersBoxRef.get(id);
  }

  Future<List<Folder>> getAllFolders() async {
    final folders = _foldersBoxRef.values.toList();
    folders.sort((a, b) => a.name.compareTo(b.name));
    return folders;
  }

  Future<void> deleteFolder(String id) async {
    // Move notes to no folder
    final notes = await getNotesByFolder(id);
    for (final note in notes) {
      note.folderId = null;
      await note.save();
    }
    await _foldersBoxRef.delete(id);
  }

  Future<void> updateFolderNoteCounts() async {
    final folders = await getAllFolders();
    for (final folder in folders) {
      final notes = await getNotesByFolder(folder.id);
      folder.noteCount = notes.length;
      await folder.save();
    }
  }

  // ============ Tag Operations ============

  Future<String> saveTag(Tag tag) async {
    await _tagsBoxRef.put(tag.id, tag);
    return tag.id;
  }

  Future<Tag?> getTagById(String id) async {
    return _tagsBoxRef.get(id);
  }

  Future<Tag?> getTagByName(String name) async {
    try {
      return _tagsBoxRef.values.firstWhere(
        (t) => t.name.toLowerCase() == name.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<Tag>> getAllTags() async {
    final tags = _tagsBoxRef.values.toList();
    tags.sort((a, b) => b.noteCount.compareTo(a.noteCount));
    return tags;
  }

  Future<void> deleteTag(String id) async {
    final tag = await getTagById(id);
    if (tag != null) {
      // Remove tag from all notes
      final notes = await getNotesByTag(tag.name);
      for (final note in notes) {
        note.tags.remove(tag.name);
        await note.save();
      }
      await _tagsBoxRef.delete(id);
    }
  }

  Future<void> updateTagNoteCounts() async {
    final tags = await getAllTags();
    final allNotes = await getAllNotes();
    for (final tag in tags) {
      tag.noteCount = allNotes.where((n) => n.tags.contains(tag.name)).length;
      await tag.save();
    }
  }

  // ============ Cleanup Operations ============

  Future<void> deleteAllData() async {
    await _meetingsBoxRef.clear();
    await _recordingsBoxRef.clear();
    await _transcriptSummariesBoxRef.clear();
    await _notesBoxRef.clear();
    await _foldersBoxRef.clear();
    await _tagsBoxRef.clear();
  }

  Future<void> emptyTrash() async {
    final deletedNotes = await getDeletedNotes();
    for (final note in deletedNotes) {
      await _notesBoxRef.delete(note.id);
    }
  }

  Future<void> close() async {
    await Hive.close();
    _isInitialized = false;
  }
}
