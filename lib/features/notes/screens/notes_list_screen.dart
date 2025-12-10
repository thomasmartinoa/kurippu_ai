import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/models.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/note_providers.dart';
import 'note_editor_screen.dart';

class NotesListScreen extends ConsumerStatefulWidget {
  const NotesListScreen({super.key});

  @override
  ConsumerState<NotesListScreen> createState() => _NotesListScreenState();
}

class _NotesListScreenState extends ConsumerState<NotesListScreen> {
  bool _isGridView = true;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _toggleViewMode() {
    setState(() => _isGridView = !_isGridView);
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        ref.read(noteSearchQueryProvider.notifier).state = '';
      } else {
        _searchFocusNode.requestFocus();
      }
    });
  }

  void _onSearchChanged(String query) {
    ref.read(noteSearchQueryProvider.notifier).state = query;
  }

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => _FilterSheet(),
    );
  }

  void _openNoteEditor([String? noteId]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NoteEditorScreen(noteId: noteId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final notes = ref.watch(filteredNotesProvider);
    final currentFilter = ref.watch(noteFilterProvider);
    final foldersAsync = ref.watch(foldersNotifierProvider);
    final folders = foldersAsync.valueOrNull ?? [];
    final selectedFolderId = ref.watch(selectedFolderProvider);

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search notes...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.5)),
                ),
                style: theme.textTheme.titleMedium,
              )
            : Text(_getFilterTitle(currentFilter, selectedFolderId, folders)),
        leading: _isSearching
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _toggleSearch,
              )
            : null,
        actions: [
          if (!_isSearching) ...[
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: _toggleSearch,
              tooltip: 'Search',
            ),
            IconButton(
              icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
              onPressed: _toggleViewMode,
              tooltip: _isGridView ? 'List view' : 'Grid view',
            ),
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: _showFilterOptions,
              tooltip: 'Filter',
            ),
          ],
        ],
      ),
      drawer: _NotesDrawer(
        folders: folders,
        selectedFolderId: selectedFolderId,
        currentFilter: currentFilter,
        onFilterChanged: (filter) {
          ref.read(noteFilterProvider.notifier).state = filter;
          ref.read(selectedFolderProvider.notifier).state = null;
          Navigator.pop(context);
        },
        onFolderSelected: (folderId) {
          ref.read(selectedFolderProvider.notifier).state = folderId;
          ref.read(noteFilterProvider.notifier).state = NoteFilter.all;
          Navigator.pop(context);
        },
        onManageFolders: () {
          Navigator.pop(context);
          _showFolderManagement();
        },
      ),
      body: notes.isEmpty
          ? _buildEmptyState(currentFilter)
          : _isGridView
              ? _buildGridView(notes)
              : _buildListView(notes),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openNoteEditor(),
        icon: const Icon(Icons.add),
        label: const Text('New Note'),
      ),
    );
  }

  Widget _buildEmptyState(NoteFilter filter) {
    final theme = Theme.of(context);
    IconData icon;
    String title;
    String subtitle;

    switch (filter) {
      case NoteFilter.favorites:
        icon = Icons.star_border;
        title = 'No favorite notes';
        subtitle = 'Star notes to add them to favorites';
        break;
      case NoteFilter.archived:
        icon = Icons.archive_outlined;
        title = 'No archived notes';
        subtitle = 'Archived notes will appear here';
        break;
      case NoteFilter.trash:
        icon = Icons.delete_outline;
        title = 'Trash is empty';
        subtitle = 'Deleted notes will appear here';
        break;
      case NoteFilter.meetings:
        icon = Icons.mic_none;
        title = 'No meeting notes';
        subtitle = 'Record a meeting to create notes';
        break;
      default:
        icon = Icons.note_add_outlined;
        title = 'No notes yet';
        subtitle = 'Tap + to create your first note';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: theme.colorScheme.outline),
          const SizedBox(height: 16),
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridView(List<Note> notes) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: notes.length,
      itemBuilder: (context, index) => _NoteCard(
        note: notes[index],
        isGrid: true,
        onTap: () => _openNoteEditor(notes[index].id),
        onLongPress: () => _showNoteOptions(notes[index]),
      ),
    );
  }

  Widget _buildListView(List<Note> notes) {
    // Group notes by pinned status
    final pinnedNotes = notes.where((n) => n.isPinned).toList();
    final otherNotes = notes.where((n) => !n.isPinned).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (pinnedNotes.isNotEmpty) ...[
          _SectionHeader(title: 'Pinned', icon: Icons.push_pin),
          const SizedBox(height: 8),
          ...pinnedNotes.map((note) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _NoteCard(
                  note: note,
                  isGrid: false,
                  onTap: () => _openNoteEditor(note.id),
                  onLongPress: () => _showNoteOptions(note),
                ),
              )),
          const SizedBox(height: 16),
        ],
        if (otherNotes.isNotEmpty) ...[
          if (pinnedNotes.isNotEmpty)
            _SectionHeader(title: 'Others', icon: Icons.notes),
          if (pinnedNotes.isNotEmpty) const SizedBox(height: 8),
          ...otherNotes.map((note) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _NoteCard(
                  note: note,
                  isGrid: false,
                  onTap: () => _openNoteEditor(note.id),
                  onLongPress: () => _showNoteOptions(note),
                ),
              )),
        ],
      ],
    );
  }

  void _showNoteOptions(Note note) {
    final notesNotifier = ref.read(notesNotifierProvider.notifier);
    
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(context);
                _openNoteEditor(note.id);
              },
            ),
            ListTile(
              leading: Icon(note.isPinned ? Icons.push_pin : Icons.push_pin_outlined),
              title: Text(note.isPinned ? 'Unpin' : 'Pin'),
              onTap: () async {
                Navigator.pop(context);
                await notesNotifier.togglePin(note.id);
              },
            ),
            ListTile(
              leading: Icon(note.isFavorite ? Icons.star : Icons.star_border),
              title: Text(note.isFavorite ? 'Remove from favorites' : 'Add to favorites'),
              onTap: () async {
                Navigator.pop(context);
                await notesNotifier.toggleFavorite(note.id);
              },
            ),
            if (!note.isArchived && !note.isDeleted)
              ListTile(
                leading: const Icon(Icons.archive_outlined),
                title: const Text('Archive'),
                onTap: () async {
                  Navigator.pop(context);
                  await notesNotifier.archiveNote(note.id);
                },
              ),
            if (note.isArchived)
              ListTile(
                leading: const Icon(Icons.unarchive_outlined),
                title: const Text('Unarchive'),
                onTap: () async {
                  Navigator.pop(context);
                  await notesNotifier.unarchiveNote(note.id);
                },
              ),
            if (!note.isDeleted)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Delete', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(context);
                  await notesNotifier.moveToTrash(note.id);
                },
              ),
            if (note.isDeleted) ...[
              ListTile(
                leading: const Icon(Icons.restore),
                title: const Text('Restore'),
                onTap: () async {
                  Navigator.pop(context);
                  await notesNotifier.restoreFromTrash(note.id);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text('Delete permanently', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(context);
                  final confirmed = await showDialog<bool>(
                    context: this.context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete permanently?'),
                      content: const Text('This action cannot be undone.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await notesNotifier.permanentlyDelete(note.id);
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getFilterTitle(NoteFilter filter, String? folderId, List<Folder> folders) {
    if (folderId != null) {
      final folder = folders.firstWhere(
        (f) => f.id == folderId,
        orElse: () {
          final f = Folder();
          f.id = '';
          f.name = 'Unknown';
          return f;
        },
      );
      return folder.name;
    }

    switch (filter) {
      case NoteFilter.all:
        return 'All Notes';
      case NoteFilter.favorites:
        return 'Favorites';
      case NoteFilter.archived:
        return 'Archived';
      case NoteFilter.trash:
        return 'Trash';
      case NoteFilter.meetings:
        return 'Meeting Notes';
    }
  }

  void _showFolderManagement() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => _FolderManagementSheet(
          scrollController: scrollController,
        ),
      ),
    );
  }
}

// Notes Drawer
class _NotesDrawer extends StatelessWidget {
  final List<Folder> folders;
  final String? selectedFolderId;
  final NoteFilter currentFilter;
  final Function(NoteFilter) onFilterChanged;
  final Function(String) onFolderSelected;
  final VoidCallback onManageFolders;

  const _NotesDrawer({
    required this.folders,
    required this.selectedFolderId,
    required this.currentFilter,
    required this.onFilterChanged,
    required this.onFolderSelected,
    required this.onManageFolders,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Text(
                'Kurippu',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const Divider(),
            _DrawerItem(
              icon: Icons.notes,
              title: 'All Notes',
              isSelected: currentFilter == NoteFilter.all && selectedFolderId == null,
              onTap: () => onFilterChanged(NoteFilter.all),
            ),
            _DrawerItem(
              icon: Icons.star_outline,
              title: 'Favorites',
              isSelected: currentFilter == NoteFilter.favorites,
              onTap: () => onFilterChanged(NoteFilter.favorites),
            ),
            _DrawerItem(
              icon: Icons.mic,
              title: 'Meeting Notes',
              isSelected: currentFilter == NoteFilter.meetings,
              onTap: () => onFilterChanged(NoteFilter.meetings),
            ),
            _DrawerItem(
              icon: Icons.archive_outlined,
              title: 'Archived',
              isSelected: currentFilter == NoteFilter.archived,
              onTap: () => onFilterChanged(NoteFilter.archived),
            ),
            _DrawerItem(
              icon: Icons.delete_outline,
              title: 'Trash',
              isSelected: currentFilter == NoteFilter.trash,
              onTap: () => onFilterChanged(NoteFilter.trash),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Folders',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined, size: 20),
                    onPressed: onManageFolders,
                    tooltip: 'Manage folders',
                  ),
                ],
              ),
            ),
            if (folders.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'No folders yet',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              )
            else
              ...folders.map((folder) => _DrawerItem(
                    icon: Icons.folder,
                    iconColor: folder.color != null ? _parseColor(folder.color!) : null,
                    title: folder.name,
                    trailing: folder.noteCount > 0 ? '${folder.noteCount}' : null,
                    isSelected: selectedFolderId == folder.id,
                    onTap: () => onFolderSelected(folder.id),
                  )),
          ],
        ),
      ),
    );
  }

  Color _parseColor(String colorStr) {
    try {
      if (colorStr.startsWith('#')) {
        return Color(int.parse(colorStr.substring(1), radix: 16) | 0xFF000000);
      }
      return Color(int.parse(colorStr));
    } catch (_) {
      return Colors.grey;
    }
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? trailing;
  final bool isSelected;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    this.iconColor,
    required this.title,
    this.trailing,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? colorScheme.primary : iconColor ?? colorScheme.onSurfaceVariant,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: isSelected ? colorScheme.primary : null,
        ),
      ),
      trailing: trailing != null
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(trailing!, style: theme.textTheme.bodySmall),
            )
          : null,
      selected: isSelected,
      selectedTileColor: colorScheme.primaryContainer.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      onTap: onTap,
    );
  }
}

