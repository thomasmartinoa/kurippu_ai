import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/home/home_screen.dart';
import '../features/calendar/calendar_screen.dart';
import '../features/recording/recording_screen.dart';
import '../features/detail/meeting_detail_screen.dart';
import '../features/settings/settings_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/calendar',
        name: 'calendar',
        builder: (context, state) => const CalendarScreen(),
      ),
      GoRoute(
        path: '/recording/:meetingId',
        name: 'recording',
        builder: (context, state) {
          final meetingId = state.pathParameters['meetingId']!;
          return RecordingScreen(meetingId: meetingId);
        },
      ),
      GoRoute(
        path: '/meeting/:meetingId',
        name: 'meeting-detail',
        builder: (context, state) {
          final meetingId = state.pathParameters['meetingId']!;
          return MeetingDetailScreen(meetingId: meetingId);
        },
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.uri}'),
      ),
    ),
  );
});
