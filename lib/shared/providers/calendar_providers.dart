import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/calendar_service.dart';
import 'service_providers.dart';

// ============ Calendar Events Providers ============

final selectedDateProvider = StateProvider<DateTime>((ref) {
  return DateTime.now();
});

final calendarEventsProvider =
    FutureProvider.family<List<CalendarEvent>, DateTime>((ref, date) async {
  final calendarService = ref.watch(calendarServiceProvider);
  return await calendarService.getEventsForDate(date);
});

final todayEventsProvider = FutureProvider<List<CalendarEvent>>((ref) async {
  final calendarService = ref.watch(calendarServiceProvider);
  return await calendarService.getTodayEvents();
});

final upcomingEventsProvider = FutureProvider<List<CalendarEvent>>((ref) async {
  final calendarService = ref.watch(calendarServiceProvider);
  return await calendarService.getUpcomingEvents(days: 7);
});

// ============ Calendar Permission Provider ============

final calendarPermissionProvider = FutureProvider<bool>((ref) async {
  final calendarService = ref.watch(calendarServiceProvider);
  return await calendarService.hasPermissions();
});

final requestCalendarPermissionProvider = FutureProvider<bool>((ref) async {
  final calendarService = ref.watch(calendarServiceProvider);
  return await calendarService.requestPermissions();
});