// Note Card
class _NoteCard extends StatelessWidget {
  final Note note;
  final bool isGrid;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _NoteCard({
    required this.note,
    required this.isGrid,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final content = note.plainTextContent ?? note.content;
    final preview = content.length > 150 ? '${content.substring(0, 150)}...' : content;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: note.isPinned
              ? colorScheme.primary.withOpacity(0.5)
              : colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with icons
              Row(
                children: [
                  if (note.type == NoteType.meeting)
                    Icon(Icons.mic, size: 16, color: colorScheme.primary),
                  if (note.type == NoteType.checklist)
                    Icon(Icons.checklist, size: 16, color: colorScheme.primary),
                  if (note.type == NoteType.voice)
                    Icon(Icons.keyboard_voice, size: 16, color: colorScheme.primary),
                  if (note.priority == NotePriority.high)
                    Icon(Icons.flag, size: 16, color: Colors.orange),
                  const Spacer(),
                  if (note.isFavorite)
                    Icon(Icons.star, size: 16, color: Colors.amber),
                  if (note.isPinned)
                    Icon(Icons.push_pin, size: 16, color: colorScheme.primary),
                ],
              ),

              const SizedBox(height: 8),

              // Title
              Text(
                note.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: isGrid ? 2 : 1,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 4),

              // Preview
              Expanded(
                child: Text(
                  preview,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: isGrid ? 5 : 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              const SizedBox(height: 8),

              // Footer
              Row(
                children: [
                  Text(
                    _formatDate(note.updatedAt),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.outline,
                    ),
                  ),
                  if (note.tags.isNotEmpty) ...[
                    const Spacer(),
                    Icon(Icons.label_outline, size: 14, color: colorScheme.outline),
                    const SizedBox(width: 4),
                    Text(
                      '${note.tags.length}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.outline,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return '${diff.inMinutes}m ago';
      }
      return '${diff.inHours}h ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// Filter Sheet
class _FilterSheet extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentFilter = ref.watch(noteFilterProvider);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Filter Notes', style: theme.textTheme.titleLarge),
          ),
          ...NoteFilter.values.map((filter) => RadioListTile<NoteFilter>(
                value: filter,
                groupValue: currentFilter,
                title: Text(_getFilterName(filter)),
                secondary: Icon(_getFilterIcon(filter)),
                onChanged: (value) {
                  if (value != null) {
                    ref.read(noteFilterProvider.notifier).state = value;
                    Navigator.pop(context);
                  }
                },
              )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  String _getFilterName(NoteFilter filter) {
    switch (filter) {
      case NoteFilter.all:
        return 'All Notes';
      case NoteFilter.favorites:
        return 'Favorites';
      case NoteFilter.archived:
        return 'Archived';
      case NoteFilter.trash:
        return 'Trash';
      case NoteFilter.meetings:
        return 'Meeting Notes';
    }
  }

  IconData _getFilterIcon(NoteFilter filter) {
    switch (filter) {
      case NoteFilter.all:
        return Icons.notes;
      case NoteFilter.favorites:
        return Icons.star_outline;
      case NoteFilter.archived:
        return Icons.archive_outlined;
      case NoteFilter.trash:
        return Icons.delete_outline;
      case NoteFilter.meetings:
        return Icons.mic;
    }
  }
}

// Folder Management Sheet
class _FolderManagementSheet extends ConsumerStatefulWidget {
  final ScrollController scrollController;

  const _FolderManagementSheet({required this.scrollController});

  @override
  ConsumerState<_FolderManagementSheet> createState() => _FolderManagementSheetState();
}

class _FolderManagementSheetState extends ConsumerState<_FolderManagementSheet> {
  final TextEditingController _nameController = TextEditingController();
  int _selectedColor = 0xFF6200EE;

  final List<int> _folderColors = [
    0xFF6200EE, // Purple
    0xFF03DAC5, // Teal
    0xFFFF5722, // Deep Orange
    0xFF4CAF50, // Green
    0xFF2196F3, // Blue
    0xFFE91E63, // Pink
    0xFFFFEB3B, // Yellow
    0xFF9C27B0, // Purple
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _createFolder() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final folder = Folder.create(
      id: '',
      name: name,
      color: '#${_selectedColor.toRadixString(16).padLeft(8, '0')}',
    );

    await ref.read(foldersNotifierProvider.notifier).addFolder(folder);
    _nameController.clear();
    setState(() => _selectedColor = _folderColors[0]);
  }

  void _deleteFolder(Folder folder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Folder'),
        content: Text('Delete "${folder.name}"? Notes in this folder will not be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(foldersNotifierProvider.notifier).deleteFolder(folder.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foldersAsync = ref.watch(foldersNotifierProvider);
    final folders = foldersAsync.value ?? [];

    return Column(
      children: [
        // Handle
        Container(
          margin: const EdgeInsets.only(top: 8),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        // Title
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text('Manage Folders', style: theme.textTheme.titleLarge),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),

        // Create folder
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('New Folder', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      hintText: 'Folder name',
                      prefixIcon: Icon(Icons.folder_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: _folderColors.map((color) {
                      final isSelected = color == _selectedColor;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedColor = color),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Color(color),
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: theme.colorScheme.onSurface, width: 2)
                                : null,
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, size: 16, color: Colors.white)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _createFolder,
                      child: const Text('Create'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Folder list
        Expanded(
          child: folders.isEmpty
              ? Center(
                  child: Text(
                    'No folders created yet',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                )
              : ListView.builder(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: folders.length,
                  itemBuilder: (context, index) {
                    final folder = folders[index];
                    return Card(
                      child: ListTile(
                        leading: Icon(
                          Icons.folder,
                          color: folder.color != null ? _parseColor(folder.color!) : null,
                        ),
                        title: Text(folder.name),
                        subtitle: Text('${folder.noteCount} notes'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _deleteFolder(folder),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Color _parseColor(String colorStr) {
    try {
      if (colorStr.startsWith('#')) {
        return Color(int.parse(colorStr.substring(1), radix: 16) | 0xFF000000);
      }
      return Color(int.parse(colorStr));
    } catch (_) {
      return Colors.grey;
    }
  }
}
