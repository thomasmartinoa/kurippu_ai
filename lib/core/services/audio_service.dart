import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

enum AudioServiceState {
  idle,
  recording,
  paused,
  stopped,
}

class AudioService {
  final AudioRecorder _recorder = AudioRecorder();
  final _uuid = const Uuid();

  AudioServiceState _state = AudioServiceState.idle;
  String? _currentFilePath;
  DateTime? _recordingStartTime;
  Timer? _durationTimer;
  int _recordingDuration = 0;

  // Stream controllers for state updates
  final _stateController = StreamController<AudioServiceState>.broadcast();
  final _durationController = StreamController<int>.broadcast();
  final _amplitudeController = StreamController<double>.broadcast();

  Stream<AudioServiceState> get stateStream => _stateController.stream;
  Stream<int> get durationStream => _durationController.stream;
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  AudioServiceState get state => _state;
  String? get currentFilePath => _currentFilePath;
  int get recordingDuration => _recordingDuration;

  /// Check if microphone permission is granted
  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  /// Start recording audio
  Future<String?> startRecording({String? meetingId}) async {
    if (_state == AudioServiceState.recording) {
      debugPrint('Already recording');
      return _currentFilePath;
    }

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      throw Exception('Microphone permission not granted');
    }

    // Generate unique filename
    final directory = await getApplicationDocumentsDirectory();
    final recordingsDir = Directory('${directory.path}/recordings');
    if (!await recordingsDir.exists()) {
      await recordingsDir.create(recursive: true);
    }

    final filename = meetingId != null
        ? 'meeting_${meetingId}_${DateTime.now().millisecondsSinceEpoch}.m4a'
        : 'recording_${_uuid.v4()}.m4a';
    _currentFilePath = '${recordingsDir.path}/$filename';

    debugPrint('Starting recording to: $_currentFilePath');

    try {
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: _currentFilePath!,
      );

      _state = AudioServiceState.recording;
      _recordingStartTime = DateTime.now();
      _recordingDuration = 0;
      _stateController.add(_state);

      // Start duration timer
      _startDurationTimer();

      // Start amplitude monitoring
      _startAmplitudeMonitoring();

      return _currentFilePath;
    } catch (e) {
      debugPrint('Failed to start recording: $e');
      _currentFilePath = null;
      rethrow;
    }
  }

  /// Pause recording
  Future<void> pauseRecording() async {
    if (_state != AudioServiceState.recording) return;

    await _recorder.pause();
    _state = AudioServiceState.paused;
    _durationTimer?.cancel();
    _stateController.add(_state);
  }

  /// Resume recording
  Future<void> resumeRecording() async {
    if (_state != AudioServiceState.paused) return;

    await _recorder.resume();
    _state = AudioServiceState.recording;
    _startDurationTimer();
    _stateController.add(_state);
  }

  /// Stop recording and return the file path
  Future<String?> stopRecording() async {
    if (_state == AudioServiceState.idle ||
        _state == AudioServiceState.stopped) {
      return _currentFilePath;
    }

    _durationTimer?.cancel();

    try {
      final path = await _recorder.stop();
      _state = AudioServiceState.stopped;
      _stateController.add(_state);

      debugPrint('Recording stopped. File: $path');
      debugPrint('Duration: $_recordingDuration seconds');

      // Verify file exists and has content
      if (path != null) {
        final file = File(path);
        if (await file.exists()) {
          final size = await file.length();
          debugPrint('File size: $size bytes');
          if (size == 0) {
            debugPrint('Warning: Recording file is empty');
          }
        }
      }

      return path ?? _currentFilePath;
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      return _currentFilePath;
    }
  }

  /// Cancel recording and delete the file
  Future<void> cancelRecording() async {
    await stopRecording();

    if (_currentFilePath != null) {
      final file = File(_currentFilePath!);
      if (await file.exists()) {
        await file.delete();
        debugPrint('Deleted cancelled recording: $_currentFilePath');
      }
    }

    _reset();
  }

  /// Get current amplitude for waveform visualization
  Future<double> getAmplitude() async {
    try {
      final amplitude = await _recorder.getAmplitude();
      return amplitude.current;
    } catch (e) {
      return -160.0; // Silence
    }
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _recordingDuration++;
      _durationController.add(_recordingDuration);
    });
  }

  void _startAmplitudeMonitoring() {
    Timer.periodic(const Duration(milliseconds: 100), (timer) async {
      if (_state != AudioServiceState.recording) {
        timer.cancel();
        return;
      }
      final amplitude = await getAmplitude();
      _amplitudeController.add(amplitude);
    });
  }

  void _reset() {
    _state = AudioServiceState.idle;
    _currentFilePath = null;
    _recordingStartTime = null;
    _recordingDuration = 0;
    _stateController.add(_state);
  }

  /// Get all recordings in the recordings directory
  Future<List<FileSystemEntity>> getRecordings() async {
    final directory = await getApplicationDocumentsDirectory();
    final recordingsDir = Directory('${directory.path}/recordings');
    if (!await recordingsDir.exists()) {
      return [];
    }
    return recordingsDir.listSync().where((f) => f.path.endsWith('.m4a')).toList();
  }

  /// Delete a recording file
  Future<void> deleteRecording(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Format duration as mm:ss or hh:mm:ss
  static String formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void dispose() {
    _durationTimer?.cancel();
    _stateController.close();
    _durationController.close();
    _amplitudeController.close();
    _recorder.dispose();
  }
}
