import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/services/gemini_service.dart';
import 'core/services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: '.env');

  // Initialize storage
  final storageService = StorageService();
  await storageService.initialize();

  // Initialize Gemini service with API key from .env
  final geminiService = GeminiService();
  final apiKey = dotenv.env['GEMINI_API_KEY'];
  if (apiKey != null && apiKey.isNotEmpty && apiKey != 'your_api_key_here') {
    await geminiService.initialize(apiKey);
  }

  runApp(
    ProviderScope(
      overrides: [
        // Provide pre-initialized storage service
      ],
      child: const KurippuApp(),
    ),
  );
}

