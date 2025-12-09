import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/services/storage_service.dart';
import '../../data/models/note.dart';
import 'service_providers.dart';

const _uuid = Uuid();

// ============ Note List Provider ============

enum NoteFilter {
  all,
  favorites,
  archived,
  trash,
  meetings,
}

final noteFilterProvider = StateProvider<NoteFilter>((ref) => NoteFilter.all);
final selectedFolderProvider = StateProvider<String?>((ref) => null);
final selectedTagProvider = StateProvider<String?>((ref) => null);
final noteSearchQueryProvider = StateProvider<String>((ref) => '');

final notesProvider =
    StateNotifierProvider<NotesNotifier, AsyncValue<List<Note>>>((ref) {
  return NotesNotifier(ref.watch(storageServiceProvider), ref);
});

class NotesNotifier extends StateNotifier<AsyncValue<List<Note>>> {
  final StorageService _storageService;
  final Ref _ref;

  NotesNotifier(this._storageService, this._ref) : super(const AsyncValue.loading()) {
    loadNotes();
  }

  Future<void> loadNotes() async {
    state = const AsyncValue.loading();
    try {
      final filter = _ref.read(noteFilterProvider);
      final folderId = _ref.read(selectedFolderProvider);
      final tagName = _ref.read(selectedTagProvider);
      final searchQuery = _ref.read(noteSearchQueryProvider);

      List<Note> notes;

      if (searchQuery.isNotEmpty) {
        notes = await _storageService.searchNotes(searchQuery);
      } else if (tagName != null) {
        notes = await _storageService.getNotesByTag(tagName);
      } else if (folderId != null) {
        notes = await _storageService.getNotesByFolder(folderId);
      } else {
        switch (filter) {
          case NoteFilter.favorites:
            notes = await _storageService.getFavoriteNotes();
          case NoteFilter.archived:
            notes = await _storageService.getArchivedNotes();
          case NoteFilter.trash:
            notes = await _storageService.getDeletedNotes();
          case NoteFilter.meetings:
            notes = await _storageService.getMeetingNotes();
          case NoteFilter.all:
            notes = await _storageService.getAllNotes();
        }
      }

      state = AsyncValue.data(notes);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<Note> createNote({
    required String title,
    String content = '',
    NoteType type = NoteType.text,
    String? folderId,
    List<String> tags = const [],
    String? meetingId,
    String? color,
  }) async {
    final note = Note()
      ..id = _uuid.v4()
      ..title = title
      ..content = content
      ..plainTextContent = content.replaceAll(RegExp(r'<[^>]*>'), '')
      ..type = type
      ..folderId = folderId
      ..tags = List.from(tags)
      ..meetingId = meetingId
      ..color = color;

    await _storageService.saveNote(note);
    await loadNotes();
    return note;
  }

  Future<void> updateNote(Note note) async {
    note.updatedAt = DateTime.now();
    await _storageService.saveNote(note);
    await loadNotes();
  }

  Future<void> togglePin(String noteId) async {
    final note = await _storageService.getNoteById(noteId);
    if (note != null) {
      note.isPinned = !note.isPinned;
      await _storageService.saveNote(note);
      await loadNotes();
    }
  }

  Future<void> toggleFavorite(String noteId) async {
    final note = await _storageService.getNoteById(noteId);
    if (note != null) {
      note.isFavorite = !note.isFavorite;
      await _storageService.saveNote(note);
      await loadNotes();
    }
  }

  Future<void> moveToFolder(String noteId, String? folderId) async {
    final note = await _storageService.getNoteById(noteId);
    if (note != null) {
      note.folderId = folderId;
      await _storageService.saveNote(note);
      await loadNotes();
    }
  }

  Future<void> addTag(String noteId, String tagName) async {
    final note = await _storageService.getNoteById(noteId);
    if (note != null && !note.tags.contains(tagName)) {
      note.tags.add(tagName);
      await _storageService.saveNote(note);
      
      // Ensure tag exists
      var tag = await _storageService.getTagByName(tagName);
      if (tag == null) {
        tag = Tag()
          ..id = _uuid.v4()
          ..name = tagName;
        await _storageService.saveTag(tag);
      }
      
      await loadNotes();
    }
  }

  Future<void> removeTag(String noteId, String tagName) async {
    final note = await _storageService.getNoteById(noteId);
    if (note != null) {
      note.tags.remove(tagName);
      await _storageService.saveNote(note);
      await loadNotes();
    }
  }

  Future<void> archiveNote(String noteId) async {
    await _storageService.archiveNote(noteId);
    await loadNotes();
  }

  Future<void> unarchiveNote(String noteId) async {
    await _storageService.unarchiveNote(noteId);
    await loadNotes();
  }

  Future<void> deleteNote(String noteId) async {
    await _storageService.softDeleteNote(noteId);
    await loadNotes();
  }

  Future<void> restoreNote(String noteId) async {
    await _storageService.restoreNote(noteId);
    await loadNotes();
  }

  Future<void> permanentlyDeleteNote(String noteId) async {
    await _storageService.permanentlyDeleteNote(noteId);
    await loadNotes();
  }

  Future<void> emptyTrash() async {
    await _storageService.emptyTrash();
    await loadNotes();
  }

  Future<void> setNoteColor(String noteId, String? color) async {
    final note = await _storageService.getNoteById(noteId);
    if (note != null) {
      note.color = color;
      await _storageService.saveNote(note);
      await loadNotes();
    }
  }
}

// ============ Single Note Provider ============

final noteDetailProvider =
    FutureProvider.family<Note?, String>((ref, noteId) async {
  final storageService = ref.watch(storageServiceProvider);
  return storageService.getNoteById(noteId);
});

// ============ Folder Providers ============

final foldersProvider =
    StateNotifierProvider<FoldersNotifier, AsyncValue<List<Folder>>>((ref) {
  return FoldersNotifier(ref.watch(storageServiceProvider));
});

class FoldersNotifier extends StateNotifier<AsyncValue<List<Folder>>> {
  final StorageService _storageService;

  FoldersNotifier(this._storageService) : super(const AsyncValue.loading()) {
    loadFolders();
  }

  Future<void> loadFolders() async {
    state = const AsyncValue.loading();
    try {
      final folders = await _storageService.getAllFolders();
      await _storageService.updateFolderNoteCounts();
      state = AsyncValue.data(folders);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<Folder> createFolder({
    required String name,
    String? icon,
    String? color,
  }) async {
    final folder = Folder()
      ..id = _uuid.v4()
      ..name = name
      ..icon = icon
      ..color = color;

    await _storageService.saveFolder(folder);
    await loadFolders();
    return folder;
  }

  Future<void> updateFolder(Folder folder) async {
    await _storageService.saveFolder(folder);
    await loadFolders();
  }

  Future<void> deleteFolder(String folderId) async {
    await _storageService.deleteFolder(folderId);
    await loadFolders();
  }
}

// ============ Tag Providers ============

final tagsProvider =
    StateNotifierProvider<TagsNotifier, AsyncValue<List<Tag>>>((ref) {
  return TagsNotifier(ref.watch(storageServiceProvider));
});

class TagsNotifier extends StateNotifier<AsyncValue<List<Tag>>> {
  final StorageService _storageService;

  TagsNotifier(this._storageService) : super(const AsyncValue.loading()) {
    loadTags();
  }

  Future<void> loadTags() async {
    state = const AsyncValue.loading();
    try {
      final tags = await _storageService.getAllTags();
      await _storageService.updateTagNoteCounts();
      state = AsyncValue.data(tags);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<Tag> createTag({
    required String name,
    String? color,
  }) async {
    // Check if tag already exists
    var existingTag = await _storageService.getTagByName(name);
    if (existingTag != null) {
      return existingTag;
    }

    final tag = Tag()
      ..id = _uuid.v4()
      ..name = name
      ..color = color;

    await _storageService.saveTag(tag);
    await loadTags();
    return tag;
  }

  Future<void> deleteTag(String tagId) async {
    await _storageService.deleteTag(tagId);
    await loadTags();
  }
}

// ============ Recent Notes Provider ============

final recentNotesProvider = FutureProvider<List<Note>>((ref) async {
  final storageService = ref.watch(storageServiceProvider);
  return storageService.getRecentNotes(limit: 5);
});

// ============ Note Stats Provider ============

final noteStatsProvider = FutureProvider<NoteStats>((ref) async {
  final storageService = ref.watch(storageServiceProvider);
  
  final allNotes = await storageService.getAllNotes();
  final archivedNotes = await storageService.getArchivedNotes();
  final deletedNotes = await storageService.getDeletedNotes();
  final meetingNotes = await storageService.getMeetingNotes();
  final favoriteNotes = await storageService.getFavoriteNotes();
  
  return NoteStats(
    totalNotes: allNotes.length,
    archivedNotes: archivedNotes.length,
    deletedNotes: deletedNotes.length,
    meetingNotes: meetingNotes.length,
    favoriteNotes: favoriteNotes.length,
  );
});

class NoteStats {
  final int totalNotes;
  final int archivedNotes;
  final int deletedNotes;
  final int meetingNotes;
  final int favoriteNotes;

  NoteStats({
    required this.totalNotes,
    required this.archivedNotes,
    required this.deletedNotes,
    required this.meetingNotes,
    required this.favoriteNotes,
  });
}
