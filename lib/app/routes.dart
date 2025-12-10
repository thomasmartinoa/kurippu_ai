import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/calendar/calendar_screen.dart';
import '../features/recording/recording_screen.dart';
import '../features/detail/meeting_detail_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/notes/screens/note_editor_screen.dart';
import '../features/notes/screens/notes_list_screen.dart';
import 'main_navigation.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      // Main navigation with bottom tabs
      GoRoute(
        path: '/',
        name: 'main',
        builder: (context, state) => const MainNavigationScreen(),
      ),
      // Legacy home route (redirects to main)
      GoRoute(
        path: '/home',
        name: 'home',
        redirect: (context, state) => '/',
      ),
      // Notes routes
      GoRoute(
        path: '/notes',
        name: 'notes',
        builder: (context, state) => const NotesListScreen(),
      ),
      GoRoute(
        path: '/note/new',
        name: 'new-note',
        builder: (context, state) => const NoteEditorScreen(),
      ),
      GoRoute(
        path: '/note/:noteId',
        name: 'edit-note',
        builder: (context, state) {
          final noteId = state.pathParameters['noteId']!;
          return NoteEditorScreen(noteId: noteId);
        },
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
