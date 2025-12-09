import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/services/services.dart';

// ============ Singleton Service Instances ============
// These are initialized once and shared across the app

final _storageService = StorageService();
final _audioService = AudioService();
final _calendarService = CalendarService();
final _geminiService = GeminiService();

// ============ Service Providers ============

final storageServiceProvider = Provider<StorageService>((ref) {
  return _storageService;
});

final audioServiceProvider = Provider<AudioService>((ref) {
  return _audioService;
});

final calendarServiceProvider = Provider<CalendarService>((ref) {
  return _calendarService;
});

final geminiServiceProvider = Provider<GeminiService>((ref) {
  return _geminiService;
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
    // First try secure storage
    var key = await _storage.read(key: _apiKeyKey);
    
    // Fallback to .env file
    if (key == null || key.isEmpty) {
      key = dotenv.env['GEMINI_API_KEY'];
      if (key != null && key.isNotEmpty && key != 'your_api_key_here') {
        // Store in secure storage for future use
        await _storage.write(key: _apiKeyKey, value: key);
      }
    }
    
    if (key != null && key.isNotEmpty && key != 'your_api_key_here') {
      state = key;
      // Initialize Gemini with the key
      await _geminiService.initialize(key);
    }
  }

  Future<void> setApiKey(String apiKey) async {
    await _storage.write(key: _apiKeyKey, value: apiKey);
    state = apiKey;
    // Initialize Gemini with new key
    await _geminiService.initialize(apiKey);
  }

  Future<void> clearApiKey() async {
    await _storage.delete(key: _apiKeyKey);
    state = null;
  }
}

// ============ App Initialization Provider ============

final appInitializationProvider = FutureProvider<bool>((ref) async {
  // Initialize storage service
  await _storageService.initialize();
  
  // Load API key (this will also initialize Gemini if key exists)
  // Just reading the provider will trigger ApiKeyNotifier._loadApiKey()
  ref.read(apiKeyProvider);
  
  return true;
});

// ============ Gemini Initialization Provider ============

final geminiInitializedProvider = Provider<bool>((ref) {
  return _geminiService.isInitialized;
});
