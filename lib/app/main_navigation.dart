import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/home/home_screen.dart';
import '../features/notes/screens/notes_list_screen.dart';
import '../features/settings/settings_screen.dart';

// Current tab index provider
final currentTabIndexProvider = StateProvider<int>((ref) => 0);

class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  ConsumerState<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const NotesListScreen(),
      const HomeScreen(),
      const SettingsScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(currentTabIndexProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          ref.read(currentTabIndexProvider.notifier).state = index;
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.notes_outlined),
            selectedIcon: Icon(Icons.notes),
            label: 'Notes',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today),
            label: 'Meetings',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      floatingActionButton: currentIndex == 1
          ? FloatingActionButton.extended(
              onPressed: () => _showRecordingOptions(context),
              icon: const Icon(Icons.mic),
              label: const Text('Record'),
            )
          : null,
    );
  }

  void _showRecordingOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Text(
              'Start Recording',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.mic),
              ),
              title: const Text('Quick Recording'),
              subtitle: const Text('Start a new recording without a calendar event'),
              onTap: () {
                Navigator.pop(context);
                _startQuickRecording();
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.event),
              ),
              title: const Text('From Calendar Event'),
              subtitle: const Text('Select a meeting from your calendar'),
              onTap: () {
                Navigator.pop(context);
                // The calendar view on HomeScreen shows meetings
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Select a meeting from the calendar to record'),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _startQuickRecording() {
    // Navigate to recording screen for quick recording
    // This will be handled by go_router
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Quick recording feature coming soon'),
      ),
    );
  }
}
