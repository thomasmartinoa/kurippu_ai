import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/services/audio_service.dart';
import '../../data/models/models.dart';
import '../../shared/providers/providers.dart';

class MeetingDetailScreen extends ConsumerStatefulWidget {
  final String meetingId;

  const MeetingDetailScreen({super.key, required this.meetingId});

  @override
  ConsumerState<MeetingDetailScreen> createState() =>
      _MeetingDetailScreenState();
}

class _MeetingDetailScreenState extends ConsumerState<MeetingDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _setupAudioPlayer();
  }

  void _setupAudioPlayer() {
    _audioPlayer.positionStream.listen((position) {
      setState(() => _position = position);
    });
    _audioPlayer.durationStream.listen((duration) {
      setState(() => _duration = duration ?? Duration.zero);
    });
    _audioPlayer.playerStateStream.listen((state) {
      setState(() => _isPlaying = state.playing);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(meetingDetailProvider(widget.meetingId));
    final processingState = ref.watch(transcriptProcessingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meeting Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Transcript'),
            Tab(text: 'Summary'),
          ],
        ),
      ),
      body: detailAsync.when(
        data: (detail) {
          if (detail == null) {
            return const Center(child: Text('Meeting not found'));
          }
          return TabBarView(
            controller: _tabController,
            children: [
              _buildOverviewTab(detail, processingState),
              _buildTranscriptTab(detail),
              _buildSummaryTab(detail),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildOverviewTab(
    MeetingDetail detail,
    AsyncValue<TranscriptSummary?> processingState,
  ) {
    final dateFormat = DateFormat('EEEE, MMMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Meeting info card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    detail.meeting.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    Icons.calendar_today,
                    dateFormat.format(detail.meeting.startTime),
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    Icons.access_time,
                    '${timeFormat.format(detail.meeting.startTime)} - ${timeFormat.format(detail.meeting.endTime)}',
                  ),
                  if (detail.meeting.location != null &&
                      detail.meeting.location!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildInfoRow(Icons.location_on, detail.meeting.location!),
                  ],
                  if (detail.meeting.attendees.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      Icons.people,
                      '${detail.meeting.attendees.length} attendees',
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Recording player
          if (detail.recording != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.audiotrack),
                        const SizedBox(width: 8),
                        Text(
                          'Recording',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const Spacer(),
                        Text(
                          AudioService.formatDuration(
                              detail.recording!.duration),
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Audio player controls
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => _togglePlayback(detail.recording!),
                          icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                          iconSize: 32,
                        ),
                        Expanded(
                          child: Slider(
                            value: _position.inSeconds.toDouble(),
                            max: _duration.inSeconds.toDouble().clamp(1, double.infinity),
                            onChanged: (value) {
                              _audioPlayer.seek(Duration(seconds: value.toInt()));
                            },
                          ),
                        ),
                        Text(
                          '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Process with AI button
          if (detail.recording != null &&
              detail.transcriptSummary == null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Icon(Icons.auto_awesome, size: 48, color: Colors.purple),
                    const SizedBox(height: 16),
                    Text(
                      'Process with AI',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Transcribe and summarize this recording using Gemini AI',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),
                    processingState.when(
                      data: (_) => ElevatedButton.icon(
                        onPressed: () => _processRecording(detail.recording!),
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text('Process Now'),
                      ),
                      loading: () => const Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 8),
                          Text('Processing... This may take a minute'),
                        ],
                      ),
                      error: (e, s) => Column(
                        children: [
                          Text(
                            'Error: $e',
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () =>
                                _processRecording(detail.recording!),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Transcript summary preview
          if (detail.transcriptSummary != null) ...[
            Card(
              color: Colors.green[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Transcript and summary available',
                        style: TextStyle(color: Colors.green[700]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTranscriptTab(MeetingDetail detail) {
    if (detail.transcriptSummary == null) {
      return _buildEmptyTabContent(
        icon: Icons.text_snippet,
        title: 'No Transcript Yet',
        subtitle: 'Process the recording to generate a transcript',
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SelectableText(
            detail.transcriptSummary!.transcript,
            style: const TextStyle(height: 1.6),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryTab(MeetingDetail detail) {
    if (detail.transcriptSummary == null) {
      return _buildEmptyTabContent(
        icon: Icons.summarize,
        title: 'No Summary Yet',
        subtitle: 'Process the recording to generate a summary',
      );
    }

    final ts = detail.transcriptSummary!;
    List<String> keyPoints = [];
    List<Map<String, dynamic>> actionItems = [];

    try {
      keyPoints = List<String>.from(jsonDecode(ts.keyPoints));
    } catch (_) {}

    try {
      actionItems = List<Map<String, dynamic>>.from(jsonDecode(ts.actionItems));
    } catch (_) {}

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary
          if (ts.summary != null && ts.summary!.isNotEmpty) ...[
            _buildSectionCard(
              'Summary',
              Icons.summarize,
              child: Text(
                ts.summary!,
                style: const TextStyle(height: 1.5),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Key Points
          if (keyPoints.isNotEmpty) ...[
            _buildSectionCard(
              'Key Points',
              Icons.lightbulb,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: keyPoints
                    .map((point) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('• ', style: TextStyle(fontSize: 16)),
                              Expanded(child: Text(point)),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Action Items
          if (actionItems.isNotEmpty) ...[
            _buildSectionCard(
              'Action Items',
              Icons.check_box,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: actionItems
                    .map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.check_box_outline_blank,
                                  size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item['task'] ?? ''),
                                    if (item['owner'] != null)
                                      Text(
                                        'Owner: ${item['owner']}',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: Colors.grey[700]),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard(String title, IconData icon, {required Widget child}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyTabContent({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _togglePlayback(Recording recording) async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      if (_audioPlayer.audioSource == null) {
        await _audioPlayer.setFilePath(recording.filePath);
      }
      await _audioPlayer.play();
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _processRecording(Recording recording) async {
    // Check if API key is set
    final apiKey = ref.read(apiKeyProvider);
    if (apiKey == null || apiKey.isEmpty) {
      _showApiKeyDialog();
      return;
    }

    // Initialize Gemini if not already
    final geminiService = ref.read(geminiServiceProvider);
    if (!geminiService.isInitialized) {
      await geminiService.initialize(apiKey);
    }

    // Process the recording
    await ref
        .read(transcriptProcessingProvider.notifier)
        .processRecording(recording);

    // Refresh the meeting detail
    ref.invalidate(meetingDetailProvider(widget.meetingId));
  }

  void _showApiKeyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('API Key Required'),
        content: const Text(
          'Please add your Gemini API key in Settings to process recordings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.push('/settings');
            },
            child: const Text('Go to Settings'),
          ),
        ],
      ),
    );
  }
}
