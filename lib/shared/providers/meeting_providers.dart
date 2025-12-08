import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/services.dart';
import '../../data/models/models.dart';
import 'service_providers.dart';

// ============ Meeting Providers ============

final meetingsProvider =
    StateNotifierProvider<MeetingsNotifier, AsyncValue<List<Meeting>>>((ref) {
  return MeetingsNotifier(ref.watch(storageServiceProvider));
});

class MeetingsNotifier extends StateNotifier<AsyncValue<List<Meeting>>> {
  final StorageService _storageService;

  MeetingsNotifier(this._storageService) : super(const AsyncValue.loading()) {
    loadMeetings();
  }

  Future<void> loadMeetings() async {
    state = const AsyncValue.loading();
    try {
      final meetings = await _storageService.getMeetingsWithRecordings();
      state = AsyncValue.data(meetings);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<Meeting> createMeetingFromCalendar(CalendarEvent event) async {
    // Check if meeting already exists
    var meeting =
        await _storageService.getMeetingByCalendarEventId(event.id);

    if (meeting == null) {
      meeting = Meeting()
        ..calendarEventId = event.id
        ..title = event.title
        ..description = event.description
        ..startTime = event.startTime
        ..endTime = event.endTime
        ..location = event.location
        ..attendees = event.attendees;

      final id = await _storageService.saveMeeting(meeting);
      meeting.id = id;
    }

    await loadMeetings();
    return meeting;
  }

  Future<void> updateMeetingHasRecording(String meetingId, bool hasRecording,
      {String? recordingId}) async {
    final meeting = await _storageService.getMeetingById(meetingId);
    if (meeting != null) {
      meeting.hasRecording = hasRecording;
      meeting.recordingId = recordingId;
      await _storageService.saveMeeting(meeting);
      await loadMeetings();
    }
  }

  Future<void> deleteMeeting(String id) async {
    await _storageService.deleteMeeting(id);
    await loadMeetings();
  }
}

// ============ Recording Providers ============

final recordingStateProvider =
    StateNotifierProvider<RecordingStateNotifier, RecordingState>((ref) {
  return RecordingStateNotifier(
    ref.watch(audioServiceProvider),
    ref.watch(storageServiceProvider),
  );
});

class RecordingState {
  final bool isRecording;
  final bool isPaused;
  final int duration;
  final String? currentFilePath;
  final String? currentMeetingId;
  final String? currentRecordingId;

  const RecordingState({
    this.isRecording = false,
    this.isPaused = false,
    this.duration = 0,
    this.currentFilePath,
    this.currentMeetingId,
    this.currentRecordingId,
  });

  RecordingState copyWith({
    bool? isRecording,
    bool? isPaused,
    int? duration,
    String? currentFilePath,
    String? currentMeetingId,
    String? currentRecordingId,
  }) {
    return RecordingState(
      isRecording: isRecording ?? this.isRecording,
      isPaused: isPaused ?? this.isPaused,
      duration: duration ?? this.duration,
      currentFilePath: currentFilePath ?? this.currentFilePath,
      currentMeetingId: currentMeetingId ?? this.currentMeetingId,
      currentRecordingId: currentRecordingId ?? this.currentRecordingId,
    );
  }
}

class RecordingStateNotifier extends StateNotifier<RecordingState> {
  final AudioService _audioService;
  final StorageService _storageService;

  RecordingStateNotifier(this._audioService, this._storageService)
      : super(const RecordingState()) {
    _audioService.durationStream.listen((duration) {
      state = state.copyWith(duration: duration);
    });
  }

  Future<void> startRecording(String meetingId) async {
    final filePath = await _audioService.startRecording(
      meetingId: meetingId,
    );

    if (filePath != null) {
      // Create recording entry
      final recording = Recording()
        ..meetingId = meetingId
        ..filePath = filePath
        ..status = RecordingStatus.recording;

      final recordingId = await _storageService.saveRecording(recording);

      state = state.copyWith(
        isRecording: true,
        isPaused: false,
        duration: 0,
        currentFilePath: filePath,
        currentMeetingId: meetingId,
        currentRecordingId: recordingId,
      );
    }
  }

  Future<void> pauseRecording() async {
    await _audioService.pauseRecording();
    state = state.copyWith(isPaused: true);
  }

  Future<void> resumeRecording() async {
    await _audioService.resumeRecording();
    state = state.copyWith(isPaused: false);
  }

  Future<Recording?> stopRecording() async {
    await _audioService.stopRecording();

    if (state.currentRecordingId != null) {
      // Update recording entry
      final recording =
          await _storageService.getRecordingById(state.currentRecordingId!);
      if (recording != null) {
        recording.status = RecordingStatus.completed;
        recording.completedAt = DateTime.now();
        recording.duration = state.duration;
        await _storageService.saveRecording(recording);

        state = const RecordingState();
        return recording;
      }
    }

    state = const RecordingState();
    return null;
  }

  Future<void> cancelRecording() async {
    if (state.currentRecordingId != null) {
      await _storageService.deleteRecording(state.currentRecordingId!);
    }
    await _audioService.cancelRecording();
    state = const RecordingState();
  }
}

// ============ Transcript Processing Provider ============

final transcriptProcessingProvider = StateNotifierProvider<
    TranscriptProcessingNotifier, AsyncValue<TranscriptSummary?>>((ref) {
  return TranscriptProcessingNotifier(
    ref.watch(geminiServiceProvider),
    ref.watch(storageServiceProvider),
  );
});

class TranscriptProcessingNotifier
    extends StateNotifier<AsyncValue<TranscriptSummary?>> {
  final GeminiService _geminiService;
  final StorageService _storageService;

  TranscriptProcessingNotifier(this._geminiService, this._storageService)
      : super(const AsyncValue.data(null));

  Future<TranscriptSummary?> processRecording(Recording recording) async {
    if (!_geminiService.isInitialized) {
      state = AsyncValue.error(
        Exception('Gemini service not initialized. Please add API key.'),
        StackTrace.current,
      );
      return null;
    }

    state = const AsyncValue.loading();

    try {
      // Update recording status
      recording.status = RecordingStatus.processing;
      await _storageService.saveRecording(recording);

      // Process audio with Gemini
      final result = await _geminiService.processAudio(recording.filePath);

      // Create transcript summary
      final transcriptSummary = TranscriptSummary()
        ..recordingId = recording.id
        ..transcript = result.transcript
        ..keyPoints = jsonEncode(result.keyPoints)
        ..actionItems = jsonEncode(
            result.actionItems.map((a) => a.toJson()).toList())
        ..summary = result.summary
        ..rawResponse = result.rawResponse;

      final id = await _storageService.saveTranscriptSummary(transcriptSummary);
      transcriptSummary.id = id;

      // Update recording with transcript link
      recording.status = RecordingStatus.completed;
      recording.transcriptSummaryId = id;
      await _storageService.saveRecording(recording);

      state = AsyncValue.data(transcriptSummary);
      return transcriptSummary;
    } catch (e, st) {
      // Mark recording as failed
      recording.status = RecordingStatus.failed;
      await _storageService.saveRecording(recording);

      state = AsyncValue.error(e, st);
      return null;
    }
  }

  void reset() {
    state = const AsyncValue.data(null);
  }
}

// ============ Single Meeting Detail Provider ============

final meetingDetailProvider =
    FutureProvider.family<MeetingDetail?, String>((ref, meetingId) async {
  final storageService = ref.watch(storageServiceProvider);

  final meeting = await storageService.getMeetingById(meetingId);
  if (meeting == null) return null;

  final recording = await storageService.getRecordingByMeetingId(meetingId);
  TranscriptSummary? transcriptSummary;

  if (recording?.transcriptSummaryId != null) {
    transcriptSummary = await storageService
        .getTranscriptSummaryById(recording!.transcriptSummaryId!);
  }

  return MeetingDetail(
    meeting: meeting,
    recording: recording,
    transcriptSummary: transcriptSummary,
  );
});

class MeetingDetail {
  final Meeting meeting;
  final Recording? recording;
  final TranscriptSummary? transcriptSummary;

  MeetingDetail({
    required this.meeting,
    this.recording,
    this.transcriptSummary,
  });
}
