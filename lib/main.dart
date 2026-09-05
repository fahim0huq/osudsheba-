import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'firebase_options.dart';
import 'app/app.dart';
import 'core/services/local_storage_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/mock_data_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await GoogleSignIn.instance.initialize(
    clientId: kIsWeb ? '429979113631-j8tke7aulp7rg9moli0deu9lmv3fseh5.apps.googleusercontent.com' : null,
    serverClientId: kIsWeb ? null : '429979113631-j8tke7aulp7rg9moli0deu9lmv3fseh5.apps.googleusercontent.com',
  );
  
  final storageService = LocalStorageService();
  await storageService.init();
  
  final notificationService = NotificationService.instance;
  await notificationService.init();
  await notificationService.requestPermissions();

  final container = ProviderContainer();
  final medicines = container.read(medicinesProvider);
  await notificationService.rescheduleAll(medicines);
  
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const OsudShebaApp(),
    ),
  );
}
