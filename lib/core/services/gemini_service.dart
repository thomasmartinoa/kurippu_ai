import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

/// Response model for combined transcription and summary
class TranscriptionResult {
  final String transcript;
  final List<String> keyPoints;
  final List<ActionItem> actionItems;
  final String summary;
  final String rawResponse;

  TranscriptionResult({
    required this.transcript,
    required this.keyPoints,
    required this.actionItems,
    required this.summary,
    required this.rawResponse,
  });

  factory TranscriptionResult.fromJson(Map<String, dynamic> json, String raw) {
    return TranscriptionResult(
      transcript: json['transcript'] ?? '',
      keyPoints: List<String>.from(json['key_points'] ?? []),
      actionItems: (json['action_items'] as List?)
              ?.map((e) => ActionItem.fromJson(e))
              .toList() ??
          [],
      summary: json['summary'] ?? '',
      rawResponse: raw,
    );
  }
}

class ActionItem {
  final String task;
  final String? owner;
  final String? dueDate;

  ActionItem({
    required this.task,
    this.owner,
    this.dueDate,
  });

  factory ActionItem.fromJson(Map<String, dynamic> json) {
    return ActionItem(
      task: json['task'] ?? '',
      owner: json['owner'],
      dueDate: json['due_date'],
    );
  }

  Map<String, dynamic> toJson() => {
        'task': task,
        'owner': owner,
        'due_date': dueDate,
      };
}

/// Service for Gemini AI - handles both transcription and summarization
/// in a single API call for efficiency
class GeminiService {
  GenerativeModel? _model;
  String? _apiKey;

  static const String _systemPrompt = '''
You are an AI assistant specialized in transcribing meeting audio and generating structured summaries.

When given an audio file, you must:
1. Transcribe the audio accurately
2. Extract key discussion points
3. Identify action items with assigned owners if mentioned
4. Provide a brief summary

IMPORTANT: Respond ONLY with valid JSON in this exact format:
{
  "transcript": "Full transcript text here...",
  "key_points": [
    "First key point discussed",
    "Second key point discussed"
  ],
  "action_items": [
    {
      "task": "Task description",
      "owner": "Person name or null",
      "due_date": "Date if mentioned or null"
    }
  ],
  "summary": "A 2-3 sentence summary of the meeting"
}

Do not include any text outside the JSON object.
''';

  /// Initialize the Gemini service with an API key
  Future<void> initialize(String apiKey) async {
    _apiKey = apiKey;
    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.3,
        maxOutputTokens: 8192,
      ),
    );
  }

  bool get isInitialized => _model != null;

  /// Process audio file and get transcription + summary in one call
  Future<TranscriptionResult> processAudio(String audioFilePath) async {
    if (_model == null) {
      throw Exception('GeminiService not initialized. Call initialize() first.');
    }

    final file = File(audioFilePath);
    if (!await file.exists()) {
      throw Exception('Audio file not found: $audioFilePath');
    }

    final bytes = await file.readAsBytes();
    final mimeType = _getMimeType(audioFilePath);

    debugPrint('Processing audio file: $audioFilePath');
    debugPrint('File size: ${bytes.length} bytes');
    debugPrint('MIME type: $mimeType');

    try {
      final response = await _model!.generateContent([
        Content.multi([
          TextPart(_systemPrompt),
          TextPart('Please transcribe and summarize the following audio:'),
          DataPart(mimeType, bytes),
        ]),
      ]);

      final responseText = response.text ?? '';
      debugPrint('Gemini response: $responseText');

      return _parseResponse(responseText);
    } catch (e) {
      debugPrint('Gemini API error: $e');
      rethrow;
    }
  }

  /// Process text transcript and generate summary (for testing without audio)
  Future<TranscriptionResult> processTranscript(String transcript) async {
    if (_model == null) {
      throw Exception('GeminiService not initialized. Call initialize() first.');
    }

    final prompt = '''
$_systemPrompt

Here is the meeting transcript to analyze:

$transcript
''';

    try {
      final response = await _model!.generateContent([
        Content.text(prompt),
      ]);

      final responseText = response.text ?? '';
      return _parseResponse(responseText);
    } catch (e) {
      debugPrint('Gemini API error: $e');
      rethrow;
    }
  }

  TranscriptionResult _parseResponse(String responseText) {
    // Try to extract JSON from the response
    String jsonString = responseText.trim();

    // Remove markdown code blocks if present
    if (jsonString.startsWith('```json')) {
      jsonString = jsonString.substring(7);
    } else if (jsonString.startsWith('```')) {
      jsonString = jsonString.substring(3);
    }
    if (jsonString.endsWith('```')) {
      jsonString = jsonString.substring(0, jsonString.length - 3);
    }
    jsonString = jsonString.trim();

    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return TranscriptionResult.fromJson(json, responseText);
    } catch (e) {
      debugPrint('Failed to parse JSON response: $e');
      // Fallback: treat entire response as transcript
      return TranscriptionResult(
        transcript: responseText,
        keyPoints: [],
        actionItems: [],
        summary: '',
        rawResponse: responseText,
      );
    }
  }

  String _getMimeType(String filePath) {
    final extension = filePath.toLowerCase().split('.').last;
    switch (extension) {
      case 'mp3':
        return 'audio/mp3';
      case 'm4a':
        return 'audio/mp4';
      case 'aac':
        return 'audio/aac';
      case 'wav':
        return 'audio/wav';
      case 'ogg':
        return 'audio/ogg';
      case 'flac':
        return 'audio/flac';
      default:
        return 'audio/mp4'; // Default to m4a
    }
  }

  /// Check if API key is valid by making a simple request
  Future<bool> validateApiKey(String apiKey) async {
    try {
      final testModel = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: apiKey,
      );

      await testModel.generateContent([
        Content.text('Say "OK" if you can read this.'),
      ]);

      return true;
    } catch (e) {
      debugPrint('API key validation failed: $e');
      return false;
    }
  }
}
