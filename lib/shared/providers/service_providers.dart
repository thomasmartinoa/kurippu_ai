import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/services/services.dart';

// ============ Service Providers ============

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

final audioServiceProvider = Provider<AudioService>((ref) {
  return AudioService();
});

final calendarServiceProvider = Provider<CalendarService>((ref) {
  return CalendarService();
});

final geminiServiceProvider = Provider<GeminiService>((ref) {
  return GeminiService();
});

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

// ============ API Key Provider ============

final apiKeyProvider = StateNotifierProvider<ApiKeyNotifier, String?>((ref) {
  return ApiKeyNotifier(ref.watch(secureStorageProvider));
});

class ApiKeyNotifier extends StateNotifier<String?> {
  final FlutterSecureStorage _storage;
  static const _apiKeyKey = 'gemini_api_key';

  ApiKeyNotifier(this._storage) : super(null) {
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    state = await _storage.read(key: _apiKeyKey);
  }

  Future<void> setApiKey(String apiKey) async {
    await _storage.write(key: _apiKeyKey, value: apiKey);
    state = apiKey;
  }

  Future<void> clearApiKey() async {
    await _storage.delete(key: _apiKeyKey);
    state = null;
  }
}

// ============ Gemini Initialization Provider ============

final geminiInitializedProvider = FutureProvider<bool>((ref) async {
  final apiKey = ref.watch(apiKeyProvider);
  if (apiKey == null || apiKey.isEmpty) {
    return false;
  }

  final geminiService = ref.read(geminiServiceProvider);
  await geminiService.initialize(apiKey);
  return true;
});
