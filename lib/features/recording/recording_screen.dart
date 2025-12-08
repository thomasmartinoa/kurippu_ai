import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/audio_service.dart';
import '../../shared/providers/providers.dart';

class RecordingScreen extends ConsumerStatefulWidget {
  final String meetingId;

  const RecordingScreen({super.key, required this.meetingId});

  @override
  ConsumerState<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends ConsumerState<RecordingScreen> {
  bool _isStarting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startRecording();
    });
  }

  Future<void> _startRecording() async {
    setState(() => _isStarting = true);
    try {
      await ref.read(recordingStateProvider.notifier).startRecording(widget.meetingId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start recording: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isStarting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final recordingState = ref.watch(recordingStateProvider);
    final meetingDetail =
        ref.watch(meetingDetailProvider(widget.meetingId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recording'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _showCancelDialog(),
        ),
      ),
      body: _isStarting
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Starting recording...'),
                ],
              ),
            )
          : _buildRecordingContent(context, recordingState, meetingDetail),
    );
  }

  Widget _buildRecordingContent(
    BuildContext context,
    RecordingState recordingState,
    AsyncValue<MeetingDetail?> meetingDetailAsync,
  ) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Meeting info
          meetingDetailAsync.when(
            data: (detail) {
              if (detail == null) {
                return const Text('Meeting not found');
              }
              return Column(
                children: [
                  Text(
                    detail.meeting.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Recording in progress...',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              );
            },
            loading: () => const CircularProgressIndicator(),
            error: (e, s) => Text('Error: $e'),
          ),

          const Spacer(),

          // Recording animation
          _RecordingIndicator(
            isRecording: recordingState.isRecording,
            isPaused: recordingState.isPaused,
          ),

          const SizedBox(height: 32),

          // Duration
          Text(
            AudioService.formatDuration(recordingState.duration),
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
          ),

          const Spacer(),

          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Pause/Resume button
              IconButton.filled(
                onPressed: () {
                  if (recordingState.isPaused) {
                    ref.read(recordingStateProvider.notifier).resumeRecording();
                  } else {
                    ref.read(recordingStateProvider.notifier).pauseRecording();
                  }
                },
                icon: Icon(
                  recordingState.isPaused ? Icons.play_arrow : Icons.pause,
                ),
                iconSize: 32,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.grey[200],
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(width: 32),
              // Stop button
              IconButton.filled(
                onPressed: () => _stopRecording(),
                icon: const Icon(Icons.stop),
                iconSize: 48,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(20),
                ),
              ),
              const SizedBox(width: 32),
              // Cancel button
              IconButton.filled(
                onPressed: () => _showCancelDialog(),
                icon: const Icon(Icons.delete_outline),
                iconSize: 32,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.grey[200],
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ],
          ),

          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Future<void> _stopRecording() async {
    final recording =
        await ref.read(recordingStateProvider.notifier).stopRecording();

    if (recording != null && mounted) {
      // Update meeting to show it has a recording
      await ref
          .read(meetingsProvider.notifier)
          .updateMeetingHasRecording(
            recording.meetingId,
            true,
            recordingId: recording.id,
          );

      // Ask if user wants to process with AI
      _showProcessDialog(recording.meetingId);
    }
  }

  void _showProcessDialog(String meetingId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Recording Complete'),
        content: const Text(
          'Would you like to transcribe and summarize this recording with AI?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/meeting/$meetingId');
            },
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/meeting/$meetingId?process=true');
            },
            child: const Text('Process Now'),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Recording?'),
        content: const Text(
          'Are you sure you want to cancel this recording? The audio will be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Continue Recording'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await ref.read(recordingStateProvider.notifier).cancelRecording();
              if (mounted) {
                context.go('/');
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cancel Recording'),
          ),
        ],
      ),
    );
  }
}

class _RecordingIndicator extends StatefulWidget {
  final bool isRecording;
  final bool isPaused;

  const _RecordingIndicator({
    required this.isRecording,
    required this.isPaused,
  });

  @override
  State<_RecordingIndicator> createState() => _RecordingIndicatorState();
}

class _RecordingIndicatorState extends State<_RecordingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (widget.isRecording && !widget.isPaused) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_RecordingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording && !widget.isPaused) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 120 * _animation.value,
          height: 120 * _animation.value,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.isPaused
                ? Colors.orange.withOpacity(0.2)
                : Colors.red.withOpacity(0.2),
          ),
          child: Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isPaused ? Colors.orange : Colors.red,
              ),
              child: Icon(
                widget.isPaused ? Icons.pause : Icons.mic,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),
        );
      },
    );
  }
}
