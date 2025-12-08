import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/foundation.dart';

class CalendarEvent {
  final String id;
  final String calendarId;
  final String title;
  final String? description;
  final DateTime startTime;
  final DateTime endTime;
  final String? location;
  final List<String> attendees;

  CalendarEvent({
    required this.id,
    required this.calendarId,
    required this.title,
    this.description,
    required this.startTime,
    required this.endTime,
    this.location,
    this.attendees = const [],
  });
}

class CalendarService {
  final DeviceCalendarPlugin _calendarPlugin = DeviceCalendarPlugin();
  List<Calendar>? _calendars;

  /// Request calendar permissions
  Future<bool> requestPermissions() async {
    var permissionsGranted = await _calendarPlugin.hasPermissions();
    if (permissionsGranted.isSuccess && (permissionsGranted.data ?? false)) {
      return true;
    }

    permissionsGranted = await _calendarPlugin.requestPermissions();
    return permissionsGranted.isSuccess && (permissionsGranted.data ?? false);
  }

  /// Check if calendar permissions are granted
  Future<bool> hasPermissions() async {
    final result = await _calendarPlugin.hasPermissions();
    return result.isSuccess && (result.data ?? false);
  }

  /// Get all available calendars
  Future<List<Calendar>> getCalendars() async {
    if (_calendars != null) return _calendars!;

    final hasPerms = await requestPermissions();
    if (!hasPerms) {
      throw Exception('Calendar permission not granted');
    }

    final result = await _calendarPlugin.retrieveCalendars();
    if (result.isSuccess && result.data != null) {
      _calendars = result.data!;
      return _calendars!;
    }

    return [];
  }

  /// Get events for today
  Future<List<CalendarEvent>> getTodayEvents() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return getEventsInRange(startOfDay, endOfDay);
  }

  /// Get events for the current week
  Future<List<CalendarEvent>> getWeekEvents() async {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfDay = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    final endOfWeek = startOfDay.add(const Duration(days: 7));

    return getEventsInRange(startOfDay, endOfWeek);
  }

  /// Get events in a specific date range
  Future<List<CalendarEvent>> getEventsInRange(
    DateTime start,
    DateTime end,
  ) async {
    final calendars = await getCalendars();
    final events = <CalendarEvent>[];

    for (final calendar in calendars) {
      if (calendar.id == null) continue;

      try {
        final result = await _calendarPlugin.retrieveEvents(
          calendar.id!,
          RetrieveEventsParams(
            startDate: start,
            endDate: end,
          ),
        );

        if (result.isSuccess && result.data != null) {
          for (final event in result.data!) {
            if (event.eventId == null || event.start == null || event.end == null) {
              continue;
            }

            events.add(CalendarEvent(
              id: event.eventId!,
              calendarId: calendar.id!,
              title: event.title ?? 'Untitled Event',
              description: event.description,
              startTime: event.start!,
              endTime: event.end!,
              location: event.location,
              attendees: event.attendees
                      ?.where((a) => a != null)
                      .map((a) => a!.name ?? a.emailAddress ?? '')
                      .where((name) => name.isNotEmpty)
                      .toList() ??
                  [],
            ));
          }
        }
      } catch (e) {
        debugPrint('Error retrieving events from calendar ${calendar.name}: $e');
      }
    }

    // Sort by start time
    events.sort((a, b) => a.startTime.compareTo(b.startTime));

    return events;
  }

  /// Get events for a specific date
  Future<List<CalendarEvent>> getEventsForDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return getEventsInRange(startOfDay, endOfDay);
  }

  /// Get upcoming events (next 7 days)
  Future<List<CalendarEvent>> getUpcomingEvents({int days = 7}) async {
    final now = DateTime.now();
    final end = now.add(Duration(days: days));

    final events = await getEventsInRange(now, end);
    
    // Filter to only future events
    return events.where((e) => e.startTime.isAfter(now)).toList();
  }

  /// Find event by ID
  Future<CalendarEvent?> getEventById(String calendarId, String eventId) async {
    try {
      final result = await _calendarPlugin.retrieveEvents(
        calendarId,
        RetrieveEventsParams(
          eventIds: [eventId],
        ),
      );

      if (result.isSuccess && result.data != null && result.data!.isNotEmpty) {
        final event = result.data!.first;
        if (event.start != null && event.end != null) {
          return CalendarEvent(
            id: event.eventId ?? eventId,
            calendarId: calendarId,
            title: event.title ?? 'Untitled Event',
            description: event.description,
            startTime: event.start!,
            endTime: event.end!,
            location: event.location,
            attendees: event.attendees
                    ?.where((a) => a != null)
                    .map((a) => a!.name ?? a.emailAddress ?? '')
                    .where((name) => name.isNotEmpty)
                    .toList() ??
                [],
          );
        }
      }
    } catch (e) {
      debugPrint('Error retrieving event: $e');
    }
    return null;
  }

  void clearCache() {
    _calendars = null;
  }
}
