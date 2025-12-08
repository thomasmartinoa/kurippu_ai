import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize storage
  final storageService = StorageService();
  await storageService.initialize();

  runApp(
    ProviderScope(
      overrides: [
        // Provide pre-initialized storage service
      ],
      child: const KurippuApp(),
    ),
  );
}

